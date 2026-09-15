"""Generate reviewable schema/API appendices directly from executable definitions."""
from pathlib import Path
import sqlite3,json,re
root=Path(__file__).resolve().parents[1]
sql=(root/'server/src/main/resources/schema.sql').read_text()
(root/'docs/Database_Schema.sql').write_text(sql)
db=sqlite3.connect(':memory:');db.executescript(sql)
lines=['# Study Arena — Complete database dictionary','', 'Generated from `Database_Schema.sql`. SQLite `REAL` timestamps are UTC Unix seconds; BOOLEAN flags use INTEGER 0/1. JSON arrays/objects use TEXT and are validated by Java. Primary keys, compound uniqueness, CHECK clauses and triggers are authoritative in the SQL appendix. `NULL` means not recorded or not applicable, not zero.','']
tables=db.execute("select name,sql from sqlite_master where type='table' and name not like 'sqlite_%' order by name").fetchall()
for table,ddl in tables:
 lines += [f'## `{table}`','', '| Column | SQLite type | Nullable | Default | Primary-key position |','|---|---|---|---|---|']
 for _,name,typ,notnull,default,pk in db.execute(f'pragma table_info("{table}")'):
  lines.append(f'| `{name}` | {typ} | {"No" if notnull or pk else "Yes"} | `{default}` | {pk or "—"} |')
 fks=db.execute(f'pragma foreign_key_list("{table}")').fetchall()
 if fks:
  lines += ['','Foreign keys:','']+[f'- `{r[3]}` → `{r[2]}.{r[4]}`; delete {r[6]}; update {r[5]}.' for r in fks]
 indices=db.execute(f'pragma index_list("{table}")').fetchall()
 if indices:
  lines += ['','Indexes and uniqueness:','']
  for r in indices:
   names=', '.join(str(x[2]) for x in db.execute(f'pragma index_info("{r[1]}")'))
   definition=db.execute('select sql from sqlite_master where name=?',(r[1],)).fetchone()
   lines.append(f'- `{r[1]}` ({names}); {"UNIQUE" if r[2] else "non-unique"}; '+(f'`{definition[0]}`' if definition and definition[0] else 'automatic primary/unique constraint.'))
 lines += ['','Complete table constraints:','','```sql',ddl+';','```','']
(root/'docs/Database_Dictionary.md').write_text('\n'.join(lines))
contracts=json.loads((root/'docs/api-contract.json').read_text())['endpoints']
head='''# Study Arena — Part 3: API and state machines

## API conventions

The route table below is generated from the same registry that serves requests. JSON bodies only; UTF-8; API prefix `/api`. Timestamps are UTC Unix seconds, not milliseconds. UUIDs are preferred for client activity IDs; seeded content has readable IDs. All successful mutations return HTTP 200, including safe replays. No operation returns an invented success while waiting for an external payout.

`public` accepts an optional bearer token to include the caller's accessible content. `student` means any authenticated, non-suspended user, acting on their own resources. `moderator` means teacher or administrator; cohort and object checks still apply. `admin` means administrator only. Role checks never replace object authorization.

Every row with **key required** needs `Idempotency-Key: <16–100 alphanumeric, underscore or hyphen characters>`. Generate one UUID before the first attempt, persist it, and reuse it on retry. Do not create a new key after an uncertain timeout. The key is scoped to the account and bound to method, path and body. Recent authentication means a successful login within the last 10 minutes; no password is asked from a room peer.

Pagination defaults to 30, maximum 100, with nonnegative `offset`. A saved deck fetches pages until `total` is reached. File downloads use byte offsets, 256 KB chunks, a final checksum, and a complete flag. Upload JSON is capped below the 2 MB request limit; file limit is 10 MB.

`?` on a field marks optional input. Record response names resolve to the columns/types in `Database_Dictionary.md` with the privacy projections listed after the table. Standard GET caches are client-encrypted; admin/export requests never enter the offline API cache.

### Endpoint surface

| Method and endpoint | Authorization / retry | Request or query shape | Success response shape | Specific errors, in addition to common errors |
|---|---|---|---|---|
'''
lines=[head]
for c in contracts:
 if c['path'].startswith('/api/demo'): continue
 esc=lambda s:str(s).replace('|','\\|').replace('\n',' ')
 lines.append(f"| `{c['method']} {c['path']}` | {c['auth']}; {'key required' if c['idempotency'] else 'no key required'} | `{esc(c['request'])}` | `{esc(c['response'])}` | {esc(c['errors']) or '—'} |")
lines += ['','### Error envelope and common errors','','Every error is `{ "error": { "code": "CODE", "message": "Human-readable reason", "request_id": "UUID" } }`. A retry must retain the activity key. Field-validation failures preserve the local form; authentication failures preserve saved study work. Unknown server failures contain a request ID and no stack trace or private fields.','']
# Include every literal domain error emitted anywhere, not only declared endpoint summaries.
errors={}
for path in (root/'server/src/main/java').rglob('*.java'):
 for match in re.finditer(r'(?:require\([^;]*?|new Fault\()\s*(400|401|403|404|405|409|413|415|422|429|500|503)\s*,\s*"([A-Z_]+)"',path.read_text()):errors.setdefault(match[2],set()).add(int(match[1]))
for code,status in [('INTERNAL_ERROR',500),('IDEMPOTENCY_REQUIRED',400),('IDEMPOTENCY_CONFLICT',409),('AUTH_REQUIRED',401),('CONTENT_TYPE',415),('ORIGIN_DENIED',403),('BODY_TOO_LARGE',413),('RATE_LIMITED',429),('FORBIDDEN',403),('NOT_FOUND',404),('VALIDATION',422)]:errors.setdefault(code,set()).add(status)
lines += ['| Error code | HTTP status | Client behavior |','|---|---|---|']
for code,status in sorted(errors.items()):
 action='Correct the input or show the domain message; do not blindly retry.'
 if code in ['INTERNAL_ERROR','PUSH_PROVIDER']:action='Keep work and retry with the same key; give support the request ID.'
 elif code in ['AUTH_REQUIRED','REAUTH_REQUIRED','INVALID_CREDENTIALS']:action='Sign in again; retain the encrypted local workspace and queue.'
 elif code=='RATE_LIMITED':action='Back off; keep the same operation key and form contents.'
 elif code in ['VERSION_CONFLICT','CONTENT_CHANGED']:action='Keep the local version, show conflict, reload current content or preserve a conflict copy.'
 elif code=='IDEMPOTENCY_CONFLICT':action='Investigate key reuse; do not silently change keys for an uncertain committed operation.'
 lines.append(f'| `{code}` | {", ".join(map(str,sorted(status)))} | {action} |')
lines += ['''
### Response projections

- `User`: `users` columns except `password_hash`, `school_hash`, `school_cipher`, `consent_ref`; subjects is a JSON array. Server data export can include a separately decrypted school ID, never the password hash or bearer credentials.
- `StudySession`: never returns `notes_cipher`. The owner's history/export includes decrypted `notes`; write responses return the timing/credit state. Other users and teacher analytics cannot access this record.
- `Deck`: deck metadata plus optional `card_count`; detail includes paginated cards and due schedule values for the requester. Public listing includes approved public decks and the owner's own decks.
- `Question`: `options` and `accepted` are arrays, not JSON strings. Solo quiz packages intentionally include accepted answers and explanations. Active duel projection strips both.
- `Attempt`: metadata plus the immutable question snapshot rendered as `questions` and the user's `answers`; raw `snapshot` TEXT is not duplicated in the response.
- `Material`: metadata and permitted body or verified binary chunks. List responses exclude full text bodies. Content entitlements are checked before material access.
- `Room`: no invitation hash is exposed. Creation/rotation returns the new plaintext code once. Roster contains display name, private-room band and join time; not email or school ID.
- `Duel`: player IDs are scoped to authenticated participants; public identity is the chosen display name. During play only the requester's submitted answers are returned, without correctness; after settlement the solutions are disclosed. Neither competitor receives the other's private study logs.
- `Wallet`: XP, coins, level, next-level XP and listed unlock thresholds. The level display is separately feature-flagged. Ledger adjustments are signed integers; resulting balances cannot be negative.
- `Admin`: teachers receive assigned content/report queues and cohort aggregates only. Administrators additionally receive access-management projections, flags, claims, catalog, ledger, audit and review signals. Neither receives a generic private-study-log endpoint.

### Non-idempotent and transient boundaries

Registration uses unique email/school identifiers. Login returns a new opaque session; the UI does not repeatedly retry a failed credential response. Reset/verification tokens are one-time and expire. GET `/duels/current` is an explicitly documented heartbeat/poll operation: it updates presence and may complete matchmaking/settlement even though it returns a view. File chunk writes live on a filesystem outside SQLite; an unknown file-upload timeout is resolved by inspecting the offset before continuing. Do not treat a filesystem write as a database transaction.

## Study-session state machine

```mermaid
stateDiagram-v2
 [*] --> Running: start
 Running --> Paused: interruption
 Paused --> Running: resume
 Running --> Completed: finish with valid evidence
 Paused --> Completed: finish with valid evidence
 Running --> Discarded: explicit discard
 Paused --> Discarded: explicit discard
 Running --> Uncredited: stale or invalid timing
 Completed --> [*]
 Uncredited --> [*]
 Discarded --> [*]
```

A connected session has server heartbeat evidence; heartbeat deltas cap at 120 seconds. The mobile web timer is local-first and submits one immutable completion. An offline log with less than five minutes or an overlap is `uncredited`. Invalid clock evidence is rejected for review and retained locally. Credited duration cannot exceed 180 minutes. The client pauses after four wall-clock hours or a large/negative clock jump. Notes survive interruptions and remain private.

A completion retry returns its previous result. A second device cannot run a second credited connected session. Offline overlap resolution uses first server acceptance; no app can prove simultaneous offline activity without a trusted witness.

## Duel state machine

```mermaid
stateDiagram-v2
 [*] --> Queued: verified opt-in
 Queued --> Active: same-band match
 Queued --> Cancelled: cancel
 Queued --> PracticeBot: choose after 20 seconds
 PracticeBot --> Completed: unranked finish
 Active --> Completed: both finish or deadline
 Active --> Forfeit: one disconnects beyond 20 seconds
 Active --> Forfeit: explicit forfeit
 Active --> Void: both disconnect or institution pauses
 Completed --> [*]
 Forfeit --> [*]
 Void --> [*]
 Cancelled --> [*]
```

Queue status is held in `duel_queue`; only active/settled rounds live in `duels`. The pilot uses exactly the same skill band, does not widen automatically, and exposes a labeled unranked bot after 20 seconds. The fixed 92-second deadline includes a two-second transport allowance for everyone. Late answers cannot add points. An operation retry cannot insert the same answer twice. Once a result is conclusive it is not changed because a client later disconnects. No exclusive XP or prize is earned by competing.

The question generator has three explicitly supported pilot topics: linear equations, elementary differentiation and binary conversion. It does not pretend to provide a comprehensive competitive question bank. Skill band is derived from learning evidence and cannot be lowered by repeatedly forfeiting. Queue entry is rate-limited to limit rematch spam; blocked peers are excluded.

Season membership is captured at duel creation. Season expiry never erases mastery, personal history, inventory or XP. Seasonal peer rankings and tournaments are deferred and have no live endpoints in this release.

## Reward redemption state machine

```mermaid
stateDiagram-v2
 [*] --> Validating: fixed-price request
 Validating --> Rejected: insufficient coins or stock or age
 Validating --> Owned: virtual entitlement
 Validating --> Pending: reserve prize and debit atomically
 Pending --> Approved: independent eligibility review
 Pending --> Denied: refund and release stock
 Pending --> Cancelled: student cancels
 Approved --> Fulfilled: record handover evidence
 Approved --> Denied: refund and release stock
 Approved --> Cancelled: student cancels
 Owned --> [*]
 Fulfilled --> [*]
 Denied --> [*]
 Cancelled --> [*]
 Rejected --> [*]
```

Validation and the debit/reservation are one transaction. Owning a nonconsumable returns the entitlement without another debit. A consumed freeze can be purchased again. One claim is allowed per account per prize offer; a new school offer gets a new catalog ID. Denial/cancellation appends a compensating entry and restores reserved stock exactly once. Fulfillment requires prior approval and a receipt reference. An administrator cannot approve their own prize claim. No cash transfer, payment entry or chance-based mechanic exists.

## Deferred API design, explicitly not live

A future tournament release adds `POST /tournaments`, `POST /tournaments/{id}/entries`, `POST /tournaments/{id}/start`, `GET /tournaments/{id}` and cancellation under room-owner authorization. Fields and uniqueness are in `Deferred_Extensions.sql`. Tournament entry requires consent and the same band; 2–8 participants; void rounds do not award points. A future `GET /rooms/{id}/standings?season=...` requires room membership and individual comparison opt-in and returns only chosen display names, cosmetics and seasonal points. These endpoints are specifications, not placeholder handlers.
''']
(root/'docs/Part_3_API_and_State_Machines.md').write_text('\n'.join(lines))
print(f'Documented {len(tables)} tables, {len(contracts)} registered endpoints, {len(errors)} literal error codes.')

# Study Arena — Complete database dictionary

Generated from `Database_Schema.sql`. SQLite `REAL` timestamps are UTC Unix seconds; BOOLEAN flags use INTEGER 0/1. JSON arrays/objects use TEXT and are validated by Java. Primary keys, compound uniqueness, CHECK clauses and triggers are authoritative in the SQL appendix. `NULL` means not recorded or not applicable, not zero.

## `answers`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `attempt_id` | TEXT | No | `None` | 1 |
| `question_id` | TEXT | No | `None` | 2 |
| `answer` | TEXT | No | `None` | — |
| `correct` | INTEGER | No | `None` | — |
| `answered` | REAL | No | `None` | — |

Foreign keys:

- `attempt_id` → `attempts.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `sqlite_autoindex_answers_1` (attempt_id, question_id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE answers (
 attempt_id TEXT NOT NULL REFERENCES attempts(id) ON DELETE CASCADE, question_id TEXT NOT NULL,
 answer TEXT NOT NULL, correct INTEGER NOT NULL CHECK(correct IN (0,1)), answered REAL NOT NULL,
 PRIMARY KEY(attempt_id,question_id)
);
```

## `attempts`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `user_id` | TEXT | No | `None` | — |
| `quiz_id` | TEXT | No | `None` | — |
| `state` | TEXT | No | `None` | — |
| `started` | REAL | No | `None` | — |
| `deadline` | REAL | Yes | `None` | — |
| `ended` | REAL | Yes | `None` | — |
| `question_order` | TEXT | No | `None` | — |
| `score` | INTEGER | No | `0` | — |
| `total` | INTEGER | No | `None` | — |
| `offline` | INTEGER | No | `0` | — |
| `flagged` | TEXT | No | `''` | — |
| `snapshot` | TEXT | No | `None` | — |

Foreign keys:

- `quiz_id` → `quizzes.id`; delete NO ACTION; update NO ACTION.
- `user_id` → `users.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `ix_one_active_attempt` (user_id, quiz_id); UNIQUE; `CREATE UNIQUE INDEX ix_one_active_attempt ON attempts(user_id,quiz_id) WHERE state='active'`
- `ix_attempt_user` (user_id, started); non-unique; `CREATE INDEX ix_attempt_user ON attempts(user_id,started)`
- `sqlite_autoindex_attempts_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE attempts (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, quiz_id TEXT NOT NULL REFERENCES quizzes(id),
 state TEXT NOT NULL CHECK(state IN ('active','completed','discarded','void')), started REAL NOT NULL, deadline REAL,
 ended REAL, question_order TEXT NOT NULL, score INTEGER NOT NULL DEFAULT 0, total INTEGER NOT NULL, offline INTEGER NOT NULL DEFAULT 0,
 flagged TEXT NOT NULL DEFAULT '', snapshot TEXT NOT NULL
);
```

## `audit`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `actor_id` | TEXT | Yes | `None` | — |
| `action` | TEXT | No | `None` | — |
| `target` | TEXT | No | `None` | — |
| `reason` | TEXT | No | `None` | — |
| `created` | REAL | No | `None` | — |
| `previous_hash` | TEXT | No | `None` | — |
| `entry_hash` | TEXT | No | `None` | — |

Foreign keys:

- `actor_id` → `users.id`; delete SET NULL; update NO ACTION.

Indexes and uniqueness:

- `sqlite_autoindex_audit_2` (entry_hash); UNIQUE; automatic primary/unique constraint.
- `sqlite_autoindex_audit_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE audit (
 id TEXT PRIMARY KEY, actor_id TEXT REFERENCES users(id) ON DELETE SET NULL, action TEXT NOT NULL, target TEXT NOT NULL,
 reason TEXT NOT NULL, created REAL NOT NULL, previous_hash TEXT NOT NULL, entry_hash TEXT NOT NULL UNIQUE
);
```

## `auth_sessions`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `token_hash` | TEXT | No | `None` | 1 |
| `user_id` | TEXT | No | `None` | — |
| `device` | TEXT | No | `None` | — |
| `created` | REAL | No | `None` | — |
| `expires` | REAL | No | `None` | — |
| `recent_auth` | REAL | No | `None` | — |

Foreign keys:

- `user_id` → `users.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `ix_auth_user` (user_id); non-unique; `CREATE INDEX ix_auth_user ON auth_sessions(user_id)`
- `sqlite_autoindex_auth_sessions_1` (token_hash); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE auth_sessions (
 token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 device TEXT NOT NULL, created REAL NOT NULL, expires REAL NOT NULL, recent_auth REAL NOT NULL
);
```

## `auth_tokens`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `token_hash` | TEXT | No | `None` | 1 |
| `user_id` | TEXT | No | `None` | — |
| `purpose` | TEXT | No | `None` | — |
| `expires` | REAL | No | `None` | — |

Foreign keys:

- `user_id` → `users.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `sqlite_autoindex_auth_tokens_1` (token_hash); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE auth_tokens (
 token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 purpose TEXT NOT NULL CHECK(purpose IN ('verify','reset')), expires REAL NOT NULL
);
```

## `badges`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `user_id` | TEXT | No | `None` | 1 |
| `badge` | TEXT | No | `None` | 2 |
| `earned` | REAL | No | `None` | — |

Foreign keys:

- `user_id` → `users.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `sqlite_autoindex_badges_1` (user_id, badge); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE badges (
 user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, badge TEXT NOT NULL, earned REAL NOT NULL, PRIMARY KEY(user_id,badge)
);
```

## `blocks`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `user_id` | TEXT | No | `None` | 1 |
| `blocked_id` | TEXT | No | `None` | 2 |

Foreign keys:

- `blocked_id` → `users.id`; delete CASCADE; update NO ACTION.
- `user_id` → `users.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `sqlite_autoindex_blocks_1` (user_id, blocked_id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE blocks (
 user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, blocked_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 PRIMARY KEY(user_id,blocked_id), CHECK(user_id!=blocked_id)
);
```

## `card_schedule`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `user_id` | TEXT | No | `None` | 1 |
| `card_id` | TEXT | No | `None` | 2 |
| `due` | REAL | No | `None` | — |
| `interval_days` | REAL | No | `None` | — |
| `ease` | REAL | No | `None` | — |
| `repetitions` | INTEGER | No | `None` | — |

Foreign keys:

- `card_id` → `cards.id`; delete CASCADE; update NO ACTION.
- `user_id` → `users.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `sqlite_autoindex_card_schedule_1` (user_id, card_id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE card_schedule (
 user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, card_id TEXT NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
 due REAL NOT NULL, interval_days REAL NOT NULL CHECK(interval_days>=0), ease REAL NOT NULL CHECK(ease>=1.3), repetitions INTEGER NOT NULL CHECK(repetitions>=0),
 PRIMARY KEY(user_id,card_id)
);
```

## `cards`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `deck_id` | TEXT | No | `None` | — |
| `front` | TEXT | No | `None` | — |
| `back` | TEXT | No | `None` | — |
| `image_id` | TEXT | Yes | `None` | — |
| `image_alt` | TEXT | No | `''` | — |
| `fingerprint` | TEXT | No | `None` | — |
| `position` | INTEGER | No | `None` | — |

Foreign keys:

- `deck_id` → `decks.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `ix_card_deck` (deck_id, position); non-unique; `CREATE INDEX ix_card_deck ON cards(deck_id,position)`
- `sqlite_autoindex_cards_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE cards (
 id TEXT PRIMARY KEY, deck_id TEXT NOT NULL REFERENCES decks(id) ON DELETE CASCADE,
 front TEXT NOT NULL CHECK(length(front) BETWEEN 1 AND 4000), back TEXT NOT NULL CHECK(length(back) BETWEEN 1 AND 4000),
 image_id TEXT, image_alt TEXT NOT NULL DEFAULT '', fingerprint TEXT NOT NULL, position INTEGER NOT NULL CHECK(position>=0)
);
```

## `catalog`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `title` | TEXT | No | `None` | — |
| `kind` | TEXT | No | `None` | — |
| `price` | INTEGER | No | `None` | — |
| `stock` | INTEGER | Yes | `None` | — |
| `adult_only` | INTEGER | No | `0` | — |
| `rules` | TEXT | No | `''` | — |
| `rules_version` | INTEGER | No | `1` | — |
| `sponsor` | TEXT | No | `''` | — |
| `active` | INTEGER | No | `1` | — |
| `value` | TEXT | No | `''` | — |

Indexes and uniqueness:

- `sqlite_autoindex_catalog_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE catalog (
 id TEXT PRIMARY KEY, title TEXT NOT NULL, kind TEXT NOT NULL CHECK(kind IN ('skin','border','hat','theme','content','freeze','prize')),
 price INTEGER NOT NULL CHECK(price>=0), stock INTEGER CHECK(stock>=0), adult_only INTEGER NOT NULL DEFAULT 0,
 rules TEXT NOT NULL DEFAULT '', rules_version INTEGER NOT NULL DEFAULT 1, sponsor TEXT NOT NULL DEFAULT '', active INTEGER NOT NULL DEFAULT 1,
 value TEXT NOT NULL DEFAULT ''
);
```

## `claims`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `user_id` | TEXT | Yes | `None` | — |
| `item_id` | TEXT | No | `None` | — |
| `state` | TEXT | No | `None` | — |
| `rules_version` | INTEGER | No | `None` | — |
| `rules_snapshot` | TEXT | No | `None` | — |
| `created` | REAL | No | `None` | — |
| `updated` | REAL | No | `None` | — |
| `reviewer` | TEXT | Yes | `None` | — |
| `receipt` | TEXT | No | `''` | — |
| `reason` | TEXT | No | `''` | — |

Foreign keys:

- `reviewer` → `users.id`; delete SET NULL; update NO ACTION.
- `item_id` → `catalog.id`; delete NO ACTION; update NO ACTION.
- `user_id` → `users.id`; delete SET NULL; update NO ACTION.

Indexes and uniqueness:

- `sqlite_autoindex_claims_2` (user_id, item_id); UNIQUE; automatic primary/unique constraint.
- `sqlite_autoindex_claims_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE claims (
 id TEXT PRIMARY KEY, user_id TEXT REFERENCES users(id) ON DELETE SET NULL, item_id TEXT NOT NULL REFERENCES catalog(id),
 state TEXT NOT NULL CHECK(state IN ('pending','approved','denied','fulfilled','cancelled')),
 rules_version INTEGER NOT NULL, rules_snapshot TEXT NOT NULL, created REAL NOT NULL, updated REAL NOT NULL,
 reviewer TEXT REFERENCES users(id) ON DELETE SET NULL, receipt TEXT NOT NULL DEFAULT '', reason TEXT NOT NULL DEFAULT '',
 UNIQUE(user_id,item_id)
);
```

## `cohort_members`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `cohort_id` | TEXT | No | `None` | 1 |
| `user_id` | TEXT | No | `None` | 2 |

Foreign keys:

- `user_id` → `users.id`; delete CASCADE; update NO ACTION.
- `cohort_id` → `cohorts.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `sqlite_autoindex_cohort_members_1` (cohort_id, user_id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE cohort_members (cohort_id TEXT NOT NULL REFERENCES cohorts(id) ON DELETE CASCADE, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, PRIMARY KEY(cohort_id,user_id));
```

## `cohort_moderators`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `cohort_id` | TEXT | No | `None` | 1 |
| `user_id` | TEXT | No | `None` | 2 |

Foreign keys:

- `user_id` → `users.id`; delete CASCADE; update NO ACTION.
- `cohort_id` → `cohorts.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `sqlite_autoindex_cohort_moderators_1` (cohort_id, user_id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE cohort_moderators (cohort_id TEXT NOT NULL REFERENCES cohorts(id) ON DELETE CASCADE, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, PRIMARY KEY(cohort_id,user_id));
```

## `cohorts`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `title` | TEXT | No | `None` | — |

Indexes and uniqueness:

- `sqlite_autoindex_cohorts_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE cohorts (id TEXT PRIMARY KEY, title TEXT NOT NULL);
```

## `decks`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `owner_id` | TEXT | Yes | `None` | — |
| `title` | TEXT | No | `None` | — |
| `topic_id` | TEXT | No | `None` | — |
| `visibility` | TEXT | No | `'private'` | — |
| `room_id` | TEXT | Yes | `None` | — |
| `status` | TEXT | No | `'private'` | — |
| `version` | INTEGER | No | `1` | — |
| `updated` | REAL | No | `None` | — |
| `source` | TEXT | No | `''` | — |
| `license` | TEXT | No | `''` | — |

Foreign keys:

- `topic_id` → `topics.id`; delete NO ACTION; update NO ACTION.
- `owner_id` → `users.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `ix_deck_topic` (topic_id, status); non-unique; `CREATE INDEX ix_deck_topic ON decks(topic_id,status)`
- `ix_deck_owner` (owner_id, updated); non-unique; `CREATE INDEX ix_deck_owner ON decks(owner_id,updated)`
- `sqlite_autoindex_decks_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE decks (
 id TEXT PRIMARY KEY, owner_id TEXT REFERENCES users(id) ON DELETE CASCADE, title TEXT NOT NULL CHECK(length(title) BETWEEN 1 AND 120),
 topic_id TEXT NOT NULL REFERENCES topics(id), visibility TEXT NOT NULL DEFAULT 'private' CHECK(visibility IN ('private','public','room')),
 room_id TEXT, status TEXT NOT NULL DEFAULT 'private' CHECK(status IN ('private','pending','approved','quarantined')),
 version INTEGER NOT NULL DEFAULT 1, updated REAL NOT NULL, source TEXT NOT NULL DEFAULT '', license TEXT NOT NULL DEFAULT ''
);
```

## `duel_answers`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `duel_id` | TEXT | No | `None` | 1 |
| `user_id` | TEXT | No | `None` | 2 |
| `question_id` | TEXT | No | `None` | 3 |
| `answer` | TEXT | No | `None` | — |
| `correct` | INTEGER | No | `None` | — |
| `received` | REAL | No | `None` | — |

Foreign keys:

- `user_id` → `users.id`; delete NO ACTION; update NO ACTION.
- `duel_id` → `duels.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `sqlite_autoindex_duel_answers_1` (duel_id, user_id, question_id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE duel_answers (
 duel_id TEXT NOT NULL REFERENCES duels(id) ON DELETE CASCADE, user_id TEXT NOT NULL REFERENCES users(id),
 question_id TEXT NOT NULL, answer TEXT NOT NULL, correct INTEGER NOT NULL CHECK(correct IN (0,1)), received REAL NOT NULL,
 PRIMARY KEY(duel_id,user_id,question_id)
);
```

## `duel_queue`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `user_id` | TEXT | No | `None` | 1 |
| `topic_id` | TEXT | No | `None` | — |
| `band` | INTEGER | No | `None` | — |
| `queued` | REAL | No | `None` | — |
| `heartbeat` | REAL | No | `None` | — |

Foreign keys:

- `topic_id` → `topics.id`; delete NO ACTION; update NO ACTION.
- `user_id` → `users.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `sqlite_autoindex_duel_queue_1` (user_id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE duel_queue (
 user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE, topic_id TEXT NOT NULL REFERENCES topics(id),
 band INTEGER NOT NULL CHECK(band BETWEEN 0 AND 3), queued REAL NOT NULL, heartbeat REAL NOT NULL
);
```

## `duels`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `a_id` | TEXT | No | `None` | — |
| `b_id` | TEXT | Yes | `None` | — |
| `topic_id` | TEXT | No | `None` | — |
| `season_id` | TEXT | Yes | `None` | — |
| `state` | TEXT | No | `None` | — |
| `created` | REAL | No | `None` | — |
| `deadline` | REAL | No | `None` | — |
| `a_seen` | REAL | No | `None` | — |
| `b_seen` | REAL | No | `None` | — |
| `question_data` | TEXT | No | `None` | — |
| `a_score` | INTEGER | No | `0` | — |
| `b_score` | INTEGER | No | `0` | — |
| `result` | TEXT | No | `''` | — |
| `bot` | INTEGER | No | `0` | — |

Foreign keys:

- `season_id` → `seasons.id`; delete NO ACTION; update NO ACTION.
- `topic_id` → `topics.id`; delete NO ACTION; update NO ACTION.
- `b_id` → `users.id`; delete NO ACTION; update NO ACTION.
- `a_id` → `users.id`; delete NO ACTION; update NO ACTION.

Indexes and uniqueness:

- `ix_duel_players` (a_id, b_id, state); non-unique; `CREATE INDEX ix_duel_players ON duels(a_id,b_id,state)`
- `sqlite_autoindex_duels_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE duels (
 id TEXT PRIMARY KEY, a_id TEXT NOT NULL REFERENCES users(id), b_id TEXT REFERENCES users(id), topic_id TEXT NOT NULL REFERENCES topics(id),
 season_id TEXT REFERENCES seasons(id), state TEXT NOT NULL CHECK(state IN ('active','completed','forfeit','void')),
 created REAL NOT NULL, deadline REAL NOT NULL, a_seen REAL NOT NULL, b_seen REAL NOT NULL, question_data TEXT NOT NULL,
 a_score INTEGER NOT NULL DEFAULT 0, b_score INTEGER NOT NULL DEFAULT 0, result TEXT NOT NULL DEFAULT '', bot INTEGER NOT NULL DEFAULT 0
);
```

## `evidence`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `user_id` | TEXT | No | `None` | — |
| `topic_id` | TEXT | No | `None` | — |
| `correct` | REAL | No | `None` | — |
| `weight` | REAL | No | `None` | — |
| `occurred` | REAL | No | `None` | — |
| `origin` | TEXT | No | `None` | — |

Foreign keys:

- `topic_id` → `topics.id`; delete NO ACTION; update NO ACTION.
- `user_id` → `users.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `ix_evidence_topic` (user_id, topic_id, occurred); non-unique; `CREATE INDEX ix_evidence_topic ON evidence(user_id,topic_id,occurred)`
- `sqlite_autoindex_evidence_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE evidence (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, topic_id TEXT NOT NULL REFERENCES topics(id),
 correct REAL NOT NULL CHECK(correct BETWEEN 0 AND 1), weight REAL NOT NULL CHECK(weight>0), occurred REAL NOT NULL, origin TEXT NOT NULL
);
```

## `flags`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `name` | TEXT | No | `None` | 1 |
| `enabled` | INTEGER | No | `None` | — |

Indexes and uniqueness:

- `sqlite_autoindex_flags_1` (name); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE flags (name TEXT PRIMARY KEY, enabled INTEGER NOT NULL CHECK(enabled IN (0,1)));
```

## `idempotency`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `user_id` | TEXT | No | `None` | 1 |
| `key` | TEXT | No | `None` | 2 |
| `fingerprint` | TEXT | No | `None` | — |
| `response` | TEXT | No | `None` | — |
| `created` | REAL | No | `None` | — |

Foreign keys:

- `user_id` → `users.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `sqlite_autoindex_idempotency_1` (user_id, key); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE idempotency (
 user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, key TEXT NOT NULL, fingerprint TEXT NOT NULL,
 response TEXT NOT NULL, created REAL NOT NULL, PRIMARY KEY(user_id,key)
);
```

## `inventory`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `user_id` | TEXT | No | `None` | 1 |
| `item_id` | TEXT | No | `None` | 2 |
| `acquired` | REAL | No | `None` | — |
| `equipped` | INTEGER | No | `0` | — |
| `consumed` | INTEGER | No | `0` | — |

Foreign keys:

- `item_id` → `catalog.id`; delete NO ACTION; update NO ACTION.
- `user_id` → `users.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `sqlite_autoindex_inventory_1` (user_id, item_id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE inventory (
 user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, item_id TEXT NOT NULL REFERENCES catalog(id),
 acquired REAL NOT NULL, equipped INTEGER NOT NULL DEFAULT 0, consumed INTEGER NOT NULL DEFAULT 0,
 PRIMARY KEY(user_id,item_id)
);
```

## `ledger`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `user_id` | TEXT | Yes | `None` | — |
| `xp` | INTEGER | No | `None` | — |
| `coins` | INTEGER | No | `None` | — |
| `origin` | TEXT | No | `None` | — |
| `reason` | TEXT | No | `None` | — |
| `created` | REAL | No | `None` | — |
| `actor_id` | TEXT | Yes | `None` | — |

Foreign keys:

- `actor_id` → `users.id`; delete SET NULL; update NO ACTION.
- `user_id` → `users.id`; delete SET NULL; update NO ACTION.

Indexes and uniqueness:

- `ix_ledger_user` (user_id, created); non-unique; `CREATE INDEX ix_ledger_user ON ledger(user_id,created)`
- `sqlite_autoindex_ledger_2` (user_id, origin); UNIQUE; automatic primary/unique constraint.
- `sqlite_autoindex_ledger_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE ledger (
 id TEXT PRIMARY KEY, user_id TEXT REFERENCES users(id) ON DELETE SET NULL, xp INTEGER NOT NULL, coins INTEGER NOT NULL,
 origin TEXT NOT NULL, reason TEXT NOT NULL, created REAL NOT NULL, actor_id TEXT REFERENCES users(id) ON DELETE SET NULL,
 UNIQUE(user_id,origin)
);
```

## `materials`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `owner_id` | TEXT | Yes | `None` | — |
| `title` | TEXT | No | `None` | — |
| `topic_id` | TEXT | No | `None` | — |
| `year` | INTEGER | No | `None` | — |
| `file_type` | TEXT | No | `None` | — |
| `body` | TEXT | No | `''` | — |
| `file_key` | TEXT | Yes | `None` | — |
| `bytes` | INTEGER | No | `0` | — |
| `sha256` | TEXT | Yes | `None` | — |
| `source` | TEXT | No | `None` | — |
| `license` | TEXT | No | `None` | — |
| `status` | TEXT | No | `None` | — |
| `verified_by` | TEXT | Yes | `None` | — |
| `created` | REAL | No | `None` | — |

Foreign keys:

- `verified_by` → `users.id`; delete SET NULL; update NO ACTION.
- `topic_id` → `topics.id`; delete NO ACTION; update NO ACTION.
- `owner_id` → `users.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `ix_material_filter` (status, topic_id, year, file_type); non-unique; `CREATE INDEX ix_material_filter ON materials(status,topic_id,year,file_type)`
- `sqlite_autoindex_materials_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE materials (
 id TEXT PRIMARY KEY, owner_id TEXT REFERENCES users(id) ON DELETE CASCADE, title TEXT NOT NULL, topic_id TEXT NOT NULL REFERENCES topics(id),
 year INTEGER NOT NULL CHECK(year BETWEEN 1 AND 6), file_type TEXT NOT NULL CHECK(file_type IN ('text','pdf','png','jpeg')),
 body TEXT NOT NULL DEFAULT '', file_key TEXT, bytes INTEGER NOT NULL DEFAULT 0 CHECK(bytes>=0), sha256 TEXT,
 source TEXT NOT NULL, license TEXT NOT NULL, status TEXT NOT NULL CHECK(status IN ('pending','approved','quarantined')),
 verified_by TEXT REFERENCES users(id) ON DELETE SET NULL, created REAL NOT NULL
);
```

## `memberships`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `room_id` | TEXT | No | `None` | 1 |
| `user_id` | TEXT | No | `None` | 2 |
| `joined` | REAL | No | `None` | — |

Foreign keys:

- `user_id` → `users.id`; delete CASCADE; update NO ACTION.
- `room_id` → `rooms.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `sqlite_autoindex_memberships_1` (room_id, user_id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE memberships (
 room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 joined REAL NOT NULL, PRIMARY KEY(room_id,user_id)
);
```

## `messages`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `room_id` | TEXT | No | `None` | — |
| `user_id` | TEXT | Yes | `None` | — |
| `body` | TEXT | No | `None` | — |
| `created` | REAL | No | `None` | — |
| `hidden` | INTEGER | No | `0` | — |

Foreign keys:

- `user_id` → `users.id`; delete SET NULL; update NO ACTION.
- `room_id` → `rooms.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `ix_message_room` (room_id, created); non-unique; `CREATE INDEX ix_message_room ON messages(room_id,created)`
- `sqlite_autoindex_messages_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE messages (
 id TEXT PRIMARY KEY, room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE, user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
 body TEXT NOT NULL CHECK(length(body) BETWEEN 1 AND 2000), created REAL NOT NULL, hidden INTEGER NOT NULL DEFAULT 0
);
```

## `notification_settings`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `user_id` | TEXT | No | `None` | 1 |
| `reminders` | INTEGER | No | `1` | — |
| `streak` | INTEGER | No | `1` | — |
| `invitations` | INTEGER | No | `1` | — |
| `challenges` | INTEGER | No | `0` | — |
| `rewards` | INTEGER | No | `1` | — |
| `quiet_start` | INTEGER | No | `22` | — |
| `quiet_end` | INTEGER | No | `7` | — |
| `reminder_time` | TEXT | No | `'18:00'` | — |
| `daily_cap` | INTEGER | No | `3` | — |

Foreign keys:

- `user_id` → `users.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `sqlite_autoindex_notification_settings_1` (user_id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE notification_settings (
 user_id TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE, reminders INTEGER NOT NULL DEFAULT 1, streak INTEGER NOT NULL DEFAULT 1,
 invitations INTEGER NOT NULL DEFAULT 1, challenges INTEGER NOT NULL DEFAULT 0, rewards INTEGER NOT NULL DEFAULT 1,
 quiet_start INTEGER NOT NULL DEFAULT 22 CHECK(quiet_start BETWEEN 0 AND 23), quiet_end INTEGER NOT NULL DEFAULT 7 CHECK(quiet_end BETWEEN 0 AND 23),
 reminder_time TEXT NOT NULL DEFAULT '18:00', daily_cap INTEGER NOT NULL DEFAULT 3 CHECK(daily_cap BETWEEN 0 AND 3)
);
```

## `notifications`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `user_id` | TEXT | No | `None` | — |
| `category` | TEXT | No | `None` | — |
| `body` | TEXT | No | `None` | — |
| `created` | REAL | No | `None` | — |
| `day` | TEXT | No | `None` | — |
| `read` | INTEGER | No | `0` | — |

Foreign keys:

- `user_id` → `users.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `ix_notify_user` (user_id, day); non-unique; `CREATE INDEX ix_notify_user ON notifications(user_id,day)`
- `sqlite_autoindex_notifications_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE notifications (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, category TEXT NOT NULL,
 body TEXT NOT NULL, created REAL NOT NULL, day TEXT NOT NULL, read INTEGER NOT NULL DEFAULT 0
);
```

## `outbox`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `user_id` | TEXT | Yes | `None` | — |
| `recipient_cipher` | TEXT | No | `None` | — |
| `subject` | TEXT | No | `None` | — |
| `body_cipher` | TEXT | No | `None` | — |
| `created` | REAL | No | `None` | — |
| `attempts` | INTEGER | No | `0` | — |
| `delivered` | REAL | Yes | `None` | — |

Foreign keys:

- `user_id` → `users.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `sqlite_autoindex_outbox_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE outbox (
 id TEXT PRIMARY KEY, user_id TEXT REFERENCES users(id) ON DELETE CASCADE, recipient_cipher TEXT NOT NULL,
 subject TEXT NOT NULL, body_cipher TEXT NOT NULL, created REAL NOT NULL, attempts INTEGER NOT NULL DEFAULT 0, delivered REAL
);
```

## `push_delivery`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `notification_id` | TEXT | No | `None` | 1 |
| `token` | TEXT | No | `None` | 2 |
| `delivered` | REAL | No | `None` | — |

Foreign keys:

- `token` → `push_tokens.token`; delete CASCADE; update NO ACTION.
- `notification_id` → `notifications.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `sqlite_autoindex_push_delivery_1` (notification_id, token); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE push_delivery (notification_id TEXT NOT NULL REFERENCES notifications(id) ON DELETE CASCADE, token TEXT NOT NULL REFERENCES push_tokens(token) ON DELETE CASCADE, delivered REAL NOT NULL, PRIMARY KEY(notification_id,token));
```

## `push_tokens`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `token` | TEXT | No | `None` | 1 |
| `user_id` | TEXT | No | `None` | — |
| `platform` | TEXT | No | `None` | — |
| `updated` | REAL | No | `None` | — |

Foreign keys:

- `user_id` → `users.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `sqlite_autoindex_push_tokens_1` (token); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE push_tokens (token TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, platform TEXT NOT NULL CHECK(platform='android'), updated REAL NOT NULL);
```

## `questions`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `quiz_id` | TEXT | No | `None` | — |
| `kind` | TEXT | No | `None` | — |
| `prompt` | TEXT | No | `None` | — |
| `options` | TEXT | No | `'[]'` | — |
| `accepted` | TEXT | No | `None` | — |
| `explanation` | TEXT | No | `None` | — |
| `topic_id` | TEXT | No | `None` | — |
| `position` | INTEGER | No | `None` | — |

Foreign keys:

- `topic_id` → `topics.id`; delete NO ACTION; update NO ACTION.
- `quiz_id` → `quizzes.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `ix_question_quiz` (quiz_id, position); non-unique; `CREATE INDEX ix_question_quiz ON questions(quiz_id,position)`
- `sqlite_autoindex_questions_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE questions (
 id TEXT PRIMARY KEY, quiz_id TEXT NOT NULL REFERENCES quizzes(id) ON DELETE CASCADE,
 kind TEXT NOT NULL CHECK(kind IN ('mcq','boolean','identification')), prompt TEXT NOT NULL CHECK(length(prompt) BETWEEN 1 AND 4000),
 options TEXT NOT NULL DEFAULT '[]', accepted TEXT NOT NULL, explanation TEXT NOT NULL CHECK(length(explanation) BETWEEN 1 AND 4000),
 topic_id TEXT NOT NULL REFERENCES topics(id), position INTEGER NOT NULL
);
```

## `quizzes`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `owner_id` | TEXT | Yes | `None` | — |
| `title` | TEXT | No | `None` | — |
| `topic_id` | TEXT | No | `None` | — |
| `status` | TEXT | No | `None` | — |
| `duration` | INTEGER | Yes | `None` | — |
| `version` | INTEGER | No | `1` | — |
| `updated` | REAL | No | `None` | — |
| `source` | TEXT | No | `None` | — |
| `license` | TEXT | No | `None` | — |

Foreign keys:

- `topic_id` → `topics.id`; delete NO ACTION; update NO ACTION.
- `owner_id` → `users.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `ix_quiz_topic` (topic_id, status); non-unique; `CREATE INDEX ix_quiz_topic ON quizzes(topic_id,status)`
- `sqlite_autoindex_quizzes_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE quizzes (
 id TEXT PRIMARY KEY, owner_id TEXT REFERENCES users(id) ON DELETE CASCADE, title TEXT NOT NULL, topic_id TEXT NOT NULL REFERENCES topics(id),
 status TEXT NOT NULL CHECK(status IN ('private','pending','approved','quarantined')), duration INTEGER CHECK(duration BETWEEN 30 AND 7200),
 version INTEGER NOT NULL DEFAULT 1, updated REAL NOT NULL, source TEXT NOT NULL, license TEXT NOT NULL
);
```

## `rate_limits`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `key` | TEXT | No | `None` | 1 |
| `window` | REAL | No | `None` | — |
| `count` | INTEGER | No | `None` | — |

Indexes and uniqueness:

- `sqlite_autoindex_rate_limits_1` (key); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE rate_limits (key TEXT PRIMARY KEY, window REAL NOT NULL, count INTEGER NOT NULL CHECK(count>=0));
```

## `reports`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `reporter` | TEXT | Yes | `None` | — |
| `kind` | TEXT | No | `None` | — |
| `target_id` | TEXT | No | `None` | — |
| `reason` | TEXT | No | `None` | — |
| `evidence` | TEXT | No | `None` | — |
| `state` | TEXT | No | `'pending'` | — |
| `created` | REAL | No | `None` | — |
| `action` | TEXT | No | `''` | — |
| `reviewed_by` | TEXT | Yes | `None` | — |

Foreign keys:

- `reviewed_by` → `users.id`; delete SET NULL; update NO ACTION.
- `reporter` → `users.id`; delete SET NULL; update NO ACTION.

Indexes and uniqueness:

- `ix_report_queue` (state, created); non-unique; `CREATE INDEX ix_report_queue ON reports(state,created)`
- `sqlite_autoindex_reports_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE reports (
 id TEXT PRIMARY KEY, reporter TEXT REFERENCES users(id) ON DELETE SET NULL,
 kind TEXT NOT NULL CHECK(kind IN ('deck','quiz','material','message','user','duel')),
 target_id TEXT NOT NULL, reason TEXT NOT NULL, evidence TEXT NOT NULL, state TEXT NOT NULL DEFAULT 'pending' CHECK(state IN ('pending','resolved','dismissed')),
 created REAL NOT NULL, action TEXT NOT NULL DEFAULT '', reviewed_by TEXT REFERENCES users(id) ON DELETE SET NULL
);
```

## `review_events`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `user_id` | TEXT | No | `None` | — |
| `card_id` | TEXT | No | `None` | — |
| `known` | INTEGER | No | `None` | — |
| `occurred` | REAL | No | `None` | — |
| `rewarded` | INTEGER | No | `None` | — |

Foreign keys:

- `card_id` → `cards.id`; delete CASCADE; update NO ACTION.
- `user_id` → `users.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `ix_review_user` (user_id, occurred); non-unique; `CREATE INDEX ix_review_user ON review_events(user_id,occurred)`
- `sqlite_autoindex_review_events_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE review_events (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, card_id TEXT NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
 known INTEGER NOT NULL CHECK(known IN (0,1)), occurred REAL NOT NULL, rewarded INTEGER NOT NULL CHECK(rewarded IN (0,1))
);
```

## `risk_events`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `user_id` | TEXT | No | `None` | — |
| `signal` | TEXT | No | `None` | — |
| `evidence` | TEXT | No | `None` | — |
| `created` | REAL | No | `None` | — |
| `resolved` | INTEGER | No | `0` | — |

Foreign keys:

- `user_id` → `users.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `ix_risk_user` (user_id, created); non-unique; `CREATE INDEX ix_risk_user ON risk_events(user_id,created)`
- `sqlite_autoindex_risk_events_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE risk_events (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, signal TEXT NOT NULL,
 evidence TEXT NOT NULL, created REAL NOT NULL, resolved INTEGER NOT NULL DEFAULT 0
);
```

## `room_resources`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `room_id` | TEXT | No | `None` | 1 |
| `kind` | TEXT | No | `None` | 2 |
| `resource_id` | TEXT | No | `None` | 3 |
| `added_by` | TEXT | Yes | `None` | — |

Foreign keys:

- `added_by` → `users.id`; delete SET NULL; update NO ACTION.
- `room_id` → `rooms.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `sqlite_autoindex_room_resources_1` (room_id, kind, resource_id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE room_resources (
 room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE, kind TEXT NOT NULL CHECK(kind IN ('deck','material')),
 resource_id TEXT NOT NULL, added_by TEXT REFERENCES users(id) ON DELETE SET NULL, PRIMARY KEY(room_id,kind,resource_id)
);
```

## `rooms`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `owner_id` | TEXT | No | `None` | — |
| `title` | TEXT | No | `None` | — |
| `topic_id` | TEXT | No | `None` | — |
| `band` | INTEGER | No | `None` | — |
| `code_hash` | TEXT | No | `None` | — |
| `code_expires` | REAL | No | `None` | — |
| `state` | TEXT | No | `None` | — |
| `scheduled` | REAL | Yes | `None` | — |
| `timer_end` | REAL | Yes | `None` | — |
| `last_active` | REAL | No | `None` | — |
| `archived` | REAL | Yes | `None` | — |
| `warned` | INTEGER | No | `0` | — |

Foreign keys:

- `topic_id` → `topics.id`; delete NO ACTION; update NO ACTION.
- `owner_id` → `users.id`; delete NO ACTION; update NO ACTION.

Indexes and uniqueness:

- `ix_room_match` (state, topic_id, band); non-unique; `CREATE INDEX ix_room_match ON rooms(state,topic_id,band)`
- `sqlite_autoindex_rooms_2` (code_hash); UNIQUE; automatic primary/unique constraint.
- `sqlite_autoindex_rooms_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE rooms (
 id TEXT PRIMARY KEY, owner_id TEXT NOT NULL REFERENCES users(id), title TEXT NOT NULL, topic_id TEXT NOT NULL REFERENCES topics(id),
 band INTEGER NOT NULL CHECK(band BETWEEN 0 AND 3), code_hash TEXT NOT NULL UNIQUE, code_expires REAL NOT NULL,
 state TEXT NOT NULL CHECK(state IN ('active','archived')), scheduled REAL, timer_end REAL,
 last_active REAL NOT NULL, archived REAL, warned INTEGER NOT NULL DEFAULT 0
);
```

## `seasons`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `title` | TEXT | No | `None` | — |
| `starts` | REAL | No | `None` | — |
| `ends` | REAL | No | `None` | — |

Indexes and uniqueness:

- `sqlite_autoindex_seasons_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE seasons (id TEXT PRIMARY KEY, title TEXT NOT NULL, starts REAL NOT NULL, ends REAL NOT NULL, CHECK(ends>starts));
```

## `streak_days`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `user_id` | TEXT | No | `None` | 1 |
| `day` | TEXT | No | `None` | 2 |
| `kind` | TEXT | No | `None` | — |
| `created` | REAL | No | `None` | — |

Foreign keys:

- `user_id` → `users.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `sqlite_autoindex_streak_days_1` (user_id, day); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE streak_days (
 user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, day TEXT NOT NULL, kind TEXT NOT NULL CHECK(kind IN ('study','grace','freeze')),
 created REAL NOT NULL, PRIMARY KEY(user_id,day)
);
```

## `study_sessions`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `user_id` | TEXT | No | `None` | — |
| `topic_id` | TEXT | No | `None` | — |
| `state` | TEXT | No | `None` | — |
| `started` | REAL | No | `None` | — |
| `ended` | REAL | Yes | `None` | — |
| `elapsed` | REAL | No | `0` | — |
| `credited` | INTEGER | No | `0` | — |
| `last_heartbeat` | REAL | No | `None` | — |
| `timezone` | TEXT | No | `None` | — |
| `notes_cipher` | TEXT | No | `None` | — |
| `offline` | INTEGER | No | `0` | — |
| `reason` | TEXT | No | `''` | — |

Foreign keys:

- `topic_id` → `topics.id`; delete NO ACTION; update NO ACTION.
- `user_id` → `users.id`; delete CASCADE; update NO ACTION.

Indexes and uniqueness:

- `ix_session_user` (user_id, started); non-unique; `CREATE INDEX ix_session_user ON study_sessions(user_id,started)`
- `ix_one_active_session` (user_id); UNIQUE; `CREATE UNIQUE INDEX ix_one_active_session ON study_sessions(user_id) WHERE state IN ('running','paused')`
- `sqlite_autoindex_study_sessions_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE study_sessions (
 id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE, topic_id TEXT NOT NULL REFERENCES topics(id),
 state TEXT NOT NULL CHECK(state IN ('running','paused','completed','discarded','uncredited')), started REAL NOT NULL,
 ended REAL, elapsed REAL NOT NULL DEFAULT 0 CHECK(elapsed>=0), credited INTEGER NOT NULL DEFAULT 0 CHECK(credited BETWEEN 0 AND 180),
 last_heartbeat REAL NOT NULL, timezone TEXT NOT NULL, notes_cipher TEXT NOT NULL, offline INTEGER NOT NULL DEFAULT 0,
 reason TEXT NOT NULL DEFAULT ''
);
```

## `topics`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `subject` | TEXT | No | `None` | — |
| `title` | TEXT | No | `None` | — |
| `course` | TEXT | No | `None` | — |

Indexes and uniqueness:

- `sqlite_autoindex_topics_2` (subject, title); UNIQUE; automatic primary/unique constraint.
- `sqlite_autoindex_topics_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE topics (id TEXT PRIMARY KEY, subject TEXT NOT NULL, title TEXT NOT NULL, course TEXT NOT NULL, UNIQUE(subject,title));
```

## `users`

| Column | SQLite type | Nullable | Default | Primary-key position |
|---|---|---|---|---|
| `id` | TEXT | No | `None` | 1 |
| `email` | TEXT | No | `None` | — |
| `password_hash` | TEXT | No | `None` | — |
| `school_hash` | TEXT | No | `None` | — |
| `school_cipher` | TEXT | No | `None` | — |
| `display_name` | TEXT | No | `None` | — |
| `age_band` | TEXT | No | `None` | — |
| `consent_ref` | TEXT | Yes | `None` | — |
| `role` | TEXT | No | `'student'` | — |
| `verified` | INTEGER | No | `0` | — |
| `competition` | INTEGER | No | `0` | — |
| `course` | TEXT | No | `''` | — |
| `year` | INTEGER | No | `1` | — |
| `subjects` | TEXT | No | `'[]'` | — |
| `timezone` | TEXT | No | `'Asia/Manila'` | — |
| `daily_goal` | INTEGER | No | `25` | — |
| `weekly_goal` | INTEGER | No | `125` | — |
| `band` | INTEGER | No | `0` | — |
| `band_evidence` | INTEGER | No | `0` | — |
| `version` | INTEGER | No | `1` | — |
| `suspended` | INTEGER | No | `0` | — |
| `created` | REAL | No | `None` | — |
| `delete_after` | REAL | Yes | `None` | — |

Indexes and uniqueness:

- `sqlite_autoindex_users_3` (school_hash); UNIQUE; automatic primary/unique constraint.
- `sqlite_autoindex_users_2` (email); UNIQUE; automatic primary/unique constraint.
- `sqlite_autoindex_users_1` (id); UNIQUE; automatic primary/unique constraint.

Complete table constraints:

```sql
CREATE TABLE users (
 id TEXT PRIMARY KEY, email TEXT NOT NULL UNIQUE COLLATE NOCASE, password_hash TEXT NOT NULL,
 school_hash TEXT NOT NULL UNIQUE, school_cipher TEXT NOT NULL, display_name TEXT NOT NULL CHECK(length(display_name) BETWEEN 2 AND 40),
 age_band TEXT NOT NULL CHECK(age_band IN ('minor','adult')), consent_ref TEXT,
 role TEXT NOT NULL DEFAULT 'student' CHECK(role IN ('student','teacher','admin')),
 verified INTEGER NOT NULL DEFAULT 0 CHECK(verified IN (0,1)), competition INTEGER NOT NULL DEFAULT 0 CHECK(competition IN (0,1)),
 course TEXT NOT NULL DEFAULT '', year INTEGER NOT NULL DEFAULT 1 CHECK(year BETWEEN 1 AND 6), subjects TEXT NOT NULL DEFAULT '[]',
 timezone TEXT NOT NULL DEFAULT 'Asia/Manila', daily_goal INTEGER NOT NULL DEFAULT 25 CHECK(daily_goal BETWEEN 5 AND 180),
 weekly_goal INTEGER NOT NULL DEFAULT 125 CHECK(weekly_goal BETWEEN 5 AND 1260), band INTEGER NOT NULL DEFAULT 0 CHECK(band BETWEEN 0 AND 3),
 band_evidence INTEGER NOT NULL DEFAULT 0, version INTEGER NOT NULL DEFAULT 1, suspended INTEGER NOT NULL DEFAULT 0,
 created REAL NOT NULL, delete_after REAL
);
```

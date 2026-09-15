from pathlib import Path
root=Path(__file__).resolve().parents[1]
part1=(root.parent/'Study_Arena_Part_1_Product_Specification.md').read_text()
section=part1.split('## 6. Explicit edge-case behavior',1)[1].split('## 7.',1)[0]
refs={
 'Account':('A01–A04, E2E02/E2E05','Account recovery with dead inbox, real email and OS session behavior require institutional/device validation.'),
 'Study sessions':('B01–B02, E2E07','Calls, alarms, clock settings, force-stop and travel timezone changes need physical-device tests.'),
 'Flashcards and quizzes':('C01–C04, D01–D04, CSV01–CSV05, E2E03–E2E06','Large-deck interaction, failed card image and device restart require the additional procedures below.'),
 'Matchmaking and duels':('H01–H02','Delay/loss windows, both-player disconnect and sustained latency require transport simulation and device validation.'),
 'Rooms':('G01–G02','Lifecycle expiry and full-room races have explicit manual/integration extension procedures below.'),
 'Progression and rewards':('J01–J04','Season boundary is design-only for standings; the captured duel season is implemented. Stock contention must also be stress-tested.'),
 'Connectivity':('SYNC01–SYNC06, E2E04–E2E06','Browser offline/queue paths are exercised; real 3G, storage pressure and large media downloads remain device checks.'),
 'Content and safety':('G02, L01','Safeguarding and copyright policy require an institution-approved procedure, not automated certification.'),
}
lines=['# Study Arena — Edge-case test plan and traceability','', 'This matrix carries forward every scenario row in Part 1. Test references map to the named executable tests in `tests/`; a reference indicates relevant coverage, not proof that every real-device variation was executed. “Additional validation” is deliberately explicit. Read `Test_Results.md` for what actually ran.','', '## Strategy','', '- Java domain/security tests exercise cryptography, normalization, CSV and database invariants.','- Node HTTP integration tests use isolated synthetic Java servers and real SQLite databases.','- JavaScript unit tests simulate unknown-success retries, expiry, bounded queues, caching and offline CSV.','- Playwright exercises the real JavaScript UI against Java, including encrypted IndexedDB, service-worker offline reload, resumed quiz state, timer and responsive layout.','- Device/institution cases are acceptance procedures with a named expected result; they are not marked passed without the hardware or external configuration.','']
category='';count=0
for line in section.splitlines():
 if line.startswith('### '):
  category=line[4:].strip()
  if category not in refs: continue
  lines += [f'## {category}','','| Case ID and scenario | Expected result carried from Part 1 | Automated references / additional validation |','|---|---|---|']
 elif line.startswith('|') and not line.startswith('| Case') and not line.startswith('|---'):
  parts=[x.strip() for x in line.strip('|').split('|')]
  if len(parts)>=2:
   count+=1;r,note=refs.get(category,('See procedures below','Manual acceptance required.'))
   outcome=parts[1]
   if parts[0]=='Two devices':outcome='Connected starts permit one active session. Offline conflicts retain both logs; first server-accepted overlapping session is credited. This explicit Part 2 refinement supersedes retrospective earliest-start credit.'
   if parts[0]=='No opponent':outcome='After 20 seconds offer cancel, continued same-band search or a clearly labeled unranked bot. No automatic or adjacent-band widening is implemented.'
   if parts[0]=='Season ends mid-duel':outcome='Keep season_id captured at creation; never reset permanent learning history. Seasonal standings are deferred.'
   lines.append(f'| EC{count:02d} · {parts[0]} | {outcome} | {r}. {note} |')
lines += ['''
## Additional explicit tests for narrative cases

| Test ID | Scenario / procedure | Required outcome | Execution class |
|---|---|---|---|
| SEC05 | Attempt direct SQL deletion/update of existing ledger/audit entries | Database rejects rewriting; correction uses a new entry | Java assertions DB01–DB03 |
| CHEAT01 | Submit an offline quiz with an impossibly short completion time | Personal result retained; reward withheld; risk reference created | HTTP extension / audit inspection |
| CHEAT02 | Repeat due-card responses immediately and retry committed operation | At most one reward per card/24h; retry returns same result | C04 and SYNC01 |
| CHEAT03 | Submit device-clock elapsed time greater than the wall interval or an overnight claim | Validation or 180-minute cap; no uncapped reward | B01; device clock test pending |
| CHEAT04 | Deliberately forfeit many rounds | No automatic downward band movement; queue rate cap; reviewed admin reset only | H01 plus manual repeated-round test |
| CHEAT05 | Create multiple accounts with the same school ID | Unique keyed school identifier prevents duplicate registration | A01 plus alternate-email duplicate-ID extension |
| CHEAT06 | Look up answers in another app | Do not claim reliable detection. Solo feedback remains useful; no high-stakes exam claim | Policy/UX review |
| CHEAT07 | Two users coordinate answer sharing or near-identical timing | Do not auto-accuse. Review reported duel evidence; apply documented graduated response | Institution review; advanced collusion detection deferred |
| ACCESS01 | Inspect all primary screens with TalkBack | Control name, role, focus order and state understandable; timer does not announce every second | Physical Android test |
| ACCESS02 | Increase system text to 200%; run at 320 px | No clipped essential control; no page-wide horizontal overflow; tables scroll in their region | Browser + physical device |
| ACCESS03 | Use keyboard only in teacher/admin console | Every action reachable; visible focus; modal focus and Escape work | Browser/manual |
| ACCESS04 | View dark mode and grayscale | Text contrast remains readable; status not encoded only in color | E2E09 plus manual contrast review |
| DEVICE01 | Cold-start on target Android with 2 GB RAM and representative library | Median <3 s; record 20 launches, OS/WebView versions, p50/p95 and peak memory | Physical performance gate |
| DEVICE02 | Run with low battery and OS power saver | No mandatory animation; reduce background polling; study works | Physical device |
| DEVICE03 | Simulate low storage before/during download | Refuse or pause cleanly; never delete unsynced learning work | Physical device |
| DEVICE04 | Force-stop mid-focus/quiz, then reopen | Saved quiz resumes; focus restores checkpoint and flags inconsistent clock gaps | E2E05/E2E06 plus native process-kill test |
| PRIV01 | Teacher outside a student's cohort tries moderation/aggregate access | No private or out-of-scope content; small groups suppressed | A03/L01 plus cohort extension |
| PRIV02 | Inspect database, localStorage and IndexedDB | Password hashes only on server; notes/school IDs encrypted; token only inside encrypted vault; local export omits token | SEC01–SEC04, E2E03 |
| PRIV03 | Request export, deletion, wait simulated 30 days, restore backup | Own data exported; access revoked immediately; primary data purged; backup restoration cannot revive deleted access without applying tombstones | A04 plus scheduled purge/backup drill |
| PRIV04 | A 16–17-year-old enrolls in production without approved consent code | Registration rejected; no implicit consent from a checkbox | Production configuration integration test |
| PRIV05 | Minor claims adult-only reward by UI or API | API rejects regardless of client visibility; school checks documentary age before approval | J03 plus physical/institution review |
| ROOM01 | Owner tries to leave while others remain | Transfer or disband required; no orphan active room | G01 plus owner-leave extension |
| ROOM02 | Join room with ten members; race two final-seat joins | At most ten memberships; rejected join makes no partial change | Concurrency extension |
| ROOM03 | Simulate 29/30 inactive days and 30-day restoration window | Warn, archive, allow timely restoration; do not erase authored content | Worker time-fixture test |
| CONTENT01 | Edit a 500-card deck, not merely submit one | Only 20 editor rows are rendered per page; all 500 preserved | Browser data-volume test |
| CONTENT02 | Image-based card cannot load | Alt/supporting text remains; explicit retry/open action; review does not crash | Browser failure-injection test |
| CONTENT03 | A formerly approved resource is quarantined | New server access denied; report/audit retained; stale offline copies flagged on next sync where available | Moderation/offline cache review |
| FILE01 | Download disconnects after first chunk | Partial record persists; next request resumes by byte offset; checksum before opening | Network failure-injection test |
| FILE02 | File changes during partial download | Detect changed hash; do not merge revisions | Network/file revision test |
| DUEL01 | No match for 20 seconds | Labeled bot option appears; no disguised human or widened band | Timer-controlled integration extension |
| DUEL02 | One player disconnects >20 seconds while other stays online | Server forfeit; later answers rejected | Two-client network test |
| DUEL03 | Both players disconnect >20 seconds | Void if not already conclusive; no invented winner | Two-client network test |
| DUEL04 | Very slow connection / late answers | Fixed shared allowance only; authoritative deadline; reject after deadline | Latency simulation |
| DUEL05 | Season boundary during active round | Round keeps captured season; personal history never reset | Date fixture; standings deferred |
| REWARD01 | Race last stock with distinct users | One successful reservation; other OUT_OF_STOCK; no negative stock | Concurrency extension |
| REWARD02 | Fulfill twice / deny after fulfillment | Invalid state; no second debit, credit, stock return or receipt mutation | J03 plus repeated fulfillment extension |
| REWARD03 | Revoke awarded XP after reviewed cheating | Append compensation with reason; block adjustments below zero; permit appeal | J04 and admin audit |
| NOTIFY01 | Quiet hours spanning midnight and cap 0/1/3 | Correct suppression; at most configured cap including local reservation | Native + provider test |
| NOTIFY02 | Revoke notification permission or disable competition | No challenge delivery; other study features still work | K01 plus Android permission test |
| NOTIFY03 | Configure valid/invalid SMTP and FCM credentials | Successful delivery is recorded only after provider acknowledgment; failures remain pending | External integration gate |
| SCALE01 | Sustained 15-user mixed study/polling load | Record error rate, latency and memory; no double purchase or lost queue item | Pilot load test |

## Execution and release procedure

1. Build Java from clean source; run domain assertions, JavaScript unit tests and HTTP integration tests.
2. Run Playwright with the browser executable available; inspect screenshots and console failures.
3. Perform the listed device, network and school-account tests with synthetic data first.
4. Record pass/fail, actual device/OS/WebView, observed latency/memory and defect reference for every manual case. Never infer a device pass from a desktop screenshot.
5. A privacy breach, cross-user log exposure, duplicate charge, missing offline work or unauthorized minor prize approval blocks pilot release. Cosmetic layout issues are prioritized by accessibility impact.
6. Keep prize and competition flags off if their corresponding external gates have not passed. Solo study remains the defensible MVP.

## Test fixtures and privacy

Every automated integration run creates a fresh temporary SQLite database and synthetic `@study.test` accounts, then removes that database. No real student email, school ID or conversation data is used. Email/push messages are not sent by demo tests. Test screenshots show synthetic users only.
''']
(root/'docs/Test_Plan_and_Edge_Cases.md').write_text('\n'.join(lines))
print(f'Mapped {count} explicit Part 1 edge-case rows plus narrative/device procedures.')

# Study Arena — Edge-case test plan and traceability

This matrix carries forward every scenario row in Part 1. Test references map to the named executable tests in `tests/`; a reference indicates relevant coverage, not proof that every real-device variation was executed. “Additional validation” is deliberately explicit. Read `Test_Results.md` for what actually ran.

## Strategy

- Java domain/security tests exercise cryptography, normalization, CSV and database invariants.
- Node HTTP integration tests use isolated synthetic Java servers and real SQLite databases.
- JavaScript unit tests simulate unknown-success retries, expiry, bounded queues, caching and offline CSV.
- Playwright exercises the real JavaScript UI against Java, including encrypted IndexedDB, service-worker offline reload, resumed quiz state, timer and responsive layout.
- Device/institution cases are acceptance procedures with a named expected result; they are not marked passed without the hardware or external configuration.

## Account

| Case ID and scenario | Expected result carried from Part 1 | Automated references / additional validation |
|---|---|---|
| EC01 · Duplicate email | Generic safe message; offer login/reset; never create duplicate identity. | A01–A04, E2E02/E2E05. Account recovery with dead inbox, real email and OS session behavior require institutional/device validation. |
| EC02 · Unverified user tries to compete | Block queue entry; preserve current page; resend verification with rate limit. Solo features remain available. | A01–A04, E2E02/E2E05. Account recovery with dead inbox, real email and OS session behavior require institutional/device validation. |
| EC03 · Forgotten password, dead inbox | Offer support-based recovery requiring school ID plus institutional verification; support cannot reveal account data; high-risk changes revoke sessions. | A01–A04, E2E02/E2E05. Account recovery with dead inbox, real email and OS session behavior require institutional/device validation. |
| EC04 · Two logged-in devices | Allowed. Data syncs; security page lists devices. Only one credited focus session or duel per account at a time. | A01–A04, E2E02/E2E05. Account recovery with dead inbox, real email and OS session behavior require institutional/device validation. |
| EC05 · Session expires mid-quiz | Solo attempt remains encrypted locally; reauthenticate and resume. Duel uses reconnect window, then server outcome rules. | A01–A04, E2E02/E2E05. Account recovery with dead inbox, real email and OS session behavior require institutional/device validation. |
| EC06 · Under 18 sees age-gated reward | Item is hidden or labeled unavailable; no claim endpoint accepts it. Approved minor-safe prizes follow consent policy. | A01–A04, E2E02/E2E05. Account recovery with dead inbox, real email and OS session behavior require institutional/device validation. |
| EC07 · Delete while owning room / holding coins | Show consequences; require owner transfer or disband. Virtual balance and inventory are deleted after retention window and cannot be cashed out. Pending prize claim must be resolved/cancelled first. | A01–A04, E2E02/E2E05. Account recovery with dead inbox, real email and OS session behavior require institutional/device validation. |
| EC08 · Guest registers after quiz | Device-held attempt is linked once using a one-time migration token; duplicate submissions are idempotent. | A01–A04, E2E02/E2E05. Account recovery with dead inbox, real email and OS session behavior require institutional/device validation. |
## Study sessions

| Case ID and scenario | Expected result carried from Part 1 | Automated references / additional validation |
|---|---|---|
| EC09 · Backgrounded/killed | Persist checkpoint; OS notification shows status; restore from monotonic/wall clock evidence. Long gaps may be marked unverified. | B01–B02, E2E07. Calls, alarms, clock settings, force-stop and travel timezone changes need physical-device tests. |
| EC10 · Call/alarm/screen lock | Timer continues by default; student can mark interruption; suspicious inactivity reduces or voids credit, not the personal log. | B01–B02, E2E07. Calls, alarms, clock settings, force-stop and travel timezone changes need physical-device tests. |
| EC11 · Device clock changed | Monotonic time and server receipt/checkpoints override wall clock; flag large drift. | B01–B02, E2E07. Calls, alarms, clock settings, force-stop and travel timezone changes need physical-device tests. |
| EC12 · Left overnight | Auto-stop at 4 hours; maximum 180 credited minutes; show adjustment. | B01–B02, E2E07. Calls, alarms, clock settings, force-stop and travel timezone changes need physical-device tests. |
| EC13 · Under 5 minutes | Save in history as uncredited; no XP/coins/streak. | B01–B02, E2E07. Calls, alarms, clock settings, force-stop and travel timezone changes need physical-device tests. |
| EC14 · Two devices | Connected starts permit one active session. Offline conflicts retain both logs; first server-accepted overlapping session is credited. This explicit Part 2 refinement supersedes retrospective earliest-start credit. | B01–B02, E2E07. Calls, alarms, clock settings, force-stop and travel timezone changes need physical-device tests. |
| EC15 · Timezone travel | Store UTC instants plus IANA timezone; day goals use timezone at session start; prevent duplicate grace-day/streak awards. | B01–B02, E2E07. Calls, alarms, clock settings, force-stop and travel timezone changes need physical-device tests. |
## Flashcards and quizzes

| Case ID and scenario | Expected result carried from Part 1 | Automated references / additional validation |
|---|---|---|
| EC16 · Empty / one-card deck | Empty cannot start review; one card supports practice but does not generate inflated repeated rewards. | C01–C04, D01–D04, CSV01–CSV05, E2E03–E2E06. Large-deck interaction, failed card image and device restart require the additional procedures below. |
| EC17 · 500-card deck | Supported with pagination/virtualization and chunked sync; card 501 is rejected until split. | C01–C04, D01–D04, CSV01–CSV05, E2E03–E2E06. Large-deck interaction, failed card image and device restart require the additional procedures below. |
| EC18 · Malformed CSV | Preview valid and rejected rows with exact errors; no mutation until user confirms. | C01–C04, D01–D04, CSV01–CSV05, E2E03–E2E06. Large-deck interaction, failed card image and device restart require the additional procedures below. |
| EC19 · Duplicate cards | Warn and offer skip/import anyway; stable hashes assist detection. | C01–C04, D01–D04, CSV01–CSV05, E2E03–E2E06. Large-deck interaction, failed card image and device restart require the additional procedures below. |
| EC20 · Long text / Unicode | Enforce documented limit by Unicode code points; preserve Filipino/Hiligaynon/special characters; wrap accessibly. | C01–C04, D01–D04, CSV01–CSV05, E2E03–E2E06. Large-deck interaction, failed card image and device restart require the additional procedures below. |
| EC21 · Failed card image | Alt text, retry, and text content remain; cache failure never crashes review. | C01–C04, D01–D04, CSV01–CSV05, E2E03–E2E06. Large-deck interaction, failed card image and device restart require the additional procedures below. |
| EC22 · No correct quiz answer | Cannot publish or download as valid; author receives field error. | C01–C04, D01–D04, CSV01–CSV05, E2E03–E2E06. Large-deck interaction, failed card image and device restart require the additional procedures below. |
| EC23 · App closes mid-solo quiz | Auto-resume from last committed answer; explicit discard only. | C01–C04, D01–D04, CSV01–CSV05, E2E03–E2E06. Large-deck interaction, failed card image and device restart require the additional procedures below. |
| EC24 · Answer after expiry | Rejected as late and recorded unanswered; server time governs connected modes. | C01–C04, D01–D04, CSV01–CSV05, E2E03–E2E06. Large-deck interaction, failed card image and device restart require the additional procedures below. |
## Matchmaking and duels

| Case ID and scenario | Expected result carried from Part 1 | Automated references / additional validation |
|---|---|---|
| EC25 · No opponent | After 20 seconds offer cancel, continued same-band search or a clearly labeled unranked bot. No automatic or adjacent-band widening is implemented. | H01–H02. Delay/loss windows, both-player disconnect and sustained latency require transport simulation and device validation. |
| EC26 · One disconnects | 20-second reconnect; otherwise forfeit if server is healthy. Repeated network losses may be voided instead of penalized. | H01–H02. Delay/loss windows, both-player disconnect and sustained latency require transport simulation and device validation. |
| EC27 · Both disconnect | Void unless server already has a conclusive completed result. | H01–H02. Delay/loss windows, both-player disconnect and sustained latency require transport simulation and device validation. |
| EC28 · Slow connection | Server deadlines include a small fixed transport allowance; questions are preloaded; no per-user dynamic advantage. | H01–H02. Delay/loss windows, both-player disconnect and sustained latency require transport simulation and device validation. |
| EC29 · App closed | Rejoin active duel within reconnect window; otherwise forfeit/void under same rule. | H01–H02. Delay/loss windows, both-player disconnect and sustained latency require transport simulation and device validation. |
| EC30 · Rematch spam | One pending request per opponent; cooldown and block/report controls. | H01–H02. Delay/loss windows, both-player disconnect and sustained latency require transport simulation and device validation. |
| EC31 · Deliberate deranking | Detect loss streaks with abnormal speed/accuracy changes and repeated counterparties; freeze rating and review rather than automatically accusing. | H01–H02. Delay/loss windows, both-player disconnect and sustained latency require transport simulation and device validation. |
## Rooms

| Case ID and scenario | Expected result carried from Part 1 | Automated references / additional validation |
|---|---|---|
| EC32 · Owner leaves/deletes | Must transfer ownership or disband; forced deletion transfers to longest-tenured eligible member, otherwise archives. | G01–G02. Lifecycle expiry and full-room races have explicit manual/integration extension procedures below. |
| EC33 · Last member leaves | Room archives immediately; content ownership remains with original creators. | G01–G02. Lifecycle expiry and full-room races have explicit manual/integration extension procedures below. |
| EC34 · Expired/guessed code | Generic invalid/expired response; attempt rate limit; codes expire and can be rotated. | G01–G02. Lifecycle expiry and full-room races have explicit manual/integration extension procedures below. |
| EC35 · Member cap | Join rejected atomically; waitlist deferred. | G01–G02. Lifecycle expiry and full-room races have explicit manual/integration extension procedures below. |
| EC36 · Removed mid-session | Access/chat stops; personal timer becomes solo and remains private. | G01–G02. Lifecycle expiry and full-room races have explicit manual/integration extension procedures below. |
| EC37 · Concurrent deck edits | First accepted version wins; other creates conflict copy/proposal. | G01–G02. Lifecycle expiry and full-room races have explicit manual/integration extension procedures below. |
| EC38 · No activity 30 days | Archive after warning; owner can restore for another 30 days before room metadata deletion, subject to content ownership rules. | G01–G02. Lifecycle expiry and full-room races have explicit manual/integration extension procedures below. |
## Progression and rewards

| Case ID and scenario | Expected result carried from Part 1 | Automated references / additional validation |
|---|---|---|
| EC39 · Insufficient currency | Atomic rejection; no partial debit. | J01–J04. Season boundary is design-only for standings; the captured duel season is implemented. Stock contention must also be stress-tested. |
| EC40 · Double tap / two-device redeem | Same idempotency key or unique purchase constraint returns one result and one debit. | J01–J04. Season boundary is design-only for standings; the captured duel season is implemented. Stock contention must also be stress-tested. |
| EC41 · Already owned | Return existing entitlement; do not charge. | J01–J04. Season boundary is design-only for standings; the captured duel season is implemented. Stock contention must also be stress-tested. |
| EC42 · Season ends mid-duel | Keep season_id captured at creation; never reset permanent learning history. Seasonal standings are deferred. | J01–J04. Season boundary is design-only for standings; the captured duel season is implemented. Stock contention must also be stress-tested. |
| EC43 · XP revoked | Append compensating ledger entry with reason; notify user and permit appeal. Never rewrite ledger history. | J01–J04. Season boundary is design-only for standings; the captured duel season is implemented. Stock contention must also be stress-tested. |
| EC44 · Negative balance | Purchases blocked; admin review; compensating credit/debit only. Client never invents zero. | J01–J04. Season boundary is design-only for standings; the captured duel season is implemented. Stock contention must also be stress-tested. |
| EC45 · Out of stock | Inventory reserved atomically for a short checkout window; otherwise return `OUT_OF_STOCK`. | J01–J04. Season boundary is design-only for standings; the captured duel season is implemented. Stock contention must also be stress-tested. |
## Connectivity

| Case ID and scenario | Expected result carried from Part 1 | Automated references / additional validation |
|---|---|---|
| EC46 · No internet at launch | Open cached signed-in workspace or guest content; show unobtrusive offline banner. | SYNC01–SYNC06, E2E04–E2E06. Browser offline/queue paths are exercised; real 3G, storage pressure and large media downloads remain device checks. |
| EC47 · Lost mid-sync | Exponential backoff; retain operation in durable queue; never lose local study work. | SYNC01–SYNC06, E2E04–E2E06. Browser offline/queue paths are exercised; real 3G, storage pressure and large media downloads remain device checks. |
| EC48 · Slow 3G | Paginated metadata, compressed images, resumable downloads, skeletons, explicit cancel. | SYNC01–SYNC06, E2E04–E2E06. Browser offline/queue paths are exercised; real 3G, storage pressure and large media downloads remain device checks. |
| EC49 · Server succeeded/client timed out | Retry same idempotency key; server returns original result. | SYNC01–SYNC06, E2E04–E2E06. Browser offline/queue paths are exercised; real 3G, storage pressure and large media downloads remain device checks. |
| EC50 · Offline conflicts on two devices | Append-only attempts/reviews merge; profile uses latest server-accepted version; deck edits create conflict copy. | SYNC01–SYNC06, E2E04–E2E06. Browser offline/queue paths are exercised; real 3G, storage pressure and large media downloads remain device checks. |
| EC51 · Large sync queue | Process in chunks, prioritize user work over analytics, show count/status, permit Wi-Fi-only media sync. | SYNC01–SYNC06, E2E04–E2E06. Browser offline/queue paths are exercised; real 3G, storage pressure and large media downloads remain device checks. |
| EC52 · Partial download | `.partial` state is not openable; range-resume and checksum verify before atomic promotion. | SYNC01–SYNC06, E2E04–E2E06. Browser offline/queue paths are exercised; real 3G, storage pressure and large media downloads remain device checks. |
## Content and safety

| Case ID and scenario | Expected result carried from Part 1 | Automated references / additional validation |
|---|---|---|
| EC53 · Copyright concern | Unpublish/quarantine pending review; retain evidence; notify uploader; provide appeal/counter-notice route defined by institution. | G02, L01. Safeguarding and copyright policy require an institution-approved procedure, not automated certification. |
| EC54 · Inappropriate deck/name/chat | Automated term/rate signals plus reports; hide locally/block user; moderator reviews with context. | G02, L01. Safeguarding and copyright policy require an institution-approved procedure, not automated certification. |
| EC55 · Report pending | Reporter sees status without accused user's private data; high-severity material can be temporarily hidden. | G02, L01. Safeguarding and copyright policy require an institution-approved procedure, not automated certification. |
| EC56 · Bullying/harassment | Immediate block/leave/report controls; preserve evidence; moderator may remove/suspend; no forced direct mediation. | G02, L01. Safeguarding and copyright policy require an institution-approved procedure, not automated certification. |
| EC57 · Visible distress | Show local emergency/support resources and encourage contacting a trusted adult/professional; escalate under written school safeguarding policy; app does not diagnose or counsel. | G02, L01. Safeguarding and copyright policy require an institution-approved procedure, not automated certification. |
| EC58 · Spam accounts | Verification, rate limits, device/IP risk signals, content throttles, and graduated suspension. | G02, L01. Safeguarding and copyright policy require an institution-approved procedure, not automated certification. |

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

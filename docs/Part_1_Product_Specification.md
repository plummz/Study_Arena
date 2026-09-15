# Study Arena — Part 1: Product Specification and Scope Decisions

**Status:** Draft for stakeholder review  
**Project:** Western Institute of Technology capstone/class project  
**Target cohort:** Senior high school and college students, including minors aged 16–17  
**Delivery constraint:** 1–2 beginner developers, 4–6 weeks  
**Release targets requested:** Android student app, web admin panel, teacher/moderator role, duels, live study rooms, and a real-prize track

## 1. Executive decision

Study Arena will be a **solo-first, offline-first study application** with optional social and competitive pilots. The product's main loop is: select a weak topic, study offline, answer explained questions, see mastery change, and earn deterministic rewards. Competition is hidden unless a student explicitly enables it and is never required for XP, levels, content access, or top progression.

The complete brief is too large for a safe production release by 1–2 beginner developers in 4–6 weeks. Release 1 therefore uses three scope tiers:

| Tier | Meaning | Included capabilities |
|---|---|---|
| **Core MVP** | Must be reliable at the final demonstration | Accounts, onboarding, guest conversion, solo timer, goals/history/streak, flashcards, quizzes with explanations, basic content library, weak-area tracker, offline study/sync, XP/currency, cosmetics, notifications, privacy/export/deletion, admin moderation and aggregate dashboard |
| **Controlled pilot** | Real but intentionally narrow; enabled only for approved demo users | One room type, parallel group timer, room thread, same-band 1v1 duels, teacher publishing, admin reward ledger, school-funded prize claims |
| **Deferred** | Specified now but built after the capstone MVP | Group tournaments, seasonal leaderboard, automatic matchmaking expansion, rich real-time collaborative deck editing, public creator ecosystem, automated prize fulfillment, iOS client |

No deferred screen will masquerade as functional. Feature flags remove incomplete features from navigation.

## 2. Evidence-led product principles

1. **Solo is the default.** Onboarding defaults competition to hidden. Enabling it is a reversible choice in Settings.
2. **Progress means self-improvement.** Home emphasizes goals, mastery, streak, and personal history. Public rank is never the default progress view.
3. **Social matching uses skill bands.** Bands are `Foundation`, `Developing`, `Proficient`, and `Advanced`; raw rating is private.
4. **Rewards are deterministic.** Students always know the XP and coins available. No paid randomization, loot boxes, gambling, or cash payout to minors.
5. **Content leads the experience.** Every game mechanic points back to flashcards, quizzes, explanations, and attributed materials.
6. **Levels are removable.** Levels are behind a feature flag. Mastery, history, and earned inventory do not depend on the level system.
7. **Calm and cozy.** Warm neutral surfaces, restrained animation, plain language, low visual pressure, reduced-motion support, and no shame messages.

## 3. Goals, non-goals, and success measures

### Goals

- Allow meaningful study with no network connection.
- Make weak areas understandable and actionable.
- Reward consistent effort without coercive competition.
- Provide verified and attributed study resources, with an engineering category.
- Demonstrate safe, same-band rooms and duels as optional features.
- Give moderators enough control to handle content, reports, flags, and prize claims.

### Non-goals for Release 1

- Replacing a learning-management system or official gradebook.
- Paying cash directly through the application.
- Proctoring high-stakes examinations.
- Open direct messaging, public follower counts, or precise location collection.
- Real-time Google-Docs-style shared deck editing.
- Claiming that mastery estimates are grades or psychometric certification.

### Release 1 success measures

- At least 80% of seeded flashcards and saved quizzes remain usable in airplane mode.
- At least 95% crash-free sessions in the pilot cohort.
- Median cold start below 3 seconds on the designated 2 GB RAM test phone.
- A student can finish first study activity within 3 minutes of launch.
- At least 70% of pilot students complete one solo study activity.
- At least 50% return for a second study day during the pilot.
- At least 80% of quiz attempts display an explanation review screen.
- No competitive surface appears for accounts that opted out.
- 100% of real-prize ledger changes have actor, timestamp, reason, and immutable audit entry.

These are pilot targets, not claims that the 15-person survey generalizes to all students.

## 4. Roles and permissions

| Capability | Guest | Student | Room owner | Teacher/moderator | Administrator |
|---|---:|---:|---:|---:|---:|
| Browse public content / try one quiz | Yes | Yes | Yes | Yes | Yes |
| Save private study data | Device only | Yes | Yes | Yes, as student | Yes, as student |
| Create content | No | Private/shared decks | Same | Verified-content drafts | Yes |
| Create/manage room | No | Create/join | Invite/remove/schedule/disband | Moderate assigned rooms | All rooms for safety |
| View individual private logs | No | Own only | No | No | No by default; access only for support/security under logged procedure |
| View aggregate cohort analytics | No | Own progress | Room participation totals | Assigned cohort, minimum group threshold | System aggregate |
| Moderate reports | No | Submit | Submit | Assigned queues | All queues |
| Manage flags/users/rewards | No | No | No | No | Yes |

Teachers receive no automatic access to a student's private notes, timer history, or answers. Cohort analytics suppress groups below five active students to reduce re-identification risk.

## 5. Functional specification by module

Each module explicitly defines happy, empty, error, and offline behavior.

### A. Accounts and onboarding

**Scope.** Email/password registration, school ID as an institution identifier, verification, reset, guest trial, profile, course/subjects, skippable diagnostic, competition preference, export, and deletion.

- **Happy:** Guest tries one seeded quiz; registration verifies email; local result is attached to the new account; student chooses display name, birth date/age band, school ID, course/year, subjects, optional diagnostic, and whether to show competitive features.
- **Empty:** New home presents `Choose a subject` and three actions: diagnostic, browse content, or start a focus session. Diagnostic skip is clearly available.
- **Error:** Field-level errors preserve entered data. Duplicate email offers login/reset. Invalid school ID explains the accepted format without revealing whether another person owns it. Verification resend is rate-limited with a visible countdown.
- **Offline:** Public guest content and a cached quiz work. New registration, login on a new device, verification, password reset, deletion, and export require a connection. An already authenticated account may enter offline mode using an encrypted local session.

**Decisions.** Competition defaults to `hidden`; changing it requires a deliberate Settings toggle. Birth date is collected only if the prize pilot needs exact eligibility; otherwise store an age band. School ID is encrypted and never public.

### B. Solo study

- **Happy:** Student selects subject/topic, duration, optional notes, and starts a timer. Pause reasons include call/interruption. Completion shows elapsed credited time, topics, goal progress, streak, XP/coins, and a note summary.
- **Empty:** No history shows a calm first-session card with 10-, 25-, and 45-minute presets.
- **Error:** If completion cannot sync, the session is saved locally as `Pending sync`; rewards are provisional until the server validates it.
- **Offline:** Full timer, notes, goals, and local history work. A monotonic elapsed timer is used while the app is alive; start/end wall-clock values and checkpoints are stored for later validation.

**Credit rules.** Minimum credited session is 5 minutes. Sessions cap credited time at 180 minutes and auto-stop after 4 hours. A grace day preserves the visible streak once per rolling 30 days but awards no study minutes. Only one active credited session is allowed per account; simultaneous-device conflicts credit the earliest valid session and retain the other as an uncredited log.

### C. Flashcards

- **Happy:** Create/edit/delete decks and cards; organize by subject/topic; import CSV or pasted text; review using spaced repetition; shuffle; mark known/review; share to public or room; clone shared decks.
- **Empty:** Empty deck offers add, paste, or CSV import. Reviews with nothing due show the next due time and an optional ungraded practice mode.
- **Error:** Import preview identifies row numbers and reasons. User may fix the file or import valid rows only after explicit confirmation. Failed writes remain local and retryable.
- **Offline:** Owned and downloaded decks are fully reviewable and editable. Review events queue for sync. Publishing/sharing and cloning a not-yet-downloaded deck require connection.

**Limits.** Release 1 limits a deck to 500 cards, plain text to 4,000 characters per side, and one compressed image per side. Duplicate front/back hashes trigger a warning, not an automatic deletion. Unicode supports Filipino, Hiligaynon, and special characters.

### D. Quizzes

- **Happy:** Multiple choice, true/false, and identification; timed or untimed; instant feedback with correct answer and explanation; saved offline attempt; reshuffled retake; topic scores feed mastery.
- **Empty:** A quiz with zero valid questions cannot be published or attempted. Search-empty offers adjacent subjects and filter reset.
- **Error:** Authoring validation requires at least one correct answer and an explanation. Sync failures keep a signed local attempt pending. Image failure shows alt text and a retry control without blocking text questions.
- **Offline:** Downloaded quizzes work. Answers, timing events, and result are queued. Competitive attempts are never available offline.

**Resume decision.** Solo quizzes save after every answer and resume from the last committed item. The student may discard explicitly. After session expiry, reauthentication returns them to the saved attempt. Answers received after a local/server deadline are recorded as unanswered. Identification uses normalized, teacher-defined accepted answers; fuzzy matching is never silently graded correct.

### E. Content library

- **Happy:** Browse/search/filter by course, subject, year, and file type; engineering has a first-class category; view attribution and verification; save/download; upload with source/license; report copyright or inappropriate material.
- **Empty:** No results explain active filters and offer clear/reset. Empty categories show moderator-curated starter resources.
- **Error:** Failed uploads retain metadata draft. Unsupported/oversized files are rejected before transfer. Failed previews allow download if the file itself is safe and available.
- **Offline:** Previously downloaded files and cached metadata open. Search is limited to downloaded/cached items and clearly labeled `Offline results`.

**Moderation.** Student uploads start private or `Pending review`; only approved content enters public search. A verification badge means source/ownership/basic quality was checked, not academic endorsement. Reports can temporarily limit discoverability without deleting evidence.

### F. Weak-area tracker

- **Happy:** Mastery is calculated per topic from recent quiz correctness and flashcard recall, weighted by recency and evidence count. It displays `Needs review`, `Developing`, or `Strong`, confidence (`Low evidence` where appropriate), and a suggested plan.
- **Empty:** With insufficient evidence, it invites a diagnostic or a short quiz; it never labels the student weak from no data.
- **Error:** If recalculation fails, the last calculated view shows its timestamp. No fabricated score is shown.
- **Offline:** Local completed work updates a provisional plan marked `Waiting to sync`; canonical mastery reconciles later.

**Decision.** Topic rank is private. The algorithm exposes contributing attempts and permits dismissing a recommendation. It is guidance, not an official grade.

### G. Study rooms and groups

- **Happy:** Create/join via expiring code or same-band discovery; roster; shared decks/materials; parallel group timer; moderated thread; schedule; leave/disband. Owner controls subject, schedule, member cap, invitations, and removal.
- **Empty:** A new room shows setup tasks and invite controls. No scheduled session offers `Schedule` or `Start solo`.
- **Error:** Expired/invalid code gives a generic response; full rooms offer return. Chat/send failures keep a retryable draft. Removal ends access immediately but preserves the student's own study record.
- **Offline:** Downloaded shared materials remain readable; the student may run a solo timer associated with the room, queued for sync. Roster, chat, invitations, and group-presence require connection.

**Release 1 limit.** Rooms cap at 10 members. Shared decks use clone-and-propose: one editor publishes a version; concurrent edits create a conflict copy for manual merge. Rich concurrent editing is deferred.

### H. Competitive layer — opt-in only

- **Happy:** Verified students who enabled competition can enter a same-band 1v1 duel. Both receive equivalent question difficulty and server-authoritative timing. Result shows explanations after the duel, rating change, report, and rate-limited rematch.
- **Empty:** If no opponent appears within 20 seconds, continue searching, cancel, or play a clearly labeled practice bot whose result does not affect rating, leaderboards, or prizes. After 45 seconds, the pilot may widen by one adjacent band only with both users' consent.
- **Error:** A disconnected player gets a 20-second reconnect window. Server outage voids the duel. A client crash can resume during that window. Outcomes never depend solely on the reporting client.
- **Offline:** Every competition entry point is disabled with `Internet required`; solo study remains available.

**Global switch.** Turning competition off removes duel, tournament, peer rank, challenge notifications, and competition rewards immediately. It does not delete past private results. Group tournaments and seasonal leaderboards are deferred; the data model will accommodate them later.

### I. Progression

- **Happy:** XP is granted for validated study minutes, due-card reviews, quiz accuracy improvement, and streak milestones. Level detail lists exact thresholds and unlocks. Badges are criterion-based.
- **Empty:** A new account sees `0 XP` plus one transparent earning example, not a low-rank warning.
- **Error:** Pending rewards show separately; reconciliation explains adjustments. Support reference IDs are provided for unexplained changes.
- **Offline:** Activity creates provisional XP. Server validation is authoritative and uses idempotent activity IDs.

**Decision.** Level display is feature-flagged. Season reset affects seasonal cosmetics/rank only; it never erases XP history, mastery, decks, attempts, or study history.

### J. Rewards

- **Happy:** Validated activity earns coins; shop lists cosmetics, themes, content unlocks, and streak freezes with fixed prices. Purchase is atomic and idempotent. Prize pilot accepts eligible claims against a school/org-funded catalog with published rules and manual approval.
- **Empty:** Empty inventory suggests attainable items. Out-of-stock prizes remain visible with status and no checkout button.
- **Error:** Insufficient funds shows balance and gap. Owned item cannot be repurchased. Failed/unknown checkout is safely retryable using the same idempotency key.
- **Offline:** Catalog and inventory may be viewed from cache, but purchases, equipping newly acquired server items, and prize claims require connection.

**Real-prize pilot.** No user pays to enter. No chance-based award. No cash payout through the app. Minors see only rewards specifically approved for minors and must satisfy documented institutional/parental consent. Every rule version, stock change, claim, approval, denial, fulfillment, and reversal is audited. For a 4–6 week capstone, fulfillment is manual and performed by an authorized school representative outside the app; the app records status and receipt evidence.

### K. Notifications

- **Happy:** Student sets reminder times and independently controls reminders, streak warnings, room invites, duel challenges, and reward events. Quiet hours and maximum three notifications per local day apply.
- **Empty:** No reminders set shows optional presets without nagging.
- **Error:** Denied OS permission is respected; settings explain how to re-enable it. Failed push registration does not block the app.
- **Offline:** Local scheduled reminders and streak warnings work; remote invitations/challenges arrive after reconnection only if still relevant.

Competition notifications are automatically disabled when competition is hidden.

### L. Admin and analytics

- **Happy:** Authorized web users review content/reports, act on users, inspect the reward ledger, change feature flags, publish teacher content, and view aggregate dashboards.
- **Empty:** Queues show `You're caught up`; dashboards distinguish zero data from loading failure.
- **Error:** Every mutation requires reason and audit entry; failed actions do not optimistically disappear. Dangerous actions require reauthentication and confirmation.
- **Offline:** Admin functions require connection. Read-only cached dashboards are not supported in Release 1 to avoid stale moderation decisions.

Analytics are aggregate and privacy-minimized. Private note text and individual study logs are excluded.

## 6. Explicit edge-case behavior

### Account

| Case | Intended behavior |
|---|---|
| Duplicate email | Generic safe message; offer login/reset; never create duplicate identity. |
| Unverified user tries to compete | Block queue entry; preserve current page; resend verification with rate limit. Solo features remain available. |
| Forgotten password, dead inbox | Offer support-based recovery requiring school ID plus institutional verification; support cannot reveal account data; high-risk changes revoke sessions. |
| Two logged-in devices | Allowed. Data syncs; security page lists devices. Only one credited focus session or duel per account at a time. |
| Session expires mid-quiz | Solo attempt remains encrypted locally; reauthenticate and resume. Duel uses reconnect window, then server outcome rules. |
| Under 18 sees age-gated reward | Item is hidden or labeled unavailable; no claim endpoint accepts it. Approved minor-safe prizes follow consent policy. |
| Delete while owning room / holding coins | Show consequences; require owner transfer or disband. Virtual balance and inventory are deleted after retention window and cannot be cashed out. Pending prize claim must be resolved/cancelled first. |
| Guest registers after quiz | Device-held attempt is linked once using a one-time migration token; duplicate submissions are idempotent. |

### Study sessions

| Case | Intended behavior |
|---|---|
| Backgrounded/killed | Persist checkpoint; OS notification shows status; restore from monotonic/wall clock evidence. Long gaps may be marked unverified. |
| Call/alarm/screen lock | Timer continues by default; student can mark interruption; suspicious inactivity reduces or voids credit, not the personal log. |
| Device clock changed | Monotonic time and server receipt/checkpoints override wall clock; flag large drift. |
| Left overnight | Auto-stop at 4 hours; maximum 180 credited minutes; show adjustment. |
| Under 5 minutes | Save in history as uncredited; no XP/coins/streak. |
| Two devices | Earliest valid active session receives credit; second is stopped/uncredited on sync. |
| Timezone travel | Store UTC instants plus IANA timezone; day goals use timezone at session start; prevent duplicate grace-day/streak awards. |

### Flashcards and quizzes

| Case | Intended behavior |
|---|---|
| Empty / one-card deck | Empty cannot start review; one card supports practice but does not generate inflated repeated rewards. |
| 500-card deck | Supported with pagination/virtualization and chunked sync; card 501 is rejected until split. |
| Malformed CSV | Preview valid and rejected rows with exact errors; no mutation until user confirms. |
| Duplicate cards | Warn and offer skip/import anyway; stable hashes assist detection. |
| Long text / Unicode | Enforce documented limit by Unicode code points; preserve Filipino/Hiligaynon/special characters; wrap accessibly. |
| Failed card image | Alt text, retry, and text content remain; cache failure never crashes review. |
| No correct quiz answer | Cannot publish or download as valid; author receives field error. |
| App closes mid-solo quiz | Auto-resume from last committed answer; explicit discard only. |
| Answer after expiry | Rejected as late and recorded unanswered; server time governs connected modes. |

### Matchmaking and duels

| Case | Intended behavior |
|---|---|
| No opponent | Options at 20 seconds; optional one-band widening at 45 seconds with consent; labeled unranked bot available. |
| One disconnects | 20-second reconnect; otherwise forfeit if server is healthy. Repeated network losses may be voided instead of penalized. |
| Both disconnect | Void unless server already has a conclusive completed result. |
| Slow connection | Server deadlines include a small fixed transport allowance; questions are preloaded; no per-user dynamic advantage. |
| App closed | Rejoin active duel within reconnect window; otherwise forfeit/void under same rule. |
| Rematch spam | One pending request per opponent; cooldown and block/report controls. |
| Deliberate deranking | Detect loss streaks with abnormal speed/accuracy changes and repeated counterparties; freeze rating and review rather than automatically accusing. |

### Rooms

| Case | Intended behavior |
|---|---|
| Owner leaves/deletes | Must transfer ownership or disband; forced deletion transfers to longest-tenured eligible member, otherwise archives. |
| Last member leaves | Room archives immediately; content ownership remains with original creators. |
| Expired/guessed code | Generic invalid/expired response; attempt rate limit; codes expire and can be rotated. |
| Member cap | Join rejected atomically; waitlist deferred. |
| Removed mid-session | Access/chat stops; personal timer becomes solo and remains private. |
| Concurrent deck edits | First accepted version wins; other creates conflict copy/proposal. |
| No activity 30 days | Archive after warning; owner can restore for another 30 days before room metadata deletion, subject to content ownership rules. |

### Progression and rewards

| Case | Intended behavior |
|---|---|
| Insufficient currency | Atomic rejection; no partial debit. |
| Double tap / two-device redeem | Same idempotency key or unique purchase constraint returns one result and one debit. |
| Already owned | Return existing entitlement; do not charge. |
| Season ends mid-duel | Duel belongs to season captured at creation; settlement completes into that season while permanent history remains. |
| XP revoked | Append compensating ledger entry with reason; notify user and permit appeal. Never rewrite ledger history. |
| Negative balance | Purchases blocked; admin review; compensating credit/debit only. Client never invents zero. |
| Out of stock | Inventory reserved atomically for a short checkout window; otherwise return `OUT_OF_STOCK`. |

### Connectivity

| Case | Intended behavior |
|---|---|
| No internet at launch | Open cached signed-in workspace or guest content; show unobtrusive offline banner. |
| Lost mid-sync | Exponential backoff; retain operation in durable queue; never lose local study work. |
| Slow 3G | Paginated metadata, compressed images, resumable downloads, skeletons, explicit cancel. |
| Server succeeded/client timed out | Retry same idempotency key; server returns original result. |
| Offline conflicts on two devices | Append-only attempts/reviews merge; profile uses latest server-accepted version; deck edits create conflict copy. |
| Large sync queue | Process in chunks, prioritize user work over analytics, show count/status, permit Wi-Fi-only media sync. |
| Partial download | `.partial` state is not openable; range-resume and checksum verify before atomic promotion. |

### Content and safety

| Case | Intended behavior |
|---|---|
| Copyright concern | Unpublish/quarantine pending review; retain evidence; notify uploader; provide appeal/counter-notice route defined by institution. |
| Inappropriate deck/name/chat | Automated term/rate signals plus reports; hide locally/block user; moderator reviews with context. |
| Report pending | Reporter sees status without accused user's private data; high-severity material can be temporarily hidden. |
| Bullying/harassment | Immediate block/leave/report controls; preserve evidence; moderator may remove/suspend; no forced direct mediation. |
| Visible distress | Show local emergency/support resources and encourage contacting a trusted adult/professional; escalate under written school safeguarding policy; app does not diagnose or counsel. |
| Spam accounts | Verification, rate limits, device/IP risk signals, content throttles, and graduated suspension. |

### Anti-cheat

The app cannot reliably detect a student looking up answers in another app and must not pretend otherwise. Signals include app background transitions during timed duels, impossibly short response times, repeated answer-pattern similarity, automation-like timing, clock/checkpoint inconsistencies, emulator/root indicators used only as risk signals, repeated opponent pairings, coordinated forfeits, duplicate school IDs, and device/account clusters. No single weak signal causes suspension.

Graduated response: (1) silently limit reward/rating pending verification; (2) warn and explain the affected rule; (3) void attempt/reward; (4) reset competitive rating/skill band only after review; (5) temporary suspension; (6) permanent suspension for repeated severe abuse, with logged evidence and appeal. Academic study history is retained even when competitive scores are voided.

### Device and accessibility

- Android baseline is a low-end 2 GB RAM phone; lists are virtualized and image memory is bounded.
- Layout supports 320 dp width, portrait orientation, large system text, reflow, and no clipped essential actions.
- Dark mode and reduced motion are supported.
- Every control has a programmatic label, role, state, and meaningful focus order.
- Color is paired with text/icon/shape; mastery is never red/green alone.
- Primary actions sit in one-handed lower reach where safe; destructive actions are separated.
- Low-battery mode reduces animation/realtime refresh; downloads can require charger/Wi-Fi by preference.
- Storage checks precede downloads; cache cleanup never deletes user-created unsynced work.

## 7. Privacy and data governance (RA 10173 design baseline)

This is a product specification, not legal advice. Before any real deployment, Western Institute of Technology should designate the responsible Personal Information Controller, identify its Data Protection Officer or accountable privacy lead, approve the privacy notice/consent basis, complete a privacy impact assessment, and obtain institutional legal review. The National Privacy Commission describes RA 10173 as regulating the collection, use, storage, disclosure, and destruction of personal data and recognizes data-subject rights.

### Data inventory, purpose, storage, and retention

| Data | Purpose | Storage | Proposed retention |
|---|---|---|---|
| Email, password credential, verification state | Authentication/recovery | Encrypted transport; managed auth; password hashes only | Account life + 30-day deletion recovery; security logs up to 12 months |
| School ID | Institutional eligibility and duplicate-account control | Encrypted field; masked in UI; never analytics/public | Account life; erased after deletion recovery unless dispute/legal hold |
| Age band or birth date | Minor safeguards/prize eligibility | Prefer age band; exact date encrypted only if required | Account life; exact date deleted when no longer needed |
| Display name/avatar | User-facing identity | Server and device cache | Account life; anonymized on deletion where shared history must remain |
| Course/year/subjects | Personalization and content filters | Server plus encrypted local cache | Account life or until user removes |
| Study sessions, notes, quiz/flashcard activity | Progress, mastery, sync | Server in Philippine/approved region when available; encrypted device DB | Detailed logs 24 months after last activity; aggregate/anonymized metrics longer |
| Private notes | Student recall | Encrypted storage; excluded from teacher analytics/search | Account life or user deletion; no routine moderator access |
| Room messages/reports | Collaboration and safety | Server; downloaded room cache | Messages 12 months after room archive; reports/evidence up to 24 months or policy requirement |
| Device/push tokens | Notifications/security | Server secret store | Until revoked, stale, or account deletion |
| Anti-abuse signals/IP logs | Integrity/security | Restricted security store | Normally 90 days; substantiated cases up to 12 months/appeal completion |
| Reward/XP/prize ledgers | Accounting, audit, dispute handling | Append-only server ledger | Virtual ledger 24 months after deletion; prize records per school accounting/legal policy, minimized/pseudonymized |
| Uploaded content/attribution | Library operation and rights handling | Object storage + metadata DB | Until deleted/withdrawn; moderation evidence follows policy |
| Aggregate analytics | Improve product/capstone evaluation | De-identified event store | Up to 24 months, then delete or irreversibly aggregate |

### Privacy rules

- Collect only what is needed; no contacts, precise location, advertising ID, microphone, or background tracking.
- Study logs and notes are private by default. Sharing requires a specific object/action, not blanket consent.
- Leaderboards expose only a chosen display name and optional cosmetic; never email, school ID, birth date, exact course section, private activity, or raw skill rating.
- Export includes profile, owned content, sessions, attempts, reviews, mastery inputs, room membership, inventory, and ledger in machine-readable form.
- Deletion uses immediate access revocation, a 30-day recoverable queue, then hard deletion/anonymization across primary stores and backup expiry. Shared authored content is either deleted or anonymized according to the user's choice where legally and technically possible.
- Access is role-based and least-privilege; sensitive admin actions and data access are audited.
- Encryption applies in transit and at rest; local secrets use Android secure storage; private local databases are encrypted.
- Breach response, notification assessment, data-subject requests, correction, objection, portability/export, and complaint handling must be documented before pilot onboarding.

### Minors and consent assumption

For the capstone pilot, the assumed model is **institutionally supervised participation**, with clear student assent and documented parent/guardian consent for participants under 18 where required by the institution's legal/privacy determination. No public launch or real-prize pilot involving minors proceeds until the institution approves the lawful basis, safeguarding process, official rules, and consent materials. Declining optional competition, analytics, notifications, or prize participation cannot block core study access.

## 8. Non-functional acceptance requirements

| Area | Release 1 acceptance criterion |
|---|---|
| Offline | Owned/downloaded flashcards, saved quizzes, cached explanations, timer, goals, notes, and downloaded materials work in airplane mode. |
| Startup | Median cold start <3 s on agreed 2 GB test phone with representative data; offline startup does not wait for network timeout. |
| Performance | 60 fps target for ordinary scrolling; no list renders all 500 cards at once; memory remains within low-end device limits. |
| Package/storage | Android download target <35 MB excluding optional content; user can inspect and clear downloaded media. |
| Reliability | Durable local mutation queue; idempotent server mutations; resumable verified file downloads. |
| Cost | Free/education tiers where appropriate; storage/upload quotas; no always-on custom server required for the basic MVP. |
| Security | OWASP-aligned validation, authorization on every object, rate limits, secret separation, dependency scanning, audit logs. |
| Accessibility | Screen reader pass on all primary flows, large-font/reflow pass, contrast pass, keyboard support for admin. |
| UX states | Every data surface defines loading, empty, recoverable error, success, offline, and permission-denied states. |
| Localization | UTF-8 end-to-end; Filipino/Hiligaynon content is preserved; English UI first, strings externalized for later localization. |

## 9. Release 1 screen-level scope summary

### Android core

Welcome/guest, register/login/reset/verify, profile/subjects/preferences/diagnostic, home, focus timer and summary, goals/history/streak, deck list/editor/import/review, quiz browse/attempt/review/retake, content library/view/download/report, weak areas/study plan, progress/wallet/shop/inventory, notification/privacy/accessibility settings, export/deletion.

### Android controlled pilot

Room list/create/join/detail/roster/shared resources/group timer/thread/schedule; competition consent/queue/duel/result/report; prize catalog/eligibility/rules/claim status.

### Web admin/teacher

Secure login, moderation queues, content editor/verification, report detail/action, aggregate analytics, user restriction tools, feature flags, reward catalog/stock/ledger/claim approval/audit.

## 10. Defensible 4–6 week implementation boundary

To avoid a nonfunctional breadth demo, the recommended final evaluation build is:

1. **Weeks 1–2:** authentication/onboarding, offline local model, seeded engineering and general content, solo timer, flashcard review, quiz attempts/explanations.
2. **Weeks 3–4:** sync, weak-area tracker, progression/cosmetics, downloads, accessibility/performance, admin content/report queue.
3. **Week 5:** one room implementation and same-band 1v1 duel pilot using a small invited test cohort; teacher publishing; prize claim ledger with manual fulfillment.
4. **Week 6:** end-to-end tests, privacy/export/deletion, abuse flows, low-end device profiling, data seeding, defect fixing, demo contingency.

If the project has only four weeks, duels are reduced to scheduled/invite-only matches and rooms to a parallel timer plus thread. If either is unstable at release freeze, its feature flag stays off; core solo study remains complete.

## 11. Key ambiguities resolved

- **`Email and school ID registration`:** both are collected, but email is the login identifier; school ID is an encrypted institutional attribute, not a public username.
- **`Ranking`:** default means personal topic/progress ordering. Peer ranking is optional and deferred beyond the invited duel pilot.
- **`Skill band`:** determined initially by diagnostic evidence, or `Unplaced` if skipped; later based on topic-relevant evidence. Competitive rating is separate from academic mastery.
- **`24-hour availability`:** means offline access to already downloaded study functions, not a promise of 24/7 moderator support or real-time service uptime.
- **`Real-prize track`:** fixed, school-funded, rules-based rewards with manual approval; never cash payout by the app, wagering, chance, or paid entry.
- **`Teacher analytics`:** aggregated class/cohort data only, with suppression for small groups; no private notes or individual study logs.
- **`Instant quiz feedback`:** solo mode shows feedback after each answer; duels delay answers/explanations until both complete to preserve fairness.
- **`Season reset`:** resets only seasonal competitive standings/season-specific progress, not learning records or permanent entitlements.

## 12. Product acceptance checklist for Part 1

Part 1 is approved when stakeholders agree that:

- Solo progress is fully viable without competition.
- The MVP/control-pilot/deferred boundary is acceptable for 1–2 beginners in 4–6 weeks.
- Teacher access is aggregate and privacy-preserving.
- The room and duel pilot limits are acceptable.
- The real-prize track is fixed-reward, school-funded, manually fulfilled, age-gated, and audited.
- The proposed retention periods and minor-consent assumption are acceptable pending institutional/legal review.
- The specified edge-case outcomes match the intended product behavior.

## Sources consulted for privacy baseline

- National Privacy Commission, [Data Privacy Act of 2012 overview](https://privacy.gov.ph/)
- Official Gazette, [Republic Act No. 10173](https://www.officialgazette.gov.ph/2012/08/15/republic-act-no-10173/)


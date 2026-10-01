# Task board

Updated 2026-09-26. No user deadline has been provided. Dates below are evidence dates, not invented due dates.

| ID | Status | Owner / head | Task and acceptance evidence | User deadline | Findings / next action |
|---|---|---|---|---|---|
| SA-001 | Done | Program manager | Agent hub, 21 role instructions, handoffs and JPG; see [validation log](VALIDATION.md) | None supplied | No open findings for the local coordination files |
| SA-002 | Inbox | Quality head | Re-run applicable source, API and browser tests for any future code changes; attach command results | None supplied | Historical results dated 2026-09-15 are not fresh proof |
| SA-003 | Blocked | Engineering head | Signed Android build and physical low end device/accessibility tests | None supplied | Device, signing and institutional setup required |
| SA-004 | Blocked | Learning/product head | Teacher verified representative course content and permission records | None supplied | Needs actual teacher review and licensed material |
| SA-005 | Blocked | Program manager | Institution approval for consent, prizes, live email/push, backup retention | None supplied | Requires institution decisions and configuration |

## SA-006 — Figma external design assets (2026-09-28)

- Status: Done (2026-09-28). User request: supporting asset preparation for Claude's Figma work.
- Owner: Codex / program manager; responsible head: design head. No deadline supplied.
- Scope: inspect pages, prepare licensed SVGs, import into separate assets page, report manifest and flags. No Wireframes or Prototype edits.
- Feature status: current asset files; app implementation unverified and outside scope.
- Inputs/privacy: public vendor assets, no student data. Destination: user-specified Figma file.
- Deliverables: [README](../assets/README.md), [manifest](../assets/manifest.json), [initial Figma inventory](../assets/figma-inventory-before.json).
- Gates passed: design-head review by primary; independent asset review by `asset_review`; 23/23 hash/XML/provenance checks and Figma import screenshot review. Evidence: [QA](../assets/QA.md), [import ledger](../assets/figma-import.json). Code review N/A: no app code changes.
- Program-manager closure: requested files and upload verified. No GitHub publication. No blocking findings; MIT notice retention and unDraw redistribution/AI restrictions accepted as documented usage conditions.

## SA-007 — High-fidelity desktop Figma concept (2026-09-28)

- Status: Done (2026-09-28). User added desktop and mobile high-fidelity screens to the current request.
- Owner: Codex / program manager; head: design head. No deadline supplied.
- Scope: user expanded to both desktop and mobile. Four matching screens (Home, Focus, Leaderboard, Challenges) at 1440 × 1024 and 390 × 844, on separate pages. Preserve Claude's mobile/prototype work.
- Direction: use existing Figma violet/lime palette, Space Grotesk headings and Inter body. Repo cream/sage/system-ui is a documented conflict; this is a Figma design concept, not a claim of repository implementation. Peer leaderboard remains planned/deferred in repository.
- Inputs: repository UI specification/tokens and live Figma conventions; all screen activity and aliases synthetic.
- Deliverables: [handoff](../assets/DESIGN_HANDOFF.md), [frame ledger](../assets/figma-responsive-state.json), [QA](../assets/QA.md). Design-head review and all eight screenshot checks passed. Independent reviewer `asset_review` visually checked all eight screens and verified text/font containment; all minor padding findings fixed and targeted re-read passed. Code review N/A (no runtime changes). No GitHub publication.
- Program-manager closure: eight static editable concepts delivered; no blocking findings. Prototype flow stays with Claude. Repository visual/feature differences accepted as documented design-concept limits, not implementation claims.

## SA-008 — Server-authoritative Dungeon of Knowledge runs (2026-09-29)

- Status: Done (2026-09-29), verified by Claude. Owner: Codex (implementation) / Claude (verification and fixes); responsible head: engineering head. No user deadline supplied.
- Scope: server run tickets, question snapshots, answer and hint ledger actions, local launch arguments, web launch flow, schema and API documentation.
- Feature status: **current**. Java server built locally with IntelliJ's bundled JDK 25 and Maven; integration suite executed against the real server.
- Inputs/privacy: repository source and synthetic accounts/fixtures only; no tickets, answers or student data logged or placed in prompts.
- Code review (Claude, 2026-09-29) findings, all fixed: (1) victory required 100 *correct* answers although questions are single-attempt, so any mistake made victory impossible — now all 100 answered without losing; timeout outcome recorded as `expired`/`timeout`. (2) True/false quiz items were padded with "Both true and false"/"Neither…" filler — removed; true/false keeps two options. (3) Flashcards were not used — added the student's own and approved public decks as 4-choice questions with same-deck distractors (schema `source` CHECK now allows `flashcard`). Ticket auth (hashed, owner-bound, expiring, suspended/deleted accounts rejected) reviewed with no findings.
- QA evidence: `mvn package` built; `scripts/build.sh` passed; DomainTests 14/14 passed (run with Windows `;` classpath — the script's `:` separator only works on Linux/CI); `npm run test:integration` 32/32 passed with `ARENA_START_ATTEMPTS=600` (server start takes ~12 s on this laptop; the new env var defaults to the old 150); new tests DUN05 (imperfect run wins; timeout) and DUN06 (flashcards become questions; not visible to another student); DUN02 made deterministic by hinting on a ≥3-option question; `npm test` 10/10; `node --check` passed; `document-contracts.py` regenerated docs (49 tables, 88 endpoints, 67 error codes); `git diff --check` clean apart from line-ending warnings.
- End-to-end: Godot client `--linked-smoke` against a local demo server with a real run ticket — questions fetched (no answers exposed), answer graded server-side with a real coin credited, hint correctly refused for an empty wallet, answered index persisted for resume. Invalid ticket shows the reconnect/practice panel.
- Open findings: none blocking. Local Windows desktop relaunch (`/api/dungeon/launch` killing and restarting Godot) not exercised. No quality percentage or release claim.

## SA-009 — First-person 3D Dungeon of Knowledge (2026-09-29)

- Status: Done (2026-09-29) pending user review. Owner/implementer: Claude; responsible head: engineering head. No user deadline supplied. Nothing committed or pushed.
- Request: first-person camera; 3D animated enemies/NPCs; a real dungeon look; gameplay depth; accessibility; performance; server-authoritative questions/coins (SA-008).
- Scope (`godot/dungeon_maze/`): new `first_person_controller.gd`, `dungeon_kit.gd` (KayKit modular maze in chunked MultiMeshes, themed chambers, wall torches with flame shader + pooled lights, gates, portal shader), `dungeon_actor.gd` (animated skeletons/adventurers that stream in and awaken), `audio_director.gd` (synthesized audio + caption events), `run_client.gd`, `practice_bank.gd`; rewritten `dungeon_game.gd`, `mobile_controls.gd`, `dungeon_map.gd`; removed unused `third_person_camera.gd`, `cartoon_actor.gd`. Web copy in `web/app.js` updated for drag-to-look.
- Assets/licence: KayKit Skeletons, Adventurers, Dungeon Remastered, Halloween Bits by Kay Lousberg, CC0 1.0 (credited in `THIRD_PARTY_NOTICES.md`); animations trimmed in Blender. Exported web pack 9.7 MB.
- QA evidence: `--headless --import` clean; `--smoke` prints `DUNGEON_SMOKE_PASS` (100 encounters, real 3D actor with skeleton, 5 rooms, torches, traps/serpents/puddles, correct/wrong/hint flows); `--screenshots` rendered 11 views reviewed visually (entrance, encounters, crypt/library/treasure rooms, traps, question, feedback, map) and fixes applied (staff scale, companion placement, nameplate legibility, library shelves); `--linked-smoke` passed (SA-008).
- Performance (Intel HD 520, 1280×720, windowed, first frames after load): High 24–39 fps, Low 21–50 fps, 150–280 draw calls. Resolution scaling was removed from Low because it slowed the Compatibility renderer.
- Accessibility: reduced motion (no bob/shake/flicker/grain; slower serpents, static runes), sound captions, invert Y, sensitivity, FOV, volume, number-key answers, focus styling, practice-run labelling.
- Open findings: full browser (WebAssembly) run not exercised locally — no export templates installed; CI exports it. Phone touch controls untested on a real device. Owner: QA/user.

## SA-010 — Dungeon relics, buffs and defeat animations (2026-09-29)

- Status: Done (2026-09-29) pending user review. Owner/implementer: Claude; responsible head: engineering head. No deadline supplied. Nothing committed or pushed.
- Request: "add also some boosts in the map, might also add buffs (you decide what to add), also improve the dying animation."
- Scope (`godot/dungeon_maze/`): relic pickups with six buffs (Swiftness, Bone Ward, Scholar's Lens, Spring Step, Radiant Lantern, Hourglass Shard — practice only; signed-in runs get a Ward instead so the client never extends a server-enforced timer), buff HUD chips, map relic markers, save/resume of buffs; enemy defeat (hit flash, knockback, Death_A, physics bone burst, top-down dissolve shader with ember edge, rising soul, coin pop-up), scholar ascension, purple retreat on wrong answers, first-person player death (view falls/rolls, fade) with a reduced-motion variant.
- QA evidence: `--headless --import` clean; `--smoke` passed with new assertions (16 relics on Easy; swift raises speed and expires after 30 s; ward blocks a trap with no time lost; hourglass +45 s; dissolve death starts without errors). `--screenshots` rendered 20 views reviewed visually (relics, hit flash, collapse + bones, dissolve, purple retreat, player fall, game-over fade); fixes applied (looping tweens bound to their nodes to stop "infinite loop" errors after pickup, softer soul glow, readable fixed-size "+1 ◉", legend fits the map).
- Performance note: relic views on Intel HD 520 at High ran 21–22 fps (draw calls 232–332), a little below earlier corridor views; Low quality remains available.
- Open findings: none blocking. Not play-tested on a phone or in a browser build.

## SA-011 — Question-scaled maze, 50-question cap (2026-09-29)

- Status: Done (2026-09-29) pending user review. Owner/implementer: Claude; responsible head: engineering head. Nothing committed or pushed.
- Request: "adjust the size of the maze based on questions … limit to 50. Adjust other difficulties. Maze map shouldn't be too large."
- Decision: Easy 20 q / 15×15 / 8 min / 5 mistakes; Average 30 / 17×17 / 12 min / 5; Hard 40 / 19×19 / 16 min / 4; Hell 50 / 21×21 / 20 min / 3. Chambers 2–5, traps, serpents, puddles, relics and penalties scale per difficulty. Hint prices unchanged (2–5).
- Scope: `dungeon_game.gd` (grid and encounter count are now per-run, sequential cell allocation, scaled loop joins and chambers, all "/100" text), `practice_bank.gd` (count parameter), `dungeon_map.gd`; server `Dungeon.java` (per-difficulty question_count/time/mistakes, library/flashcard/practice fill to count, victory = all served questions answered, index 0–49), schema CHECK idx 0–49 (table unreleased), tests, web difficulty labels/copy, README. Save version bumped to 3 (older saves are ignored).
- QA evidence: `--smoke` passed (Easy: 20 encounters, 15×15, 2 chambers, 6 traps, 3 serpents, 6 relics, capacity assertion). `--size-report` over 40 seeds × 4 difficulties: walkable minimum 93/124/155/195 vs needed 41/58/75/92; exit path average 29/31/34/37 cells; Hell occasionally places 4 of 5 chambers. Integration 32/32 (DUN01 20-question run with 480 s / 5 mistakes; DUN03 hard = 40; DUN04/05 victory on 20); unit 10/10; build passed. Live `--linked-smoke` on a Hell run: server question_count 50 → game built 50 encounters on a 21×21 grid; answer and hint flowed through the server. Screenshots reviewed (map legible at 17×17); draw calls fell to 67–275 per view, fps unchanged on the fill-rate-bound HD 520.
- Open findings: none blocking.

## SA-012 — Responsive polish, themes, coin display, effects, note to self, AI key, private folder (2026-09-30)

- Status: QA / code review passed; awaiting user review. Nothing committed or pushed. Owner/implementer: Claude; heads: design (UI tasks), engineering (API/wallet/storage), security/privacy (folder, note, AI key). No deadline supplied.
- Request: media-query fix at `web/style.css` companion grid; tasks 1–8 (login centering/safe areas, responsive polish, 1–2 themes, Home coin accuracy, purchasable celebration effects, personal Home note, `OPENAI_API_KEY` wiring, per-user private folder).
- Decisions: high contrast is a free Settings theme (accessibility is not sold); warm paper (sepia) is the purchasable theme. No school-wide announcement system existed (checked Part 3 and `Admin.java`; notifications are per-user system messages), so the note is personal only. The folder extends Studio sources rather than adding a second upload path.
- Feature status: **current** — landscape/tablet bottom-nav rule (E2E21), login centering + safe-area padding (E2E20, notch emulated at 47 px), 44 px targets and no overflow at 375/820/1440 on Home, Focus, Library, Progress, Settings, Rewards (audit script), themes with AA contrast (`check-theme-contrast.mjs`, E2E18), shared wallet + sync race fix (WALLET01–03, E2E16), effects with reduced-motion suppression (J05, E2E17), note to self (E2E19), encrypted owner-only folder with quota (S02, S03), catalog migration (DB06–08), AI startup status line (manual run). **Unverified** — real-phone address-bar behaviour and physical notch; live Gemini calls (no key used; no external calls made; request shape follows Google's `generateContent` reference, response parsing and error mapping are unit-tested); Android app.
- QA evidence (2026-09-30, IntelliJ JBR 25, local Chrome): `npm test` 13/13; DomainTests 17/17; `npm run test:integration` 35/35, no unhandled server exceptions; `npm run test:e2e` 22/22 checks, exit 0; `node --check` clean; contracts regenerated (49 tables, 96 endpoints, 71 error codes).
- Code review (self, second pass): fixed during review — theme `inUse` for re-applying owned themes; e2e races (awaited theme changes); Chromium touch-emulation loss after full-page screenshot isolated to a fresh context.
- Provider change (user request, 2026-09-30): OpenAI removed; the Studio uses Google Gemini only (`GEMINI_API_KEY`, default model `gemini-3.8-flash` per Google's models page). Office files must be saved as PDF. Gemini free tier may use submitted content to improve Google's products — own/synthetic material only until a billed project is approved. DomainTests AI01–AI05 added. Live check 2026-09-30 with the user's key on synthetic text and a synthetic PDF: summary, reviewer, flashcards, quiz, slides and study plan all generated (JSON tools parsed as arrays); `gemini-3.8-flash` repeatedly answered 503 "high demand", so a one-time retry on `GEMINI_FALLBACK_MODEL` (default `gemini-3.5-flash`) and an `AI_BUSY` message were added. Audio/image/video inputs not exercised live. The user pasted the key into the chat; advised to rotate it.
- Open findings: (1) every request, including Gemini calls up to 180 s, runs inside one global DB lock, so AI generation stalls other users — pre-existing, documented in Part 5, owner engineering head. (2) Resolved 2026-09-30 by user decision: the 20-coin "Moonlit theme" (plain dark mode, free in Settings) became the Cosmos theme in place (same item id, so owners keep it); Cosmos passes AA contrast; reduced-motion rule extended to pseudo-elements (it previously missed `::before`/`::after`, including the companion sparkle effects). (3) Studio partial uploads are plaintext until completion (abandoned ones are purged after 24 h); pre-change `.bin` files stay unencrypted until deleted. (4) The companion dock covers the Home coin card on phones until moved (pre-existing, draggable). (5) The note to self is per-device (encrypted workspace), not synced.

## SA-013 — Phone usability, password reveal, remembered sign-in (2026-10-01)

- Status: QA passed; awaiting user review. Nothing pushed. Owner/implementer: Claude; heads: design, engineering, security/privacy. No deadline supplied.
- Request (user phone screenshots, Messenger in-app browser): bottom navigation too small and the app awkward to use; sign-in form moves when tapped; no show-password; keep students signed in after closing the app; advice on a real native app.
- Findings: no horizontal overflow at 412 px in Chrome emulation; the screenshots match an in-app browser laying out at desktop width (~980 px) and scaling down — the page's viewport meta is present in the deployed HTML, so the cause is the in-app browser or its “Desktop site” mode (not reproducible here).
- Changes: larger bottom navigation (58 px buttons, 25 px icons, 0.78 rem labels); sign-in card top-aligned on phones; Show/Hide password on sign-in, register and reset; “Keep me signed in on this device” (non-extractable CryptoKey in IndexedDB; cleared by Lock/sign-out; 401 → back to sign-in with work kept); notice for in-app browsers and desktop mode; offline signed-in pages fall back to bundled starter content when nothing is cached; service-worker cache version bumped.
- Feature status: **current** — E2E05 (offline reload resumes the remembered workspace), E2E21 (nav buttons ≥ 56 px), E2E22 (password toggle, remember option), card position unchanged with a simulated keyboard (88 px → 88 px); `npm test` 13/13; `npm run test:e2e` 23/23. **Unverified** — Messenger's in-app browser itself and real phone keyboards.
- Security/privacy: remembered sign-in lets anyone holding the unlocked device open the workspace until Lock; the sign-in caption tells students to untick it on shared computers.

## SA-014 — Android build, dungeon touch controls, Gemini quota, server lock, agent guide (2026-10-01)

- Status: QA passed; awaiting user review. Owner/implementer: Claude; heads: engineering, design, security/privacy. No deadline supplied.
- Request: build the Android app in Android Studio; dungeon touch controls too small and swipe-look too sensitive, with a setting; find bugs across the app; Gemini "busy / limit" after failed generations; a read-first file for Claude/Codex with the Android Studio and rebuild instructions.
- Android: Android Studio Quail 4 installed by the user; JDK 21 added at `D:\Android\jdk-21` (Gradle 8.14.3 cannot run on Java 25); `npx cap sync android` + `gradlew assembleDebug` build `app-debug.apk` (10 MB). The app opens the published web dungeon (`DUNGEON_WEB_URL`) instead of the desktop launcher endpoint. **Unverified:** behaviour on a physical phone beyond the user's report.
- Dungeon: controls sized from the screen's short side (joystick ~2.2 cm, buttons 1.4–1.6 cm on a 720-unit-tall phone screen); touch look normalised to screen size and about half as fast by default; settings **Touch look speed** and **Touch control size**; UI enlarged 30% on touch screens; pause/map moved upper-left so they no longer cover the map; touch wording ("Tap an answer"); `--touch-preview` flag. Evidence: `--smoke` pass; 20 screenshots at 1600×720 reviewed.
- Gemini: the owner's key showed `gemini-3.8-flash` free tier limited to 20 requests (`generate_content_free_tier_requests, limit: 20`) and frequently 503. Defaults now `gemini-3.5-flash` → fallback `gemini-3.5-flash-lite` (separate quota), fallback also on 429, low thinking for Gemini 3, messages naming the wait or the midnight-Pacific reset. Live: reviewer/Quizlet/quiz generated from a synthetic PDF; two 503s rescued by the fallback.
- Bug fixes: AI calls held the global DB lock for up to 3 minutes, blocking every other request — now released during the call (`Db.withoutLock`; DomainTests LOCK01–02; live: `/api/progress` answered in 34 ms during a 9 s generation). Session-expiry handling narrowed to `AUTH_REQUIRED` so `REAUTH_REQUIRED` no longer signs students out. Crawl of every nav screen for student/teacher/admin at 1440 and 375 px: no script errors, error screens, 5xx responses, overflow or server exceptions.
- Docs: `START_HERE.md` (read first; Android Studio setup and rebuild/run steps), `CLAUDE.md` imports it with AGENTS.md; AGENTS.md links it.
- QA evidence: see the SA-014 test run in the final report (unit, integration, e2e, DomainTests, Godot smoke, APK build).

## SA-015 — Shooter-style dungeon controls, landscape, settings, performance, in-app updates (2026-10-01)

- Status: QA passed; awaiting user review. Owner/implementer: Claude; heads: engineering, design. No deadline supplied.
- Request: dungeon auto-landscape; controls like the user's CODM screenshot (stick left; attack/buffs/jump/crouch right); reduce lag on phone and desktop; a settings button; APK replaced in Drive after every app change, recorded in the read-first file; auto-update.
- Dungeon: ENGAGE (E / big button, starts the nearest unresolved encounter within 4.5 m, gold when available), CROUCH (C; 55% speed, lower eye height, skeletons notice at 5.2 m instead of 10.5 m), JUMP, RUN; buff badges; PAUSE/MAP/SETTINGS upper-left; the touch PAUSE button never worked before (simulated actions create no InputEvent) — fixed by calling the game directly. Settings panel (gear, O, Pause → Settings) with touch look speed/size/opacity, left-handed layout, vibration, mouse sensitivity, invert, quality, FOV, fps readout, volume, captions, reduced motion, reset.
- Landscape: fullscreen + `screen.orientation.lock('landscape')` on the first tap on touch devices, portrait cover otherwise (export head_include); checked in emulated portrait/landscape/desktop pages.
- Performance (owner's laptop, `--bench`, 1600×720): touch layout 30 → 53 fps after redrawing controls only on change; 3D resolution scaling measured slower (56 → 23 fps) and was not used; web build renders at CSS pixels (`allow_hidpi=false`) to cut phone pixel count ~7×; 60 fps cap on touch; desktop auto-Low when < 28 fps for 6 s on High; vignette shader skips grain math when off. **Unverified:** frame rate on a real phone.
- Updates: `APP_BUILD` 2 / versionCode 2; `web/app-version.json` on Pages; app shows "A new version is ready → Download update" when a higher build is published (tested with a faked newer and equal build). Silent auto-install is not possible for sideloaded APKs.
- Drive: the Drive connector cannot replace content or upload 10 MB; releases overwrite `G:\My Drive\ANDROID APPS\app-debug.apk` through Google Drive for desktop (keeps the link). Recorded in START_HERE.md and agent memory.

## Task card template

ID; request/source; feature status (current/planned/unverified); owner; responsible head; acceptance criteria; inputs and privacy class; user supplied deadline; dependencies; status; deliverable links; head review; independent verification; QA evidence; code review (or N/A reason); security/privacy review; unresolved findings and owner; decision/date.

**Done rule:** the program manager records evidence for every applicable gate and resolves or explicitly accepts each finding with its owner. A blank gate is not a pass.

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

## Task card template

ID; request/source; feature status (current/planned/unverified); owner; responsible head; acceptance criteria; inputs and privacy class; user supplied deadline; dependencies; status; deliverable links; head review; independent verification; QA evidence; code review (or N/A reason); security/privacy review; unresolved findings and owner; decision/date.

**Done rule:** the program manager records evidence for every applicable gate and resolves or explicitly accepts each finding with its owner. A blank gate is not a pass.

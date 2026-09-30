# Study Arena — responsive high-fidelity concepts

Prepared 2026-09-28. The user expanded the original asset-support task to request both desktop and mobile high-fidelity screens.

## Deliverables

Four matching screens: Home, Study Session, Leaderboard, and Challenges.

| Format | Canvas | Figma page / first frame |
|---|---|---|
| Desktop | 1440 × 1024 | [Desktop Hi-Fi — Codex](https://www.figma.com/design/9bmV20pkokhObHQufee8Vt/Study-Arena?node-id=30-14) |
| Mobile | 390 × 844 | [Mobile Hi-Fi — Codex](https://www.figma.com/design/9bmV20pkokhObHQufee8Vt/Study-Arena?node-id=35-2) |
| External assets | 23 original SVGs | [External Assets — Study Arena](https://www.figma.com/design/9bmV20pkokhObHQufee8Vt/Study-Arena?node-id=17-2) |

Exact frame, component, and variable IDs are in `figma-responsive-state.json`. Source/license metadata and imported asset node IDs are in `manifest.json`.

All screens are editable Figma layers with auto-layout, shared button/navigation/stat components, and color bindings to the existing 13 Arena tokens. Desktop uses persistent left navigation and multiple columns. Mobile uses bottom navigation and prioritizes the core content at phone width. Typography follows the current Figma direction: Space Grotesk headings and Inter body. Primary buttons are 48px high; mobile navigation targets are 87 × 56px.

## Repository comparison and deliberate differences

The supplied local repository's `.git/config` identifies `https://github.com/plummz/Study_Arena.git` as origin. The GitHub web fetch was unavailable; this review used the local checkout, not a verified latest remote revision.

- `web/tokens.css` uses cream and sage; `web/style.css` uses system-ui. The current Figma prototype instead uses violet/lime/ember, Space Grotesk, and Inter. These new concepts deliberately follow Figma to remain cohesive with Claude's mobile work. No repository theme was changed.
- `docs/Part_4_UI_Specification.md` describes solo-first study and opt-in competition; seasonal peer leaderboards are deferred. Leaderboard and challenge UI here are planned design concepts, not evidence of implemented/live competition. XP awards and challenge thresholds are illustrative and must be reconciled with actual earning rules before implementation.
- Names are fictional aliases and activity values are synthetic. No student records were used. Desktop and mobile show the same sample session, rank, XP and challenge progress.
- The timer displays a static design state; buttons and navigation are visual controls. No prototype interaction flow was added because Claude owns prototype flow.

## Scope and validation

Codex did not edit the existing Wireframes or Prototype pages, did not modify existing Arena color tokens, and did not push to GitHub. Claude was actively changing the original pages during this work, so the initial inventory is a timestamped snapshot rather than a current complete listing.

Original snapshot: Wireframes contained 01 Onboarding and 02 Sign up / Log in; Prototype and Sources were empty. A later read showed nine wireframes (Onboarding, Sign up / Log in, Home / Dashboard, Study Session, Leaderboard, Challenges, Challenge Detail, Profile, Notifications) and an in-progress styled Prototype with palette, assets, tab bar and initial screens. These were not duplicated or rearranged inside the original pages.

Validation: all 23 local SVGs pass XML and hash checks, all 23 imported on the separate asset board, and the board was visually checked. All eight new screens were screenshot-reviewed by primary and independent reviewer. The mobile focus card was enlarged and its redundant footer removed; level-badge headers, leaderboard table and rank-card padding were corrected after review. Post-fix screenshots passed. All eight screens use Inter/Space Grotesk with no text exceeding screen bounds. Independent review results are recorded in `QA.md` and the task board.

Implementation, assistive-technology behavior, functional navigation, responsive breakpoints outside these two sizes, and real student research are unverified/out of scope.

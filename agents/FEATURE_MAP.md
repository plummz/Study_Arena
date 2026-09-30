# Feature and evidence map

This map describes the local checkout inspected on 2026-09-26. “Current” means implementation is present and previously documented checks exist; it does not mean production ready. Run task specific checks again before relying on behavior.

| Capability | Status | Evidence / limit |
|---|---|---|
| Solo timer, goals, personal progress, spaced flashcards, CSV import, explained quizzes, offline encrypted study and sync | Current | `web/app.js`, `web/vault.js`, `server/src/main/java/ph/edu/wit/studyarena/Study.java`, `README.md`, dated `docs/Test_Results.md` |
| Private AI Study Studio drafts, uploads and generated study materials | Current | `web/studio.js`, `server/src/main/java/ph/edu/wit/studyarena/Studio.java`; real OpenAI calls require server key and remain unverified here |
| Companions, deterministic rewards, optional rooms/duels, teacher/admin moderation | Current controlled pilot | `web/app.js`, `server/.../Social.java`, `Economy.java`, `Admin.java`, `README.md`; school approvals and real prize fulfillment unverified |
| Android project and Capacitor web asset sync | Current source | `android/`, `capacitor.config.json`, `docs/Part_5_Build_and_Handover.md`; signed APK and physical device behavior unverified |
| Real email/push delivery, low end device performance, verified course library, institution consent/funding, backup operations | Unverified release gates | `README.md` and `docs/Part_5_Build_and_Handover.md` list these as outstanding |
| Tournaments, seasonal peer leaderboards, rich shared editing, automated physical prize fulfillment, iOS | Planned/deferred | `docs/Part_1_Product_Specification.md` and `README.md`; never label live |

The product specification is a draft. Its pilot targets are goals, not measured outcomes. `docs/Test_Results.md` reports checks from 2026-09-15; treat them as historical evidence.

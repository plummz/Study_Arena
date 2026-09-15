# Study Arena — Verification Results

Verified on September 15, 2026.

| Suite | Result | Coverage note |
|---|---:|---|
| Java domain/security | 14 passed | Password derivation, encryption, quiz normalization, CSV rules, immutable ledger/audit and database integrity |
| JavaScript unit | 9 passed | Durable sync, offline cache, CSV parsing, safe Studio preview and Quizlet CSV export |
| HTTP integration against source build | 26 passed | Authentication/roles, content, study, quiz, economy, rooms, duels, privacy, login streak and private Studio uploads/artifacts |
| HTTP integration against packaged JAR | 26 passed | The final executable JAR passed the same API suite with no unhandled server exceptions |
| Android web asset sync | Passed | Capacitor copied the current Studio, companion and service-worker assets into the Android project |
| Windows full browser E2E | 16 passed | Guest/login, Studio upload/reviewer, encrypted offline quiz, focus, mobile, dark mode, teacher, rooms, shop, eight-companion drag/motion and no uncaught browser errors |
| Windows installed-app smoke | 3 passed | Private upload/reviewer generation, eight companions/streak/movement room, and no uncaught errors against the live port-8080 installation |

The repeatable isolated E2E scenario is present in `tests/e2e.mjs`; the installed server was also checked directly with `tests/live-studio-smoke.mjs`. Live OpenAI calls, real audio transcription quality/cost, a signed Android APK, physical low-end-device performance and external email/push delivery remain deployment checks rather than simulated passes.

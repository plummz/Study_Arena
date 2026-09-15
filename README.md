# Study Arena

A solo-first study application for a Western Institute of Technology capstone. **Java backend, JavaScript student/admin client, and a Capacitor Android project.**

On Windows, double-click **Start-Study-Arena.cmd**. It uses the project-local Java runtime when available and opens the browser after startup. Open **StudyArena.code-workspace** in VS Code to edit the project. To rebuild changed Java source with Node and a JDK, run `node scripts/build-windows.mjs`; remove or rename `dist/study-arena.jar` when you want the launcher to use compiled classes instead of the packaged release.

Start the precompiled synthetic demo from this directory with Java 17+:

```bash
java -jar dist/study-arena.jar --demo
```

Open [localhost:8080](http://localhost:8080). Demo accounts are `student@study.test`, `teacher@study.test`, and `admin@study.test`, all using `StudyArena!2026`. These credentials are intentionally public and valid only for synthetic demonstration data.

The app includes encrypted offline study, a timer, four-rating spaced flashcards and CSV import, explained quizzes, reference notes, personal mastery, same-band rooms/duels, deterministic rewards, a school-reviewed prize workflow, and role-scoped administration. AI Study Studio privately stores inert uploads up to 25 MB and can create source-grounded reviewers, summaries, plans, flashcards, Quizlet CSVs, explained quizzes, PowerPoint-readable slide outlines, and audio transcripts. Plain text has a local draft fallback; common documents, images and audio require `OPENAI_API_KEY` on the server. Eight hand-drawn, full-color study companions are free to unlock and select. Each has an individual voice and movement style, reacts occasionally to review, quiz, focus and Studio moments, earns friendship, lives in a companion room, and can be dragged by mouse or touch or moved with the keyboard. Login streaks unlock free companion effects at 3, 7, 14 and 30 days. Motion is GPU-friendly, configurable, and respects reduced-motion preferences. Competition is off in student preferences; levels and prizes are hidden by default. No payments, cash payouts or random rewards exist.

Read these in order:

1. [Part 1 — Product scope](docs/Part_1_Product_Specification.md)
2. [Part 2 — Architecture](docs/Part_2_Architecture.md)
3. [Database dictionary](docs/Database_Dictionary.md) and [executable schema](docs/Database_Schema.sql)
4. [Part 3 — API and state machines](docs/Part_3_API_and_State_Machines.md)
5. [Part 4 — UI specification](docs/Part_4_UI_Specification.md)
6. [Part 5 — Build, Android and operations](docs/Part_5_Build_and_Handover.md)
7. [Edge-case test plan](docs/Test_Plan_and_Edge_Cases.md) and [actual results](docs/Test_Results.md)

Build and test from source:

```bash
bash scripts/build.sh
bash scripts/test-domain.sh
npm ci
npm test
npm run test:integration
npx playwright install chromium
npm run test:e2e
```

For a conventional Java build use `cd server && mvn package`; run the resulting JAR from the project root. The fallback compiler script downloads pinned Maven Central dependencies. Full instructions and environment variables are in Part 5.

**Release boundaries:** Android source is included, but a signed APK, device performance, real email/push delivery, school consent/funding, backup operations and a representative verified content library need institution-specific validation. Tournaments, seasonal peer leaderboards, rich shared editing and automated physical prize fulfillment are deferred under Part 1. The code is a reviewed capstone pilot implementation, not a claim of production certification.

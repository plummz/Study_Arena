# Study Arena — Part 5: Code, verification and handover

## 1. What is delivered

This is a working Java/JavaScript capstone implementation, with source, native Android project, executable Java demo, schema, API documentation, screen specification, tests, CI recipes and operational instructions. The demo uses synthetic accounts and original starter study content. It includes a private upload and AI Study Studio workflow, login-streak gifts, smarter four-rating flashcards, daily plans and weekly progress stories. Eight free hand-drawn study companions have encrypted local selection, friendship, cosmetics and position, drag/touch/keyboard placement, individual voices, contextual reactions, a companion room, and reduced-motion-safe walking, running, hopping, hovering, spinning, shaking and wiggling animation. The full contents are in the accompanying ZIP.

Parts 2–5 follow the Part 1 MVP/pilot boundary. Tournaments, seasonal public rankings, rich shared editing and automatic physical prize fulfillment remain explicitly deferred. The source does not contain “implementation left as an exercise” functions or fake payout success handlers.

## 2. Start the demo

Install Java 17 or later. Extract the whole ZIP, open a terminal in the `study-arena` directory, and run:

```bash
java -jar dist/study-arena.jar --demo
```

Open `http://localhost:8080` in the same computer's browser. Student, teacher and administrator use the same application with role-specific navigation.

| Role | Demo email | Demo password |
|---|---|---|
| Student | student@study.test | StudyArena!2026 |
| Teacher | teacher@study.test | StudyArena!2026 |
| Administrator | admin@study.test | StudyArena!2026 |

These credentials are intentionally public **only for synthetic demo mode**. Do not reuse them for a real pilot. Data created by the demo stays in the local `data` directory. Stop the process with Ctrl+C. The application requires no Python runtime; Python is used only by an optional documentation-generation script.

If port 8080 is occupied, set `PORT` and `APP_ORIGIN` consistently. An HTTPS or localhost secure context is necessary for Web Crypto and service workers. Do not assume a plain HTTP LAN address supports offline browser storage features.

### Windows laptop setup

The requested folder is `C:\Users\hcpre\OneDrive\Desktop\John Rey's Codes\Study Arena app`. Double-click `Start-Study-Arena.cmd`, or open `StudyArena.code-workspace` in VS Code and run the Start Study Arena demo task. Leave its terminal running while using the app. The launcher recognizes the local Java runtime installed under `runtime/java`.

For source changes, run `node scripts/build-windows.mjs`. This verifies pinned dependency checksums and compiles Java 17 bytecode using the local JDK. The source-only laptop installation runs `build/classes`; the downloadable release also includes a precompiled JAR, which takes precedence when present.

### Recovered project contracts

The executable schema, `docs/api-contract.json`, and Parts 2–4 in this package describe the recovered runnable implementation. They supersede intermediate chat reconstructions made while workspace access was unavailable.

## 3. Build source

Recommended: Java 17, Maven, Node 22+ and npm.

```bash
cd server
mvn package
cd ..
java -jar server/target/study-arena-1.0.0.jar --demo
```

The package also includes a compiler fallback for environments with Java runtime but no Maven/JDK compiler executable:

```bash
bash scripts/build.sh
bash scripts/run.sh --demo
```

That script downloads pinned Maven Central JARs and compiles with the Eclipse Java compiler. The delivered executable has already been compiled. Run from the project root so the default `web` directory resolves correctly; `WEB_DIR` can override it.

Java classes are separated by responsibility:

| File | Responsibility |
|---|---|
| `Main.java` | Startup, synthetic seed content, bounded HTTP runtime, scheduled maintenance |
| `Api.java` | Route registry, HTTP limits, authentication boundary, transaction and idempotency wrapper |
| `Db.java` | Parameterized JDBC helpers, schema startup, audit chaining, rate accounting |
| `Util.java` | Validation, Unicode normalization, password derivation, AES-GCM and typed errors |
| `Auth.java` | Registration, verification, sessions, profile, export and deletion request |
| `Content.java` | Decks, CSV preview, quiz authoring, attributed notes and file transfer |
| `Study.java` | Timer credit, saved attempts, reviews, mastery and streak calculations |
| `Social.java` | Room membership, discussion, same-band queue, generated duel questions and settlement |
| `Economy.java` | XP/coin ledger, fixed-price purchases, inventory, claims and notification preferences |
| `Admin.java` | Scoped moderation, aggregate analytics, flags, users and auditable review actions |
| `Mail.java` | Durable SMTP-over-TLS delivery adapter |
| `Push.java` | Firebase HTTP v1 delivery adapter with service-account OAuth signing |

The client has `app.js` (screens/actions), `api.js` (requests/durable sync), `vault.js` (encrypted storage), `native.js` (Android notification adapters), CSS tokens/layout, a restrictive service worker and bundled starter content. The shared UI is JavaScript, not a separate native screen implementation.

## 4. Android build

The generated project is in `android/`. Capacitor 8's generated project uses Java 21 for native compilation and Android API 36 compile/target settings; the backend still runs on Java 17. Use Android Studio with the matching SDK and an updated Android WebView. Project minimum Android API is 24. [Capacitor Android setup](https://capacitorjs.com/docs/android).

1. Install dependencies with `npm ci`.
2. Set the school's **HTTPS** API origin in `web/config.js` using `node scripts/configure-android.mjs https://your-school-api.example`.
3. If enabling push, place the institution's Firebase `google-services.json` at `android/app/google-services.json`. It is intentionally absent from the source package.
4. Run `npx cap sync android`.
5. Open Android Studio or run `cd android && ./gradlew assembleDebug` (Windows: `gradlew.bat assembleDebug`).
6. Install the APK on the designated low-end Android device and complete the device tests.
7. For distribution, create an institution-owned release signing key; do not distribute a debug build as a production release.

**Build evidence limit:** native source generation and synchronization were performed. A signed APK and physical Android validation are not represented as completed. The supplied CI job can compile an Android debug artifact where the Android SDK/JDK 21 toolchain is available.

Android cloud backups are disabled and cleartext traffic is disallowed. The notification icon is included. Local notification scheduling reserves one daily slot when enabled; remote notifications use the remaining cap. Firebase delivery requires actual school configuration; it is not simulated as successful delivery. [Firebase HTTP v1 authorization and sending](https://firebase.google.com/docs/cloud-messaging/send/v1-api).

## 5. Configuration inventory

| Variable / file | Required for | Meaning |
|---|---|---|
| `DATA_KEY` | Production startup | Base64 of 32 random bytes; encrypts private fields/outbox; back up separately |
| `APP_ORIGIN` | Production | HTTPS public origin; also used for verification/reset links |
| `DATA_DIR` | Optional | Persistent database/file directory; default `data` |
| `WEB_DIR` | Optional | Static UI directory; default `web` |
| `PORT`, `BIND` | Optional | Default 8080 and 127.0.0.1; keep behind a proxy |
| `BOOTSTRAP_ADMIN_EMAIL`, `BOOTSTRAP_ADMIN_PASSWORD` | First production startup | Create first admin only when none exists; password minimum 16 characters |
| `MINOR_CONSENT_CODE` | Under-18 pilot registration | Institution-issued consent admission code; does not replace documentary consent |
| `PRIZE_POLICY_APPROVED=true` | Enabling production prizes | School has approved actual rules, funding and safeguarding |
| `SMTP_HOST`, `SMTP_PORT` | Email delivery | Implicit TLS SMTP; default port 465 |
| `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM` | Email delivery | Institution-controlled sender credentials; never put in client assets |
| `FCM_SERVICE_ACCOUNT` | Android remote notifications | Absolute path to protected service-account JSON |
| `OPENAI_API_KEY` | AI document generation and audio transcription | Server-side secret only; never add it to `web/`, Android assets, source control or exports |
| `OPENAI_MODEL` | Optional AI model override | Defaults to `gpt-5.6`; use a Responses API model available to the institution’s project |
| `android/app/google-services.json` | Android Firebase build | Matching Firebase application configuration |
| `web/config.js` | Android client | Public HTTPS API origin; contains no secrets |

SMTP outbox entries remain pending when SMTP is unconfigured. Firebase delivery remains inactive without a service account. This is a configuration boundary, not a claim that real messages were sent.

### AI Study Studio boundary

The upload control accepts any private file as inert bytes, never executes it, verifies its SHA-256 checksum, and limits each file to 25 MB. Common documents, spreadsheets, presentations, text/code files and images can be passed to the Responses API. MP3, MP4, MPEG, MPGA, M4A, WAV and WebM audio can be transcribed through the Audio Transcriptions API. Unsupported binary formats remain safely stored and downloadable but are not represented as understood by the AI.

Generated reviewers, summaries, study plans, cards, Quizlet CSVs, quizzes, slide outlines and transcripts are drafts. Students must check them against the source. API calls use `store:false`; the application still retains the uploaded source and generated artifact in its own private data volume until the student deletes them or the institution’s retention job runs. Configure spend/rate limits and an institution-approved privacy notice before enabling the key for a real cohort.

## 6. Operational runbook

**Hosting:** use the supplied Docker/Caddy examples on an institution-approved VM. Persist `/data` on encrypted storage. Keep the Java port private; expose only HTTPS. The JVM is capped at 256 MB in the demo launcher; measure the actual pilot's usage before setting a host memory limit. Do not start multiple API replicas against this design's single JDBC connection model.

**Backup:** stop writes or use SQLite's online backup API/CLI; do not copy only `arena.db` while WAL is active. Back up the database and material volume consistently, encrypt the backup, record its creation time, and protect `DATA_KEY` separately. Restore into an isolated instance and check login, one saved deck, one file checksum, ledger balances and audit-chain consistency before considering the backup usable.

**Deletion:** access is revoked immediately; primary deletion runs after 30 days. Active rooms must transfer/disband and pending claims must resolve before a normal deletion request. At purge, remaining room ownership is transferred or archived, shared duel identities become “Former student,” and private account data is removed. The institution must expire backups under its retention policy and retain only minimized accounting/safety records for its approved duration.

**Retention gate:** the worker expires sessions/tokens, stale queue entries, old notifications, delivered outbox records, resolved risk signals and archived-room messages. Automatic accounting-ledger destruction and backup erasure are intentionally not performed by an application timer. The school must approve a retention/export/destruction procedure for immutable audit and prize records. The 24-month detailed-study retention target from Part 1 must be enforced through the school's approved retention job before an extended public deployment; account deletion itself is implemented.

**Content quality:** the package contains three small original decks, three explained quizzes and three short reference notes, including engineering mathematics. This is seed content, not a full course library. Before a real student pilot, teachers should add and independently verify the required course material and permissions. Never upload an engineering textbook merely because a respondent requested one.

**Moderation:** appoint cohort moderators, publish reporting/appeal and safeguarding channels, and check the moderation queue. No model or keyword detector is treated as conclusive evidence of cheating or distress. The app cannot reliably detect outside answer lookup. An integrity action requires a logged reason and should follow warn → withhold/void specific rewards → reviewed band reset → suspension, with appeal.

**Prizes:** replace demonstration rules and sponsor labels with real approved terms. Never activate the sample catalog as a promise of funding. Review enrollment, age, consent and study eligibility outside the self-reported offline data; record only evidence references in the app. No user-funded entry fee, randomness or cash payout exists. Fulfillment is recorded only after an authorized school representative hands over the fixed item.

**Monitoring:** monitor `/api/health`, disk free space, backup age, failed login volume, failed outbox entries, moderation backlog and repeated server request IDs. Server errors omit request bodies but may contain operational stack traces; restrict log access. Do not add analytics SDKs without privacy review.

## 7. Verification summary

The exact executed results are recorded in `Test_Results.md` and supporting test logs. They distinguish Java domain/security assertions, HTTP integration cases, JavaScript sync cases and browser flows from tests requiring a physical Android phone or external service.

The remaining release gates are: signed Android build; low-end 2 GB RAM cold-start/memory measurements; TalkBack and large-font tests; calls/alarms/process kill; real slow-mobile-network behavior; SMTP and FCM delivery using institutional accounts; backup restoration; representative teacher-verified content; and institutional privacy/consent/prize approval. These are not falsely marked as passed by the automated tests.

## 8. Demo sequence

1. Enter as guest, show that competition is absent, and open an explained quiz.
2. Sign in as the student; set goals and leave competition off.
3. Save a quiz, go offline, answer a question, reload and unlock, then resume it.
4. Run a short focus session; show that less than five minutes gets a log but no reward.
5. Review a due flashcard; inspect personal weak-topic progress and exact coin rules.
6. Sign in as teacher, contribute content, and show aggregate suppression for small groups.
7. Sign in as admin, independently inspect/moderate content and show the audit trail.
8. Demonstrate the room/duel pilot only after opting in on verified synthetic accounts.
9. Demonstrate a fixed prize claim and denial/refund without promising real funding or transferring cash.

This sequence demonstrates the survey-led product rather than presenting competition as the “real” application.

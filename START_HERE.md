# START HERE — Study Arena for AI coding agents (Claude, Codex)

Read this file first, then [AGENTS.md](AGENTS.md) (workflow, task board, privacy rules). Keep
this file current when the setup changes. Last updated 2026-10-01.

## What the project is

| Part | Folder | Runs where |
|---|---|---|
| Web app (vanilla JS, no bundler) | `web/` | GitHub Pages `https://plummz.github.io/Study_Arena/` and inside the Android app |
| Java API server (JDK HttpServer + SQLite) | `server/` | **Railway**: `https://study-arena-api-production.up.railway.app` (auto-deploys from `main`) |
| 3D Dungeon of Knowledge (Godot 4.7) | `godot/dungeon_maze/` | Exported to WebAssembly by GitHub Actions on push to `main` (`.github/workflows/pages.yml`), served at `…/Study_Arena/dungeon/` |
| **Android app (Capacitor 8)** | `android/` | Built in **Android Studio**, installed on phones as an APK |

There is **no Render deployment** (the old `render.yaml` was removed). Server secrets live in
Railway → service → Variables (`GEMINI_API_KEY`, `DATA_KEY`, …) and in a local, gitignored
`.env` — never commit `.env` or paste keys into code, docs, commits or chat.

## Android Studio setup (done on the owner's Windows PC, 2026-10-01)

The `android/` Capacitor project was opened and built in **Android Studio Quail 4
(2026.1.4 Patch 1)**. A debug APK builds successfully.

- Android Studio itself is installed at `D:\Android\Sdk` (the folder name is misleading — it
  is the IDE, not the SDK).
- The **Android SDK** is at `C:\Users\johnr\AppData\Local\Android\Sdk` (platforms 36 and 37).
- **JDK 21** (Eclipse Temurin, portable) is at `D:\Android\jdk-21`. Required: this project's
  Gradle 8.14.3 cannot run on the Java 25 bundled with Android Studio Quail. In Android Studio:
  File → Settings → Build, Execution, Deployment → Build Tools → Gradle → **Gradle JDK** →
  `D:\Android\jdk-21`.
- `android/local.properties` (gitignored, machine-specific) contains
  `sdk.dir=C:/Users/johnr/AppData/Local/Android/Sdk` — use forward slashes; backslashes are
  escape characters in that file and break the build.
- App id `ph.edu.wit.studyarena`, minSdk 24, compile/target 36. The app bundles `web/` and talks
  to the Railway API (address from the `study-arena-api` meta tag in `web/index.html`; the server
  accepts the app's origin `https://localhost`).
- In the app, the dungeon opens the published web dungeon in the phone's browser
  (`DUNGEON_WEB_URL` in `web/config.js`), because the app has no local game server.

## Rebuild and run after changes

| You changed | Do this |
|---|---|
| `web/` (screens, CSS, JS) | 1) `npx cap sync android` in the repo root (copies `web/` into the Android project). 2) Android Studio → **▶ Run** with the phone connected (USB debugging on), **or** build an APK (below). 3) Push to `main` to update the website too. |
| `server/` (Java) | Push to `main` → Railway rebuilds and redeploys the API. Check `…/api/health` and `…/api/contracts`. |
| `godot/dungeon_maze/` | Push to `main` → GitHub Actions exports the web dungeon to Pages (a few minutes). The Android app opens that published version, so no APK rebuild is needed for dungeon-only changes. |
| `android/` native files, icons, plugins | `npx cap sync android`, then ▶ Run / rebuild the APK. |

Build a shareable APK from a terminal (same result as Android Studio → Build → Build APK(s)):

```bash
cd android
JAVA_HOME="D:/Android/jdk-21" ./gradlew.bat assembleDebug     # Git Bash
# PowerShell: $env:JAVA_HOME="D:\Android\jdk-21"; .\gradlew.bat assembleDebug
```

Output: `android/app/build/outputs/apk/debug/app-debug.apk` (install on a phone by opening the
file and allowing "Install unknown apps"). A Play Store release needs Build → Generate Signed
App Bundle and a keystore that must be backed up — losing it blocks all future updates.

## Local development and tests (Windows)

Java is **not** on PATH. Use IntelliJ's bundled JDK for the server and tests:
`C:\Users\johnr\AppData\Local\Programs\IntelliJ IDEA 2026.2.3\jbr\bin\java.exe`.

```bash
# Build the server (scripts/build.sh uses ':' classpaths that only work on Linux/CI)
J="/c/Users/johnr/AppData/Local/Programs/IntelliJ IDEA 2026.2.3/jbr/bin"
CP=$(ls .deps/*.jar | grep -v ecj | tr '\n' ';')
"$J/java.exe" -jar .deps/ecj.jar -17 -encoding UTF-8 -warn:none -cp "$CP" -d build/classes server/src/main/java/ph/edu/wit/studyarena/*.java
cp server/src/main/resources/* build/classes/

export JAVA_BIN="$J/java.exe" ARENA_START_ATTEMPTS=600
export CHROMIUM_EXECUTABLE="C:/Program Files/Google/Chrome/Application/chrome.exe"
npm test                     # client unit tests
npm run test:integration     # starts the real server with synthetic data
npm run test:e2e             # Playwright + local Chrome; rewrites docs/screenshots/*.png
node scripts/check-theme-contrast.mjs   # WCAG contrast for every theme in web/tokens.css
node scripts/export-contracts.mjs && python scripts/document-contracts.py   # regenerate API/DB docs
```

Java domain tests: compile `tests/DomainTests.java` against `build/classes` with the same ecj
command (Windows `;` classpath) and run `ph.edu.wit.studyarena.DomainTests`.

Godot 4.7.2: `C:\Users\johnr\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`.

```bash
godot --headless --path godot/dungeon_maze -- --smoke                    # gameplay self-test
godot --path godot/dungeon_maze --resolution 1600x720 -- --screenshots=<dir> --touch-preview
```

`--touch-preview` shows the phone touch controls on a desktop for screenshot checks.

Run the app locally: `node scripts/start-windows.mjs` with `JAVA_BIN` set (reads only
`GEMINI_API_KEY` / `GEMINI_MODEL` from `.env`); open `http://localhost:8080`, demo accounts
`student@study.test` / `teacher@study.test` / `admin@study.test`, password `StudyArena!2026`.

## Things that have bitten us

- **Messenger / Facebook in-app browsers** ignore the mobile viewport and render the site at
  desktop width (everything tiny). The app shows a notice; test phones in Chrome or the APK.
- **Gemini free tier:** `gemini-3.8-flash` allowed only 20 free requests on the owner's key and
  was often "high demand". Defaults are `gemini-3.5-flash` with fallback `gemini-3.5-flash-lite`
  (separate quotas), low thinking, and a retry on 429/500/503. Daily quotas reset at midnight
  Pacific time (≈3–4 PM Philippine time). Free-tier content may be used by Google — synthetic or
  the owner's own material only.
- AI calls run with the database lock released (`Db.withoutLock`); anything else must keep the
  existing `synchronized (db)` pattern — there is one shared SQLite connection.
- `npm run test:e2e` rewrites `docs/screenshots/*.png` and `docs/e2e-results.json`; a failed run
  leaves `docs/screenshots/e2e-failure.png` — delete it, don't commit it.
- In Node on Windows, POSIX paths like `/c/Users/...` resolve to `C:\c\Users\...`; pass `C:/...`.
- Keep line endings as they are (most files LF in git). Python `write_text` on Windows writes
  CRLF — write bytes instead.
- "Keep me signed in" stores a non-extractable CryptoKey in IndexedDB; Lock/sign-out deletes it.
  Server sessions last 7 days; `AUTH_REQUIRED` sends the student back to sign-in with work kept.
- Nothing goes to GitHub until the owner has seen the exact files and destination (AGENTS.md).

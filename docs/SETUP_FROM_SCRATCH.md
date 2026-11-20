# CampusConnect: complete setup from scratch

This guide takes you from an empty computer to the running app: the code, the app on a phone, the server on AWS, and the automatic builds. Pick the path that matches what you need.

| I want to... | Do this | Time |
|---|---|---|
| **Show the app and the server still exists** | Install `CampusConnect.apk` on an Android phone | 2 min |
| **See the app with no server at all** | Part 4 (offline demo mode) | 15 min |
| **Bring the server back on AWS** | Parts 1 to 3, then [AWS_ONE_COMMAND.md](AWS_ONE_COMMAND.md) | 1 hour |
| **Run everything on my own laptop** | Parts 1 to 5 | 1 to 2 hours |
| **Understand or change the code** | Parts 1 to 3, then Part 9 | |

## 1. Accounts you need

| Account | For | Cost |
|---|---|---|
| **GitHub** | Holds the code and builds the app and API automatically (repo `hamza-core/Campus-connect`) | Free |
| **AWS** | The server and database | Free-tier credits; delete when finished |
| **Groq** (console.groq.com) | The chat assistant. Create an API key | Free tier, with limits |
| **Google AI Studio** (aistudio.google.com) | Photo suggestions. Create a Gemini API key | Free tier, with daily limits |

The AI keys are optional. Without them the app works, but the assistant answers from its knowledge base only and photo suggestions are off.

## 2. Tools to install on the Mac

| Tool | Used for | Install |
|---|---|---|
| **Git** and **GitHub CLI** (`gh`) | Get the code, run the build workflows | `brew install git gh`, then `gh auth login` |
| **.NET 10 SDK** | Build and run the API | dotnet.microsoft.com/download |
| **Flutter 3.47** (Dart 3.13) | Build the app | docs.flutter.dev/get-started/install |
| **Android Studio** (for the Android SDK) and **JDK 17** | Build the APK | developer.android.com/studio |
| **AWS CLI** | The one-command AWS setup | See [AWS_ONE_COMMAND.md](AWS_ONE_COMMAND.md), Step 1 |
| **Docker Desktop** | Only for running the database on your laptop | docker.com |

Check them: `git --version`, `dotnet --version`, `flutter doctor`, `aws --version`.

## 3. Get the code

**From GitHub (normal case):**
```
git clone https://github.com/hamza-core/Campus-connect.git CampusConnect
cd CampusConnect
```

**From the archive (if GitHub is gone).** The folder `02-source-code/` holds the full history as one file:
```
git clone CampusConnect-full-history.bundle CampusConnect
```
To put it back on a new GitHub repository:
```
cd CampusConnect
git remote set-url origin https://github.com/<you>/<repo>.git
git push --all origin
```
If the repository name or owner changes, update these two places: `REPO="hamza-core/Campus-connect"` in `infra/rebuild.sh`, and the `BootstrapUrl` default in `infra/cloudformation.yaml`.

**Folder map**

| Folder | What is in it |
|---|---|
| `frontend/` | The Flutter app |
| `backend/` | The ASP.NET Core API, its tests, and `deploy/` scripts |
| `contract/` | The OpenAPI file both sides are built against |
| `infra/` | One-command AWS build (`rebuild.sh`, `cloudformation.yaml`) |
| `docs/` | All guides |
| `.github/workflows/` | The automatic builds and deploys |

## 4. Run the app with no server (demo mode)

The app has built-in sample data for offline use.
```
cd frontend
flutter pub get
flutter run --dart-define=USE_MOCK=true
```
Pick a phone or emulator when asked (`flutter devices` lists them). Run the tests with `flutter analyze && flutter test`. They need no network.

## 5. Run the whole system on your laptop

**Database.** The API needs SQL Server. In Docker:
```
docker run -d --name cc-sql -e ACCEPT_EULA=Y -e MSSQL_SA_PASSWORD='Local_Pass123!' -p 1433:1433 mcr.microsoft.com/mssql/server:2022-latest
```
(On an Apple Silicon Mac this image needs Rosetta emulation turned on in Docker Desktop.)

**API.** From `backend/`:
```
dotnet tool restore
export ConnectionStrings__DefaultConnection='Server=localhost,1433;Database=CampusConnect;User Id=sa;Password=Local_Pass123!;TrustServerCertificate=true;Encrypt=true'
export JWT_SECRET="$(openssl rand -base64 48)"
export SEED_PASSWORD='ChooseADemoPassword1'
export UPLOADS_DIR="$HOME/cc-uploads"

dotnet run --project src/CampusConnect.Api -- --seed                  # departments + 7 demo accounts
CONFIRM_RESET=delete-all-complaints dotnet run --project src/CampusConnect.Api -- --reset-demo   # 44 realistic complaints
dotnet run --project src/CampusConnect.Api --no-launch-profile --urls http://localhost:4000
```
Check it: `curl http://localhost:4000/api/v1/health` should return `{"status":"ok"}`.

To turn on the AI features, also export `LLM_API_KEY` (Groq), `LLM_BASE_URL=https://api.groq.com/openai/v1`, `LLM_MODEL=openai/gpt-oss-20b`, `LLM_REASONING_EFFORT=low`, `VISION_API_KEY` (Gemini) and `VISION_MODEL=gemini-flash-lite-latest` before starting.

**Backend tests:**
```
export TEST_DATABASE_URL='Server=localhost,1433;User Id=sa;Password=Local_Pass123!;TrustServerCertificate=true'
dotnet test CampusConnect.sln
```

**App against your laptop API:**
```
cd frontend
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000/api/v1      # Android emulator
flutter run --dart-define=API_BASE_URL=http://<your-mac-ip>:4000/api/v1  # phone on the same Wi-Fi
```

## 6. Build the APK

```
cd frontend
flutter build apk --release --dart-define=API_BASE_URL=http://<server-ip>/api/v1
```
The file is `build/app/outputs/flutter-apk/app-release.apk`. Rename it `CampusConnect.apk` if you like; the name does not matter. The server address is only set here, at build time. The app is signed with a debug key, so uninstall an older copy before installing a new one. Install with `adb install -r CampusConnect.apk`, or copy the file to the phone and open it.

## 7. Put the server on AWS

Follow [AWS_ONE_COMMAND.md](AWS_ONE_COMMAND.md). In short:
1. Set up AWS credentials on the Mac (Step 1 of that guide).
2. `./infra/rebuild.sh check`, then `./infra/rebuild.sh up`. It asks for a demo password and the two AI keys.
3. When it finishes it prints the server address. Rebuild the APK against it (Part 6, or the GitHub variable below).
4. When you are done: `./infra/rebuild.sh down`. A final database snapshot is kept.

The manual version of the same steps, and a reference of what gets built, is [AWS_REBUILD.md](AWS_REBUILD.md).

## 8. Automatic builds on GitHub

The workflows in `.github/workflows/` run on their own:

| Workflow | When | What |
|---|---|---|
| **Backend CI** | A change under `backend/` or `contract/` | Builds the API and runs all tests against SQL Server |
| **Backend CD** | After Backend CI passes on `main` | Deploys the API to the server. Stays idle until the secrets below are set |
| **Frontend APK** | A change under `frontend/` | Analyzes, tests and builds the APK. On `main` it publishes it as the **`latest`** release |

**To switch on automatic deploys:** GitHub, then Settings, Secrets and variables, Actions, add the secrets `EC2_HOST`, `EC2_USER` (`ubuntu`) and `EC2_SSH_KEY` (a dedicated deploy key, not your personal one). Optionally add `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` and `SG_ID` so the pipeline opens SSH for one IP only while it deploys.

**To point new APK builds at a new server:** the same page, tab **Variables**, set `API_BASE_URL` to `http://<server-ip>/api/v1`, then run the *Frontend APK* workflow (Actions tab, Run workflow). Download the APK from **Releases**.

## 9. Demo accounts and data

All demo accounts use `@campusconnect.edu` and the password you chose as `SEED_PASSWORD`.

| Role | Accounts |
|---|---|
| Student | `student`, `student2`, `sara`, `usman`, `hina`, `zain` |
| Department admin | `cafeteria`, `library`, `labit`, `academic` |
| Super admin (read-only) | `super` |

Anyone can also register a new student account inside the app.

On a **new, empty database** run `--seed` first, then `--reset-demo`: `--seed` creates the departments and admin accounts, and `--reset-demo` replaces its plain sample data with the 44 realistic complaints and adds the extra students. `--reset-demo` **deletes every complaint**, so it refuses to run without `CONFIRM_RESET=delete-all-complaints`.

## 10. Where to read next

| Topic | File |
|---|---|
| What the app does, by role | `README.md`, and the project documentation PDF |
| Architecture and design decisions | `docs/ARCHITECTURE.md` |
| The API | `contract/openapi.yaml`, `docs/INTEGRATION.md` |
| The AI assistant | `docs/CHATBOT.md` |
| Server details and deploy steps | `docs/DEPLOYMENT.md` |
| Everything that changed, version by version | `docs/CHANGELOG.md` |

## 11. Things to keep private

Never commit these, and keep a copy somewhere safe (a password manager):
- The AWS access key (`~/.aws/credentials`) and the SSH key (`~/.ssh/campusconnect-key.pem`).
- `~/.campusconnect/secrets.env`, written by `rebuild.sh`: the database password, the login-signing key, the demo password and the AI keys.
- The AI keys themselves (Groq and Gemini), which you can recreate in their consoles.

## 12. If something goes wrong

| Problem | Try |
|---|---|
| App says "Set API_BASE_URL" | You built or ran without `--dart-define=API_BASE_URL=...` or `USE_MOCK=true` |
| App cannot connect | The APK points at an old server address; rebuild it (Part 6). Check `http://<ip>/api/v1/health` in a browser |
| `up` fails | `./infra/rebuild.sh down`, then read the message and see the table at the end of AWS_ONE_COMMAND.md |
| Photo suggestions or chat do nothing | The free AI quota ran out, or a key is missing. The rest of the app still works |
| `flutter doctor` complains | Fix what it lists, usually the Android SDK licences: `flutter doctor --android-licenses` |

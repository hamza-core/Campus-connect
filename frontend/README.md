# CampusConnect app (Flutter, Android)

Student, department-admin and super-admin app for CampusConnect. Talks to the ASP.NET Core API described in `../contract/openapi.yaml`.

## Run

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://13.53.165.254/api/v1      # real API
flutter run --dart-define=USE_MOCK=true                                 # offline demo data
flutter analyze && flutter test                                         # 37 tests
flutter build apk --release --dart-define=API_BASE_URL=http://13.53.165.254/api/v1
```

`API_BASE_URL` is the only required setting (no trailing slash). Without it (and without `USE_MOCK`) the app shows "Set API_BASE_URL".
The demo server is plain HTTP, so `AndroidManifest.xml` sets `usesCleartextTraffic="true"` — remove it once HTTPS exists.

Releases are built by GitHub Actions (`.github/workflows/frontend-apk.yml`: analyze → test → build → artifact `campusconnect-apk`). Each build is signed with a temporary debug key, so run `adb uninstall com.example.project` before installing a different build.

## Architecture (`lib/`)

| Folder | Role |
|---|---|
| `core/` | API client (`network/`), errors, theme, widgets (hero header, floating pill nav, badges), secure token + photo storage, platform alerts |
| `domain/` | Enums and immutable models (`Complaint`, `ComplaintSummary`, `AppNotification`, …) |
| `data/` | Repository interfaces; `remote/` (real API), `mock/` (demo data, used by tests); `realtime/` (SignalR) |
| `features/` | `auth`, `student`, `department_admin`, `super_admin`, `shared`, `notifications` — screens, widgets, controllers (`ChangeNotifier`) |
| `routing/` | `go_router` routes and the role guard |
| `di/` | `AppDependencies` + `AppScope` (no state-management package) |

State: `ChangeNotifier` controllers on a small `BaseController` (loading / success / empty / error, stale-response protection). Navigation: `go_router` with role-based redirects.

## Behaviour worth knowing

- **Roles** come from `GET /auth/me` / login; the route guard hides other roles' pages, but every call may still return `403` (shown as an access-denied screen).
- **Status changes** (department admin only) send the `rowVersion` last read; `409` reloads the complaint. Buttons come from the server's `allowedTransitions`. Super admin is read-only.
- **Photos** stay on the device (sembast database keyed by account + complaint); the server stores none and `imageUrls` is never sent.
- **Realtime**: after student sign-in the app opens a SignalR connection (`/hubs/notifications`, token in `access_token`). New events appear as a banner in the app and as a **system notification while minimized** (Android foreground service of type `dataSync` keeps the connection alive; the user must allow notifications).
- **Auto-refresh**: lists and dashboards quietly refresh every 10 s, when the app is reopened, and on a live notification — without loading flicker, and not while the user is scrolled down a list.
- **Session**: the login token is kept in Android Keystore (`flutter_secure_storage`) and cleared on logout or `401`.
- **Export**: admins can export the filtered list as CSV through the system share sheet.

## Tests

`test/` covers the API client, repositories (live and mock), controllers (including quiet refresh and realtime notifications), role-scoped flows, and layout at 360–1440 px with larger text. Tests use the mock repositories; no network or Android needed.

## Android notes

`compileSdk 37` (required by `flutter_local_notifications` / AndroidX), core library desugaring enabled. Permissions: `INTERNET`, `POST_NOTIFICATIONS`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`, `WAKE_LOCK`. On Samsung/other OEMs set the app's battery to *Unrestricted* if popups stop after long idle periods. On Android 15+ a `dataSync` foreground service is limited to ~6 h per day unless the app is opened.

Known package name: `com.example.project` (default Flutter template) — change before any store release.

# CLAUDE.md — Claude: frontend (Flutter app)

You are the **frontend engineer** for **CampusConnect** (Smart Campus Complaint & Feedback Management System). Codex owns the backend (ASP.NET Core, deployed). The owner (human) is the integrator.

**Read first, every session:** `CONTRACT.md` → `contract/openapi.yaml` → `docs/INTEGRATION.md` → `frontend/README.md` → top of `docs/HANDOFF.md`. Requirements: `docs/CampusConnect_Competition_Problem_Statement.pdf`; status: `docs/REQUIREMENTS_COVERAGE.md`.

## Territory
- You edit **only `frontend/**`** (and append to `docs/HANDOFF.md`). Never `backend/**`.
- API change needed → a `contract/` PR or a handoff to Codex; update `docs/INTEGRATION.md` in the same change as the app.

## Stack (implemented — don't re-litigate)
Flutter 3.47 / Dart 3.13, Android. `go_router` (role guard), `ChangeNotifier` controllers on `BaseController`, repositories with `remote/` and `mock/` implementations (`AppDependencies` + `AppScope`), `http`, `signalr_netcore` (live notifications), `flutter_local_notifications` + `flutter_foreground_task` (popups while minimized, Android only), `flutter_secure_storage` (saved login), `sembast` (device-only photos), `image_picker`, `fl_chart`, `share_plus` (CSV), `intl`, `shimmer`. Config: `--dart-define=API_BASE_URL=…` (required) or `USE_MOCK=true`.

## Commands (from `frontend/`)
```
flutter pub get
flutter analyze && flutter test            # 37 tests, no network needed (mock repositories)
flutter run --dart-define=API_BASE_URL=http://13.53.165.254/api/v1
flutter build apk --release --dart-define=API_BASE_URL=http://13.53.165.254/api/v1
```
CI (`frontend-apk.yml`) runs analyze → test → build and uploads artifact `campusconnect-apk`. Always run analyze + test locally before pushing.

## Rules that matter
- **Authorization is never frontend-only.** Hide by role for UX, but any call can return `403` → access-denied screen. Roles come from the server.
- Status changes (department admin only) send the `rowVersion` last read; `409` reloads. Buttons come from `allowedTransitions`. **Super admin is read-only.** A remark is required for `RESOLVED`/`REJECTED`.
- Create complaint sends `category` (never a department). **No image upload** — photos stay on the device; never send `imageUrls`.
- Lists/dashboards refresh quietly every 10 s (`core/utils/auto_refresh.dart`), on resume, and on a live notification — no loading flicker, skipped while scrolled down. Don't reintroduce full-screen spinners on refresh.
- Realtime is for the owning student only; the REST list stays authoritative (merge by `id`, reload after reconnect). Android popups go through `BackgroundAlerts` (no-op in tests/mock/web).
- Every list handles loading, empty and error states; status colours: Pending amber · In progress blue · Resolved green · Rejected red (icon/label too). Tap targets ≥ 44 px; labels on inputs.
- Style: app font `Inter` must be set on any custom `TextStyle` used in button/chip themes; borders `#CFC9B8` 1.5 px; primary `#004741`; cream surfaces. Reuse `HeroHeader`, `FloatingPillNav`, `StatusBadge`, `PriorityBadge`, `ClayCard`.
- No secrets in the app; no `any`; keep files small; no unused packages (several are still listed — remove, don't add more).
- Tests: widget tests that scroll a pushed page should target the topmost `ListView` (`find.byType(ListView).last`) and drop text focus first.

## Workflow
Branch `fe/<feature>`; Conventional Commits `feat(fe): …`; one-side-only PRs into `main`. CI must be green. Append milestones to `docs/HANDOFF.md`.

## Release / demo checklist
- [ ] APK from CI installs and signs in as each role; Library admin → Lab complaint = 403 screen
- [ ] Status change with remark works; stale edit shows the conflict message
- [ ] Banner + system popup when the owner's complaint changes (allow notifications; battery Unrestricted)
- [ ] Super admin dashboard shows the department bar chart; CSV export opens the share sheet
- [ ] `GET /api/v1/health` = 200 and SignalR negotiate = 200

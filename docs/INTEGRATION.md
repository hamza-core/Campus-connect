# Frontend integration guide

For the app (Flutter, `frontend/`) and anyone building another client. API: ASP.NET Core, base `/api/v1`. Source of truth: `contract/openapi.yaml` (v1.2.1). The realtime hub is documented here and in `CONTRACT.md` (OpenAPI cannot describe it).

## 1. Connection settings

| Setting | Value |
|---|---|
| Production API | `http://13.53.165.254/api/v1` (HTTP only until a domain + certificate exist; IP changes on restart unless an Elastic IP is attached) |
| Realtime hub | `http://13.53.165.254/hubs/notifications` (note: **not** under `/api/v1`) |
| Health | `GET /api/v1/health` → `{ "status": "ok" }` (503 when the database is down) |
| Local API | `http://localhost:4000/api/v1` · Android emulator → host `http://10.0.2.2:4000/api/v1` |
| Mock server | `npx @stoplight/prism-cli mock contract/openapi.yaml -p 4010` |

The Flutter app reads `--dart-define=API_BASE_URL=…` (no trailing slash). **Android + HTTP:** release builds block cleartext traffic, so `AndroidManifest.xml` sets `android:usesCleartextTraffic="true"` for the demo — remove it once HTTPS is available. CORS only matters for a web client (origins must be in the server's `CORS_ORIGINS`).

## 2. Request/response rules

- `Authorization: Bearer <token>`; JSON bodies.
- Success `{ "data": … }`; lists add `page`, `pageSize`, `total`. **Login/register return `{ "token", "user" }` with no `data` wrapper** (the app also accepts the wrapped form).
- Errors `{ "error": { "code", "message", "fields?" } }`.

| Status | `code` | UI reaction |
|---|---|---|
| 401 | `UNAUTHORIZED` | Clear the session → login ("Invalid email or password" on login itself) |
| 403 | `FORBIDDEN` | Access-denied screen; never retry |
| 404 | `NOT_FOUND` | Not-found screen |
| 409 | `CONFLICT` / `INVALID_TRANSITION` | Reload the complaint; "This complaint changed" |
| 422 | `VALIDATION_FAILED` | Show `fields` |
| 429 | `RATE_LIMITED` | "Too many attempts, wait a minute" |

## 3. Auth

1. `POST /auth/login` `{ email, password }` → `{ token, user }`. Students can `POST /auth/register` `{ name, email, password, studentId? }` (password 8–72 bytes). Admins are seeded, never registered.
2. Token lifetime is 7 days (no refresh endpoint). The app keeps it in memory **and** in the device's secure storage (Android Keystore) so the session survives restarts; it is cleared on logout or `401`.
3. On start: if a saved token exists call `GET /auth/me` → `{ data: user }`; `401` → login.
4. `user.role` (`STUDENT`, `DEPT_ADMIN`, `SUPER_ADMIN`) drives navigation; `user.department` is set for department admins.

## 4. Endpoint map

| Screen | Call |
|---|---|
| Submit | `POST /complaints` `{ category, title (5–120), description (10–3000), subIssue?, priority? (LOW\|MEDIUM\|HIGH), location? (≤120), anonymousToStaff?, imageUrls? (ignored) }` → 201. **Never send a department.** |
| Lists | `GET /complaints?status=&category=&departmentId=&priority=&overdue=true&q=&sort=&page=&pageSize=` — scoped by role on the server |
| Detail | `GET /complaints/{id}` → complaint + `timeline[]`, `feedback`, `allowedTransitions[]`, `rowVersion`, `dueAt`, `isOverdue`, `location`, `subIssue` |
| Status (dept admin) | `PATCH /complaints/{id}/status` `{ status, remark?, rowVersion }` |
| Remark (dept admin) | `POST /complaints/{id}/comments` `{ body }` |
| Rating (owner, resolved, once) | `POST /complaints/{id}/feedback` `{ rating 1–5, comment? }` → complaint detail |
| Notifications | `GET /notifications` → `{ data, unreadCount }` · `POST /notifications/read-all` → 204 |
| Dashboard | `GET /analytics/summary` (counts, `overdue`, `avgResolutionHours`, `avgRating`), `/analytics/by-department`, `/by-status`, `/trend?days=14`, `/recurring` |
| Export (admins) | `GET /admin/complaints/export.csv` (same filters) → `text/csv` |

Role rules: students get `403` on `/analytics/*` and admin routes; department admins only see their own department; the super admin is read-only (`403` on status/remarks).

## 5. Realtime notifications (SignalR)

- Endpoint `/hubs/notifications` (ASP.NET Core SignalR, JSON protocol). Authenticate with the same JWT: WebSocket clients pass it as the `access_token` **query** parameter (negotiate also accepts the `Authorization` header). Unauthenticated → `401`.
- The server pushes to the **complaint owner only**. Event name `notification`, one argument `{ id, message, complaintId, read, createdAt }` (camelCase). The REST list stays authoritative: load it first, then merge live events by `id` (ignore duplicates), and reload after a reconnect.
- Nginx must forward WebSocket upgrade headers (`Upgrade`, `Connection`) — configured in `docs/DEPLOYMENT.md`.

Flutter specifics: `signalr_netcore` (WebSockets only, automatic reconnect), `NotificationController` (`features/notifications/`), `BackgroundAlerts` (`core/platform/`).

### System popups while the app is minimized (Android)
A foreground service (`flutter_foreground_task`, type `dataSync`) keeps the process and the SignalR connection alive after sign-in; when an event arrives while the app is paused/hidden, `flutter_local_notifications` shows a heads-up notification; tapping it opens that complaint. The user must allow notifications (Android 13+). Not available on web, in mock mode, or in tests (`NoopBackgroundAlerts`).

## 6. Auto-refresh
Lists and dashboards call a quiet refresh every 10 s (`core/utils/auto_refresh.dart`), when the app resumes, and on a live notification. It never shows a loading state, changes nothing if the data is the same, and is skipped while the user is scrolled down a list. There is no server push to admins yet; new complaints appear within ~10 s.

## 7. Photos and AI issue detection
Up to 3 photos per complaint (≤ 5 MB). Each pick is uploaded with `POST /uploads` (multipart, field `file`) and the returned URL is sent as `imageUrls` on `POST /complaints`; a copy also stays on the device (sembast) for the detail screen. The first photo triggers `POST /complaints/analyze`, which suggests category, issue label and priority (503 `AI_UNAVAILABLE` → the app says to choose manually). The "kind of problem" chips come from `GET /meta/frequent-issues?category=` (most reported labels in the database) and fall back to the brief's examples while the database is empty. Showing server photos to department admins in the detail screen is not built yet.

## 8. Status changes without lost updates
Read the complaint → show buttons from `allowedTransitions` (empty for students and the super admin) → `PATCH …/status` with the `rowVersion` from that read. `200` replace local copy; `409` reload and tell the user; `422` show fields (remark required for `RESOLVED` and `REJECTED`).

## 9. Typed models
The Dart models in `frontend/lib/domain` mirror the contract by hand (the schema is small). When the contract changes, update `domain/models/*` and the repositories in `data/repositories/remote/` together and extend `frontend/test`.

## 10. Test accounts
Created with `--seed` using the server's `SEED_PASSWORD` (shared privately): `super@`, `cafeteria@`, `library@`, `labit@`, `academic@`, `student@`, `student2@` + `campusconnect.edu`. Offline demo accounts for `USE_MOCK=true`: `ali@student.com / Ali@1234`, `library.admin@campus.com / Admin@1234`, `super.admin@campus.com / Admin@1234`.

## 11. Pre-demo checks from the app
- [ ] `GET /api/v1/health` is 200 from the phone's network
- [ ] Each role signs in and sees only its scope
- [ ] Library admin opening a Lab/IT complaint → access-denied screen
- [ ] Submit → complaint appears in the right department inbox (within ~10 s)
- [ ] Status change with a remark → the student gets a banner/popup
- [ ] Super admin dashboard shows the department bar chart

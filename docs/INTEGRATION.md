# Frontend integration guide

For the frontend (Claude / the owner's app). The API is implemented (ASP.NET Core, `/api/v1`). Source of truth: `contract/openapi.yaml`.

## 1. Connection settings

| Setting | Value |
|---|---|
| Production base URL | `http://13.53.165.254/api/v1` (HTTP until a domain + certificate exist; the IP changes if the instance stops unless an Elastic IP is attached) |
| Local backend | `http://localhost:4000/api/v1` · Android emulator → host: `http://10.0.2.2:4000/api/v1` |
| Mock server | `npx @stoplight/prism-cli mock contract/openapi.yaml -p 4010` → `http://localhost:4010/api/v1` |
| Health check | `GET /health` → `{ "status": "ok" }` (503 = database down) |

Put the base URL in **build-time config** (e.g. `--dart-define=API_BASE_URL=…`, `.env` for Expo/Vite, a Gradle `buildConfigField`) — never hard-code it in feature code.

**Android + HTTP:** release builds block cleartext traffic. For the demo over the raw IP, allow it explicitly (`android:usesCleartextTraffic="true"` in `AndroidManifest.xml`, or a network-security-config limited to that host). Remove it once Nginx serves HTTPS (needs a domain; certbot).
**CORS** only matters if you also run a web build; a native app is unaffected. Web origins must be listed in the server's `CORS_ORIGINS`.

## 2. Request/response rules

- Header: `Authorization: Bearer <token>`; `Content-Type: application/json`.
- Success: `{ "data": … }`; lists: `{ "data": […], "page", "pageSize", "total" }`. **Login/register return `{ "token", "user" }` (no `data` wrapper).**
- Errors: `{ "error": { "code", "message", "fields?" } }`, `fields` = `{ fieldName: message }` for 422.

| Status | `code` | UI reaction |
|---|---|---|
| 401 | `UNAUTHORIZED` | Clear session → login screen (on login itself: "Invalid email or password") |
| 403 | `FORBIDDEN` | Show the 403 screen ("You don't have access") — do not retry |
| 404 | `NOT_FOUND` | 404 screen |
| 409 | `CONFLICT` / `INVALID_TRANSITION` | Reload the complaint; message "This complaint changed, please review" |
| 422 | `VALIDATION_FAILED` | Show `fields` under the matching inputs |
| 429 | `RATE_LIMITED` | "Too many attempts. Wait a minute." |
| 5xx | `INTERNAL` | Generic retry message |

## 3. Auth flow

1. `POST /auth/login` `{ email, password }` → `{ token, user }`. Students can `POST /auth/register` `{ name, email, password, studentId? }` (password 8–72 bytes). Admins are seeded, never registered.
2. Keep `token` in memory; persist in secure storage if "stay signed in" is needed (Keychain/Keystore, not plain preferences). Token lifetime is 7 days; no refresh endpoint yet.
3. On app start, if a token exists call `GET /auth/me` → `{ data: user }`; 401 → login.
4. `user.role` drives navigation: `STUDENT` → student shell; `DEPT_ADMIN` → department shell (`user.department` = its department); `SUPER_ADMIN` → global read-only shell.

## 4. Endpoint map (what each screen calls)

| Screen | Call |
|---|---|
| Category picker | `GET /meta/categories` → `[{ key, label, description, subIssues[], department }]` (cache it) |
| Submit complaint | `POST /complaints` `{ category, subIssue?, title (5–120), description (10–3000), priority?, location?, imageUrls? (≤3), anonymousToStaff? }` → 201 `{ data: complaint }`. **Never send a department.** |
| My / inbox / all lists | `GET /complaints?status=&category=&departmentId=&priority=&overdue=&q=&sort=&page=&pageSize=` — the server scopes by role (student: own, dept admin: own dept, super admin: all) |
| Complaint detail | `GET /complaints/{id}` → `{ data: complaint + timeline[], feedback, allowedTransitions[] }` |
| Change status (DEPT_ADMIN) | `PATCH /complaints/{id}/status` `{ status, remark?, rowVersion }` → 200 `{ data: detail }` |
| Add remark (DEPT_ADMIN) | `POST /complaints/{id}/comments` `{ body }` |
| Rate resolution (student) | `POST /complaints/{id}/feedback` `{ rating 1–5, comment? }` (once, only when RESOLVED) |
| Notifications | `GET /notifications?unreadOnly=` → `{ data, unreadCount }`, poll every 30 s · `POST /notifications/read-all` → 204 |
| KPI cards (admins) | `GET /analytics/summary` → `{ total, pending, inProgress, resolved, rejected, overdue, … }` |
| Bar chart | `GET /analytics/by-department` → `[{ department, count }]` |
| Status chart | `GET /analytics/by-status` → `[{ status, count }]` |
| Trend / recurring | `GET /analytics/trend?days=14`, `GET /analytics/recurring` |
| CSV export (admins) | `GET /admin/complaints/export.csv` (same filters) |
| Image upload | see §5 |

Roles: students calling `/analytics/*` or admin routes get 403 — don't show those screens.

## 5. Complaint images — kept on the device for now

The server has **no image storage and no upload endpoint**. Do not call `/uploads/sign` (removed). Let the user attach up to 3 photos when submitting, keep them **locally** (app storage, keyed by the complaint `id`/`ticket` returned by `POST /complaints`), and show them from there on that device. Do **not** send `imageUrls` (it is ignored; responses always return `[]`). Staff on other devices will not see the photos — say so in the UI ("Photos are saved on this device only"). Storage on a server will be added later through a contract change.

## 6. Status changes without losing data

```text
detail = GET /complaints/42               # contains rowVersion and allowedTransitions
show buttons only for allowedTransitions   # empty for students and SUPER_ADMIN
PATCH /complaints/42/status { status, remark, rowVersion: detail.rowVersion }
  200 → replace local copy with response
  409 → refetch detail, tell the user someone else changed it
  422 → show fields (remark is required for RESOLVED and REJECTED)
```

## 7. Typed client (recommended)

Generate types/DTOs from `contract/openapi.yaml` (e.g. `openapi-typescript` for TS, `openapi-generator -g dart-dio` for Flutter, `-g kotlin`/`swift5` for native) and wrap them in one HTTP module. If the generator struggles with the spec, hand-write the DTOs for the ~10 shapes in §4 and keep them in a single file so a contract change touches one place.

TypeScript sketch (one client module for the whole app):
```ts
const BASE = import.meta.env.VITE_API_URL;          // …/api/v1
let token: string | null = null;
export const setToken = (t: string | null) => { token = t; };

export async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
  const res = await fetch(BASE + path, {
    ...init,
    headers: { 'Content-Type': 'application/json', ...(token && { Authorization: `Bearer ${token}` }), ...init.headers },
  });
  if (res.status === 204) return undefined as T;
  const body = await res.json().catch(() => null);
  if (!res.ok) throw { status: res.status, ...(body?.error ?? { code: 'INTERNAL', message: 'Request failed' }) };
  return body as T;
}
// usage: const { data } = await api<{ data: Complaint }>('/complaints/42');
```
Dart/dio: one `Dio` with `baseUrl` from `String.fromEnvironment('API_BASE_URL')`, an interceptor adding the bearer header, and an error interceptor mapping `response.data['error']` to a typed `ApiException(status, code, message, fields)`.

## 8. Test accounts

Created with `--seed` on the server (password from the server's `SEED_PASSWORD`; ask the owner). Emails: `super@`, `cafeteria@`, `library@`, `labit@`, `academic@`, `student@`, `student2@` + `campusconnect.edu`.

## 9. Pre-demo checks from the app

- [ ] `GET /health` is 200 from the phone's network
- [ ] Each role logs in and sees only its scope
- [ ] Library admin opening a Lab/IT complaint id → 403 screen
- [ ] Submit → complaint appears in the right department inbox
- [ ] Status change with a remark, then a stale second edit → 409 message
- [ ] Dashboard bar chart loads

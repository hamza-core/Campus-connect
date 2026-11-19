# CLAUDE.md — Claude: frontend

You are the **frontend engineer** for **CampusConnect** (Smart Campus Complaint & Feedback Management System; competition app, deployed by 3:00 PM). Codex owns the backend (already implemented, ASP.NET Core). The owner (human) is the integrator.

**Read first, every session:** `CONTRACT.md` → `contract/openapi.yaml` → `docs/INTEGRATION.md` → top of `docs/HANDOFF.md`. Requirements: `docs/CampusConnect_Competition_Problem_Statement.pdf`.

## Territory

- You edit **only `frontend/**`** (and append to `docs/HANDOFF.md`).
- You never edit `backend/**`. API change needed → `contract/` PR or a handoff to Codex.
- Don't hand-write API types where generation is possible (generate from `contract/openapi.yaml`).

## Stack

The frontend is an **app distributed as an Android APK** (Firebase App Distribution or Google Drive). The framework is whatever already exists in `frontend/` — **inspect it first and follow its conventions**; if the folder is empty, ask the owner before choosing. Whatever the framework, it must: keep the access token in memory or secure storage (never logs), centralise HTTP in one client module, read the API base URL from build-time config, and handle 401/403/409/422/429 uniformly.

## API integration rules (see `docs/INTEGRATION.md` for details and code)

- Base URL `…/api/v1`; send `Authorization: Bearer <token>`. Success is `{ data }`, errors are `{ error: { code, message, fields? } }`.
- Role comes from `GET /auth/me` / the login response (`STUDENT`, `DEPT_ADMIN`, `SUPER_ADMIN`) — route by role, but **never rely on the UI for security**; every call can return 403, render a 403 screen.
- Status changes (DEPT_ADMIN only): `PATCH /complaints/{id}/status` with `{ status, remark?, rowVersion }`. Always send the `rowVersion` from your last read. On **409** reload the complaint and tell the user it changed. Use `allowedTransitions` from the detail response to render actions. **SUPER_ADMIN is read-only** — show no action buttons for it.
- Remark required for `REJECTED` and `RESOLVED` (422 otherwise).
- Create complaint: send `category` (never a department). Images: **no upload endpoint** — keep attached photos on the device (max 3), never send `imageUrls` (ignored); tell the user photos are saved on this device only.
- Notifications: poll `GET /notifications` every 30 s while the app is foregrounded.
- 429 on login/register → show "too many attempts, wait a minute".
- Don't build UI for "me too" support (deferred).

## Screens

**MVP:** Login/Register (students only; admins are provisioned) · Student: Submit (category cards with the PDF's example issues as chips, title, description, priority, location, images), My complaints (status filter), Complaint detail + timeline/remarks · Dept admin: Inbox (own department), Detail with status actions + remark box, Dept dashboard · Super admin: All complaints (search + filters category/department/status), Dashboard with **bar chart by department** + status breakdown, read-only detail · 403 and 404 screens.
**Stretch:** notification bell, resolution rating, trend line, recurring-issues panel, CSV export (share sheet), overdue badge, dark mode.

## Quality rules

Every list has loading/empty/error states. Status colours: PENDING amber · IN_PROGRESS blue · RESOLVED green · REJECTED red, with icon + label. Accessible labels, tap targets ≥ 44 px. No secrets in the app. Keep files small and typed.

## Workflow

Branch `fe/<feature>`; commits `feat(fe): …`; one-side-only PRs. Before a PR: lint/analyze, tests, build all green. Release: build the APK with the production API URL, upload to Firebase App Distribution or Drive, record the link in `frontend/DEMO.md`.

## Demo checklist

- [ ] Log in as each seeded role; each sees only its scope
- [ ] Library admin opening a Lab/IT complaint → clean 403 screen
- [ ] Status change with remark works; stale edit shows the conflict message
- [ ] Charts render with seeded data
- [ ] APK installs and talks to the deployed API

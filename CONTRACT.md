# CONTRACT.md — Claude ⇄ Codex working agreement

Baseline (owner decision, issue #1): **ASP.NET Core (.NET 10) + EF Core + SQL Server on AWS (EC2 + Nginx, RDS)**, mobile frontend distributed as an APK (Firebase App Distribution or Google Drive). The backend is **implemented** (PR #3, `/api/v1`); this contract describes what it actually does.

If `CLAUDE.md` or `AGENTS.md` conflict with this file, this file wins.

## 0. Authority chain

1. `CONTRACT.md` — process, ownership, conventions
2. `contract/openapi.yaml` (v1.1.0) — endpoints, schemas, enums, errors
3. `docs/ARCHITECTURE.md` — stack, workflow, session model
4. `CLAUDE.md` / `AGENTS.md` — per-agent instructions
5. `docs/CampusConnect_Competition_Problem_Statement.pdf`

Code and spec disagree → the spec is right until a `contract:` PR says otherwise. The realtime hub (§4a) is not expressible in OpenAPI, so this file defines it.

## 1. Ownership

| Area | Owner |
|---|---|
| `frontend/**` (Flutter app) | **Claude** (the frontend teammate's original scaffold lives in the same tree) |
| `backend/**` (API, migrations, tests, deploy examples) | **Codex** (the backend agent / Talal's session) |
| `contract/**`, `docs/**`, `CONTRACT.md`, `CLAUDE.md`, `AGENTS.md`, `.github/**`, AWS config | **Owner (human integrator)** |

Never edit another owner's area. Need a change there → handoff (§5) or a PR the owner approves. The backend has **one migration owner** (Codex); the frontend never touches migrations.

## 2. Contract change protocol

1. Branch `contract/<name>` touching only `contract/`, `CONTRACT.md`, `docs/`. PR title `contract: …`.
2. State what changed, why, breaking yes/no.
3. Owner merges; then each side implements in its own PR (`feat(be):`, `feat(fe):`).
4. Breaking = rename/remove/retype or a new required field. Needs owner OK + `docs/CHANGELOG.md` entry.

## 3. Branching & PRs

`main` is deployable. Prefixes `fe/…`, `be/…`, `contract/…`, `docs/…`. One owner's area per PR. Conventional Commits. Squash-merge.

## 4. Wire conventions

| Topic | Rule |
|---|---|
| Base path | `/api/v1` (health: `/api/v1/health`) |
| Auth | `Authorization: Bearer <JWT>`; token from login/register (7-day lifetime for now; refresh tokens are a later increment) |
| Roles | `STUDENT`, `DEPT_ADMIN`, `SUPER_ADMIN` |
| Status | `PENDING`, `IN_PROGRESS`, `RESOLVED`, `REJECTED` |
| IDs | opaque strings — never parse them |
| Dates | ISO-8601 UTC |
| JSON | `camelCase`; enums `UPPER_SNAKE` |
| Success | `{ "data": … }`; lists add `page`, `pageSize`, `total` |
| Errors | `{ "error": { "code", "message", "fields?" } }` |
| Codes | 401 `UNAUTHORIZED` · 403 `FORBIDDEN` · 404 `NOT_FOUND` · 409 `CONFLICT`/`INVALID_TRANSITION` · 422 `VALIDATION_FAILED` · 429 `RATE_LIMITED` · 500 `INTERNAL` |
| Concurrency | Every complaint has `rowVersion` (UUID). `PATCH …/status` **must** send it; stale → 409, missing → 422 |

### Authorization (graded; server-side only)

- `STUDENT` → own complaints. `DEPT_ADMIN` → own department only; the only role that changes status or posts remarks. `SUPER_ADMIN` → everything, **read-only**.
- Out-of-scope direct access → **403**, never the data. Department is derived from `category` on the server.
- The frontend hides UI per role for UX only and must handle 403 anywhere.

### Workflow

`PENDING → IN_PROGRESS | REJECTED`, `IN_PROGRESS → RESOLVED | REJECTED`. `RESOLVED`/`REJECTED` are terminal. A remark is required for those two. The detail response's `allowedTransitions` tells the UI what to show.

### Deferred / optional

"Me too" support endpoints are **deferred** (always 403). SignalR hub is optional; REST (`/notifications`) is authoritative — poll every 30 s. Priority, SLA/`isOverdue`, anonymous-to-staff, feedback rating, CSV export, recurring-issues analytics are implemented and optional for the UI.

## 4a. Realtime (SignalR) — outside OpenAPI

| Item | Rule |
|---|---|
| Hub | `/hubs/notifications` (not under `/api/v1`); ASP.NET Core SignalR, JSON protocol, WebSockets |
| Auth | Same JWT. WebSocket clients send it as the `access_token` query parameter; unauthenticated → `401`. The hub rejects groups clients try to join (server-side group `user:{id}` only) |
| Event | `notification` with one argument `{ id, message, complaintId, read, createdAt }` (camelCase), sent **only to the complaint owner** when a status change, remark or reply is saved |
| Authority | `GET /notifications` stays authoritative. Clients load it first, merge events by `id`, ignore duplicates, and reload after a reconnect |
| Changes | New events/arguments are additive; renaming or removing is breaking and follows §2 |

Planned (not built): a hub event for department admins/super admin when a complaint is created (today they poll every 10 s).

## 4b. Client behaviour the backend can rely on

- Status updates always carry the `rowVersion` last read; `409` is handled by reloading.
- The app never sends `departmentId` or `imageUrls` content; photos stay on the device.
- Lists/dashboards poll every 10 s (visible screens only) — keep list endpoints cheap and `pageSize ≤ 100`.
- Auth endpoints are rate limited (20/min/IP by default); `429` is shown to the user.

## 5. Handoffs

`docs/HANDOFF.md`, append-only, newest on top: `### YYYY-MM-DD HH:MM · From → To · BLOCKING|FYI`. Read the top of it and `git log --oneline -20` at session start.

## 6. Parallel-work enablers

- Mock server from the spec: `npx @stoplight/prism-cli mock contract/openapi.yaml -p 4010`.
- Real API: `http://13.53.165.254/api/v1` (HTTP until a domain/certificate exist). See `docs/INTEGRATION.md`.
- **Secrets policy:** nothing secret is committed. Demo accounts are created with `dotnet CampusConnect.Api.dll --seed` using `SEED_PASSWORD` from the server env; share that password privately. Accounts: `super@`, `cafeteria@`, `library@`, `labit@`, `academic@`, `student@`, `student2@` + `campusconnect.edu`.

## 7. Definition of done

- [ ] Spec merged first if the API surface changed
- [ ] Builds clean; analyzers/lint clean
- [ ] Tests incl. a forbidden-scope case (backend) / a 403 render (frontend)
- [ ] Works against the real API or the Prism mock
- [ ] `GET /api/v1/health` = 200 after deploy

## 8. Competition clock

Deployed by **3:00 PM**; **2:00 PM feature freeze**. See `docs/ROADMAP.md`.

## 9. Disputes

The owner decides; `main` stands until then.

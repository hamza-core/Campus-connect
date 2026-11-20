# Architecture & Decisions

Baseline (owner decision, issue #1): **ASP.NET Core 10 · EF Core · SQL Server on AWS · mobile app delivered as an APK.** The backend is implemented (PR #3); this doc describes the real system.

## System

```
 Android app (Flutter)             AWS eu-north-1
 ┌────────────────────┐  HTTP    ┌────────────────────────────────┐
 │ go_router, ChangeN.│─────────►│ Nginx :80 → Kestrel 127.0.0.1:5000 │──► RDS SQL Server
 │ JWT (memory+Keystore)│ WebSocket│  ASP.NET Core 10 API            │    (private; 1433 from EC2 SG only)
 │ sembast (photos)   │◄────────►│  /api/v1/*  +  /hubs/notifications │
 │ foreground service │  SignalR └────────────────────────────────┘
 │ + local notifications│
 └────────────────────┘
 APK distribution: GitHub Actions artifact → adb / Drive / Firebase App Distribution
```

## Decisions

| # | Decision | Why |
|---|---|---|
| 1 | Monorepo: `backend/`, `frontend/`, `contract/`, `docs/` | One history; contract shared by both agents |
| 2 | Contract-first OpenAPI (v1.2.1) + hub rules in `CONTRACT.md` | App built against a mock while the API finished; contract tests catch drift |
| 3 | ASP.NET Core minimal APIs + EF Core + SQL Server | Owner baseline; maps to RDS |
| 4 | EC2 + Nginx + RDS | Required AWS hosting; DB private |
| 5 | JWT bearer, 7 days; kept in Android Keystore | Simple for a native app; remembered login. Refresh-token flow deferred (must ship complete or not at all) |
| 6 | One scope function for all complaint queries | Provable RBAC; out-of-scope → 403 |
| 7 | Department derived from category on the server | Automatic routing; no client spoofing |
| 8 | `rowVersion` optimistic concurrency on status change | Two admins can't overwrite each other |
| 9 | Super admin read-only | Least privilege |
| 10 | Admins seeded; password from `SEED_PASSWORD` | Public repo, no committed secrets |
| 11 | Photos are uploaded to the API server's disk (`~/uploads`), scoped by role | S3 dropped to keep the setup simple; access = uploader or anyone allowed to see the attached complaint. Not backed up yet |
| 12 | **Hybrid freshness**: SignalR for the owning student, 10 s polling for lists/dashboards | Push to admins needs a backend event (planned); polling is robust and cheap at this scale |
| 13 | **Android system popups** via foreground service + local notifications | Delivers alerts while minimized without Firebase/FCM accounts; costs a persistent low-priority notification and OEM battery settings |
| 14 | Forwarded headers trusted only from `TRUSTED_PROXIES` | Correct per-client rate limiting behind Nginx |
| 15 | Flutter with plain `ChangeNotifier` controllers + repositories (remote/mock) | Small, testable, no extra state package; the mock repo powers tests and demo mode |
| 16 | CI builds the APK (analyze → test → build) | Mac toolchain was unreliable; every build is reproducible |

## Workflow

```
PENDING ──► IN_PROGRESS ──► RESOLVED   (terminal)
   │             └────────► REJECTED   (terminal, remark required)
   └─────────────────────► REJECTED
```
Only the owning department's `DEPT_ADMIN` transitions; `SUPER_ADMIN` and students never write.

## Data model

`Department(id, name, slug)` · `User(id, name, email, passwordHash, role, studentId?, departmentId?)` · `Complaint(id, ticket, authorId, departmentId, category, subIssue?, title, description, status, priority, location?, imageUrls[], anonymousToStaff, dueAt, resolvedAt?, version)` · `TimelineEntry` · `Support` (deferred) · `Feedback` · `Notification` · `TicketCounter(year)`. Indexes on `(DepartmentId, Status)`, `AuthorId`, `Category`, `CreatedAt`.

## Features beyond the PDF

(Implemented in app and backend: ticket numbers, audit timeline, priority + overdue flag, anonymous-to-staff, ratings, notifications, CSV export, recurring-issue analytics, status donut and trend charts, auto-refresh, remembered login.)

Ticket numbers (`CC-2026-0042`), audit timeline, priority + SLA overdue flag, anonymous-to-staff option, resolution rating, notifications (polling/SignalR), CSV export (formula-safe), recurring-issues analytics, trend chart, concurrency control. **Deferred:** "me too" support (#4), refresh tokens, email/SMS.

## Judge pitch (60 s)

"Contract-first: one OpenAPI spec between the app and an ASP.NET Core API on EC2/RDS. A complaint's department is derived from its category on the server, and every query passes one scope function, so a Library admin opening a Lab complaint gets a 403 — covered by integration tests. Status changes follow a state machine with optimistic concurrency and write a timeline entry and notification atomically. Dashboards are SQL aggregates scoped by role."

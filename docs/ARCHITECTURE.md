# Architecture & Decisions

Baseline (owner decision, issue #1): **ASP.NET Core 10 · EF Core · SQL Server on AWS · mobile app delivered as an APK.** The backend is implemented (PR #3); this doc describes the real system.

## System

```
 Mobile app (APK)                 AWS eu-north-1
 ┌──────────────┐  HTTP(S)   ┌──────────────────────────────┐
 │ Bearer token │───────────►│ Nginx :80/:443               │
 └──────┬───────┘            │   └► Kestrel 127.0.0.1:5000  │──► RDS SQL Server
        │                    │      ASP.NET Core 10 API     │    (private, 1433 from EC2 SG only)
        │ signed upload      └──────────────────────────────┘
        └──────────────────────────► Amazon S3 (images)  ◄── API presigns PUTs (instance role), verifies objects
```

## Decisions

| # | Decision | Why |
|---|---|---|
| 1 | Monorepo: `backend/`, `frontend/`, `contract/`, `docs/` | One history; shared contract |
| 2 | Contract-first (`contract/openapi.yaml` v1.1.0) | Frontend builds against a mock while the backend finishes; contract tests catch drift |
| 3 | ASP.NET Core minimal APIs + EF Core + SQL Server | Owner baseline; maps to RDS; typed, fast to ship |
| 4 | EC2 + Nginx + RDS | Required AWS hosting; Nginx terminates TLS; DB private |
| 5 | JWT bearer (7 days) | Simple for a native app; refresh-token flow is a later, all-or-nothing increment |
| 6 | One scope function for all complaint queries | Provable RBAC; out-of-scope → 403 |
| 7 | Department derived from category on the server | PDF §4.2 automatic routing; no client spoofing |
| 8 | `rowVersion` optimistic concurrency on status change | Two admins can't silently overwrite each other |
| 9 | SUPER_ADMIN read-only | Least privilege: only the owning department resolves complaints |
| 10 | Admins seeded; password from `SEED_PASSWORD` env | PDF needs no admin signup; repo is public, no committed secrets |
| 11 | **Amazon S3 presigned PUT**, URL allow-list per submitting user, HeadObject verification | No file bytes through the API; no arbitrary image URLs; credentials come from an EC2 instance role (no keys) |
| 12 | Notifications via REST polling (30 s); SignalR optional | REST is authoritative; real-time is a bonus |
| 13 | Forwarded headers trusted only from `TRUSTED_PROXIES` | Correct per-client rate limiting behind Nginx without allowing spoofing |

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

Ticket numbers (`CC-2026-0042`), audit timeline, priority + SLA overdue flag, anonymous-to-staff option, resolution rating, notifications (polling/SignalR), CSV export (formula-safe), recurring-issues analytics, trend chart, concurrency control. **Deferred:** "me too" support (#4), refresh tokens, email/SMS.

## Judge pitch (60 s)

"Contract-first: one OpenAPI spec between the app and an ASP.NET Core API on EC2/RDS. A complaint's department is derived from its category on the server, and every query passes one scope function, so a Library admin opening a Lab complaint gets a 403 — covered by integration tests. Status changes follow a state machine with optimistic concurrency and write a timeline entry and notification atomically. Dashboards are SQL aggregates scoped by role."

# AGENTS.md — Codex: backend

You are the **backend engineer** for **CampusConnect** (Smart Campus Complaint & Feedback Management System; competition app, deployed by 3:00 PM). Claude owns the frontend. The owner (human) is the integrator.

**Read first, every session:** `CONTRACT.md` → `contract/openapi.yaml` → `docs/DEPLOYMENT.md` → top of `docs/HANDOFF.md`. Requirements: `docs/CampusConnect_Competition_Problem_Statement.pdf`.

## Territory

- You edit **only `backend/**`** (and append to `docs/HANDOFF.md`). You are the single migration owner.
- You never edit `frontend/**` or `contract/**` directly. Any change to routes, DTOs, enums, error codes or required fields goes through a `contract/` PR first (CONTRACT.md §2). Implementation currently being merged: PR #3; its `backend/contracts/PR3_REVIEW.md` is absorbed in spec v1.1.0 — keep the two in sync.

## Stack (implemented)

ASP.NET Core (**.NET 10**, minimal APIs) · **EF Core 10 + SQL Server** · JWT bearer (`sub`, `role`; HS256, 7 days) · bcrypt · rate limiting on `/auth/*` · optional SignalR hub `/hubs/notifications` · Cloudinary signed uploads · xUnit integration tests (SQL Server) + OpenAPI contract tests.
Hosting: **AWS EC2 (Ubuntu) + Nginx → Kestrel on `127.0.0.1`**, **RDS for SQL Server**. See `docs/DEPLOYMENT.md`.

## Configuration (env vars; never commit values)

`ConnectionStrings__DefaultConnection` (required — no fallback) · `JWT_SECRET` (≥32 bytes) · `ASPNETCORE_URLS` · `ASPNETCORE_ENVIRONMENT` · `CORS_ORIGINS` (explicit origins; only matters for a web client) · `TRUSTED_PROXIES` (default `127.0.0.1,::1`) · `CLOUDINARY_CLOUD_NAME|API_KEY|API_SECRET` · `SEED_PASSWORD` (only with `--seed`) · `Auth__PermitLimit` (default 20/min).
CLI flags: `--migrate` (apply migrations), `--seed` (demo data; requires `SEED_PASSWORD`).

## Non-negotiables (graded)

1. **Server-side authorization** through the single scope helper: STUDENT → own; DEPT_ADMIN → own department; SUPER_ADMIN → all, **read-only**. Out-of-scope → **403**, no data. Department comes from `category`, never from the client.
2. **State machine** PENDING→IN_PROGRESS|REJECTED; IN_PROGRESS→RESOLVED|REJECTED; terminal after; remark required for RESOLVED/REJECTED; illegal → 409 `INVALID_TRANSITION`.
3. **Optimistic concurrency:** `rowVersion` required on status change (missing → 422, stale → 409).
4. Status change + timeline + notification in **one transaction**.
5. Errors use the contract envelope and codes (incl. `RATE_LIMITED`); never leak stack traces or EF/SQL exceptions; login failure message stays generic.
6. No secrets or default passwords in the repo or the code; seed password only from env.
7. Behind Nginx, only trusted proxies may set forwarded headers.

## Tests (must stay green; CI runs them on a SQL Server container)

Keep and extend: forbidden-scope cases (library admin ↔ lab complaint by id and on status PATCH; student ↔ other student's complaint; student on admin routes; SUPER_ADMIN on PATCH/comments), routing for all four categories, every legal/illegal transition, stale rowVersion, validation → 422, upload URL policy, rate limit per client IP, health 503 when DB down, contract test (every documented route exists; responses match schema).

## Open items (from the PR #3 review, owner-tracked)

- Tab/CR prefixes in CSV cells; self-notification on a user's own reply; ticket-counter first-of-year race — verify closed in `backend/PROGRESS.md`.
- JWT lifetime: keep 7 days until a refresh-token increment is designed with the client (single-flight refresh, rotation, replay revocation) — do not shorten it alone.
- Support endpoints deferred (#4): keep returning 403 or remove with their tests, then update the spec in a `contract/` PR.

## Workflow

Branch `be/<feature>`; commits `feat(be): …` / `fix(be): …`; one-side-only PRs. After each milestone append to `docs/HANDOFF.md`: what's live, new env vars, migration notes. Keep schema changes backward-compatible (migrations are not rolled back with the app).

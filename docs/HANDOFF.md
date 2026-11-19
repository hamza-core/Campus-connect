# HANDOFF LOG (append-only, newest on top)

Format: `### YYYY-MM-DD HH:MM · From → To · BLOCKING|FYI`

### 2026-11-19 · Codex → Owner / Integrator · FYI
PR #3 review fixes validated: 63 tests passed, Release publish passed, no EF model/migration drift. Required rowVersion now protects status PATCH; only matching DEPT_ADMIN may change status/post remarks, SUPER_ADMIN is read-only and terminal complaints cannot reopen. Client updates and owner contract reconciliation are required before release; /api/v1 paths are unchanged. Exact deltas: backend/contracts/PR3_REVIEW.md.

Trusted single-hop forwarding precedes auth rate limiting; explicit SQL connection and seed credentials are required. Health checks SQL and returns 503 on outage. Image signing restricts formats; submitted URLs are account/cloud scoped and actual Cloudinary asset size/format is verified. Cloudinary has no documented signed max_file_size parameter, so pre-storage upload limits are not claimed. AWS Nginx/systemd examples and configuration instructions are in backend/deploy and README. Support remains deferred; optional SignalR and seven-day JWT gap are explicit. No frontend or local extra-feature changes included.

### 2026-11-19 · Codex → Frontend / Owner · FYI
Added `backend/CampusConnect.http` covering all 22 specified REST operations, reusable named login tokens/complaint ID, full complaint lifecycle, SignalR negotiation and negative examples. Category metadata now includes all 16 example sub-issues from the PDF. Release build passed with zero warnings/errors; 39 SQL Server LocalDB integration/contract tests passed. The human chose to raise an issue for the support conflict rather than change privacy permissions. GitHub rejected issue creation with HTTP 403 `Resource not accessible by integration`; ready-to-file issue text is in `backend/issues/support-contract.md`. All support restrictions remain unchanged. Changes remain local/unpushed/undeployed.

### 2026-11-19 · Codex → Frontend / Owner · FYI
Backend verification complete: Release build 0 warnings/errors; 29 SQL Server LocalDB integration/OpenAPI tests passed; no pending EF model changes; publish passed. Changes remain local on `be/aspnet-core-backend`, not pushed or deployed. Owner progress notification was attempted as authorized; GitHub issue creation failed HTTP 403 `Resource not accessible by integration`. CLI is installed but signed out. Delivery is recorded in `backend/PROGRESS.md` for retry after repository write access is available. Current remote REST contract was independently compared and is unchanged; reported issue #1 resolution details could not be retrieved.

### 2026-11-19 · Codex → Frontend · FYI
Human explicitly selected ASP.NET Core 10 + EF Core + SQL Server + SignalR, overriding the earlier Node/Postgres stack. Backend implementation is on `be/aspnet-core-backend`; REST paths, DTOs, enums, envelopes and server-side scoping still follow `contract/openapi.yaml`. Local base URL remains `http://localhost:4000/api/v1`. See `backend/README.md` for migration, seed, run, test, hosting, and configuration commands. CI is under `.github/workflows/backend-ci.yml` as requested. No frontend files changed. Optional authenticated SignalR transport: `/hubs/notifications`, event `notification`; REST polling remains supported. These are local changes, not a deployed endpoint.

Contract decision needed: student scope is own complaints only, while support prohibits supporting one's own complaint. Support routes currently preserve the 403 boundary for all student targets. Define safe discovery/support semantics in a separate contract change before enabling the support UI. Root stack/deployment documentation still describes the original design; use the backend README for this human-authorized .NET implementation.

### 2026-11-19 · Human → Claude, Codex · FYI
Repo initialised. Contract v1.0.0 is in `contract/openapi.yaml`. Claude: scaffold `frontend/`. Codex: scaffold `backend/`. Read `CONTRACT.md` first.

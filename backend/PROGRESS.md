# PR #3 review fixes — local validation

Implemented on isolated branch be/pr3-fixes from PR head 52b590c. The shared be/extra-features checkout is untouched.

- Locked restore: passed.
- Release compilation with warnings treated as errors: passed.
- Full SQL Server LocalDB unit/integration/OpenAPI suite: 63 passed, 0 failed (TestResults/pr3-review.trx).
- EF model/migration check: no pending model changes; no new schema migration required.
- Release publish: passed.
- GitHub CI and deployment are separate checks; no production smoke-test claim is made here.

Resolved review changes: trusted single-hop forwarded headers before rate limiting; required database configuration; required rowVersion with stale-write rejection; external seed password and explicit rotation; account-scoped Cloudinary URL and real-resource verification; no self-notification; RATE_LIMITED; database readiness; one ticket-race retry; CSV control-character neutralization; read-only SuperAdmin/department-only remarks; JWT gap documented. SDK latestFeature roll-forward was already present.

Cloudinary's documented API has no signed max_file_size parameter. Format restrictions are signed, declared oversize uploads are rejected, and real asset bytes/format are verified before attachment. A strict cap before Cloudinary stores a direct upload is not implemented or claimed; see README's provider references.

Canonical contract revision remains integrator-owned; required deltas are in contracts/PR3_REVIEW.md. Support stays deferred/denied, SignalR optional, Cloudinary retained. No frontend/views or optional extra-feature code is included.

---

## Earlier baseline record

# Validated backend milestone — 2026-11-19

## HTTP collection and endpoint coverage

Added `CampusConnect.http` with all 22 OpenAPI operations, named token/ID reuse, a full complaint lifecycle, CSV, upload signing, SignalR negotiation, and negative authorization/validation examples. All specified REST routes are implemented; support remains intentionally denied under the unchanged privacy policy. Metadata now lists all 16 sub-issue examples from the competition PDF.

Latest Release build: zero warnings/errors. Latest SQL Server LocalDB integration/OpenAPI suite: **39 passed, 0 failed**. New checks cover Cloudinary signature correctness using fake credentials, upload role/format/configuration errors, CSV filters and formula escaping, rejection/reopening permissions, both support methods, notification read-all isolation, and HTTP collection coverage against OpenAPI.

The human requested a support-contract issue. GitHub issue creation was attempted and rejected with HTTP 403 `Resource not accessible by integration`; CLI is still unauthenticated. No remote issue was created. The issue draft and filing command are saved at `issues/support-contract.md`.

The owner notification for this HTTP/endpoint milestone was also attempted separately and rejected with the same HTTP 403. No progress notification was delivered. Final EF migration-drift check passed with no pending changes.

## Earlier baseline verification

Branch: `be/aspnet-core-backend`. Local implementation; not committed, pushed, deployed, or run on GitHub Actions yet.

- ASP.NET Core / EF Core / SQL Server backend with authenticated SignalR notifications.
- Mandatory auth, complaints, automatic routing, server-side scope and status lifecycle implemented; analytics, timeline, notifications, feedback, CSV and upload signing included.
- `dotnet restore CampusConnect.sln --locked-mode`: passed.
- Release build: passed, zero warnings and errors.
- SQL Server LocalDB integration + OpenAPI contract tests: **29 passed, 0 failed**.
- EF model/migration drift check: passed, no pending changes.
- Release publish: passed.
- Current remote `CONTRACT.md`, `contract/openapi.yaml`, and `docs/ARCHITECTURE.md` were compared with local files and were unchanged. Remote `AGENTS.md` still specifies the older Node stack; the explicit human stack instruction takes precedence.
- Issue #1 resolution details could not be read due an API timeout; no resolution decisions were inferred.

Remaining limitation: the support feature's contradictory authorization requirements are documented in `README.md`; security scope remains enforced.

## Owner notification delivery

One progress issue creation was attempted through the connected GitHub integration, mentioning `@hamza-core` and reporting the actual validation above. GitHub rejected it with HTTP 403: **Resource not accessible by integration**. No issue or notification was created. GitHub CLI 2.105.0 is installed, but `gh auth status` reports no signed-in hosts. Retry the notification after an authorized connection has repository issue-write access. There is no existing notification to duplicate.

# CampusConnect

Smart Campus Complaint & Feedback Management System — BIIT Software Engineering Society Application Development Competition.

Students report problems with campus services (Cafeteria, Library, Labs & IT, Teaching & Academic). Each complaint is **routed automatically** to the responsible department, department admins respond and update its status, students follow progress and get **live notifications**, and the Super Admin monitors everything with dashboards and charts.

## What's in the box

| Part | Technology | Where |
|---|---|---|
| **Android app** | Flutter 3.47 / Dart 3.13 | `frontend/` |
| **API** | ASP.NET Core 10, EF Core, SQL Server, JWT, SignalR | `backend/` |
| **Database** | SQL Server Express on AWS RDS | eu-north-1 |
| **Hosting** | AWS EC2 (Ubuntu) + Nginx → Kestrel, systemd service `api` | `http://13.53.165.254/api/v1` |
| **API contract** | OpenAPI 3.1 (`contract/openapi.yaml`, v1.2.1) | `contract/` |

## Roles

- **Student** — register, log in, submit complaints, follow status and department replies, rate resolved complaints, receive live notifications.
- **Department admin** (Cafeteria, Library, Lab/IT, Academic) — sees **only their department's** complaints (current and history), starts work, resolves or rejects with a reason, posts remarks, sees department analytics.
- **Super admin** — sees every complaint, searches/filters, and gets the global dashboard and charts. **Read-only.**

Authorization is enforced **on the server** (a Library admin opening a Lab/IT complaint gets `403`); the app only mirrors it for UX.

## Feature summary

Registration & login (remembered securely) · category-based submission with sub-issue, priority, location, anonymous-to-staff option · automatic department routing · status workflow with remarks and optimistic concurrency · ticket numbers and audit timeline · overdue/SLA flags · ratings after resolution · realtime notifications (SignalR) with Android system popups while the app is minimized · auto-refreshing lists and dashboards · charts (by department, by status, 14-day trend, recurring issues) and KPI cards · priority/overdue/category/department filters and search · CSV export · photos kept on the device.

Full requirement-by-requirement status: [`docs/REQUIREMENTS_COVERAGE.md`](docs/REQUIREMENTS_COVERAGE.md).

## Repository layout

| Path | What |
|---|---|
| `frontend/` | Flutter app (see `frontend/README.md`) |
| `backend/` | API, EF Core migrations, tests, deploy examples (see `backend/README.md`) |
| `contract/openapi.yaml` | API source of truth |
| `CONTRACT.md` | Working agreement + wire conventions (incl. realtime) |
| `CLAUDE.md` / `AGENTS.md` | Instructions for the frontend / backend agent |
| `docs/` | Requirements PDF, architecture, integration guide, deployment, coverage matrix, roadmap, handoff log, changelog |
| `.github/workflows/` | `backend-ci.yml` (build + tests on SQL Server), `frontend-apk.yml` (analyze, test, build APK) |

## Quick start

```bash
# API (needs SQL Server and the env vars in backend/.env.example)
cd backend && dotnet run --project src/CampusConnect.Api          # http://localhost:4000

# App against the live server
cd frontend && flutter pub get
flutter run --dart-define=API_BASE_URL=http://13.53.165.254/api/v1

# App with built-in demo data (no server)
flutter run --dart-define=USE_MOCK=true
```

Start here: connecting the app → [`docs/INTEGRATION.md`](docs/INTEGRATION.md) · architecture & decisions → [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) · servers, keys, APK builds → [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) · rules between the two agents → [`CONTRACT.md`](CONTRACT.md).

No secrets are committed. Demo accounts (`super@`, `cafeteria@`, `library@`, `labit@`, `academic@`, `student@`, `student2@` + `campusconnect.edu`) are created with `--seed` using `SEED_PASSWORD` from the server environment; the password is shared privately.

# CampusConnect

Smart Campus Complaint & Feedback Management System — BIIT Software Engineering Society Application Development Competition.

Students report issues (Cafeteria, Library, Labs & IT, Teaching & Academic); complaints auto-route to the responsible department; department admins respond; the Super Admin monitors everything with dashboards and charts.

## Stack
**ASP.NET Core (.NET 10) · EF Core · SQL Server** on **AWS** (EC2 + Nginx, RDS) · mobile app distributed as an APK (Firebase App Distribution or Google Drive).

## Repo layout

| Path | Owner | What |
|---|---|---|
| `backend/` | Codex | API, migrations, tests, deploy examples |
| `frontend/` | Claude | The app |
| `contract/openapi.yaml` | owner | API source of truth (v1.1.0) |
| `CONTRACT.md`, `CLAUDE.md`, `AGENTS.md` | owner | Working agreement and per-agent instructions |
| `docs/` | owner | Requirements PDF, architecture, **integration guide**, **deployment & setup checklist**, roadmap, handoff log |

## Start here
- Connecting the app to the API → `docs/INTEGRATION.md`
- Keys, env vars, AWS and APK steps → `docs/DEPLOYMENT.md`
- Rules between the two agents → `CONTRACT.md`

No secrets are committed. Demo accounts are created with `--seed` using `SEED_PASSWORD` from the server environment.

# Requirements coverage

Source: `docs/CampusConnect_Competition_Problem_Statement.pdf`. Status as of the latest build (app commit tagged `demo-v3-notifications` and later; backend = `main`).

## Required by the brief

| # | Requirement | Status | Where |
|---|---|---|---|
| 1 | Student registration and login | Done | `POST /auth/register`, `/auth/login`; auth screens |
| 2 | Complaint submission through predefined categories (Cafeteria, Library, Labs & IT, Teaching & Academic) with details and optional images | Done — images stay on the device | Submit flow; category cards; brief's example issues as choices |
| 3 | Automatic assignment to the relevant department | Done — decided **on the server** from the category | `ComplaintService.Create`; the form shows "This will be sent to …" |
| 4 | Role-based access (Student / Department admin / Super admin), **enforced server-side** | Done | One scope function for every complaint query; `403` on out-of-scope access (covered by backend tests and the live check "Library admin → Lab complaint = 403") |
| 5 | Students see only their own complaints, status, and department remarks | Done | Student lists/detail/timeline/reply blocks |
| 6 | Department admin: view own department, review, update status, respond, resolve/reject with reason, current **and** past complaints | Done | Department inbox (Current / History), detail actions, remark box |
| 7 | Super admin: all complaints, search, filter by category/department/status, pending/in-progress/resolved/rejected views, analytics | Done (read-only) | All-complaints list + filters, dashboards |
| 8 | Database integration | Done | SQL Server (RDS), EF Core migrations |
| 9 | Admin dashboard with totals and per-status counts | Done | KPI cards (+ overdue, averages) |
| 10 | Graphical reports — **bar chart comparing departments** | Done (super admin) | Department bar chart; also status donut, 14-day trend, recurring issues |
| 11 | Deployed, reachable by judges | Done | `http://13.53.165.254/api/v1` (API) + APK |

## Backend capabilities and the app

| Backend feature | In the app |
|---|---|
| Sub-issue, priority, location, anonymous-to-staff on create | Submit form |
| Ticket number, timeline, remarks | Detail screen |
| Overdue flag + due date | Badge, details card, dashboard card, "Overdue only" filter |
| Optimistic concurrency (`rowVersion`) | Status updates; `409` reloads |
| Feedback (rating 1–5, once, resolved only) | Rating card; admins see it |
| Notifications (REST + SignalR hub) | Bell/badge/list, in-app banner, Android system popups |
| Analytics: summary, by-department, by-status, trend, recurring | Dashboards |
| CSV export (admins) | Share-sheet export |
| Student ID on registration | Sign-up field |
| "Me too" support | **Not built** — the backend denies it by design (issue #4) |
| Image upload | **Removed** — no storage provider; photos stay on the device |

## Beyond the brief
Live notifications and popups while minimized · auto-refreshing screens · remembered login · floating navigation, hero headers and consistent styling · CSV export · quiet background refresh · backups/tags for rollback.

## Known limitations
- Plain HTTP (no domain/certificate yet); the EC2 public IP changes on restart unless an Elastic IP is attached.
- New complaints reach admins within ~10 s (polling); only the owning student gets instant SignalR events.
- Photos are visible only on the phone that took them.
- JWT lifetime is 7 days with no refresh/revocation flow.
- App id is still `com.example.project`; each CI build uses a temporary signing key.

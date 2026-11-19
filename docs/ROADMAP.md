# Roadmap (to the 3:00 PM deadline)

| Stage | Backend (Codex) | Frontend (Claude) | Owner |
|---|---|---|---|
| Now | Merge PR #3 once CI is green; close open review items | Integrate per `docs/INTEGRATION.md`; build against Prism/real API | Deploy build to EC2 (`docs/DEPLOYMENT.md` §C); Elastic IP; Cloudinary keys |
| Next | Support decision (#4); spec/code sync | MVP screens: auth, submit, lists, detail, dept actions, dashboards | Merge contract PR #2 (v1.1.0) |
| Then | Refresh-token increment only if time (all-or-nothing) | Charts, notifications, rating, CSV | Domain + HTTPS (certbot), APK build |
| **2:00 PM** | **Feature freeze** — bug fixes only | same | Smoke test every role from the installed APK |
| 2:45–3:00 | — | — | Submit API URL + APK link |

Cut order if behind: CSV → trend → recurring → rating → notifications. Never cut: auth, submit, auto-routing, 403 isolation, status updates, bar chart, deployment.

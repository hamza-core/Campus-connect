# Deployment & setup checklist (AWS)

Region **eu-north-1**. EC2 `api-server` (t3.micro, Ubuntu) + Nginx → Kestrel; RDS SQL Server Express `campusconnectv1`.

## A. What YOU must set (keys, connections, accounts)

| # | Item | Where it goes | Notes |
|---|---|---|---|
| 1 | **RDS connection string** | `/etc/api.env` → `ConnectionStrings__DefaultConnection` | `Server=campusconnectv1.chmciaeskuj8.eu-north-1.rds.amazonaws.com,1433;Database=CampusConnect;User Id=admin;Password='<RDS password>';Encrypt=True;TrustServerCertificate=True`. Quote the password if it contains `;` or `=`. The exact key name matters (not `…__Default`) |
| 2 | **JWT secret** | `/etc/api.env` → `JWT_SECRET` | `openssl rand -base64 48`. ≥ 32 bytes. Changing it logs everyone out. Never reuse a dev value |
| 3 | **Listen address** | `ASPNETCORE_URLS=http://localhost:5000` and Nginx `proxy_pass http://127.0.0.1:5000` | Must match |
| 4 | **Environment** | `ASPNETCORE_ENVIRONMENT=Production` | |
| 5 | **Trusted proxy** | `TRUSTED_PROXIES` (optional) | Default `127.0.0.1,::1` is correct when Nginx is on the same host. Without it all clients share one rate-limit bucket |
| 7 | **Demo seed password** | `SEED_PASSWORD` (only when you run `--seed`) | 8–72 chars. Share privately with judges/teammates. Remove from the env file afterwards |
| 8 | **CORS** (only if you add a web build) | `CORS_ORIGINS=https://your-web-origin` | Explicit origins, no `*`. Native apps don't need it |
| 9 | **Rate limit** (optional) | `Auth__PermitLimit=60` | Default 20/min per client IP; raise for a demo on shared Wi-Fi |
| 10 | **Elastic IP** | AWS console → EC2 → Elastic IPs → Associate with `api-server` | Otherwise the public IP changes on stop/start and the app's base URL breaks |
| 11 | **Security groups** | `launch-wizard-1`: 22 (your IP / temporary 0.0.0.0/0), 80, 443 · `db-sg`: 1433 from `launch-wizard-1` only | RDS must stay non-public |
| 12 | **Domain + HTTPS** (needed for a release APK without cleartext) | Route 53/any DNS A record → Elastic IP; `sudo certbot --nginx -d api.<domain>` | Optional for a demo if the app allows cleartext |
| 13 | **Firebase/Drive for the APK** | Firebase console → App Distribution (package name must match the app id) or a Drive link ("Anyone with the link") | |
| 14 | **GitHub Actions secrets** (later) | Repo → Settings → Secrets: `EC2_HOST`, `EC2_USER`, `EC2_SSH_KEY` (a dedicated deploy key), `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION=eu-north-1`, `SG_ID` | Needs repo admin; IAM user limited to authorize/revoke ingress on the SG |
| 15 | **Cost safety** | Delete the unused Aurora cluster `database-1` if nothing needs it; set an AWS Budget alert | |

Never commit any of the above. The env file is `chmod 600`, owned by root.

## B. Server env file template (`/etc/api.env`)

```
ASPNETCORE_ENVIRONMENT=Production
ASPNETCORE_URLS=http://localhost:5000
ConnectionStrings__DefaultConnection=Server=<rds-endpoint>,1433;Database=CampusConnect;User Id=admin;Password='<PASSWORD>';Encrypt=True;TrustServerCertificate=True
JWT_SECRET=<48 random bytes, base64>
# only while seeding:
# SEED_PASSWORD=
```

## C. Deploy (manual)

1. **Build:** easiest is the CI artifact — every push/PR touching `backend/` runs `backend-ci.yml`, which publishes `backend-api` (`gh run download <run-id> -n backend-api`). Locally: `cd backend && dotnet publish src/CampusConnect.Api -c Release -r linux-x64 --self-contained false -o publish` (SDK 10.0.x).
2. **Mac:** `ssh … "mkdir -p ~/api"` then `scp -r publish/* ubuntu@<ip>:~/api/`.
3. **Server:** `/etc/api.env` as in §B (`sudo chmod 600`).
4. **Server (first time / after schema changes):**
   ```
   # Run through systemd so /etc/api.env is parsed correctly (sourcing it in a shell breaks on the
   # semicolons/spaces in the connection string).
   sudo systemd-run --wait --pipe -q -p EnvironmentFile=/etc/api.env -p WorkingDirectory=/home/ubuntu/api -p User=ubuntu \
     /usr/bin/dotnet /home/ubuntu/api/CampusConnect.Api.dll --migrate          # creates DB CampusConnect + applies migrations
   # Demo data (departments + 7 accounts + ~40 complaints). Departments are REQUIRED for /meta/categories:
   sudo systemd-run --wait --pipe -q -p EnvironmentFile=/etc/api.env -p WorkingDirectory=/home/ubuntu/api -p User=ubuntu \
     --setenv=SEED_PASSWORD='<password>' /usr/bin/dotnet /home/ubuntu/api/CampusConnect.Api.dll --seed
   ```
5. **Server:** `/etc/systemd/system/api.service` (`User=ubuntu`, `WorkingDirectory=/home/ubuntu/api`, `EnvironmentFile=/etc/api.env`, `ExecStart=/usr/bin/dotnet /home/ubuntu/api/CampusConnect.Api.dll`, `Restart=always`) → `sudo systemctl daemon-reload && sudo systemctl enable --now api`. Logs: `journalctl -u api -n 50 --no-pager`. Examples: `backend/deploy/`.
6. **Server:** Nginx default site on port 80 → `http://127.0.0.1:5000` with `proxy_http_version 1.1`, headers `Host $host`, `X-Forwarded-For $remote_addr`, `X-Forwarded-Proto $scheme`, and **WebSocket upgrade** (`map $http_upgrade $connection_upgrade { default upgrade; "" close; }` + `proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection $connection_upgrade;`, `proxy_read_timeout 120s`) — required for SignalR; `sudo nginx -t && sudo systemctl reload nginx`. See `backend/deploy/nginx.conf.example`.
7. **Verify:** `curl http://<ip>/api/v1/health` → `{"status":"ok"}`; `curl http://<ip>/api/v1/meta/categories`; SignalR: `curl -X POST "http://<ip>/hubs/notifications/negotiate?negotiateVersion=1" -H "Authorization: Bearer <token>"` → 200 with `WebSockets` available (no token → 401).
8. **Update later:** repeat 1–2, then `sudo systemctl restart api` (run `--migrate` first if the PR has a new migration; keep migrations backward-compatible).

## C1. Resetting the demo data (destructive)

`--reset-demo` deletes **every complaint** (with its timeline, feedback, support and notifications) and re-creates ~44 realistic ones across the four departments. User accounts are kept; the demo logins get real display names and four extra student accounts are added (they use `SEED_PASSWORD`). It refuses to run without an explicit confirmation:

```
sudo systemd-run --wait --pipe -q -p EnvironmentFile=/etc/api.env -p WorkingDirectory=/home/ubuntu/api -p User=ubuntu \
  --setenv=SEED_PASSWORD='<password>' --setenv=CONFIRM_RESET=delete-all-complaints \
  /usr/bin/dotnet /home/ubuntu/api/CampusConnect.Api.dll --reset-demo
```

Take a backup first (CSV export from the super admin account, and `tar czf ~/backup-uploads.tgz ~/uploads`), then clear `~/uploads` by hand if you also want the old photos gone.

## C2. CI/CD pipelines (GitHub Actions)

| Workflow | Runs on | What it does |
|---|---|---|
| `backend-ci.yml` (CI) | every push/PR touching `backend/` or `contract/` | restore (locked) → build → EF model check → all tests against SQL Server 2022 → publish artifact `backend-api` |
| `backend-cd.yml` (CD) | after Backend CI succeeds on `main`, or manually | publish for linux-x64 → copy to the server → `backend/deploy/deploy.sh` (apply migrations, swap, restart, health check, **automatic rollback** if unhealthy) |
| `frontend-apk.yml` (CI + CD) | every push/PR touching `frontend/` | `flutter analyze` → `flutter test` → release APK artifact `campusconnect-apk`; on `main` it also publishes the APK as the rolling GitHub Release **`latest`** |

**Turning on automatic deploys** (one time, needs repo admin): Settings → Secrets and variables → Actions:

- `EC2_HOST` (the server address), `EC2_USER` (`ubuntu`), `EC2_SSH_KEY` (a **dedicated deploy key**, not your personal key) — required.
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` (`eu-north-1`), `SG_ID` — optional but recommended: the pipeline then opens port 22 for the runner's single IP and closes it again, so SSH never has to stay open to the world. Use an IAM user that may only authorize/revoke ingress on that one security group.

Until the required secrets exist the CD job is skipped with a notice; it never turns the pipeline red. Run it by hand from the Actions tab (*Backend CD → Run workflow*) or locally: copy the build to `~/api-new` on the server and run `ssh <server> 'bash -s' < backend/deploy/deploy.sh`.

## D. The Android app (APK)

- **Build:** GitHub Actions `frontend-apk.yml` runs on pushes to `fe/**` and PRs touching `frontend/`: `flutter analyze` → `flutter test` → `flutter build apk --release --dart-define=API_BASE_URL=http://13.53.165.254/api/v1` → artifact **`campusconnect-apk`** (`gh run download <run-id> -n campusconnect-apk`). Flutter 3.47.9, JDK 17, Android compileSdk 37. The workflow's `API_BASE_URL` env must be updated when the server address or scheme changes.
- **Install on a phone:** `adb install -r app-release.apk` (wireless debugging works) or copy the file and allow *Install unknown apps*.
- **Signing:** CI uses a temporary debug key, so each build has a different signature. Switching builds requires `adb uninstall com.example.project` first (this clears the app's local photos). For a stable key, add a release keystore as a repository secret before a store release; change the application id (`com.example.project`) at the same time.
- **Distribute (pick one):** Firebase App Distribution (`firebase appdistribution:distribute app-release.apk --app <APP_ID> --testers "a@x.com"`) or Google Drive link ("Anyone with the link").
- **Permissions:** the app asks for notifications on the first student sign-in. For popups while minimized on Samsung/Xiaomi/etc. set *Settings → Apps → CampusConnect → Battery → Unrestricted*. The foreground service shows one quiet "Listening for complaint updates" notification.
- Give judges: the APK link, the API URL (`/api/v1/health`), and the demo accounts (privately).

## Live server layout (as deployed)

| Item | Value |
|---|---|
| Host | EC2 `api-server`, `13.53.165.254` (no Elastic IP yet), user `ubuntu` |
| App files | `/home/ubuntu/api` (publish output) |
| Service | `api.service` (systemd, `EnvironmentFile=/etc/api.env`, `Restart=always`) — logs: `journalctl -u api -n 50 --no-pager` |
| Nginx | `/etc/nginx/sites-available/default` (backup: `~/nginx-default.stable`) |
| Known-good backup | `~/api-stable` (+ `~/api-stable.env.bak`) |
| Database | RDS `campusconnectv1` (SQL Server Express), database `CampusConnect` |

**Roll back the API:** `sudo systemctl stop api && rm -rf ~/api && cp -r ~/api-stable ~/api && sudo systemctl start api`.
**Roll back the app:** reinstall an earlier APK (uninstall first). Git tags `demo-stable-app`, `demo-ui-v2`, `demo-v3-notifications` (app) and `demo-stable-backend` (API) mark known-good commits.

## E. Pre-demo checklist

- [ ] `/api/v1/health` = 200 from outside the VPC
- [ ] Elastic IP attached; app points to it
- [ ] 7 seeded accounts log in; Library admin → Lab complaint = 403
- [ ] RDS and EC2 running; billing alarm set
- [ ] SSH rule narrowed back to your IP

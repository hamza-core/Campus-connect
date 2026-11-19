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
| 6 | **Cloudinary** (image upload) | `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET` | Free account at cloudinary.com → Dashboard. Without them `/uploads/sign` returns 500; everything else works |
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
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=
# only while seeding:
# SEED_PASSWORD=
```

## C. Deploy (manual)

1. **Mac:** `cd backend && dotnet publish src/CampusConnect.Api -c Release -r linux-x64 --self-contained false -o publish` (SDK 10 required; `global.json` allows later 10.0.x).
2. **Mac:** `ssh … "mkdir -p ~/api"` then `scp -r publish/* ubuntu@<ip>:~/api/`.
3. **Server:** `/etc/api.env` as in §B (`sudo chmod 600`).
4. **Server (first time / after schema changes):**
   ```
   cd ~/api
   set -a; sudo cat /etc/api.env > /tmp/e; . /tmp/e; set +a; rm /tmp/e
   dotnet CampusConnect.Api.dll --migrate        # creates DB CampusConnect + applies migrations
   SEED_PASSWORD='…' dotnet CampusConnect.Api.dll --migrate --seed   # optional demo data
   ```
5. **Server:** `/etc/systemd/system/api.service` (`User=ubuntu`, `WorkingDirectory=/home/ubuntu/api`, `EnvironmentFile=/etc/api.env`, `ExecStart=/usr/bin/dotnet /home/ubuntu/api/CampusConnect.Api.dll`, `Restart=always`) → `sudo systemctl daemon-reload && sudo systemctl enable --now api`. Logs: `journalctl -u api -n 50 --no-pager`. Examples: `backend/deploy/`.
6. **Server:** Nginx site on port 80 → `http://127.0.0.1:5000` with headers `Host $host`, `X-Forwarded-For $remote_addr`, `X-Forwarded-Proto $scheme`, `client_max_body_size 6m`, WebSocket upgrade lines for SignalR; `sudo nginx -t && sudo systemctl restart nginx`.
7. **Verify:** `curl http://<ip>/api/v1/health` → `{"status":"ok"}`; `curl http://<ip>/api/v1/meta/categories`.
8. **Update later:** repeat 1–2, then `sudo systemctl restart api` (run `--migrate` first if the PR has a new migration; keep migrations backward-compatible).

## D. APK distribution

- Build the app with the production API base URL (see `docs/INTEGRATION.md` §1).
- **Firebase App Distribution:** console upload or `firebase appdistribution:distribute app-release.apk --app <APP_ID> --testers "a@x.com" --release-notes "…"`.
- **Google Drive:** upload, share "Anyone with the link"; testers allow *Install unknown apps*.
- Give judges: the APK link, the API URL (`/api/v1/health`), and the demo accounts (privately).

## E. Pre-demo checklist

- [ ] `/api/v1/health` = 200 from outside the VPC
- [ ] Elastic IP attached; app points to it
- [ ] 7 seeded accounts log in; Library admin → Lab complaint = 403
- [ ] RDS and EC2 running; billing alarm set
- [ ] SSH rule narrowed back to your IP

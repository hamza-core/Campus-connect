#!/usr/bin/env bash
# Prepares a FRESH Ubuntu 26.04 LTS EC2 instance to run the CampusConnect API.
# Run it on the server as the default `ubuntu` user:   bash bootstrap-ec2.sh
#
# It installs the .NET runtime and Nginx, writes the Nginx site (port 80 -> Kestrel on
# 127.0.0.1:5000, WebSocket upgrade for SignalR, 6 MB uploads), creates the `api` systemd
# service, and drops a settings template at /etc/api.env. It does NOT start the API: there is
# no build yet. Follow docs/AWS_REBUILD.md for the remaining steps.
# NOTE: written from the live server's configuration; not yet run on a brand-new instance.
set -euo pipefail

sudo apt-get update
sudo apt-get install -y aspnetcore-runtime-10.0 nginx

mkdir -p "$HOME/api" "$HOME/uploads"

sudo tee /etc/nginx/sites-available/default >/dev/null <<'NGINX'
map $http_upgrade $connection_upgrade { default upgrade; "" close; }
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    client_max_body_size 6m;
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $remote_addr;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_read_timeout 120s;
    }
}
NGINX
sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl reload nginx

sudo tee /etc/systemd/system/api.service >/dev/null <<'UNIT'
[Unit]
Description=CampusConnect API
After=network-online.target
Wants=network-online.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/api
EnvironmentFile=/etc/api.env
ExecStart=/usr/bin/dotnet /home/ubuntu/api/CampusConnect.Api.dll
Restart=always
RestartSec=5
NoNewPrivileges=true

[Install]
WantedBy=multi-user.target
UNIT

if [ ! -f /etc/api.env ]; then
  sudo install -m 600 -o root -g root /dev/null /etc/api.env
  sudo tee /etc/api.env >/dev/null <<'ENV'
ASPNETCORE_ENVIRONMENT=Production
ASPNETCORE_URLS=http://localhost:5000
ConnectionStrings__DefaultConnection=Server=<RDS-ENDPOINT>,1433;Database=CampusConnect;User Id=admin;Password='<RDS-PASSWORD>';Encrypt=True;TrustServerCertificate=True
JWT_SECRET=<output of: openssl rand -base64 48>
UPLOADS_DIR=/home/ubuntu/uploads
LLM_API_KEY=<Groq API key>
LLM_BASE_URL=https://api.groq.com/openai/v1
LLM_MODEL=openai/gpt-oss-20b
LLM_REASONING_EFFORT=low
CHAT_MAX_TOKENS=1200
VISION_API_KEY=<Google Gemini API key>
VISION_MODEL=gemini-flash-lite-latest
VISION_REASONING_EFFORT=low
ENV
  echo ">>> Edit /etc/api.env and replace every <placeholder> before starting the API."
fi

sudo systemctl daemon-reload
sudo systemctl enable api
echo "Bootstrap done. Next: put a build in ~/api-new and run backend/deploy/deploy.sh (see docs/AWS_REBUILD.md)."

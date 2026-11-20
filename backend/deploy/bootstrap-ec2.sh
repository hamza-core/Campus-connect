#!/usr/bin/env bash
# Prepares an Ubuntu 26.04 LTS EC2 instance to run the CampusConnect API.
# Run it on the server as the default `ubuntu` user:
#     bash bootstrap-ec2.sh --check     # shows what it WOULD change, changes nothing
#     bash bootstrap-ec2.sh             # applies only what is missing or different
#
# Safe on a running server: it never upgrades an installed package, only rewrites a file whose
# content differs (after saving a timestamped .bak copy), reloads Nginx gracefully only when its
# config changed, never touches an existing /etc/api.env, and never restarts the API.
# On a fresh instance it installs the .NET runtime and Nginx, writes the Nginx site (port 80 ->
# Kestrel on 127.0.0.1:5000, WebSocket upgrade for SignalR, 6 MB uploads), creates the `api`
# systemd service and a settings template at /etc/api.env. It does NOT start the API: there is
# no build yet. See docs/AWS_REBUILD.md for the remaining steps.
set -euo pipefail

CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1
CHANGES=0
LAST_CHANGED=0

say() { printf '%s\n' "$*"; }

# put_file <destination>  (new content on stdin) - writes only when different, backing up first.
put_file() {
  local dest="$1" tmp
  tmp="$(mktemp)"
  cat > "$tmp"
  LAST_CHANGED=0
  if sudo test -f "$dest" && sudo cmp -s "$tmp" "$dest"; then
    say "unchanged:    $dest"
    rm -f "$tmp"
    return 0
  fi
  LAST_CHANGED=1
  CHANGES=$((CHANGES + 1))
  if [ "$CHECK" = 1 ]; then
    say "WOULD CHANGE: $dest"
    rm -f "$tmp"
    return 0
  fi
  if sudo test -f "$dest"; then
    sudo cp -p "$dest" "$dest.bak-$(date +%Y%m%d-%H%M%S)"
    say "backed up:    $dest"
  fi
  sudo install -m 644 -o root -g root "$tmp" "$dest"
  rm -f "$tmp"
  say "wrote:        $dest"
}

# 1) Packages: install only what is missing, never upgrade what is there.
missing=()
for pkg in aspnetcore-runtime-10.0 nginx; do
  dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
done
if [ "${#missing[@]}" -gt 0 ]; then
  CHANGES=$((CHANGES + 1))
  if [ "$CHECK" = 1 ]; then
    say "WOULD INSTALL: ${missing[*]}"
  else
    sudo apt-get update
    sudo apt-get install -y --no-upgrade "${missing[@]}"
  fi
else
  say "installed:    aspnetcore-runtime-10.0 nginx"
fi

# 2) Folders (creating an existing folder is a no-op).
for dir in "$HOME/api" "$HOME/uploads"; do
  if [ -d "$dir" ]; then
    say "exists:       $dir"
  else
    CHANGES=$((CHANGES + 1))
    if [ "$CHECK" = 1 ]; then say "WOULD CREATE: $dir"; else mkdir -p "$dir"; say "created:      $dir"; fi
  fi
done

# 3) Nginx site.
put_file /etc/nginx/sites-available/default <<'NGINX'
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
if [ "$CHECK" = 0 ]; then
  if [ "$LAST_CHANGED" = 1 ]; then
    sudo nginx -t
    if systemctl is-active --quiet nginx; then sudo systemctl reload nginx; else sudo systemctl enable --now nginx; fi
    say "nginx:        configuration tested and applied"
  elif ! systemctl is-active --quiet nginx; then
    sudo systemctl enable --now nginx
    say "nginx:        started"
  fi
fi

# 4) The API service.
put_file /etc/systemd/system/api.service <<'UNIT'
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
if [ "$CHECK" = 0 ] && [ "$LAST_CHANGED" = 1 ]; then sudo systemctl daemon-reload; fi
if systemctl is-enabled --quiet api 2>/dev/null; then
  say "enabled:      api (service)"
else
  CHANGES=$((CHANGES + 1))
  if [ "$CHECK" = 1 ]; then say "WOULD ENABLE: api (service)"; else sudo systemctl enable api; say "enabled:      api (service)"; fi
fi

# 5) Settings file: created only when absent, never overwritten.
if sudo test -f /etc/api.env; then
  say "present:      /etc/api.env (left untouched)"
else
  CHANGES=$((CHANGES + 1))
  if [ "$CHECK" = 1 ]; then
    say "WOULD CREATE: /etc/api.env (template)"
  else
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
    say "created:      /etc/api.env (template) - edit it and replace every <placeholder>"
  fi
fi

echo
if [ "$CHANGES" = 0 ]; then
  say "Result: nothing to change - this server already matches."
elif [ "$CHECK" = 1 ]; then
  say "Result: $CHANGES change(s) would be made. Re-run without --check to apply them."
else
  say "Result: $CHANGES change(s) applied. Next: put a build in ~/api-new and run backend/deploy/deploy.sh (docs/AWS_REBUILD.md)."
fi

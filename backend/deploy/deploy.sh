#!/usr/bin/env bash
# Runs ON the EC2 server. Expects the new build in ~/api-new (copied there by the pipeline
# or by hand). Applies pending database migrations, swaps the build in, restarts the
# service, checks health, and rolls back to the previous build if the API does not come up.
set -euo pipefail

APP=/home/ubuntu/api
NEW=/home/ubuntu/api-new
PREV=/home/ubuntu/api-prev
HEALTH=http://127.0.0.1:5000/api/v1/health

[ -f "$NEW/CampusConnect.Api.dll" ] || { echo "No build found in $NEW"; exit 1; }

rm -rf "$PREV"
cp -r "$APP" "$PREV"

# Apply any new EF Core migrations with the NEW build, before touching the live one.
# Safe to run repeatedly; if it fails the live service is left untouched.
sudo systemd-run --wait --pipe -q \
  -p EnvironmentFile=/etc/api.env -p WorkingDirectory="$NEW" -p User=ubuntu \
  /usr/bin/dotnet "$NEW/CampusConnect.Api.dll" --migrate

sudo systemctl stop api
cp -r "$NEW"/. "$APP"/
sudo systemctl start api

for i in $(seq 1 30); do
  if curl -fsS -m 3 "$HEALTH" >/dev/null; then
    echo "API healthy after $((i * 2))s"
    exit 0
  fi
  sleep 2
done

echo "API did not become healthy - rolling back to the previous build"
sudo systemctl stop api
rm -rf "$APP"
cp -r "$PREV" "$APP"
sudo systemctl start api
exit 1

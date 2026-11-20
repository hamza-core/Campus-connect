#!/usr/bin/env bash
# One-command build and teardown of the whole CampusConnect AWS setup.
#
#   ./infra/rebuild.sh check    free preflight: tools, AWS login, network, template (changes nothing)
#   ./infra/rebuild.sh up       create the server + database + security groups, deploy the API, load demo data
#   ./infra/rebuild.sh status   show the stack, its address and a health check
#   ./infra/rebuild.sh ssh      open a shell on the server
#   ./infra/rebuild.sh down     delete everything (a final database snapshot is kept)
#
# Needs: the AWS CLI logged in (docs/AWS_ONE_COMMAND.md), ssh, scp, openssl, curl, and either
# dotnet or gh (to get the API build). Works with the bash 3.2 that ships with macOS.
#
# Optional settings (environment variables):
#   AWS_REGION=eu-north-1   STACK_NAME=campusconnect   KEY_NAME=campusconnect-key
#   SNAPSHOT_ID=<id>        restore the database from a snapshot instead of seeding demo data
#   USE_ELASTIC_IP=true     fixed server address (small ongoing charge)
#   AMI_ID=ami-...          use this image instead of looking up the newest Ubuntu 26.04
#   SKIP_SEED=1             do not load demo data
set -euo pipefail

STACK="${STACK_NAME:-campusconnect}"
export AWS_REGION="${AWS_REGION:-eu-north-1}"
export AWS_DEFAULT_REGION="$AWS_REGION"
KEY_NAME="${KEY_NAME:-campusconnect-key}"
KEY_FILE="${KEY_FILE:-$HOME/.ssh/${KEY_NAME}.pem}"
SECRETS_FILE="${SECRETS_FILE:-$HOME/.campusconnect/secrets.env}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$ROOT/infra/cloudformation.yaml"
REPO="hamza-core/Campus-connect"

say()  { printf '%s\n' "$*"; }
ok()   { printf '  [ok]   %s\n' "$*"; }
bad()  { printf '  [FAIL] %s\n' "$*"; FAILED=1; }
die()  { printf 'Error: %s\n' "$*" >&2; exit 1; }
FAILED=0

need() { command -v "$1" >/dev/null 2>&1 || die "'$1' is not installed. See docs/AWS_ONE_COMMAND.md."; }

# ---------------------------------------------------------------- AWS lookups
default_vpc()    { aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text; }
vpc_subnets()    { aws ec2 describe-subnets --filters "Name=vpc-id,Values=$1" Name=default-for-az,Values=true \
                     --query 'Subnets[].SubnetId' --output text; }
stack_status()   { aws cloudformation describe-stacks --stack-name "$STACK" --query 'Stacks[0].StackStatus' --output text 2>/dev/null || true; }
stack_output()   { aws cloudformation describe-stacks --stack-name "$STACK" \
                     --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text; }
key_exists()     { aws ec2 describe-key-pairs --key-names "$KEY_NAME" >/dev/null 2>&1; }

# ---------------------------------------------------------------- secrets kept on THIS computer
save_secret() { printf '%s=%q\n' "$1" "$2" >> "$SECRETS_FILE"; }

ask() {   # ask <VAR> <prompt> [secret]  - keeps an existing value, else asks
  local var="$1" prompt="$2" secret="${3:-}" value
  eval "value=\${$var:-}"
  [ -n "$value" ] && return 0
  if [ "$secret" = secret ]; then read -r -s -p "$prompt" value; echo; else read -r -p "$prompt" value; fi
  eval "$var=\$value"
  [ -n "$value" ] && save_secret "$var" "$value"
  return 0
}

load_secrets() {
  mkdir -p "$(dirname "$SECRETS_FILE")"
  chmod 700 "$(dirname "$SECRETS_FILE")"
  [ -f "$SECRETS_FILE" ] || install -m 600 /dev/null "$SECRETS_FILE"
  # shellcheck disable=SC1090
  set -a; . "$SECRETS_FILE"; set +a
  DB_PASSWORD="${DB_PASSWORD:-}"; JWT_SECRET="${JWT_SECRET:-}"; SEED_PASSWORD="${SEED_PASSWORD:-}"
  LLM_API_KEY="${LLM_API_KEY:-}"; VISION_API_KEY="${VISION_API_KEY:-}"

  if [ -z "$DB_PASSWORD" ]; then
    if [ -n "${SNAPSHOT_ID:-}" ]; then
      ask DB_PASSWORD "Database password of the snapshot you are restoring: " secret
    else
      DB_PASSWORD="$(openssl rand -hex 16)"; save_secret DB_PASSWORD "$DB_PASSWORD"
    fi
  fi
  case "$DB_PASSWORD" in *\'*|*\;*|*\"*|*' '*) die "The database password must not contain quotes, semicolons or spaces.";; esac
  if [ -z "$JWT_SECRET" ]; then JWT_SECRET="$(openssl rand -base64 48)"; save_secret JWT_SECRET "$JWT_SECRET"; fi
  if [ -z "${SKIP_SEED:-}" ] && [ -z "${SNAPSHOT_ID:-}" ]; then
    ask SEED_PASSWORD "Choose the demo password for all demo accounts (8+ letters/digits . _ @ % + -): " secret
    case "$SEED_PASSWORD" in
      *[!A-Za-z0-9._@%+-]*|'') die "The demo password may only use letters, digits and . _ @ % + -";;
    esac
    [ "${#SEED_PASSWORD}" -ge 8 ] || die "The demo password needs at least 8 characters."
  fi
  ask LLM_API_KEY "Groq API key for the chat assistant (Enter to skip): " secret
  ask VISION_API_KEY "Google Gemini API key for photo suggestions (Enter to skip): " secret
}

# ---------------------------------------------------------------- server access
ssh_srv() { ssh -i "$KEY_FILE" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=15 -o ServerAliveInterval=30 "ubuntu@$SERVER_IP" "$@"; }
scp_srv() { scp -i "$KEY_FILE" -o StrictHostKeyChecking=accept-new -q "$@"; }

wait_for_ssh() {
  say "Waiting for the server to accept SSH..."
  local i
  for i in $(seq 1 40); do
    if ssh_srv 'true' </dev/null >/dev/null 2>&1; then return 0; fi
    sleep 8
  done
  die "The server did not accept SSH in time. Check the security group allows your IP ($MY_IP)."
}

# ---------------------------------------------------------------- commands
cmd_check() {
  say "Preflight (changes nothing):"
  for t in aws ssh scp openssl curl; do command -v "$t" >/dev/null 2>&1 && ok "$t installed" || bad "$t is missing (docs/AWS_ONE_COMMAND.md)"; done
  if command -v dotnet >/dev/null 2>&1 || command -v gh >/dev/null 2>&1; then ok "dotnet or gh available (to get the API build)"; else bad "install dotnet or gh to get the API build"; fi
  if command -v aws >/dev/null 2>&1; then
    if ident="$(aws sts get-caller-identity --query Arn --output text 2>/dev/null)"; then ok "signed in to AWS as $ident (region $AWS_REGION)"; else bad "not signed in to AWS - run 'aws configure' (docs/AWS_ONE_COMMAND.md)"; fi
    if [ "$FAILED" = 0 ]; then
      vpc="$(default_vpc 2>/dev/null || true)"
      if [ -n "$vpc" ] && [ "$vpc" != None ]; then ok "default VPC $vpc"; else bad "no default VPC in $AWS_REGION"; fi
      n="$(vpc_subnets "$vpc" 2>/dev/null | wc -w | tr -d ' ' || true)"
      [ "${n:-0}" -ge 2 ] && ok "$n default subnets" || bad "need at least 2 default subnets"
      if key_exists; then
        [ -f "$KEY_FILE" ] && ok "key pair $KEY_NAME and $KEY_FILE" || bad "key pair $KEY_NAME exists in AWS but $KEY_FILE is missing (set KEY_NAME to a new name)"
      else ok "key pair $KEY_NAME will be created"; fi
      if aws cloudformation validate-template --template-body "file://$TEMPLATE" >/dev/null 2>&1; then ok "template is valid"; else bad "template did not validate"; fi
      st="$(stack_status)"
      [ -z "$st" ] && ok "no stack named '$STACK' yet" || say "  [info] stack '$STACK' already exists: $st"
    fi
  fi
  [ "$FAILED" = 0 ] && say "All good - run './infra/rebuild.sh up'." || { say "Fix the items above first."; exit 1; }
}

build_api() {
  PUB="$(mktemp -d)"
  if command -v dotnet >/dev/null 2>&1; then
    say "Building the API with dotnet..."
    ( cd "$ROOT/backend" && dotnet publish src/CampusConnect.Api -c Release -r linux-x64 --self-contained false -o "$PUB" >/dev/null )
    git -C "$ROOT" checkout -- backend/src/CampusConnect.Api/packages.lock.json backend/tests/CampusConnect.Tests/packages.lock.json 2>/dev/null || true
  elif command -v gh >/dev/null 2>&1; then
    say "Downloading the latest API build from GitHub..."
    run_id="$(gh run list -R "$REPO" --workflow backend-ci.yml --branch main --status success --limit 1 --json databaseId -q '.[0].databaseId')"
    [ -n "$run_id" ] || die "No successful Backend CI run found."
    gh run download "$run_id" -R "$REPO" -n backend-api -D "$PUB"
  else
    die "Need dotnet or gh to get the API build."
  fi
  [ -f "$PUB/CampusConnect.Api.dll" ] || die "The API build is missing CampusConnect.Api.dll."
}

write_server_env() {
  {
    echo "ASPNETCORE_ENVIRONMENT=Production"
    echo "ASPNETCORE_URLS=http://localhost:5000"
    echo "ConnectionStrings__DefaultConnection=Server=$DB_ENDPOINT,1433;Database=CampusConnect;User Id=admin;Password='$DB_PASSWORD';Encrypt=True;TrustServerCertificate=True"
    echo "JWT_SECRET=$JWT_SECRET"
    echo "UPLOADS_DIR=/home/ubuntu/uploads"
    if [ -n "$LLM_API_KEY" ]; then
      echo "LLM_API_KEY=$LLM_API_KEY"
      echo "LLM_BASE_URL=https://api.groq.com/openai/v1"
      echo "LLM_MODEL=openai/gpt-oss-20b"
      echo "LLM_REASONING_EFFORT=low"
      echo "CHAT_MAX_TOKENS=1200"
    fi
    if [ -n "$VISION_API_KEY" ]; then
      echo "VISION_API_KEY=$VISION_API_KEY"
      echo "VISION_MODEL=gemini-flash-lite-latest"
      echo "VISION_REASONING_EFFORT=low"
    fi
  } | ssh_srv 'sudo tee /etc/api.env >/dev/null && sudo chmod 600 /etc/api.env && sudo chown root:root /etc/api.env'
}

run_dotnet() {   # run_dotnet <flag> [extra systemd-run options]
  local out
  if ! out="$(ssh_srv "sudo systemd-run --wait --pipe -q -p EnvironmentFile=/etc/api.env -p WorkingDirectory=/home/ubuntu/api -p User=ubuntu --setenv=SEED_PASSWORD='$SEED_PASSWORD' ${2:-} /usr/bin/dotnet /home/ubuntu/api/CampusConnect.Api.dll $1" </dev/null 2>&1)"; then
    printf '%s\n' "$out" | tail -15
    die "'$1' failed on the server (output above)."
  fi
  printf '%s\n' "$out" | grep -E '^(Before|After)' || true
}

cmd_up() {
  need aws; need ssh; need scp; need openssl; need curl
  aws sts get-caller-identity >/dev/null 2>&1 || die "Not signed in to AWS. Run 'aws configure' (docs/AWS_ONE_COMMAND.md)."
  st="$(stack_status)"
  [ -z "$st" ] || die "A stack named '$STACK' already exists ($st). Use './infra/rebuild.sh status' or 'down' first."
  load_secrets

  VPC="$(default_vpc)"; [ -n "$VPC" ] && [ "$VPC" != None ] || die "No default VPC in $AWS_REGION."
  SUBNETS="$(vpc_subnets "$VPC")"
  [ "$(echo "$SUBNETS" | wc -w | tr -d ' ')" -ge 2 ] || die "Need at least two default subnets."
  SERVER_SUBNET="$(echo "$SUBNETS" | awk '{print $1}')"
  SUBNET_CSV="$(echo "$SUBNETS" | tr -s '[:space:]' ',' | sed 's/,$//')"
  MY_IP="$(curl -fsS https://checkip.amazonaws.com | tr -d '[:space:]')"
  [ -n "$MY_IP" ] || die "Could not work out your public IP address."

  if ! key_exists_or_create; then die "Key pair problem."; fi

  say "Creating the stack '$STACK' (the database takes 10-20 minutes)..."
  params=("KeyPairName=$KEY_NAME" "VpcId=$VPC" "ServerSubnetId=$SERVER_SUBNET" "DbSubnetIds=$SUBNET_CSV" \
          "SshCidr=$MY_IP/32" "UseElasticIp=${USE_ELASTIC_IP:-false}")
  if [ -n "${SNAPSHOT_ID:-}" ]; then params+=("DbSnapshotId=$SNAPSHOT_ID"); else params+=("DbPassword=$DB_PASSWORD"); fi
  if [ -n "${AMI_ID:-}" ]; then params+=("AmiIdOverride=$AMI_ID"); fi
  aws cloudformation deploy --stack-name "$STACK" --template-file "$TEMPLATE" --no-fail-on-empty-changeset \
    --parameter-overrides "${params[@]}"

  SERVER_IP="$(stack_output ServerPublicIp)"; DB_ENDPOINT="$(stack_output DbEndpoint)"
  [ -n "$SERVER_IP" ] && [ -n "$DB_ENDPOINT" ] || die "The stack finished but its outputs are empty."
  say "Server: $SERVER_IP    Database: $DB_ENDPOINT"

  wait_for_ssh
  say "Waiting for the server's first-boot setup to finish..."
  ssh_srv 'cloud-init status --wait' </dev/null >/dev/null 2>&1 || true
  ssh_srv 'test -f /etc/api.env && systemctl is-enabled --quiet api' </dev/null || die "First-boot setup did not complete. Look at /var/log/cloud-init-output.log on the server."

  say "Writing the server settings..."
  write_server_env

  build_api
  say "Uploading the API..."
  ssh_srv 'rm -rf ~/api-new && mkdir -p ~/api-new' </dev/null
  scp_srv -r "$PUB"/. "ubuntu@$SERVER_IP:~/api-new/"
  say "Deploying (applies database migrations, starts the API, checks health)..."
  ssh_srv 'bash -s' < "$ROOT/backend/deploy/deploy.sh"

  if [ -n "${SNAPSHOT_ID:-}" ]; then
    say "Restored from snapshot $SNAPSHOT_ID - existing data kept, demo data not loaded."
  elif [ -n "${SKIP_SEED:-}" ]; then
    say "SKIP_SEED set - demo data not loaded."
  else
    say "Loading demo data..."
    run_dotnet --seed
    run_dotnet --reset-demo "--setenv=CONFIRM_RESET=delete-all-complaints"
  fi

  say ""
  say "Done."
  say "  Health:  http://$SERVER_IP/api/v1/health  -> $(curl -s -m 8 "http://$SERVER_IP/api/v1/health" || echo 'no answer yet')"
  say "  Next:    point the app at it - set the GitHub variable API_BASE_URL to http://$SERVER_IP/api/v1"
  say "           then run the 'Frontend APK' workflow and download the APK (docs/AWS_ONE_COMMAND.md)."
}

key_exists_or_create() {
  if key_exists; then
    [ -f "$KEY_FILE" ] || { say "Key pair '$KEY_NAME' exists in AWS but $KEY_FILE is missing. Set KEY_NAME to a new name."; return 1; }
    return 0
  fi
  say "Creating key pair '$KEY_NAME' -> $KEY_FILE"
  mkdir -p "$(dirname "$KEY_FILE")"
  aws ec2 create-key-pair --key-name "$KEY_NAME" --query KeyMaterial --output text > "$KEY_FILE"
  chmod 400 "$KEY_FILE"
}

cmd_status() {
  need aws
  st="$(stack_status)"
  [ -n "$st" ] || { say "No stack named '$STACK' in $AWS_REGION."; return 0; }
  say "Stack '$STACK': $st"
  SERVER_IP="$(stack_output ServerPublicIp 2>/dev/null || true)"
  if [ -n "$SERVER_IP" ] && [ "$SERVER_IP" != None ]; then
    say "Server:   $SERVER_IP"
    say "Database: $(stack_output DbEndpoint 2>/dev/null || true)"
    say "Health:   $(curl -s -m 8 "http://$SERVER_IP/api/v1/health" || echo 'no answer')"
  fi
}

cmd_ssh() {
  need aws
  SERVER_IP="$(stack_output ServerPublicIp)"; [ -n "$SERVER_IP" ] || die "No running stack."
  exec ssh -i "$KEY_FILE" -o StrictHostKeyChecking=accept-new "ubuntu@$SERVER_IP"
}

cmd_down() {
  need aws
  st="$(stack_status)"
  [ -n "$st" ] || { say "No stack named '$STACK' in $AWS_REGION - nothing to delete."; return 0; }
  say "This permanently deletes the server, the database and the security groups of stack '$STACK'."
  say "A final database snapshot is kept so the data can be restored (SNAPSHOT_ID=... ./infra/rebuild.sh up)."
  if [ "${1:-}" != "--yes" ]; then
    read -r -p "Type DELETE to continue: " answer
    [ "$answer" = DELETE ] || { say "Cancelled."; return 0; }
  fi
  aws cloudformation delete-stack --stack-name "$STACK"
  say "Deleting (the database takes a few minutes)..."
  aws cloudformation wait stack-delete-complete --stack-name "$STACK"
  say "Deleted. The final snapshot is kept:"
  aws rds describe-db-snapshots --snapshot-type manual --query "DBSnapshots[?contains(DBSnapshotIdentifier, 'campusconnect')].[DBSnapshotIdentifier,SnapshotCreateTime,Status]" --output table || true
  say "Snapshots cost a little each month. Delete one you no longer need with:"
  say "  aws rds delete-db-snapshot --db-snapshot-identifier <name>"
}

case "${1:-}" in
  check)  cmd_check ;;
  up)     cmd_up ;;
  status) cmd_status ;;
  ssh)    cmd_ssh ;;
  down)   shift; cmd_down "${1:-}" ;;
  *)      sed -n '2,12p' "${BASH_SOURCE[0]}"; exit 1 ;;
esac

#!/usr/bin/env bash
#
# create-user.sh — provision an Arkham Horror account (invite-only instance).
#
# Public self-registration is disabled by a DB trigger (see private-signup.sql).
# This helper inserts a user directly, setting the app.allow_register flag on its
# own connection so the trigger permits the insert. Password is stored as a
# bcrypt hash, which the app's Crypto.BCrypt validator accepts.
#
# Usage:
#   scripts/azure/create-user.sh <username> <email> <password> [--admin]
#
# Requirements: az CLI (logged into the MSDN sub), psql, htpasswd, terraform.
# Run from the repo root so it can read the DB password from terraform state,
# or set AZ_PG_PASSWORD in the environment to skip that.

set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-arkham-horror}"
PG_SERVER="${PG_SERVER:-arkham-pg}"
PG_HOST="${PG_HOST:-arkham-pg.postgres.database.azure.com}"
PG_USER="${PG_USER:-arkham_pg_user}"
PG_DATABASE="${PG_DATABASE:-arkham-horror-backend}"

usage() { echo "Usage: $0 <username> <email> <password> [--admin]" >&2; exit 1; }

[ "$#" -ge 3 ] || usage
USERNAME="$1"; EMAIL="$2"; PASSWORD="$3"; ADMIN="false"
[ "${4:-}" = "--admin" ] && ADMIN="true"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- DB password -------------------------------------------------------------
if [ -z "${AZ_PG_PASSWORD:-}" ]; then
  AZ_PG_PASSWORD="$(cd "$REPO_ROOT/terraform/azure" && terraform state pull \
    | python3 -c "import json,sys;s=json.load(sys.stdin);print([r for r in s['resources'] if r['type']=='random_password' and r['name']=='pg_admin'][0]['instances'][0]['attributes']['result'])")"
fi

# --- bcrypt hash (accepts either $2y$/$2b$; app validates both) ---------------
HASH="$(htpasswd -bnBC 12 "" "$PASSWORD" | tr -d '\n' | sed -e 's/^[^:]*://' -e 's/^\$2y\$/\$2b\$/')"

# --- open a temporary firewall rule for this machine's IP ---------------------
MYIP="$(curl -s https://api.ipify.org)"
RULE="tmp-createuser-$$"
fw() { # $1 = create|delete
  if [ "$1" = "create" ]; then
    az postgres flexible-server firewall-rule create --resource-group "$RESOURCE_GROUP" \
      --name "$PG_SERVER" --rule-name "$RULE" --start-ip-address "$MYIP" --end-ip-address "$MYIP" --output none 2>/dev/null \
    || az postgres flexible-server firewall-rule create --resource-group "$RESOURCE_GROUP" \
      --server-name "$PG_SERVER" --name "$RULE" --start-ip-address "$MYIP" --end-ip-address "$MYIP" --output none
  else
    az postgres flexible-server firewall-rule delete --resource-group "$RESOURCE_GROUP" \
      --name "$PG_SERVER" --rule-name "$RULE" --yes --output none 2>/dev/null \
    || az postgres flexible-server firewall-rule delete --resource-group "$RESOURCE_GROUP" \
      --server-name "$PG_SERVER" --name "$RULE" --yes --output none 2>/dev/null || true
  fi
}
cleanup() { fw delete; }
trap cleanup EXIT

echo "==> opening firewall for $MYIP"
fw create

# --- insert the user (allow_register flag lets the trigger pass) --------------
echo "==> creating user '$USERNAME' <$EMAIL> (admin=$ADMIN)"
PGPASSWORD="$AZ_PG_PASSWORD" PGOPTIONS="-c app.allow_register=on" \
  psql "host=$PG_HOST port=5432 dbname=$PG_DATABASE user=$PG_USER sslmode=require" \
  -v ON_ERROR_STOP=1 \
  -v uname="$USERNAME" -v uemail="$EMAIL" -v udigest="$HASH" -v uadmin="$ADMIN" <<'SQL'
INSERT INTO users (username, email, password_digest, beta, admin)
VALUES (:'uname', :'uemail', :'udigest', false, :'uadmin'::boolean);
SQL

echo "==> done. '$USERNAME' can now log in."

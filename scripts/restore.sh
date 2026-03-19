#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

usage() {
    echo "Usage: $0 postgres <backup-file.sql.gz>"
    echo ""
    echo "Restores a PostgreSQL backup created by backup.sh."
    echo "WARNING: This will overwrite the current database contents."
    echo ""
    echo "Example:"
    echo "  $0 postgres /backups/amp-postgres-20260318_120000.sql.gz"
    exit 1
}

[[ $# -ne 2 ]] && usage
[[ "$1" != "postgres" ]] && { echo "Only 'postgres' restore is supported"; usage; }

BACKUP_FILE="$2"

if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "ERROR: Backup file not found: $BACKUP_FILE"
    exit 1
fi

source "$PROJECT_DIR/.env"
[ -f "$PROJECT_DIR/.env.local" ] && source "$PROJECT_DIR/.env.local"

echo "WARNING: This will overwrite the '${POSTGRES_DB:-amp}' database."
read -r -p "Continue? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted."
    exit 0
fi

echo "Stopping Amp to release database connections..."
docker compose -f "$PROJECT_DIR/docker-compose.yml" stop amp || true

echo "Restoring PostgreSQL from ${BACKUP_FILE}..."
gunzip -c "$BACKUP_FILE" | docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T postgres \
    psql -U "${POSTGRES_USER:-amp}" -d "${POSTGRES_DB:-amp}"

echo "Restarting Amp..."
docker compose -f "$PROJECT_DIR/docker-compose.yml" up -d amp

echo "Restore complete."

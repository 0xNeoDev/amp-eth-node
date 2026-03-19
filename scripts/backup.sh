#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

usage() {
    echo "Usage: $0 <component> <output-dir>"
    echo ""
    echo "Components: postgres, config, all"
    echo ""
    echo "Examples:"
    echo "  $0 postgres /backups"
    echo "  $0 config /backups"
    echo "  $0 all /backups"
    exit 1
}

[[ $# -ne 2 ]] && usage

COMPONENT="$1"
OUTPUT_DIR="$2"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "ERROR: Output directory does not exist: $OUTPUT_DIR"
    exit 1
fi

source "$PROJECT_DIR/.env"
[ -f "$PROJECT_DIR/.env.local" ] && source "$PROJECT_DIR/.env.local"

backup_postgres() {
    local outfile="${OUTPUT_DIR}/amp-postgres-${TIMESTAMP}.sql.gz"
    echo "Backing up PostgreSQL to ${outfile}..."

    docker compose -f "$PROJECT_DIR/docker-compose.yml" exec -T postgres \
        pg_dump -U "${POSTGRES_USER:-amp}" -d "${POSTGRES_DB:-amp}" --clean --if-exists \
        | gzip > "$outfile"

    local size
    size=$(du -h "$outfile" | cut -f1)
    echo "PostgreSQL backup complete: $outfile ($size)"
}

backup_config() {
    local outfile="${OUTPUT_DIR}/amp-config-${TIMESTAMP}.tar.gz"
    echo "Backing up configuration to ${outfile}..."

    tar -czf "$outfile" \
        -C "$PROJECT_DIR" \
        .env \
        config/ \
        justfile \
        docker-compose.yml \
        docker-compose.dev.yml \
        docker-compose.prod.yml \
        scripts/

    local size
    size=$(du -h "$outfile" | cut -f1)
    echo "Config backup complete: $outfile ($size)"
}

case "$COMPONENT" in
    postgres)
        backup_postgres
        ;;
    config)
        backup_config
        ;;
    all)
        backup_postgres
        backup_config
        ;;
    *)
        echo "Unknown component: $COMPONENT"
        usage
        ;;
esac

echo ""
echo "Backup(s) saved to: $OUTPUT_DIR"
ls -lh "${OUTPUT_DIR}"/amp-*-"${TIMESTAMP}"* 2>/dev/null

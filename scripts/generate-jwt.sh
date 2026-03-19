#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
JWT_DIR="$PROJECT_DIR/jwt"
JWT_FILE="$JWT_DIR/jwt.hex"

mkdir -p "$JWT_DIR"

if [[ -f "$JWT_FILE" ]]; then
    echo "JWT secret already exists at $JWT_FILE"
    echo "To regenerate, delete the file and re-run this script."
    exit 0
fi

umask 077
openssl rand -hex 32 > "$JWT_FILE" || {
    echo "ERROR: Failed to generate JWT secret (is openssl installed?)"
    rm -f "$JWT_FILE"
    exit 1
}
chmod 600 "$JWT_FILE"
echo "Generated JWT secret at $JWT_FILE (mode 600)"

#!/bin/sh

set -eu

if ! command -v python3 >/dev/null 2>&1; then
    printf '{"configured":false,"available":false,"success":false,"error":"python3 not found"}\n'
    exit 0
fi

exec python3 "$(dirname "$0")/homeassistant.py" "$@"

#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
project_dir=$(dirname "$script_dir")

if ! command -v uv >/dev/null 2>&1; then
    printf '{"configured":false,"available":false,"success":false,"error":"uv not found"}\n'
    exit 0
fi

exec uv run --project "$project_dir" python3 "$script_dir/homeassistant.py" "$@"

#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
pycache_dir=$(mktemp -d)

cleanup() {
    rm -rf "$pycache_dir"
}

trap cleanup EXIT INT TERM

if ! command -v python3 >/dev/null 2>&1; then
    printf '%s\n' "python3 is required for the Quickshell Python syntax check" >&2
    exit 1
fi

PYTHONPYCACHEPREFIX="$pycache_dir" python3 -m py_compile \
    "$script_dir/fetch_meteo_forecast.py"

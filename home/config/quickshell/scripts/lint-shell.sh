#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

scripts="
$script_dir/connectivity-status.sh
$script_dir/focus-codex-ghostty.sh
$script_dir/system-stats.sh
$script_dir/weather.sh
$script_dir/lint-shell.sh
$script_dir/python-check.sh
$script_dir/qml-test.sh
$script_dir/smoke-load.sh
"

if command -v shellcheck >/dev/null 2>&1; then
    # shellcheck disable=SC2086
    shellcheck $scripts
    exit 0
fi

printf '%s\n' "shellcheck not installed, falling back to sh -n syntax checks" >&2
for script in $scripts; do
    sh -n "$script"
done

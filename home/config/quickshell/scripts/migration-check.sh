#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

printf '%s\n' "[1/7] format check"
sh "$script_dir/format.sh" --check

printf '%s\n' "[2/7] lint"
"$script_dir/lint.sh"

printf '%s\n' "[3/7] architecture checks"
"$script_dir/arch-check.sh"

printf '%s\n' "[4/7] cutover status"
sh "$script_dir/cutover-status.sh"

printf '%s\n' "[5/7] tests"
"$script_dir/python-check.sh"
"$script_dir/qml-test.sh"

printf '%s\n' "[6/7] smoke (system bar)"
"$script_dir/smoke-load.sh"

printf '%s\n' "[7/7] integration diagnostics"
INTEGRATION_SMOKE_REQUIRE_LIVE=1 sh "$script_dir/integration-smoke.sh"

printf '%s\n' "migration-check: ok"

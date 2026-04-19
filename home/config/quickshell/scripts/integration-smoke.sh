#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root_dir=$(dirname "$script_dir")
shell_entry="$root_dir/shell.qml"
require_live="${INTEGRATION_SMOKE_REQUIRE_LIVE:-0}"

if ! qs list 2>/dev/null | grep -F "Config path: $shell_entry" >/dev/null 2>&1; then
	if [ "$require_live" = "1" ]; then
		printf '%s\n' "integration-smoke: no live quickshell instance for $shell_entry" >&2
		exit 1
	fi
	printf '%s\n' "integration-smoke: skipped (no live quickshell instance for $shell_entry)"
	exit 0
fi

launcher_snapshot=$("$script_dir/shellctl" launcher.integrations.describe 2>&1) || {
	printf '%s\n' "$launcher_snapshot" >&2
	exit 1
}

health_snapshot=$("$script_dir/shellctl" integrations.health 2>&1) || {
	printf '%s\n' "$health_snapshot" >&2
	exit 1
}

if ! printf '%s' "$launcher_snapshot" | grep -F '"status":"applied"' >/dev/null; then
	printf '%s\n' "integration-smoke: launcher.integrations.describe did not return applied outcome" >&2
	printf '%s\n' "$launcher_snapshot" >&2
	exit 1
fi

if ! printf '%s' "$launcher_snapshot" | grep -F '"integrationCount":' >/dev/null; then
	printf '%s\n' "integration-smoke: launcher integration snapshot missing integrationCount" >&2
	printf '%s\n' "$launcher_snapshot" >&2
	exit 1
fi

if ! printf '%s' "$launcher_snapshot" | grep -F '"ready":' >/dev/null; then
	printf '%s\n' "integration-smoke: launcher integration snapshot missing ready markers" >&2
	printf '%s\n' "$launcher_snapshot" >&2
	exit 1
fi

if ! printf '%s' "$launcher_snapshot" | grep -F '"degraded":' >/dev/null; then
	printf '%s\n' "integration-smoke: launcher integration snapshot missing degraded markers" >&2
	printf '%s\n' "$launcher_snapshot" >&2
	exit 1
fi

if ! printf '%s' "$health_snapshot" | grep -F '"status":"applied"' >/dev/null; then
	printf '%s\n' "integration-smoke: integrations.health did not return applied outcome" >&2
	printf '%s\n' "$health_snapshot" >&2
	exit 1
fi

if ! printf '%s' "$health_snapshot" | grep -F '"overallStatus":"' >/dev/null; then
	printf '%s\n' "integration-smoke: integrations.health snapshot missing overallStatus" >&2
	printf '%s\n' "$health_snapshot" >&2
	exit 1
fi

printf '%s\n' "integration-smoke: ok"

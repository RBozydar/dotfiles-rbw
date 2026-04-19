#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root_dir=$(dirname "$script_dir")
legacy_bridge_allowlist="$script_dir/legacy-system-bridge-allowlist.txt"

failed=0

fail() {
	printf '%s\n' "cutover-status: $1" >&2
	failed=1
}

check_decommissioned_legacy_dirs() {
	for relative_dir in components modules; do
		target_dir="$root_dir/$relative_dir"
		if [ -d "$target_dir" ]; then
			fail "decommissioned legacy directory still present: $relative_dir"
		fi
	done
}

active_bridge_entry_count() {
	if [ ! -f "$legacy_bridge_allowlist" ]; then
		fail "missing allowlist file: $legacy_bridge_allowlist"
		printf '%s\n' "0"
		return
	fi

	grep -Evc '^[[:space:]]*($|#)' "$legacy_bridge_allowlist" || true
}

check_shell_bootstrap_contract() {
	shell_bootstrap="$root_dir/shell.qml"

	if [ ! -f "$shell_bootstrap" ]; then
		fail "missing shell bootstrap entrypoint: $shell_bootstrap"
		return
	fi

	if ! grep -Eq '^import Quickshell$' "$shell_bootstrap"; then
		fail "shell bootstrap missing required Quickshell import"
	fi
	if ! grep -Eq '^import "system/ui" as SystemUi$' "$shell_bootstrap"; then
		fail "shell bootstrap missing required system/ui import alias"
	fi
	if ! grep -Eq '^SystemUi\.SystemShell \{$' "$shell_bootstrap"; then
		fail "shell bootstrap must instantiate SystemUi.SystemShell"
	fi

	if rg -n --glob 'shell.qml' '^\s*import "(modules|components|services)/' "$root_dir" >/dev/null; then
		fail "shell bootstrap must not import legacy modules/components/services"
	fi
	if rg -n --glob 'shell.qml' '^\s*import qs\.services' "$root_dir" >/dev/null; then
		fail "shell bootstrap must not import qs.services directly"
	fi
}

check_homeassistant_singleton_decommission() {
	if [ -f "$root_dir/services/HomeAssistant.qml" ]; then
		fail "legacy HomeAssistant singleton file still present (services/HomeAssistant.qml)"
	fi

	if rg -n 'singleton[[:space:]]+HomeAssistant' \
		"$root_dir/services/qmldir" \
		"$root_dir/qs/services/qmldir" >/dev/null; then
		fail "legacy HomeAssistant singleton registration still present in qmldir"
	fi
}

check_decommissioned_legacy_dirs
check_shell_bootstrap_contract
check_homeassistant_singleton_decommission
bridge_count=$(active_bridge_entry_count)

printf '%s\n' "cutover-status: decommissioned_legacy_dirs=ok"
printf '%s\n' "cutover-status: shell_bootstrap_contract=ok"
printf '%s\n' "cutover-status: legacy_homeassistant_singleton=absent"
printf '%s\n' "cutover-status: legacy_bridge_allowlist_entries=${bridge_count}"

if [ "$bridge_count" -ne 0 ]; then
	fail "legacy bridge allowlist should be empty after entrypoint cutover"
fi

if [ "$failed" -ne 0 ]; then
	exit 1
fi

printf '%s\n' "cutover-status: ok"

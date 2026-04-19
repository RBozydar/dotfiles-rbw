#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root_dir=$(dirname "$script_dir")
repo_root=$(git -C "$root_dir" rev-parse --show-toplevel 2>/dev/null || printf '%s\n' "$root_dir")
system_dir="$root_dir/system"
legacy_bridge_allowlist="$script_dir/legacy-system-bridge-allowlist.txt"
exception_list=$(mktemp)
bridge_allowlist_entries=$(mktemp)

failed=0

cleanup() {
	rm -f "$exception_list" "$bridge_allowlist_entries"
}

trap cleanup EXIT INT TERM

if ! command -v rg >/dev/null 2>&1; then
	printf '%s\n' "arch-check: rg is required" >&2
	exit 1
fi

fail() {
	printf '%s\n' "$1" >&2
	failed=1
}

check_no_match() {
	description=$1
	shift

	if rg -n "$@"; then
		fail "arch-check: $description"
	fi
}

check_required_line() {
	file=$1
	pattern=$2
	message=$3

	if ! grep -Eq "$pattern" "$file"; then
		fail "arch-check: $message ($file)"
	fi
}

check_agents_metadata() {
	file=$1

	check_required_line "$file" '^## Metadata$' "missing metadata section"
	check_required_line "$file" "\`scope\`:" "missing scope metadata"
	check_required_line "$file" "\`owner\`:" "missing owner metadata"
	check_required_line "$file" "\`linked-adrs\`:" "missing linked-adrs metadata"
	check_required_line "$file" "\`architecture-version\`:" "missing architecture-version metadata"
	check_required_line "$file" "\`last-reviewed\`:" "missing last-reviewed metadata"
}

check_path_exists() {
	path=$1
	if [ ! -e "$path" ]; then
		fail "arch-check: missing required path $path"
	fi
}

check_agents_linked_adrs() {
	file=$1
	line=$(grep -E "\`linked-adrs\`:" "$file" || true)

	if [ -z "$line" ]; then
		fail "arch-check: no linked-adrs metadata found ($file)"
		return
	fi

	for adr in $(printf '%s\n' "$line" | grep -Eo 'ADR-[0-9]{4}'); do
		number=$(printf '%s' "$adr" | cut -d- -f2)
		if ! find "$root_dir/adr" -maxdepth 1 -type f -name "$number-*.md" | grep -q .; then
			fail "arch-check: linked ADR $adr does not exist for $file"
		fi
	done
}

check_exception_metadata() {
	path=$1

	if ! grep -Eq '"adr"' "$path" ||
		! grep -Eq '"path"' "$path" ||
		! grep -Eq '"reason"' "$path" ||
		! grep -Eq '"owner"' "$path" ||
		! grep -Eq '"expiry"' "$path" ||
		! grep -Eq '"ticket"' "$path"; then
		fail "arch-check: malformed ARCH-EXCEPTION metadata in $path"
	fi
}

check_path_absent() {
	path=$1
	description=$2

	if [ -e "$path" ]; then
		fail "arch-check: $description ($path)"
	fi
}

check_no_editor_backup_artifacts() {
	search_root=$1
	backup_paths=$(find "$search_root" -type f \( -name '*.bak' -o -name '*.orig' -o -name '*~' \) 2>/dev/null || true)

	if [ -z "$backup_paths" ]; then
		return
	fi

	for backup_path in $backup_paths; do
		fail "arch-check: remove backup artifact $backup_path"
	done
}

check_shell_bootstrap_contract() {
	bootstrap_path="$root_dir/shell.qml"

	check_required_line "$bootstrap_path" '^import Quickshell$' "shell bootstrap must import Quickshell"
	check_required_line "$bootstrap_path" '^import "system/ui" as SystemUi$' "shell bootstrap must import system/ui as SystemUi"
	check_required_line "$bootstrap_path" '^SystemUi\.SystemShell \{$' "shell bootstrap must instantiate SystemUi.SystemShell"

	check_no_match \
		"shell.qml must not import legacy runtime modules/components/services directly" \
		--glob 'shell.qml' \
		'^\s*import "(modules|components|services)/' \
		"$root_dir"

	check_no_match \
		"shell.qml must not import qs.services directly" \
		--glob 'shell.qml' \
		'^\s*import qs\.services' \
		"$root_dir"
}

load_bridge_allowlist_entries() {
	: >"$bridge_allowlist_entries"

	if [ ! -f "$legacy_bridge_allowlist" ]; then
		fail "arch-check: missing required path $legacy_bridge_allowlist"
		return
	fi

	while IFS= read -r relative_path; do
		case "$relative_path" in
		'' | \#*)
			continue
			;;
		esac
		printf '%s\n' "$relative_path" >>"$bridge_allowlist_entries"
	done <"$legacy_bridge_allowlist"
}

check_legacy_system_bridge_allowlist() {
	legacy_import_files=$(rg -l --glob '*.qml' --glob '*.js' '^\s*import .*system/' "$root_dir/components" "$root_dir/modules" "$root_dir/services" 2>/dev/null || true)

	if [ -s "$bridge_allowlist_entries" ]; then
		while IFS= read -r relative_path; do
			allowlisted_file="$root_dir/$relative_path"

			if [ ! -f "$allowlisted_file" ]; then
				fail "arch-check: allowlisted bridge path missing: $relative_path"
				continue
			fi

			if ! rg -q --glob '*.qml' --glob '*.js' '^\s*import .*system/' "$allowlisted_file"; then
				fail "arch-check: allowlisted bridge path does not import system/: $relative_path"
			fi

			if ! grep -q 'ARCH-EXCEPTION' "$allowlisted_file"; then
				fail "arch-check: allowlisted bridge path is missing ARCH-EXCEPTION metadata: $relative_path"
			fi
		done <"$bridge_allowlist_entries"
	fi

	if [ -n "$legacy_import_files" ]; then
		for import_file in $legacy_import_files; do
			relative_path=$(printf '%s\n' "$import_file" | sed "s|^$root_dir/||")
			if ! grep -Fxq "$relative_path" "$bridge_allowlist_entries"; then
				fail "arch-check: legacy runtime import from system/ must be allowlisted: $relative_path"
			fi
		done
	fi
}

for agents_file in \
	"$root_dir/AGENTS.md" \
	"$system_dir/AGENTS.md" \
	"$system_dir/core/AGENTS.md" \
	"$system_dir/adapters/AGENTS.md" \
	"$system_dir/ui/AGENTS.md"; do
	check_path_exists "$agents_file"
	check_agents_metadata "$agents_file"
	check_agents_linked_adrs "$agents_file"
done

check_path_exists "$system_dir/ui/bridges"
check_path_exists "$legacy_bridge_allowlist"
load_bridge_allowlist_entries
check_shell_bootstrap_contract
check_path_absent "$root_dir/components" "legacy components directory must stay removed after cutover"
check_path_absent "$root_dir/modules" "legacy modules directory must stay removed after cutover"
check_no_editor_backup_artifacts "$root_dir"

for required_path in \
	"$root_dir/package.json" \
	"$root_dir/package-lock.json" \
	"$root_dir/eslint.config.cjs" \
	"$root_dir/.prettierrc.json" \
	"$root_dir/.prettierignore" \
	"$root_dir/.taplo.toml" \
	"$root_dir/scripts/format.sh" \
	"$root_dir/scripts/lint.sh" \
	"$root_dir/scripts/lint-node.sh" \
	"$root_dir/scripts/lint-qml.sh" \
	"$root_dir/scripts/cutover-status.sh" \
	"$root_dir/scripts/integration-smoke.sh" \
	"$root_dir/scripts/shellctl" \
	"$root_dir/scripts/legacy-system-bridge-allowlist.txt" \
	"$root_dir/scripts/lintable-legacy-qml.txt" \
	"$root_dir/scripts/build-launcher-app-catalog.py" \
	"$root_dir/scripts/review.sh" \
	"$root_dir/scripts/review.js" \
	"$root_dir/scripts/migration-check.sh" \
	"$root_dir/scripts/refresh-review-evidence.sh" \
	"$repo_root/.github/workflows/quickshell-verify.yml"; do
	check_path_exists "$required_path"
done

for example_path in \
	"$system_dir/core/contracts/operation-outcome.js" \
	"$system_dir/core/contracts/launcher-contracts.js" \
	"$system_dir/core/contracts/compositor-contracts.js" \
	"$system_dir/core/contracts/ipc-command-contracts.js" \
	"$system_dir/core/contracts/settings-contracts.js" \
	"$system_dir/core/contracts/notification-contracts.js" \
	"$system_dir/core/contracts/theme-contracts.js" \
	"$system_dir/core/domain/launcher/launcher-store.js" \
	"$system_dir/core/domain/compositor/workspace-store.js" \
	"$system_dir/core/domain/settings/settings-store.js" \
	"$system_dir/core/domain/notifications/notification-store.js" \
	"$system_dir/core/application/launcher/run-launcher-search.js" \
	"$system_dir/core/application/launcher/activate-launcher-item.js" \
	"$system_dir/core/application/compositor/sync-workspace-snapshots.js" \
	"$system_dir/core/application/ipc/dispatch-shell-command.js" \
	"$system_dir/core/application/settings/hydrate-settings.js" \
	"$system_dir/core/application/settings/update-settings.js" \
	"$system_dir/core/application/settings/persist-settings.js" \
	"$system_dir/core/application/notifications/ingest-notification.js" \
	"$system_dir/core/application/notifications/activate-notification-entry.js" \
	"$system_dir/core/application/notifications/clear-notification-history.js" \
	"$system_dir/core/application/notifications/clear-notification-entry.js" \
	"$system_dir/core/application/notifications/dismiss-notification-popup.js" \
	"$system_dir/core/application/notifications/mark-all-notifications-read.js" \
	"$system_dir/core/application/notifications/expire-notification-popups.js" \
	"$system_dir/core/ports/shell-command-port.js" \
	"$system_dir/core/ports/command-execution-port.js" \
	"$system_dir/core/ports/persistence-port.js" \
	"$system_dir/core/ports/theme-provider-port.js" \
	"$system_dir/core/policies/launcher/launcher-scoring-policy.js" \
	"$system_dir/core/selectors/launcher/select-launcher-sections.js" \
	"$system_dir/core/selectors/bar/select-bar-workspace-strip.js" \
	"$system_dir/adapters/search/example-launcher-search-adapter.js" \
	"$system_dir/adapters/search/system-launcher-search-adapter.js" \
	"$system_dir/adapters/search/desktop-app-catalog-model.js" \
	"$system_dir/adapters/search/DesktopAppCatalogAdapter.qml" \
	"$system_dir/adapters/persistence/FilePersistenceAdapter.qml" \
	"$system_dir/adapters/persistence/in-memory-persistence-adapter.js" \
	"$system_dir/adapters/persistence/settings-file-migrations.js" \
	"$system_dir/adapters/theming/static-theme-provider.js" \
	"$system_dir/adapters/theming/matugen-theme-provider.js" \
	"$system_dir/adapters/hyprland/workspace-snapshot-adapter.js" \
	"$system_dir/adapters/notifications/NotificationServerAdapter.qml" \
	"$system_dir/adapters/notifications/notification-server-model.js" \
	"$system_dir/adapters/quickshell/ShellIpcAdapter.qml" \
	"$system_dir/ui/bridges/HyprlandWorkspaceBridge.qml" \
	"$system_dir/ui/bridges/NotificationBridge.qml" \
	"$system_dir/ui/bridges/ShellChromeBridge.qml" \
	"$system_dir/ui/bridges/ThemeBridge.qml" \
	"$system_dir/ui/modules/bar/BarPresentationModel.qml" \
	"$system_dir/ui/modules/bar/BarScreen.qml" \
	"$system_dir/ui/modules/launcher/LauncherPresentationModel.qml" \
	"$system_dir/ui/modules/notifications/NotificationPopups.qml"; do
	check_path_exists "$example_path"
done

check_legacy_system_bridge_allowlist

check_no_match \
	"system/ imports from legacy runtime modules or services" \
	--glob '*.qml' --glob '*.js' \
	'^\s*import .*([.][.]/)+(modules|services|components|Theme\.qml|shell\.qml)' \
	"$system_dir"

check_no_match \
	"forbidden hyprctl usage under system outside adapters/hyprland" \
	--glob '*.qml' --glob '*.js' \
	-g '!**/adapters/hyprland/**' \
	'hyprctl' \
	"$system_dir"

check_no_match \
	"forbidden Hyprland.dispatch usage under system outside adapters/hyprland and ui/bridges" \
	--glob '*.qml' --glob '*.js' \
	-g '!**/adapters/hyprland/**' \
	-g '!**/ui/bridges/**' \
	'Hyprland\.dispatch\s*\(' \
	"$system_dir"

check_no_match \
	"forbidden execDetached usage under system outside adapters/quickshell" \
	--glob '*.qml' --glob '*.js' \
	-g '!**/adapters/quickshell/**' \
	'execDetached\s*\(' \
	"$system_dir"

check_no_match \
	"forbidden qs.services imports under system/ui outside ui/bridges" \
	--glob '*.qml' \
	-g '!**/ui/bridges/**' \
	'^\s*import qs\.services' \
	"$system_dir/ui"

check_no_match \
	"core importing ui/" \
	--glob '*.qml' --glob '*.js' \
	'^\s*import .*ui/' \
	"$system_dir/core"

check_no_match \
	"adapters importing ui/" \
	--glob '*.qml' --glob '*.js' \
	'^\s*import .*ui/' \
	"$system_dir/adapters"

find "$root_dir" -type f \( -name '*.md' -o -name '*.qml' -o -name '*.js' \) -exec grep -l 'ARCH-EXCEPTION' {} + >"$exception_list" || true

while IFS= read -r exception_path; do
	if grep -q 'ARCH-EXCEPTION' "$exception_path"; then
		check_exception_metadata "$exception_path"
	fi
done <"$exception_list"

if [ "$failed" -ne 0 ]; then
	exit 1
fi

printf '%s\n' "arch-check: ok"

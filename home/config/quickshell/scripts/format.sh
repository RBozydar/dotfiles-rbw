#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root_dir=$(dirname "$script_dir")
repo_root=$(git -C "$root_dir" rev-parse --show-toplevel 2>/dev/null || printf '%s\n' "$root_dir")
node_bin_dir="$root_dir/node_modules/.bin"
prettier_bin="$node_bin_dir/prettier"
taplo_bin="$node_bin_dir/taplo"
legacy_qml_allowlist="$script_dir/lintable-legacy-qml.txt"
check_mode=0
failed=0

find_qt_tool() {
	primary=$1

	for candidate in "$primary" "${primary}-qt6" "${primary}6"; do
		if command -v "$candidate" >/dev/null 2>&1; then
			command -v "$candidate"
			return 0
		fi
	done

	return 1
}

resolve_qmlformat() {
	if [ -n "${QMLFORMAT_BIN:-}" ]; then
		if [ -x "$QMLFORMAT_BIN" ]; then
			printf '%s\n' "$QMLFORMAT_BIN"
			return 0
		fi

		printf '%s\n' "format: qmlformat override is not executable: $QMLFORMAT_BIN" >&2
		return 1
	fi

	if [ -x /usr/lib/qt6/bin/qmlformat ]; then
		printf '%s\n' /usr/lib/qt6/bin/qmlformat
		return 0
	fi

	find_qt_tool qmlformat
}

require_node_tool() {
	name=$1
	path=$2

	if [ ! -x "$path" ]; then
		printf '%s\n' "format: missing $name at $path. Run npm install in $root_dir" >&2
		exit 1
	fi
}

collect_files() {
	if [ "$#" -eq 0 ]; then
		return 0
	fi

	rg --files "$@" 2>/dev/null || true
}

append_file_if_exists() {
	list=$1
	candidate=$2

	if [ -f "$candidate" ]; then
		if [ -n "$list" ]; then
			printf '%s\n%s\n' "$list" "$candidate"
		else
			printf '%s\n' "$candidate"
		fi
		return 0
	fi

	printf '%s' "$list"
}

check_qml_file() {
	qmlformat_bin=$1
	file=$2
	tmp_file=$(mktemp)

	"$qmlformat_bin" "$file" >"$tmp_file"

	if ! cmp -s "$file" "$tmp_file"; then
		printf '%s\n' "format: qml needs formatting: $file" >&2
		failed=1
	fi

	rm -f "$tmp_file"
}

if [ "${1:-}" = "--check" ]; then
	check_mode=1
elif [ "$#" -gt 0 ]; then
	printf '%s\n' "usage: $(basename "$0") [--check]" >&2
	exit 1
fi

qmlformat_bin=$(resolve_qmlformat || true)
if [ -z "$qmlformat_bin" ]; then
	printf '%s\n' "format: qmlformat is required" >&2
	exit 1
fi

if ! command -v shfmt >/dev/null 2>&1; then
	printf '%s\n' "format: shfmt is required" >&2
	exit 1
fi

require_node_tool prettier "$prettier_bin"
require_node_tool taplo "$taplo_bin"

qml_files=$(rg --files "$root_dir/system" "$root_dir/tests" -g '*.qml' 2>/dev/null || true)
prettier_files=$(rg --files "$root_dir" -g '*.js' -g '*.json' -g '*.md' -g '*.yaml' -g '*.yml' -g '*.cjs' -g '*.mjs' 2>/dev/null || true)
prettier_files=$(append_file_if_exists "$prettier_files" "$repo_root/.github/workflows/quickshell-verify.yml")
toml_files=$(rg --files "$root_dir" -g '*.toml' -g '!uv.lock' 2>/dev/null || true)
shell_files=$(rg --files "$root_dir/scripts" -g '*.sh' 2>/dev/null || true)
shell_files=$(append_file_if_exists "$shell_files" "$root_dir/scripts/shellctl")

if [ -f "$legacy_qml_allowlist" ]; then
	while IFS= read -r relative_path; do
		[ -n "$relative_path" ] || continue
		legacy_file="$root_dir/$relative_path"
		if [ ! -f "$legacy_file" ]; then
			continue
		fi
		if [ -n "$qml_files" ]; then
			qml_files=$(printf '%s\n%s\n' "$qml_files" "$legacy_file")
		else
			qml_files=$legacy_file
		fi
	done <"$legacy_qml_allowlist"
fi

if [ -n "$qml_files" ]; then
	if [ "$check_mode" -eq 1 ]; then
		for file in $qml_files; do
			check_qml_file "$qmlformat_bin" "$file"
		done
	else
		# shellcheck disable=SC2086
		"$qmlformat_bin" -i $qml_files
	fi
fi

if [ -n "$prettier_files" ]; then
	if [ "$check_mode" -eq 1 ]; then
		# shellcheck disable=SC2086
		"$prettier_bin" --config "$root_dir/.prettierrc.json" --ignore-path "$root_dir/.prettierignore" --check $prettier_files
	else
		# shellcheck disable=SC2086
		"$prettier_bin" --config "$root_dir/.prettierrc.json" --ignore-path "$root_dir/.prettierignore" --write $prettier_files
	fi
fi

if [ -n "$toml_files" ]; then
	if [ "$check_mode" -eq 1 ]; then
		# shellcheck disable=SC2086
		"$taplo_bin" format --check $toml_files
	else
		# shellcheck disable=SC2086
		"$taplo_bin" format $toml_files
	fi
fi

if [ -n "$shell_files" ]; then
	if [ "$check_mode" -eq 1 ]; then
		# shellcheck disable=SC2086
		shfmt -d $shell_files
	else
		# shellcheck disable=SC2086
		shfmt -w $shell_files
	fi
fi

if [ "$failed" -ne 0 ]; then
	exit 1
fi

printf '%s\n' "format: ok"

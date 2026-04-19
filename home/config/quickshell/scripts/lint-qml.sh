#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root_dir=$(dirname "$script_dir")
legacy_qml_allowlist="$script_dir/lintable-legacy-qml.txt"

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

resolve_qmllint() {
	if [ -n "${QMLLINT_BIN:-}" ]; then
		if [ -x "$QMLLINT_BIN" ]; then
			printf '%s\n' "$QMLLINT_BIN"
			return 0
		fi

		printf '%s\n' "lint-qml: qmllint override is not executable: $QMLLINT_BIN" >&2
		return 1
	fi

	if [ -x /usr/lib/qt6/bin/qmllint ]; then
		printf '%s\n' /usr/lib/qt6/bin/qmllint
		return 0
	fi

	find_qt_tool qmllint
}

qmllint_bin=$(resolve_qmllint || true)
if [ -z "$qmllint_bin" ]; then
	printf '%s\n' "lint-qml: qmllint is required" >&2
	exit 1
fi

qml_files=$(rg --files "$root_dir/system" "$root_dir/tests" -g '*.qml' 2>/dev/null || true)

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

if [ -z "$qml_files" ]; then
	printf '%s\n' "lint-qml: no QML files found"
	exit 0
fi

# shellcheck disable=SC2086
"$qmllint_bin" --max-warnings 0 --uncreatable-type=info --signal-handler-parameters=info -I "$root_dir" $qml_files

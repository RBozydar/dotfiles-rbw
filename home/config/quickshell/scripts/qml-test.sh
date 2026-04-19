#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root_dir=$(dirname "$script_dir")

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

resolve_qmltestrunner() {
	if [ -n "${QMLTESTRUNNER_BIN:-}" ]; then
		if [ -x "$QMLTESTRUNNER_BIN" ]; then
			printf '%s\n' "$QMLTESTRUNNER_BIN"
			return 0
		fi

		printf '%s\n' "qmltestrunner override is not executable: $QMLTESTRUNNER_BIN" >&2
		return 1
	fi

	if [ -x /usr/lib/qt6/bin/qmltestrunner ]; then
		printf '%s\n' /usr/lib/qt6/bin/qmltestrunner
		return 0
	fi

	find_qt_tool qmltestrunner
}

qmltestrunner_bin=$(resolve_qmltestrunner || true)
if [ -z "$qmltestrunner_bin" ]; then
	printf '%s\n' "qmltestrunner is required for Quickshell QML tests" >&2
	exit 1
fi

export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}"

exec "$qmltestrunner_bin" -input "$root_dir/tests" -import "$root_dir" -o -,txt

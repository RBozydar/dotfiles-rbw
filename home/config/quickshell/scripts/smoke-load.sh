#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root_dir=$(dirname "$script_dir")
log_file=$(mktemp)
status=0

cleanup() {
	rm -f "$log_file"
}

trap cleanup EXIT INT TERM

if ! command -v qs >/dev/null 2>&1; then
	printf '%s\n' "qs is required for the Quickshell smoke test" >&2
	exit 1
fi

if ! command -v timeout >/dev/null 2>&1; then
	printf '%s\n' "timeout is required for the Quickshell smoke test" >&2
	exit 1
fi

if [ -z "${WAYLAND_DISPLAY-}" ] && [ -z "${DISPLAY-}" ]; then
	printf '%s\n' "Quickshell smoke test requires a live graphical session (WAYLAND_DISPLAY or DISPLAY)." >&2
	exit 1
fi

if ! timeout 5s qs -p "$root_dir" >"$log_file" 2>&1; then
	status=$?
fi

case "$status" in
0 | 124)
	;;
*)
	cat "$log_file" >&2
	exit "$status"
	;;
esac

if ! grep -q "Configuration Loaded" "$log_file"; then
	cat "$log_file" >&2
	printf '%s\n' "Quickshell smoke test did not reach Configuration Loaded" >&2
	exit 1
fi

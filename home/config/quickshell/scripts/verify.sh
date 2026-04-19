#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
review_args=
require_smoke=
allow_smoke_skip="${VERIFY_ALLOW_SMOKE_SKIP:-0}"

if [ "${CODEX_SANDBOX_NETWORK_DISABLED:-0}" = "1" ] && [ "${VERIFY_ALLOW_SANDBOX:-0}" != "1" ]; then
	printf '%s\n' "verify: refusing to run in Codex sandbox. Run outside sandbox (or set VERIFY_ALLOW_SANDBOX=1)." >&2
	exit 1
fi

if [ "${CI:-}" = "1" ] || [ "${CI:-}" = "true" ]; then
	review_args="--classify-only"
	require_smoke=0
else
	review_args="--require-secondary"
	require_smoke="${VERIFY_REQUIRE_SMOKE:-1}"
fi

integration_require_live=0
if [ "$require_smoke" = "1" ] && [ "$allow_smoke_skip" != "1" ]; then
	integration_require_live=1
fi

printf '%s\n' "[1/8] format check"
sh "$script_dir/format.sh" --check

printf '%s\n' "[2/8] lint"
"$script_dir/lint.sh"

printf '%s\n' "[3/8] architecture checks"
"$script_dir/arch-check.sh"

printf '%s\n' "[4/8] cutover status"
sh "$script_dir/cutover-status.sh"

printf '%s\n' "[5/8] tests"
"$script_dir/python-check.sh"
"$script_dir/qml-test.sh"

printf '%s\n' "[6/8] smoke"
if [ -n "${WAYLAND_DISPLAY-}" ] || [ -n "${DISPLAY-}" ]; then
	smoke_log=$(mktemp)
	smoke_status=0
	if ! "$script_dir/smoke-load.sh" >"$smoke_log" 2>&1; then
		smoke_status=$?
	fi

	if [ "$smoke_status" -eq 0 ]; then
		:
	elif grep -Eq 'Failed to create wl_display \(Operation not permitted\)|Could not load the Qt platform plugin|Could not create instance runtime directory' "$smoke_log"; then
		if [ "$require_smoke" = "1" ] && [ "$allow_smoke_skip" != "1" ]; then
			cat "$smoke_log" >&2
			rm -f "$smoke_log"
			printf '%s\n' "verify: smoke failed due environment restrictions. Run verify outside sandbox (or set VERIFY_ALLOW_SMOKE_SKIP=1)." >&2
			exit 1
		fi
		printf '%s\n' "verify: smoke skipped (environment does not permit live graphical smoke)."
	else
		cat "$smoke_log" >&2
		rm -f "$smoke_log"
		exit "$smoke_status"
	fi
	rm -f "$smoke_log"
elif [ "$require_smoke" = "1" ] && [ "$allow_smoke_skip" != "1" ]; then
	printf '%s\n' "verify: smoke required but no live graphical session detected. Run verify on host (or set VERIFY_ALLOW_SMOKE_SKIP=1)." >&2
	exit 1
else
	printf '%s\n' "verify: smoke skipped (no live graphical session)."
fi

printf '%s\n' "[7/8] integration diagnostics"
INTEGRATION_SMOKE_REQUIRE_LIVE="$integration_require_live" sh "$script_dir/integration-smoke.sh"

printf '%s\n' "[8/8] review"
# shellcheck disable=SC2086
"$script_dir/review.sh" $review_args

printf '%s\n' "verify: ok"

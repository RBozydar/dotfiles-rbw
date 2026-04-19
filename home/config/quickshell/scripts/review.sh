#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root_dir=$(dirname "$script_dir")
repo_root=$(git -C "$root_dir" rev-parse --show-toplevel)
status_file=$(mktemp)
numstat_file=$(mktemp)
root_rel=${root_dir#"$repo_root"/}
review_mode=worktree

cleanup() {
	rm -f "$status_file" "$numstat_file"
}

trap cleanup EXIT INT TERM

if [ -n "${REVIEW_BASE_REF:-}" ] && [ -n "${REVIEW_HEAD_REF:-}" ]; then
	review_mode=range
	git -C "$repo_root" diff --name-status --find-renames "$REVIEW_BASE_REF" "$REVIEW_HEAD_REF" -- \
		"$root_rel" ".github/workflows/quickshell-verify.yml" >"$status_file"
	git -C "$repo_root" diff --numstat "$REVIEW_BASE_REF" "$REVIEW_HEAD_REF" -- \
		"$root_rel" ".github/workflows/quickshell-verify.yml" >"$numstat_file"
else
	git -C "$repo_root" status --porcelain=v1 --untracked-files=all >"$status_file"
	git -C "$repo_root" diff --numstat -- "$root_rel" ".github/workflows/quickshell-verify.yml" >"$numstat_file"
fi

exec env REVIEW_REPO_ROOT="$repo_root" REVIEW_STATUS_FILE="$status_file" REVIEW_NUMSTAT_FILE="$numstat_file" \
	REVIEW_MODE="$review_mode" REVIEW_BASE_REF="${REVIEW_BASE_REF:-}" REVIEW_HEAD_REF="${REVIEW_HEAD_REF:-}" \
	node "$script_dir/review.js" "$@"

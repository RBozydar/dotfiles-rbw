#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root_dir=$(dirname "$script_dir")
eslint_bin="$root_dir/node_modules/.bin/eslint"

if [ ! -x "$eslint_bin" ]; then
	printf '%s\n' "lint-node: missing eslint at $eslint_bin. Run npm install in $root_dir" >&2
	exit 1
fi

"$eslint_bin" --max-warnings=0 "$root_dir/services" "$root_dir/scripts" "$root_dir/system"

#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root_dir=$(dirname "$script_dir")

if ! command -v qmltestrunner >/dev/null 2>&1; then
    printf '%s\n' "qmltestrunner is required for Quickshell QML tests" >&2
    exit 1
fi

export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}"

exec qmltestrunner -input "$root_dir/tests" -import "$root_dir" -o -,txt

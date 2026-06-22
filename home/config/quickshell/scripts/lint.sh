#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

printf '%s\n' "[1/4] QML lint"
"$script_dir/lint-qml.sh"

printf '%s\n' "[2/4] qmllint directive policy"
"$script_dir/lint-qmllint-directives.sh"

printf '%s\n' "[3/4] JavaScript lint"
"$script_dir/lint-node.sh"

printf '%s\n' "[4/4] shell lint"
"$script_dir/lint-shell.sh"

printf '%s\n' "lint: ok"

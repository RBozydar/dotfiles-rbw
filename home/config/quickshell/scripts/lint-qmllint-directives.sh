#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root_dir=$(dirname "$script_dir")
legacy_qml_allowlist="$script_dir/lintable-legacy-qml.txt"

qml_files=$(rg --files "$root_dir/system" "$root_dir/tests" -g '*.qml' 2>/dev/null || true)

if [ -f "$legacy_qml_allowlist" ]; then
	while IFS= read -r relative_path; do
		[ -n "$relative_path" ] || continue
		legacy_file="$root_dir/$relative_path"
		[ -f "$legacy_file" ] || continue
		if [ -n "$qml_files" ]; then
			qml_files=$(printf '%s\n%s\n' "$qml_files" "$legacy_file")
		else
			qml_files=$legacy_file
		fi
	done <"$legacy_qml_allowlist"
fi

if [ -z "$qml_files" ]; then
	printf '%s\n' "lint-qmllint-directives: no QML files found"
	exit 0
fi

status=0

for qml_file in $qml_files; do
	if ! awk '
function trim(s) {
	gsub(/^[[:space:]]+/, "", s)
	gsub(/[[:space:]]+$/, "", s)
	return s
}

function parse_rules(raw, tokens, line_num, action,     n, i, token) {
	raw = trim(raw)

	if (raw == "") {
		printf("%s:%d: qmllint %s must name explicit rule(s)\n", FILENAME, line_num, action) > "/dev/stderr"
		errors = 1
		return ""
	}

	n = split(raw, tokens, /[[:space:]]+/)

	if (n > 3) {
		printf("%s:%d: qmllint %s lists %d rules (max 3)\n", FILENAME, line_num, action, n) > "/dev/stderr"
		errors = 1
	}

	joined = ""
	for (i = 1; i <= n; i++) {
		token = tokens[i]

		if (token == "all" || token == "*") {
			printf("%s:%d: qmllint %s uses forbidden broad token \"%s\"\n", FILENAME, line_num, action, token) > "/dev/stderr"
			errors = 1
		}

		if (token !~ /^[a-z][a-z0-9-]*$/) {
			printf("%s:%d: qmllint %s contains invalid rule token \"%s\"\n", FILENAME, line_num, action, token) > "/dev/stderr"
			errors = 1
		}

		if (joined != "")
			joined = joined " "
		joined = joined token
	}

	return joined
}

BEGIN {
	errors = 0
	stack_size = 0
}

{
	if ($0 ~ /qmllint[[:space:]]+disable([[:space:]]|$)/) {
		disable_line = $0
		sub(/^.*qmllint[[:space:]]+disable[[:space:]]*/, "", disable_line)
		key = parse_rules(disable_line, disable_tokens, FNR, "disable")
		if (key != "") {
			stack_size++
			stack_key[stack_size] = key
			stack_line[stack_size] = FNR
		}
	}

	if ($0 ~ /qmllint[[:space:]]+enable([[:space:]]|$)/) {
		enable_line = $0
		sub(/^.*qmllint[[:space:]]+enable[[:space:]]*/, "", enable_line)
		key = parse_rules(enable_line, enable_tokens, FNR, "enable")

		if (key != "") {
				if (stack_size == 0) {
					printf("%s:%d: qmllint enable \"%s\" has no matching disable\n", FILENAME, FNR, key) > "/dev/stderr"
					errors = 1
				} else if (stack_key[stack_size] != key) {
					printf("%s:%d: qmllint enable \"%s\" does not match nearest disable \"%s\" at line %d\n", FILENAME, FNR, key, stack_key[stack_size], stack_line[stack_size]) > "/dev/stderr"
					errors = 1
					stack_size--
				} else {
					stack_size--
				}
		}
	}
}

END {
	while (stack_size > 0) {
		printf("%s:%d: qmllint disable \"%s\" is not re-enabled\n", FILENAME, stack_line[stack_size], stack_key[stack_size]) > "/dev/stderr"
		errors = 1
		stack_size--
	}

	exit errors ? 1 : 0
}
' "$qml_file"; then
		status=1
	fi
done

if [ "$status" -ne 0 ]; then
	printf '%s\n' "lint-qmllint-directives: failed"
	exit 1
fi

printf '%s\n' "lint-qmllint-directives: ok"

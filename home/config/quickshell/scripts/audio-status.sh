#!/bin/sh

set -eu

emit_unavailable() {
	error_message=$1
	printf '{"available":false,"defaultOutput":"","defaultInput":"","outputs":[],"inputs":[],"error":"%s"}\n' "$error_message"
}

if ! command -v pactl >/dev/null 2>&1; then
	emit_unavailable "pactl unavailable"
	exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
	emit_unavailable "jq unavailable"
	exit 0
fi

default_output=$(pactl get-default-sink 2>/dev/null || true)
default_input=$(pactl get-default-source 2>/dev/null || true)
sinks_json=$(pactl --format=json list sinks 2>/dev/null || true)
sources_json=$(pactl --format=json list sources 2>/dev/null || true)

if [ -z "$sinks_json" ]; then
	sinks_json='[]'
fi

if [ -z "$sources_json" ]; then
	sources_json='[]'
fi

if ! printf '%s' "$sinks_json" | jq empty >/dev/null 2>&1; then
	sinks_json='[]'
fi

if ! printf '%s' "$sources_json" | jq empty >/dev/null 2>&1; then
	sources_json='[]'
fi

jq -cn \
	--arg defaultOutput "$default_output" \
	--arg defaultInput "$default_input" \
	--argjson sinks "$sinks_json" \
	--argjson sources "$sources_json" '
	{
		available: true,
		defaultOutput: $defaultOutput,
		defaultInput: $defaultInput,
		outputs: (
			$sinks
			| map({
				id: (.name // ""),
				description: (.description // .properties["device.description"] // .properties["node.description"] // .name // "output"),
				muted: (.mute // false),
				state: (.state // "UNKNOWN"),
				isDefault: ((.name // "") == $defaultOutput)
			})
			| map(select(.id != ""))
		),
		inputs: (
			$sources
			| map(select(((.name // "") | endswith(".monitor")) | not))
			| map({
				id: (.name // ""),
				description: (.description // .properties["device.description"] // .properties["node.description"] // .name // "input"),
				muted: (.mute // false),
				state: (.state // "UNKNOWN"),
				isDefault: ((.name // "") == $defaultInput)
			})
			| map(select(.id != ""))
		),
		error: ""
	}
	| .available = ((.outputs | length) > 0 or (.inputs | length) > 0)
'

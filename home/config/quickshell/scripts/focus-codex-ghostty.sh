#!/bin/sh

set -eu

if ! command -v hyprctl >/dev/null 2>&1; then
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    exit 1
fi

target=$(
    hyprctl clients -j | jq -r '
        map(select(.mapped == true and .class == "com.mitchellh.ghostty")) as $ghostty
        | (
            $ghostty
            | map(select((.title | ascii_downcase | contains("codex")) or (.title | ascii_downcase | contains("repo/codex"))))
            + $ghostty
          )
        | unique_by(.address)
        | .[0]
        | if . == null then empty else "\(.workspace.id) \(.address)" end
    '
)

[ -n "$target" ]

workspace_id=${target%% *}
window_address=${target#* }

hyprctl dispatch workspace "$workspace_id" >/dev/null
hyprctl dispatch focuswindow "address:$window_address" >/dev/null

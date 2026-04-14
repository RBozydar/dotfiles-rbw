#!/bin/sh

set -eu

runtime_dir="/run/user/$(id -u)"
hypr_dir="$runtime_dir/hypr"

resolve_signature() {
    for path in $(ls -td "$hypr_dir"/* 2>/dev/null); do
        if [ -S "$path/.socket.sock" ]; then
            basename "$path"
            return 0
        fi
    done

    return 1
}

HYPRLAND_INSTANCE_SIGNATURE="$(resolve_signature)"
export HYPRLAND_INSTANCE_SIGNATURE

exec hyprctl dispatch exec "pkill -x qs || true; qs"

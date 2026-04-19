#!/bin/sh

set -eu

script_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
root_dir=$(dirname "$script_dir")
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

shellctl_cmd="$root_dir/scripts/shellctl"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
state_path="$state_home/rbw-shell.settings.state.json"
default_wallpaper_path="${RBW_WALLPAPER_DEFAULT_PATH:-$root_dir/../../../wallpapers/m31.jpg}"

resolve_wallpaper_from_state() {
	if [ ! -f "$state_path" ]; then
		return 0
	fi

	if ! command -v python3 >/dev/null 2>&1; then
		return 0
	fi

	python3 - "$state_path" <<'PY'
import json
import sys
from pathlib import Path

path = ""
state_file = Path(sys.argv[1])

try:
    payload = json.loads(state_file.read_text())
    wallpaper = payload.get("wallpaper", {})
    history = wallpaper.get("history", [])
    if isinstance(history, list) and history:
        cursor = wallpaper.get("cursor")
        if not isinstance(cursor, int):
            cursor = len(history) - 1
        if cursor < 0:
            cursor = 0
        if cursor >= len(history):
            cursor = len(history) - 1
        entry = history[cursor]
        if isinstance(entry, dict):
            candidate = entry.get("path", "")
            if isinstance(candidate, str):
                candidate = candidate.strip()
                if candidate.startswith("/"):
                    path = candidate
except Exception:
    path = ""

print(path)
PY
}

apply_wallpaper_direct() {
	path=$1
	if [ -z "$path" ] || [ ! -f "$path" ]; then
		return 1
	fi

	if command -v swww >/dev/null 2>&1; then
		swww query >/dev/null 2>&1 || { command -v swww-daemon >/dev/null 2>&1 && swww-daemon >/dev/null 2>&1 & sleep 0.2; }
		swww img "$path" >/dev/null 2>&1 && return 0
	fi

	if command -v awww >/dev/null 2>&1; then
		awww query >/dev/null 2>&1 || { command -v awww-daemon >/dev/null 2>&1 && awww-daemon >/dev/null 2>&1 & sleep 0.2; }
		awww img "$path" >/dev/null 2>&1 && return 0
	fi

	return 1
}

persisted_wallpaper_path="$(resolve_wallpaper_from_state || true)"
restore_wallpaper_path=""
if [ -n "$persisted_wallpaper_path" ] && [ -f "$persisted_wallpaper_path" ]; then
	restore_wallpaper_path="$persisted_wallpaper_path"
elif [ -n "$default_wallpaper_path" ] && [ -f "$default_wallpaper_path" ]; then
	restore_wallpaper_path="$default_wallpaper_path"
fi

hyprctl dispatch exec "pkill -x mako || true; pkill -x dunst || true; pkill -x swaync || true; pkill -x qs || true; qs -p $root_dir"

if [ ! -x "$shellctl_cmd" ]; then
	[ -n "$restore_wallpaper_path" ] && apply_wallpaper_direct "$restore_wallpaper_path" || true
	exit 0
fi

attempt=0
until "$shellctl_cmd" --path "$root_dir" --target shell commands >/dev/null 2>&1; do
	attempt=$((attempt + 1))
	if [ "$attempt" -ge 50 ]; then
		exit 0
	fi
	sleep 0.1
done

if [ -n "$restore_wallpaper_path" ] && [ -f "$restore_wallpaper_path" ]; then
	apply_wallpaper_direct "$restore_wallpaper_path" || true

	set_attempt=0
	until "$shellctl_cmd" --path "$root_dir" --target shell wallpaper.set "$restore_wallpaper_path" >/dev/null 2>&1; do
		set_attempt=$((set_attempt + 1))
		if [ "$set_attempt" -ge 40 ]; then
			break
		fi
		sleep 0.1
	done

	"$shellctl_cmd" --path "$root_dir" --target shell settings.persist >/dev/null 2>&1 || true
fi

#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import stat
import sys
import tempfile
from pathlib import Path
from typing import Any


HOOK_EVENT_KEYS = {
    "SessionStart",
    "PreToolUse",
    "PostToolUse",
    "Notification",
    "Stop",
    "SubagentStop",
    "UserPromptSubmit",
}


def merge_hook_list(current: list[Any], desired: list[Any]) -> bool:
    changed = False

    for desired_entry in desired:
        if not isinstance(desired_entry, dict):
            if desired_entry not in current:
                current.append(desired_entry)
                changed = True
            continue

        matcher = desired_entry.get("matcher")
        desired_hooks = desired_entry.get("hooks")
        matching_entries = [
            current_entry
            for current_entry in current
            if (
                isinstance(current_entry, dict)
                and current_entry.get("matcher") == matcher
                and isinstance(current_entry.get("hooks"), list)
            )
        ]

        if not matching_entries:
            current.append(desired_entry)
            changed = True
            continue

        if not isinstance(desired_hooks, list):
            changed = merge_value(matching_entries[0], desired_entry) or changed
            continue

        for desired_hook in desired_hooks:
            if not isinstance(desired_hook, dict) or "command" not in desired_hook:
                current_hooks = matching_entries[0]["hooks"]
                if desired_hook not in current_hooks:
                    current_hooks.append(desired_hook)
                    changed = True
                continue

            existing_hook = None
            for current_entry in matching_entries:
                existing_hook = next(
                    (
                        current_hook
                        for current_hook in current_entry["hooks"]
                        if isinstance(current_hook, dict)
                        and current_hook.get("command") == desired_hook.get("command")
                    ),
                    None,
                )
                if existing_hook is not None:
                    break

            if existing_hook is None:
                matching_entries[0]["hooks"].append(desired_hook)
                changed = True
            else:
                changed = merge_value(existing_hook, desired_hook) or changed

    return changed


def merge_list(current: list[Any], desired: list[Any]) -> bool:
    changed = False
    for item in desired:
        if item not in current:
            current.append(item)
            changed = True
    return changed


def merge_value(current: Any, desired: Any) -> bool:
    if isinstance(current, dict) and isinstance(desired, dict):
        changed = False
        for key, desired_value in desired.items():
            if key not in current:
                current[key] = desired_value
                changed = True
                continue

            current_value = current[key]
            if isinstance(current_value, dict) and isinstance(desired_value, dict):
                changed = merge_value(current_value, desired_value) or changed
            elif key in HOOK_EVENT_KEYS and isinstance(current_value, list) and isinstance(desired_value, list):
                changed = merge_hook_list(current_value, desired_value) or changed
            elif isinstance(current_value, list) and isinstance(desired_value, list):
                changed = merge_list(current_value, desired_value) or changed
            elif current_value != desired_value:
                current[key] = desired_value
                changed = True

        return changed

    return False


def write_atomic(path: Path, content: str, mode: int | None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as tmp:
        tmp.write(content)
        tmp_path = Path(tmp.name)

    os.chmod(tmp_path, mode if mode is not None else 0o600)
    os.replace(tmp_path, path)


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: merge-settings.py /path/to/source.json /path/to/settings.json", file=sys.stderr)
        return 2

    source = Path(sys.argv[1]).expanduser()
    target = Path(sys.argv[2]).expanduser()

    desired = json.loads(source.read_text(encoding="utf-8"))
    target_was_symlink = target.is_symlink()
    existing_mode: int | None = None

    if target.exists():
        existing_mode = stat.S_IMODE(target.stat().st_mode)
        current = json.loads(target.read_text(encoding="utf-8"))
        changed = merge_value(current, desired)
    else:
        current = desired
        changed = True

    content = json.dumps(current, indent=2, sort_keys=False)
    content += "\n"

    if not changed and not target_was_symlink:
        print("ok")
        return 0

    write_atomic(target, content, existing_mode)
    print("changed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

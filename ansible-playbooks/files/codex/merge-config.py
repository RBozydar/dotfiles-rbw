#!/usr/bin/env python3

from __future__ import annotations

import json
import os
import stat
import sys
import tempfile
from collections import OrderedDict
from pathlib import Path


TOP_LEVEL_SETTINGS = OrderedDict(
    [
        ("model", "gpt-5.5"),
        ("model_reasoning_effort", "high"),
        ("approvals_reviewer", "auto_review"),
        ("sandbox_mode", "workspace-write"),
        ("personality", "pragmatic"),
    ]
)

SECTION_SETTINGS = OrderedDict(
    [
        (
            "features",
            OrderedDict(
                [
                    ("memories", True),
                    ("chronicle", True),
                ]
            ),
        ),
        (
            "desktop",
            OrderedDict(
                [
                    ("selected-avatar-id", "custom:tabbyneko"),
                ]
            ),
        ),
        (
            "sandbox_workspace_write",
            OrderedDict(
                [
                    ("network_access", True),
                ]
            ),
        ),
        (
            "memories",
            OrderedDict(
                [
                    ("generate_memories", True),
                    ("use_memories", True),
                ]
            ),
        ),
    ]
)


def format_value(value: str | bool) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    return json.dumps(value)


def setting_line(key: str, value: str | bool) -> str:
    return f"{key} = {format_value(value)}\n"


def section_name(line: str) -> str | None:
    stripped = line.strip()
    if stripped.startswith("[[") or not stripped.startswith("[") or not stripped.endswith("]"):
        return None
    return stripped[1:-1].strip()


def key_name(line: str) -> str | None:
    stripped = line.strip()
    if not stripped or stripped.startswith("#") or "=" not in stripped:
        return None
    return stripped.split("=", 1)[0].strip().strip('"')


def seed_config() -> list[str]:
    lines: list[str] = []
    for key, value in TOP_LEVEL_SETTINGS.items():
        lines.append(setting_line(key, value))

    for section, settings in SECTION_SETTINGS.items():
        lines.append("\n")
        lines.append(f"[{section}]\n")
        for key, value in settings.items():
            lines.append(setting_line(key, value))

    return lines


def section_ranges(lines: list[str]) -> dict[str, tuple[int, int]]:
    headers: list[tuple[str, int]] = []
    for index, line in enumerate(lines):
        name = section_name(line)
        if name is not None:
            headers.append((name, index))

    ranges: dict[str, tuple[int, int]] = {}
    for header_index, (name, start) in enumerate(headers):
        end = headers[header_index + 1][1] if header_index + 1 < len(headers) else len(lines)
        ranges.setdefault(name, (start, end))
    return ranges


def update_existing_lines(lines: list[str]) -> tuple[set[str], dict[str, set[str]]]:
    present_top_level: set[str] = set()
    present_by_section: dict[str, set[str]] = {section: set() for section in SECTION_SETTINGS}
    current_section: str | None = None

    for index, line in enumerate(lines):
        found_section = section_name(line)
        if found_section is not None:
            current_section = found_section
            continue

        found_key = key_name(line)
        if found_key is None:
            continue

        if current_section is None and found_key in TOP_LEVEL_SETTINGS:
            present_top_level.add(found_key)
            replacement = setting_line(found_key, TOP_LEVEL_SETTINGS[found_key])
            if line != replacement:
                lines[index] = replacement
            continue

        if current_section in SECTION_SETTINGS and found_key in SECTION_SETTINGS[current_section]:
            present_by_section[current_section].add(found_key)
            replacement = setting_line(found_key, SECTION_SETTINGS[current_section][found_key])
            if line != replacement:
                lines[index] = replacement

    return present_top_level, present_by_section


def insert_top_level_missing(lines: list[str], missing_keys: list[str]) -> None:
    if not missing_keys:
        return

    insert_at = next((index for index, line in enumerate(lines) if section_name(line) is not None), len(lines))
    new_lines = [setting_line(key, TOP_LEVEL_SETTINGS[key]) for key in missing_keys]

    if insert_at > 0 and lines[insert_at - 1].strip():
        new_lines.insert(0, "\n")
    if insert_at < len(lines) and new_lines[-1].strip():
        new_lines.append("\n")

    lines[insert_at:insert_at] = new_lines


def insert_section_missing(lines: list[str], present_by_section: dict[str, set[str]]) -> None:
    ranges = section_ranges(lines)

    for section in reversed(SECTION_SETTINGS):
        if section not in ranges:
            continue

        missing = [
            key for key in SECTION_SETTINGS[section] if key not in present_by_section.get(section, set())
        ]
        if not missing:
            continue

        _start, end = ranges[section]
        new_lines = [setting_line(key, SECTION_SETTINGS[section][key]) for key in missing]
        lines[end:end] = new_lines

    for section, settings in SECTION_SETTINGS.items():
        if section in ranges:
            continue

        if lines and lines[-1].strip():
            lines.append("\n")
        lines.append(f"\n[{section}]\n")
        for key, value in settings.items():
            lines.append(setting_line(key, value))


def merge(lines: list[str]) -> list[str]:
    present_top_level, present_by_section = update_existing_lines(lines)
    missing_top_level = [key for key in TOP_LEVEL_SETTINGS if key not in present_top_level]

    insert_top_level_missing(lines, missing_top_level)
    insert_section_missing(lines, present_by_section)
    return lines


def write_atomic(path: Path, content: str, mode: int | None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)

    with tempfile.NamedTemporaryFile("w", encoding="utf-8", dir=path.parent, delete=False) as tmp:
        tmp.write(content)
        tmp_path = Path(tmp.name)

    os.chmod(tmp_path, mode if mode is not None else 0o600)
    os.replace(tmp_path, path)


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: merge-config.py /path/to/config.toml", file=sys.stderr)
        return 2

    target = Path(sys.argv[1]).expanduser()
    existing_mode: int | None = None

    if target.exists():
        existing_mode = stat.S_IMODE(target.stat().st_mode)
        original = target.read_text(encoding="utf-8")
        updated = "".join(merge(original.splitlines(keepends=True)))
    else:
        original = ""
        updated = "".join(seed_config())

    if updated == original:
        print("ok")
        return 0

    write_atomic(target, updated, existing_mode)
    print("changed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

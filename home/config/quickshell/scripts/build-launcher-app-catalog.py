#!/usr/bin/env python3
"""Build a launcher app catalog from installed freedesktop desktop entries."""

from __future__ import annotations

import configparser
import json
import os
import re
import sys
from pathlib import Path
from typing import Any

FIELD_CODE_RE = re.compile(r"%[fFuUdDnNickvm]")
WHITESPACE_RE = re.compile(r"\s+")


def parse_bool(value: str | None) -> bool:
    if value is None:
        return False
    normalized = value.strip().lower()
    return normalized in {"1", "true", "yes", "on"}


def normalize_exec(value: str) -> str:
    without_literal_escape = value.replace("%%", "%")
    without_field_codes = FIELD_CODE_RE.sub("", without_literal_escape)
    return WHITESPACE_RE.sub(" ", without_field_codes).strip()


def parse_keywords(value: str | None) -> list[str]:
    if value is None:
        return []
    return [part.strip() for part in value.split(";") if part.strip()]


def desktop_entry_id(applications_dir: Path, desktop_file: Path) -> str:
    relative = desktop_file.relative_to(applications_dir)
    return str(relative).replace("/", "-")


def parse_desktop_file(path: Path) -> dict[str, Any] | None:
    parser = configparser.RawConfigParser(interpolation=None, strict=False)
    parser.optionxform = str

    try:
        parser.read(path, encoding="utf-8")
    except (configparser.Error, OSError):
        return None

    if not parser.has_section("Desktop Entry"):
        return None

    entry = parser["Desktop Entry"]
    if entry.get("Type", "Application").strip() != "Application":
        return None
    if parse_bool(entry.get("NoDisplay")):
        return None
    if parse_bool(entry.get("Hidden")):
        return None

    name = entry.get("Name", "").strip()
    command = normalize_exec(entry.get("Exec", "").strip())
    if not name or not command:
        return None

    return {
        "name": name,
        "iconName": entry.get("Icon", "").strip(),
        "genericName": entry.get("GenericName", "").strip(),
        "comment": entry.get("Comment", "").strip(),
        "exec": command,
        "keywords": parse_keywords(entry.get("Keywords")),
        "categories": parse_keywords(entry.get("Categories")),
        "terminal": parse_bool(entry.get("Terminal")),
    }


def xdg_data_dirs() -> list[Path]:
    home = os.environ.get("HOME", "")
    data_home = os.environ.get("XDG_DATA_HOME", "").strip()
    if not data_home:
        data_home = f"{home}/.local/share"

    data_dirs_env = os.environ.get("XDG_DATA_DIRS", "").strip()
    if not data_dirs_env:
        data_dirs_env = "/usr/local/share:/usr/share"

    dirs: list[Path] = [Path(data_home)]
    for candidate in data_dirs_env.split(":"):
        if not candidate:
            continue
        dirs.append(Path(candidate))

    return dirs


def collect_catalog_entries() -> list[dict[str, Any]]:
    results_by_id: dict[str, dict[str, Any]] = {}
    data_dirs = xdg_data_dirs()

    for priority, data_dir in enumerate(data_dirs):
        applications_dir = data_dir / "applications"
        if not applications_dir.is_dir():
            continue

        for desktop_file in sorted(applications_dir.rglob("*.desktop")):
            app_id = desktop_entry_id(applications_dir, desktop_file)
            if app_id in results_by_id:
                continue

            parsed = parse_desktop_file(desktop_file)
            if parsed is None:
                continue

            results_by_id[app_id] = {
                "desktopId": app_id,
                "sourcePath": str(desktop_file),
                "sourcePriority": priority,
                **parsed,
            }

    entries = list(results_by_id.values())
    entries.sort(key=lambda item: (item["name"].lower(), item["desktopId"].lower()))
    return entries


def main() -> int:
    entries = collect_catalog_entries()
    json.dump(entries, sys.stdout, ensure_ascii=False, separators=(",", ":"))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

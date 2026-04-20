#!/usr/bin/env python3
"""Build a launcher command catalog from executables visible in PATH."""

from __future__ import annotations

import json
import os
import stat
import sys
from pathlib import Path
from typing import Iterable


def iter_path_dirs(path_env: str) -> Iterable[Path]:
    seen: set[str] = set()

    for raw_part in path_env.split(":"):
        candidate = raw_part.strip()
        if not candidate:
            continue
        resolved = os.path.abspath(candidate)
        if resolved in seen:
            continue
        seen.add(resolved)
        yield Path(resolved)


def is_executable_file(path: Path) -> bool:
    try:
        info = path.stat()
    except OSError:
        return False

    if not stat.S_ISREG(info.st_mode):
        return False
    return os.access(path, os.X_OK)


def collect_entries() -> list[dict[str, object]]:
    path_env = os.environ.get("PATH", "")
    entries_by_name: dict[str, dict[str, object]] = {}

    for priority, directory in enumerate(iter_path_dirs(path_env)):
        if not directory.is_dir():
            continue

        try:
            candidates = sorted(directory.iterdir(), key=lambda item: item.name.lower())
        except OSError:
            continue

        for candidate in candidates:
            name = candidate.name.strip()
            if not name:
                continue
            if name in entries_by_name:
                continue
            if not is_executable_file(candidate):
                continue

            entries_by_name[name] = {
                "name": name,
                "path": str(candidate),
                "sourcePriority": priority,
            }

    entries = list(entries_by_name.values())
    entries.sort(key=lambda item: str(item["name"]).lower())
    return entries


def main() -> int:
    json.dump(collect_entries(), sys.stdout, ensure_ascii=False, separators=(",", ":"))
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

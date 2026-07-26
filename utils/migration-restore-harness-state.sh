#!/usr/bin/env bash
set -euo pipefail

apply=false
archive_path=""

usage() {
  cat <<'EOF'
Usage: migration-restore-harness-state.sh [--apply] [archive.zip]

Dry-run is the default. Pass --apply to restore home-directory harness state.
System-level configs inside the archive are never restored automatically; review
and copy them manually with sudo after the home restore.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      apply=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -n "$archive_path" ]]; then
        echo "ERROR: multiple archive paths passed" >&2
        usage >&2
        exit 2
      fi
      archive_path="$1"
      shift
      ;;
  esac
done

if [[ -z "$archive_path" ]]; then
  archive_path="$(
    find "$HOME/repo/migration-archives" -maxdepth 1 -type f -name 'harness-state-*.zip' -exec stat -f '%m %N' {} + 2>/dev/null \
      | sort -nr \
      | sed -n '1{s/^[0-9]* //;p;}' \
      || true
  )"
fi

if [[ -z "$archive_path" || ! -f "$archive_path" ]]; then
  echo "ERROR: archive not found. Pass an explicit harness-state zip path." >&2
  exit 1
fi

tmp="$(mktemp -d "${TMPDIR:-/tmp}/harness-state-restore.XXXXXX")"
cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT

unzip -q "$archive_path" -d "$tmp"
archive_root="$(find "$tmp" -maxdepth 1 -type d -name 'harness-state-*' | head -n 1 || true)"
if [[ -z "$archive_root" ]]; then
  echo "ERROR: archive does not contain harness-state-* root directory" >&2
  exit 1
fi

home_payload="$archive_root/home"
system_payload="$archive_root/system"
backup_root="$HOME/repo/migration-restore-backups/$(date +%Y%m%d-%H%M%S)"

backup_one() {
  local rel="$1"
  local src="$HOME/$rel"
  local dest="$backup_root/$rel"
  if [[ -d "$src" ]]; then
    mkdir -p "$dest"
    rsync -aE "$src/" "$dest/"
    echo "backed up dir:  $src -> $dest"
  elif [[ -f "$src" || -L "$src" ]]; then
    mkdir -p "$(dirname "$dest")"
    rsync -aE "$src" "$dest"
    echo "backed up file: $src -> $dest"
  fi
}

if [[ ! -d "$home_payload" ]]; then
  echo "ERROR: archive has no home payload" >&2
  exit 1
fi

cat <<EOF
Archive: $archive_path
Payload: $archive_root
Home payload: $home_payload
Mode: $([[ "$apply" == true ]] && echo apply || echo dry-run)
EOF

if [[ "$apply" != true ]]; then
  echo
  echo "Would restore home payload into: $HOME"
  echo "Would first back up existing destinations under: $backup_root"
  echo
  echo "Top-level home payload:"
  find "$home_payload" -mindepth 1 -maxdepth 2 -print | sed "s#^$home_payload#  ~#" | sort
else
  mkdir -p "$backup_root"
  backup_one ".codex"
  backup_one "Library/Application Support/Codex"
  backup_one ".claude"
  backup_one ".claude.json"
  backup_one ".config/opencode"
  backup_one ".local/share/opencode"
  backup_one ".opencode"
  backup_one ".pi"
  backup_one ".agents"
  backup_one ".cursor"
  backup_one ".roo"
  backup_one ".histfile"
  backup_one ".zsh_history"

  rsync -aE "$home_payload/" "$HOME/"
  echo
  echo "Restored home payload into $HOME"
  echo "Existing destinations were backed up under $backup_root"
fi

if [[ -d "$system_payload" ]]; then
  echo
  echo "System-level payload is present but was not restored automatically:"
  find "$system_payload" -mindepth 1 -maxdepth 3 -print | sed "s#^$system_payload#  /#" | sort
  echo "Review those files and copy manually with sudo only if still needed."
fi

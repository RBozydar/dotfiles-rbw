#!/usr/bin/env bash
set -euo pipefail

archive_root="${1:-$HOME/repo/migration-archives}"
timestamp="$(date +%Y%m%d-%H%M%S)"
archive_name="harness-state-${timestamp}"
stage="$(mktemp -d "${TMPDIR:-/tmp}/${archive_name}.XXXXXX")"
payload="${stage}/${archive_name}"
manifest="${payload}/MANIFEST.txt"
excludes="${stage}/rsync-excludes.txt"
rsync_args=(-rltpE --exclude-from="$excludes")

cleanup() {
  rm -rf "$stage"
}
trap cleanup EXIT

mkdir -p "$payload" "$archive_root"

cat >"$excludes" <<'EOF'
auth.json
auth*.json
*auth*.json
*auth-token*
*token*
*tokens*
*credential*
*credentials*
*secret*
*secrets*
*.pem
*.key
*.p12
*.p8
cookies*
Cookies
Login Data
Network Persistent State
.git/
.tmp/
tmp/
cache/
ipc/
log/
logs_*.sqlite*
*.sock
*.socket
node_repl/active_execs/
mcp-oauth-locks/
process_manager/
snapshot/
bin/
node_modules/
EOF

note() {
  printf '%s\n' "$*" | tee -a "$manifest"
}

copy_dir() {
  local src="$1" rel="$2" dest
  dest="${payload}/${rel}"
  if [[ -d "$src" && -r "$src" ]]; then
    mkdir -p "$dest"
    rsync "${rsync_args[@]}" "$src/" "$dest/"
    note "included dir:  $src -> $rel"
  elif [[ -e "$src" ]]; then
    note "skipped unreadable dir: $src"
  else
    note "missing dir:   $src"
  fi
}

copy_file() {
  local src="$1" rel="$2" dest dest_dir
  dest="${payload}/${rel}"
  dest_dir="$(dirname "$dest")"
  if [[ -f "$src" && -r "$src" ]]; then
    mkdir -p "$dest_dir"
    rsync "${rsync_args[@]}" "$src" "$dest_dir/"
    note "included file: $src -> $rel"
  elif [[ -e "$src" ]]; then
    note "skipped unreadable file: $src"
  else
    note "missing file:  $src"
  fi
}

cat >"$manifest" <<EOF
Harness state archive
Created: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Host: $(hostname)
User: $(id -un)

This archive is private. It intentionally preserves agent sessions, prompts,
local config, and shell history where present. Files whose names look like auth,
tokens, credentials, secrets, or private keys are excluded, but session logs may
still contain sensitive text if it was pasted into an agent or shell.

Excluded filename patterns:
$(sed 's/^/- /' "$excludes")

Included paths:
EOF

copy_dir "$HOME/.codex" "home/.codex"
copy_dir "$HOME/.claude" "home/.claude"
copy_file "$HOME/.claude.json" "home/.claude.json"
copy_dir "$HOME/.config/opencode" "home/.config/opencode"
copy_dir "$HOME/.local/share/opencode" "home/.local/share/opencode"
copy_dir "$HOME/.opencode" "home/.opencode"
copy_dir "$HOME/.pi" "home/.pi"
copy_dir "$HOME/.agents" "home/.agents"
copy_dir "$HOME/.cursor" "home/.cursor"
copy_dir "$HOME/.roo" "home/.roo"
copy_file "$HOME/.histfile" "home/.histfile"
copy_file "$HOME/.zsh_history" "home/.zsh_history"


archive_path="${archive_root}/${archive_name}.zip"
(
  cd "$stage"
  zip -qry -y "$archive_path" "$archive_name"
)
shasum -a 256 "$archive_path" >"${archive_path}.sha256"

printf '\nCreated archive:\n%s\n%s\n' "$archive_path" "${archive_path}.sha256"
du -sh "$archive_path"

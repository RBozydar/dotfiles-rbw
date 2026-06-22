#!/usr/bin/env bash
set -euo pipefail

out_dir="${1:-$HOME/repo/dotfiles-rbw/docs/migration-inventory/current}"
repo_root="${REPO_ROOT:-$HOME/repo}"

tool_path="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$HOME/.cargo/bin:$HOME/.bun/bin:$HOME/.local/bin:$HOME/.opencode/bin"
export PATH="$tool_path:${PATH:-}"

mkdir -p "$out_dir"

write_command() {
  local file="$1"
  shift
  if command -v "$1" >/dev/null 2>&1; then
    "$@" >"$file" 2>"$file.stderr" || true
  else
    printf '%s not found\n' "$1" >"$file"
    : >"$file.stderr"
  fi
}

write_tool_versions() {
  local file="$out_dir/tool-versions.tsv"
  printf 'tool\tpath\tversion\n' >"$file"
  local tool path version
  for tool in brew npm node cargo rustc python python3 uv pipx bun fnm pyenv mise go gcloud gh docker colima opencode claude codex pi gws; do
    path="$(command -v "$tool" 2>/dev/null || true)"
    if [[ -z "$path" ]]; then
      printf '%s\tMISSING\t\n' "$tool" >>"$file"
      continue
    fi
    case "$tool" in
      go)
        version="$("$tool" version 2>/dev/null || true)"
        ;;
      *)
        version="$("$tool" --version 2>/dev/null | /usr/bin/head -n 1 || true)"
        ;;
    esac
    printf '%s\t%s\t%s\n' "$tool" "$path" "$version" >>"$file"
  done
}

write_repositories() {
  local file="$out_dir/repositories.tsv"
  printf 'name\ttype\tbranch\thead\tupstream\taheadbehind\ttracked_dirty\tuntracked\tstashes\tworktree\tremote\n' >"$file"

  while IFS= read -r dir; do
    local name branch head upstream aheadbehind tracked untracked stashes gitdir common worktree remote
    name="${dir##*/}"
    if git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      branch="$(git -C "$dir" branch --show-current 2>/dev/null || true)"
      head="$(git -C "$dir" rev-parse --short HEAD 2>/dev/null || true)"
      upstream="$(git -C "$dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
      aheadbehind="$(git -C "$dir" status --porcelain=v2 --branch 2>/dev/null | awk '/^# branch.ab /{print $3" "$4}')"
      tracked="$(git -C "$dir" status --porcelain=v1 -uno 2>/dev/null | awk 'END{print NR+0}')"
      untracked="$(git -C "$dir" status --porcelain=v1 --untracked-files=all 2>/dev/null | awk 'substr($0,1,2)=="??"{n++} END{print n+0}')"
      stashes="$(git -C "$dir" stash list 2>/dev/null | awk 'END{print NR+0}')"
      gitdir="$(git -C "$dir" rev-parse --git-dir 2>/dev/null || true)"
      common="$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null || true)"
      worktree="no"
      [[ -n "$gitdir" && "$gitdir" != "$common" ]] && worktree="yes"
      remote="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
      printf '%s\tgit\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$branch" "$head" "${upstream:-none}" "${aheadbehind:-none}" "$tracked" "$untracked" "$stashes" "$worktree" "${remote:-none}" >>"$file"
    else
      printf '%s\tnon_git\t\t\t\t\t\t\t\t\t\n' "$name" >>"$file"
    fi
  done < <(find "$repo_root" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort)
}

write_non_git_dirs() {
  local file="$out_dir/non-git-dirs.txt"
  : >"$file"
  while IFS= read -r dir; do
    if ! git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      printf '%s\n' "${dir##*/}" >>"$file"
    fi
  done < <(find "$repo_root" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort)
}

write_repo_summary() {
  local file="$out_dir/repo-summary.txt"
  awk -F '\t' '
    NR == 1 { next }
    {
      total++
      if ($2 == "git") {
        gitrepos++
        if ($7 != "0" || $8 != "0") dirty++
        if ($7 != "0") tracked_dirty++
        if ($8 != "0") untracked++
        if ($5 == "none") no_upstream++
        if ($10 == "yes") worktrees++
        if ($9 != "0") stashes++
      } else {
        non_git++
      }
    }
    END {
      printf "first_level_dirs=%d\n", total
      printf "git_repos=%d\n", gitrepos
      printf "non_git_dirs=%d\n", non_git
      printf "dirty_repos=%d\n", dirty
      printf "tracked_dirty_repos=%d\n", tracked_dirty
      printf "untracked_repos=%d\n", untracked
      printf "no_upstream_repos=%d\n", no_upstream
      printf "worktrees=%d\n", worktrees
      printf "repos_with_stashes=%d\n", stashes
    }
  ' "$out_dir/repositories.tsv" >"$file"
}

write_config_paths() {
  local file="$out_dir/config-paths.tsv"
  printf 'path\texists\tsize\n' >"$file"
  local path size
  for path in \
    "$HOME/.codex" \
    "$HOME/.claude" \
    "$HOME/.claude.json" \
    "$HOME/.config/opencode" \
    "$HOME/.local/share/opencode" \
    "$HOME/.local/state/opencode" \
    "$HOME/.opencode" \
    "$HOME/.pi" \
    "$HOME/.agents" \
    "$HOME/.ssh" \
    "$HOME/.config/gh" \
    "$HOME/.config/gcloud" \
    "$HOME/.config/ghostty" \
    "$HOME/.docker" \
    "$HOME/.colima" \
    "$HOME/.npmrc" \
    "$HOME/.node-version" \
    "$HOME/.zshrc" \
    "$HOME/.zsh_aliases" \
    "$HOME/.zsh_exports" \
    "$HOME/.gitconfig" \
    "$HOME/zscaler-root-ca.pem" \
    "$HOME/Library/Application Support/Codex" \
    "$HOME/Library/Application Support/OpenAI/Codex" \
    "$HOME/Library/Application Support/com.openai.codex"; do
    if [[ -e "$path" ]]; then
      size="$(du -sh "$path" 2>/dev/null | awk '{print $1}')"
      printf '%s\tyes\t%s\n' "$path" "$size" >>"$file"
    else
      printf '%s\tno\t\n' "$path" >>"$file"
    fi
  done
}

write_package_inventory() {
  if command -v brew >/dev/null 2>&1; then
    brew leaves | sort >"$out_dir/brew-leaves.txt" 2>"$out_dir/brew-leaves.stderr" || true
    brew list --cask | sort >"$out_dir/brew-casks.txt" 2>"$out_dir/brew-casks.stderr" || true
    brew tap | sort >"$out_dir/brew-taps.txt" 2>"$out_dir/brew-taps.stderr" || true
    brew bundle dump --describe --force --file="$out_dir/Brewfile" >"$out_dir/brew-bundle-dump.stdout" 2>"$out_dir/brew-bundle-dump.stderr" || true
    {
      while IFS= read -r tap; do
        [[ -n "$tap" ]] && printf 'tap "%s"\n' "$tap"
      done <"$out_dir/brew-taps.txt"
      printf '\n'
      while IFS= read -r formula; do
        [[ -n "$formula" ]] && printf 'brew "%s"\n' "$formula"
      done <"$out_dir/brew-leaves.txt"
      printf '\n'
      while IFS= read -r cask; do
        [[ -n "$cask" ]] && printf 'cask "%s"\n' "$cask"
      done <"$out_dir/brew-casks.txt"
    } >"$out_dir/Brewfile.generated"
    brew services list >"$out_dir/brew-services.txt" 2>"$out_dir/brew-services.stderr" || true
  fi

  write_command "$out_dir/npm-global.txt" npm -g ls --depth=0
  if command -v fnm >/dev/null 2>&1; then
    : >"$out_dir/fnm-npm-global.txt"
    fnm list 2>/dev/null | awk '{for (i = 1; i <= NF; i++) if ($i ~ /^v[0-9]/) print $i}' | while IFS= read -r node_version; do
      printf '## %s\n' "$node_version" >>"$out_dir/fnm-npm-global.txt"
      fnm exec --using "$node_version" npm -g ls --depth=0 >>"$out_dir/fnm-npm-global.txt" 2>>"$out_dir/fnm-npm-global.stderr" || true
      printf '\n' >>"$out_dir/fnm-npm-global.txt"
    done
  fi
  write_command "$out_dir/cargo-install-list.txt" cargo install --list
  write_command "$out_dir/uv-tools.txt" uv tool list
  write_command "$out_dir/fnm-list.txt" fnm list
  write_command "$out_dir/pyenv-versions.txt" pyenv versions --bare
  write_command "$out_dir/bun-global.txt" bun pm ls -g
  write_command "$out_dir/mas-list.txt" mas list
  launchctl list 2>/dev/null | /usr/bin/grep -i homebrew >"$out_dir/launchctl-homebrew.txt" || true
}

write_tool_versions
write_repositories
write_non_git_dirs
write_repo_summary
write_config_paths
write_package_inventory

printf 'Wrote migration inventory to %s\n' "$out_dir"

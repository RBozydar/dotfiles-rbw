# Git Worktree Helper Functions
# Zsh-compatible functions for managing git worktrees

# Create a new worktree and branch from within current git directory.
gwa() {
  if [[ -z "$1" ]]; then
    echo "Usage: gwa [branch name]"
    return 1
  fi

  local branch="$1"
  local base="$(basename "$PWD")"
  local worktree_path="../${base}--${branch}"

  git worktree add -b "$branch" "$worktree_path" || return 1
  [[ -x "$(command -v mise)" ]] && mise trust "$worktree_path"
  cd "$worktree_path" || return 1
}

# Remove worktree and branch from within active worktree directory.
gwd() {
  read -q "REPLY?Remove worktree and branch? [y/N] " || return 0
  echo

  local worktree root branch

  worktree="$(basename "$PWD")"

  # split on first `--`
  root="${worktree%%--*}"
  branch="${worktree#*--}"

  # Protect against accidentally nuking a non-worktree directory
  if [[ "$root" != "$worktree" ]]; then
    cd "../$root"
    git worktree remove "$worktree" --force
    git branch -D "$branch"
  fi
}

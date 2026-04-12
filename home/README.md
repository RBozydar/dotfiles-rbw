# Shell Setup Notes

The tracked shell files in this repo are meant to be the portable baseline:

- `.zshrc`
- `.zsh_exports`
- `.zsh_aliases`
- `.zsh_utils_git-worktree`
- `.zsh_plugins.txt`

Machine-specific paths and secrets should stay outside the repo.

## Bootstrap on a new machine

Install the basic prerequisites first:

```sh
# Example baseline packages; use your platform package manager.
# Needed before the shell config works as intended:
# - git
# - zsh
# - curl
```

Clone the repo and link the shell files into `$HOME`:

```sh
ln -sfn ~/repo/dotfiles-rbw/home/.zshrc ~/.zshrc
ln -sfn ~/repo/dotfiles-rbw/home/.zsh_exports ~/.zsh_exports
ln -sfn ~/repo/dotfiles-rbw/home/.zsh_aliases ~/.zsh_aliases
ln -sfn ~/repo/dotfiles-rbw/home/utils/git-worktree.zsh ~/.zsh_utils_git-worktree
ln -sfn ~/repo/dotfiles-rbw/home/.zsh_plugins.txt ~/.zsh_plugins.txt
```

Install Antidote into the default location expected by `.zshrc`:

```sh
git clone --depth=1 https://github.com/mattmc3/antidote.git ~/.antidote
```

Then start a new shell. The plugin bundle file `~/.zsh_plugins.zsh` will be
generated automatically from `~/.zsh_plugins.txt` when needed.

## Local machine overlay

On a new machine:

```sh
cp ~/repo/dotfiles-rbw/home/.zsh_local.example ~/.zsh_local
```

Then edit `~/.zsh_local` and uncomment only the variables that apply to that
machine.

Use `~/.zsh_local` for:

- host-specific SDK locations
- workstation-only CUDA / model paths
- machine-local service endpoints
- temporary global env vars that are not yet project-scoped

Use `~/.zsh_secrets` for:

- tokens
- credentials
- private file paths

`~/.zshrc` loads both files automatically when they exist.

## Agent prep

This setup is meant to keep agent-facing shell startup predictable:

- shared shell behavior lives in tracked files
- machine-local overrides live in `~/.zsh_local`
- secrets live in `~/.zsh_secrets`
- project-specific env should move to project-level tooling later

That separation makes it easier to reuse the same repo across machines without
forcing every agent session to inherit workstation-only paths.

## Current defaults

The tracked config already handles a few common cases without extra local
changes:

- Homebrew is loaded via `brew shellenv` if `brew` is installed.
- Google Cloud SDK defaults to `$HOME/google-cloud-sdk`.
- Conda defaults to `$HOME/miniforge3`, with a fallback to `$HOME/mambaforge`.
- CUDA is auto-detected from `/opt/cuda` or `/usr/local/cuda`.

## What not to put in global shell files

Avoid committing these into `.zshrc` or `.zsh_exports`:

- hardcoded usernames like `/home/rbw/...`
- repo-specific `JAVA_HOME`
- one-project DBT or Dagster paths
- model cache mounts
- machine-only runtime library paths

If a variable is tied to a single project, prefer a project-local solution like
`direnv` later rather than keeping it in global shell startup.

# Shell Setup Notes

The tracked shell files in this repo are meant to be the portable baseline:

- `.zshrc`
- `.zsh_exports`
- `.zsh_aliases`
- `.zsh_utils_git-worktree`

Machine-specific paths and secrets should stay outside the repo.

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

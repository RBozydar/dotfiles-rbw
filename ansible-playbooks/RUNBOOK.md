# Ansible Playbook Runbook

Use this runbook when applying or changing the playbooks.

## Setup

Install Ansible requirements before full syntax or check-mode runs:

```sh
ansible-galaxy install -r requirements.yml
```

If Ansible tries to write outside the sandbox during local validation, redirect
its temp paths:

```sh
export ANSIBLE_LOCAL_TEMP=/private/tmp/ansible-local
export ANSIBLE_REMOTE_TEMP=/tmp/ansible-remote
```

## Profiles

Run from `ansible-playbooks/`.

Default terminal/server-oriented local setup:

```sh
ansible-playbook main.yml
```

Linux workstation with GUI and NVIDIA stack:

```sh
ansible-playbook main.yml --extra-vars "@vars/workstation.yml"
```

Work Mac with common GUI apps and no personal/private apps:

```sh
ansible-playbook main.yml --extra-vars "@vars/macos-work.yml"
```

Private Mac with common apps plus personal/private apps:

```sh
ansible-playbook main.yml --extra-vars "@vars/macos-private.yml"
```

One-off flags:

```sh
ansible-playbook main.yml -e enable_gui=true -e enable_nvidia=false -e enable_private_apps=false
ansible-playbook main.yml -e configure_macos_defaults=false
```

## macOS Host Inspection

Before changing macOS package/default lists on a new laptop:

```sh
sw_vers
uname -m
xcode-select -p 2>/dev/null || true
brew --prefix 2>/dev/null || true
brew list --formula 2>/dev/null | sort
brew list --cask 2>/dev/null | sort
mas list 2>/dev/null | sort
```

Check local overlays and merge-managed app config:

```sh
test -f ~/.zsh_local && sed -n '1,160p' ~/.zsh_local
test -f ~/.zsh_secrets && echo "~/.zsh_secrets exists"
test -f ~/.codex/config.toml && sed -n '1,160p' ~/.codex/config.toml
test -f ~/.claude/settings.json && python3 -m json.tool ~/.claude/settings.json >/dev/null
```

Do not copy secrets or work-internal details into the repo.

## Planning And Dry Runs

List tasks before a broad run:

```sh
ansible-playbook main.yml --list-tasks
ansible-playbook main.yml --list-tasks --extra-vars "@vars/macos-work.yml"
ansible-playbook main.yml --list-tasks --extra-vars "@vars/macos-private.yml"
```

Use check mode when practical:

```sh
ansible-playbook main.yml --check --diff
ansible-playbook main.yml --check --diff --extra-vars "@vars/macos-work.yml"
ansible-playbook main.yml --check --diff --extra-vars "@vars/macos-private.yml"
```

Check mode may be imperfect for installer tasks that download tools. Call that
out in handoff notes when it happens.

## Focused Validation

Parse YAML vars/tasks:

```sh
ruby -ryaml -e 'ARGV.each { |p| YAML.load_file(p); puts p }' vars/*.yml tasks/*.yml
```

Check shell and Python helpers:

```sh
sh -n files/macos/defaults.sh
python3 -m py_compile files/codex/merge-config.py files/claude/merge-settings.py
```

Run a full syntax check when roles and collections are available:

```sh
ansible-playbook --syntax-check main.yml -i localhost, -c local
```

Run repo whitespace checks from the repo root:

```sh
git diff --check
```

## Post-Run Smoke Checks

On macOS:

```sh
zsh -lic 'command -v brew rg bat eza shellcheck tree watch colima docker'
zsh -lic 'command -v fnm node npm uv bun'
colima version 2>/dev/null || true
docker version 2>/dev/null || true
```

For merge-managed config:

```sh
test -f ~/.codex/config.toml && sed -n '1,160p' ~/.codex/config.toml
test -f ~/.claude/settings.json && python3 -m json.tool ~/.claude/settings.json >/dev/null
```

For shell startup:

```sh
zsh -lic 'echo $SHELL; command -v brew fnm uv bun'
```

## Common Failure Modes

- Missing Galaxy role or collection: install `requirements.yml` or report the
  missing dependency explicitly.
- Homebrew path wrong in Vagrant or remote runs: use target facts/env, not
  controller `lookup("env")`, for target paths.
- Existing macOS app outside Homebrew: cask installs use
  `accept_external_apps` so pre-existing `/Applications/*.app` bundles do not
  fail a bootstrap run.
- Homebrew tap trust warnings: do not broadly trust third-party taps from the
  playbook. Remove obsolete taps when possible, or trust only the specific
  formula/cask you intentionally installed from that tap.
- Root-owned files in user home: check `become`, `become_user`, and
  `user_task_become`.
- Unsupported macOS cask: gate by OS version or architecture instead of letting
  one cask fail the whole cask task.
- Codex or Claude config conflicts: keep using merge helpers; do not reintroduce
  full-file symlinks for machine-local settings.
- Review comment churn: apply only feedback that fixes a real issue for this
  personal dotfiles workflow.

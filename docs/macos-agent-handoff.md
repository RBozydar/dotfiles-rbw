# macOS Agent Handoff

This repo is meant to stay unified across Linux servers, Linux desktops, private
Macs, and work Macs. For macOS changes, first classify the machine and the
change before editing package lists or defaults.

## Host Check

Run these before changing the repo:

```sh
sw_vers
uname -m
xcode-select -p 2>/dev/null || true
brew --prefix 2>/dev/null || true
brew list --formula 2>/dev/null | sort
brew list --cask 2>/dev/null | sort
mas list 2>/dev/null | sort
```

Check shell/config state separately:

```sh
test -f ~/.zsh_local && sed -n '1,160p' ~/.zsh_local
test -f ~/.zsh_secrets && echo "~/.zsh_secrets exists"
test -f ~/.codex/config.toml && sed -n '1,160p' ~/.codex/config.toml
test -f ~/.claude/settings.json && python3 -m json.tool ~/.claude/settings.json >/dev/null
```

Do not copy secrets, employer-internal URLs, VPN profiles, tokens, local project
paths, or license data into the repo.

## Choose The Profile

From `ansible-playbooks/`:

```sh
# Work Mac: common GUI apps and tooling, no personal/private apps.
ansible-playbook main.yml --extra-vars "@vars/macos-work.yml"

# Private Mac: work-safe common setup plus personal/private apps.
ansible-playbook main.yml --extra-vars "@vars/macos-private.yml"
```

Use `-e configure_macos_defaults=false` when you only want package/config
changes and do not want to touch macOS defaults yet.

## Where Changes Belong

Use this split when adding another laptop setup:

- Common terminal tooling for all Macs belongs in `macos_brew_packages`.
- Common GUI apps that are acceptable on work and private Macs belong in `macos_common_brew_casks`.
- Work-only but non-secret apps belong in `macos_work_brew_casks` and are gated by `enable_work_apps`.
- Personal apps belong in `macos_private_brew_casks` and are gated by `enable_private_apps`.
- Host-only paths, SDK roots, experimental env vars, and machine quirks belong in `~/.zsh_local`.
- Secrets, tokens, internal endpoints, and credentials belong in `~/.zsh_secrets` or the app's own secure storage.
- Linux desktop packages stay behind `enable_gui`; NVIDIA tooling stays behind `enable_nvidia`.

Do not add macOS GUI apps to the default/server path. These playbooks are also
used on servers.

## macOS Defaults

`ansible-playbooks/files/macos/defaults.sh` is the source of truth for managed
macOS settings. Each `write_default` line has a comment explaining the setting.

Before adding a new default:

- Confirm the setting is safe for both work and private Macs, or add a gating
  variable first.
- Keep screenshot location unmanaged; macOS should keep the Desktop/default or
  a manually selected location.
- Prefer reversible `defaults write` settings over opaque UI automation.
- Add a short comment explaining the behavior, not just the key name.

To inspect current values, use `defaults read <domain> <key>` based on the
existing `write_default` lines. Example:

```sh
defaults read NSGlobalDomain com.apple.swipescrolldirection 2>/dev/null || true
defaults read NSGlobalDomain ApplePressAndHoldEnabled 2>/dev/null || true
defaults read com.apple.finder ShowPathbar 2>/dev/null || true
defaults read com.apple.screencapture type 2>/dev/null || true
```

## Verify Before Pushing

Use check/list modes for broad review:

```sh
ansible-playbook main.yml --list-tasks --extra-vars "@vars/macos-work.yml"
ansible-playbook main.yml --check --diff --extra-vars "@vars/macos-work.yml"
ansible-playbook main.yml --check --diff --extra-vars "@vars/macos-private.yml"
```

Then run focused syntax checks from the repo root:

```sh
ruby -ryaml -e 'ARGV.each { |p| YAML.load_file(p); puts p }' ansible-playbooks/vars/*.yml ansible-playbooks/tasks/*.yml
zsh -n home/.zshrc home/.zsh_exports
sh -n ansible-playbooks/files/macos/defaults.sh
python3 -m py_compile ansible-playbooks/files/codex/merge-config.py ansible-playbooks/files/claude/merge-settings.py
git diff --check
```

If local Ansible roles or collections are missing, report that explicitly rather
than weakening the playbook to satisfy a partial local environment.

## Post-Run Smoke Checks

After applying a profile, verify the managed tools and merge-based configs:

```sh
zsh -lic 'command -v brew rg bat eza shellcheck tree watch colima docker'
zsh -lic 'command -v fnm node npm uv bun'
test -f ~/.codex/config.toml && sed -n '1,160p' ~/.codex/config.toml
test -f ~/.claude/settings.json && python3 -m json.tool ~/.claude/settings.json >/dev/null
```

Codex and Claude settings are merged, not fully symlinked. Shared repo defaults
should be curated and portable; machine-specific auth, caches, trust state,
marketplaces, and app paths should remain local.

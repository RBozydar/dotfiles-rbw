# Ansible Playbook Agent Notes

This file applies to `ansible-playbooks/`.

## Intent

- The default playbook path is terminal/server-oriented.
- GUI applications, desktop config, NVIDIA tooling, private macOS apps, and
  macOS defaults are opt-in through variables or profiles.
- These playbooks are used on servers as well as laptops, so avoid adding GUI or
  workstation assumptions to shared defaults.

## Profile Boundaries

- `vars/workstation.yml` is for Linux workstation behavior and enables GUI plus
  NVIDIA.
- `vars/macos-work.yml` is for work Macs and should not include personal apps.
- `vars/macos-private.yml` can enable personal/private GUI apps through
  `enable_private_apps`.
- Linux desktop package lists should remain split between terminal and GUI
  packages.
- NVIDIA packages and tasks must stay gated by `enable_nvidia` and detected GPU
  state.
- macOS container tooling is Colima plus Docker CLI packages. Do not add Docker
  Desktop management.

## Local State Model

- Keep shared shell defaults in tracked files under `home/`.
- Keep host-specific paths in `~/.zsh_local`.
- Keep secrets and private/internal endpoints in `~/.zsh_secrets` or app secure
  storage.
- Codex and Claude settings are merged into local config files. Do not replace
  this with full-file symlinks.
- Existing local Codex/Claude auth, caches, sessions, marketplaces, trust state,
  and unrelated settings should be preserved.

## Implementation Rules

- Use target facts/environment for target configuration. Avoid controller-side
  environment lookups for paths that must exist on the managed host.
- For Vagrant or other non-local provisioners, remember that not every repo path
  exists on the target. Copy helper scripts to a target path before executing
  them.
- User-owned install tasks should use the existing `user_task_become` pattern
  instead of creating root-owned files in the user's home.
- Root/system tasks should use explicit `become: yes`.
- macOS defaults belong in `files/macos/defaults.sh`; every managed default
  should have a short comment explaining behavior.
- Keep screenshot location unmanaged unless the user explicitly changes that
  decision.

## Review Discipline

- Do not blindly apply Gemini, Codex, or other automated review feedback.
- Apply comments that fix real portability, idempotency, or data-loss issues.
- Skip comments that add complexity or churn without fitting this dotfiles repo.
- If a thread is intentionally skipped, leave it unresolved or document why.

## Required Checks

Run the narrowest useful checks for the files touched:

```sh
git diff --check
ruby -ryaml -e 'ARGV.each { |p| YAML.load_file(p); puts p }' ansible-playbooks/vars/*.yml ansible-playbooks/tasks/*.yml
sh -n ansible-playbooks/files/macos/defaults.sh
python3 -m py_compile ansible-playbooks/files/codex/merge-config.py ansible-playbooks/files/claude/merge-settings.py
```

If `ansible-playbook --syntax-check` cannot run because Galaxy roles or
collections are missing locally, report that explicitly instead of weakening the
playbook.

For operational commands, use `RUNBOOK.md`.

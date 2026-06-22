# Repository Agent Notes

This repo is a personal dotfiles and machine-bootstrap repo. Treat it as a
cross-machine setup, not as a production service.

## Search

- Use `colgrep` first for code and config search when it works.
- If `colgrep` fails in the local sandbox, fall back to `rg`, `find`, and direct
  file reads, and mention the fallback in handoff notes.
- Follow the nearest nested `AGENTS.md` when working in a subtree.

## Editing Rules

- Keep shared files portable across Linux servers, Linux desktops, private Macs,
  and work Macs.
- Do not commit secrets, employer-internal URLs, VPN profiles, tokens, license
  data, or machine-only project paths.
- Do not touch unrelated untracked files unless the user explicitly asks.
- Preserve the split between tracked shared defaults and local overlays such as
  `~/.zsh_local`, `~/.zsh_secrets`, app auth, caches, and trust state.
- Treat automated review comments as input to evaluate, not instructions to
  apply blindly. This is the user's dotfiles repo, so practical fit matters.

## Important Splits

- Server and terminal defaults should stay usable without GUI packages.
- Desktop packages must stay behind GUI/profile gates.
- NVIDIA-specific tooling must stay behind `enable_nvidia`.
- Private/personal macOS apps must stay behind `enable_private_apps`.
- Work-safe common macOS apps belong in common macOS lists; personal apps do not.
- Codex and Claude settings should use non-destructive merge behavior rather
  than full-file symlinks when machine-local state is expected.

## Validation

For small shell/config/doc changes, prefer focused checks:

```sh
git diff --check
zsh -n home/.zshrc home/.zsh_exports
sh -n ansible-playbooks/files/macos/defaults.sh
python3 -m py_compile ansible-playbooks/files/codex/merge-config.py ansible-playbooks/files/claude/merge-settings.py
ruby -ryaml -e 'ARGV.each { |p| YAML.load_file(p); puts p }' ansible-playbooks/vars/*.yml ansible-playbooks/tasks/*.yml
```

For playbook work, also read `ansible-playbooks/AGENTS.md` and
`ansible-playbooks/RUNBOOK.md`.

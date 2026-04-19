# Quickshell Agent Notes

This file applies to `home/config/quickshell/`.

## Metadata

- `scope`: `home/config/quickshell/` excluding `home/config/quickshell/system/` unless a task explicitly targets both
- `owner`: `rbw`
- `linked-adrs`: `ADR-0020`
- `architecture-version`: `shell-arch-2026-04-15`
- `last-reviewed`: `2026-04-17`

## Required Workflow

- Always load and follow the `$linux-hyprland:quickshell` skill for Quickshell, QML, bar, popup, notification, launcher, IPC, settings-spine, or Hyprland-shell work in this tree. Treat it as mandatory context, not optional reference.
- Use `colgrep` first for code search. That is a repo-level rule and it works well for this tree.
- Prefer small, isolated edits. This config live-reloads and cross-file regressions show up immediately.
- Run `make format`, `make lint`, `make review`, and `make verify` from `home/config/quickshell/` as the standard control-plane commands.
- Treat `.review/latest.json` as the machine-readable local review artifact.
- High-risk changes should collect secondary review evidence in `.review/evidence/*.json` before claiming completion.
- The current legacy QML lint/format allowlist lives in [`scripts/lintable-legacy-qml.txt`](./scripts/lintable-legacy-qml.txt). Keep it in sync when a legacy file becomes reliably lintable.
- During dual-tree mode, static QML formatting is intentionally limited to `system/` and `tests/`; the legacy tree should remain thin wrappers and compatibility shims.

## Migration Status

- Runtime startup remains rooted at [shell.qml](./shell.qml) because Quickshell imports cannot resolve paths outside the configured root directory.
- Runtime composition is system-owned via [`system/ui/SystemShell.qml`](./system/ui/SystemShell.qml).
- The future shell-system architecture lives under [`system/`](./system).
- Do not move new foundational architecture into the legacy tree by default.
- Use the legacy tree for active-runtime fixes, bounded UX changes, and
  compatibility work unless the task is explicitly architectural or system-tree
  work.
- `scripts/legacy-system-bridge-allowlist.txt` is intentionally empty after
  entrypoint cutover. Any new legacy-to-system runtime bridge requires explicit
  ADR-backed exception metadata.

## Runtime Model

- Startup entry point: [shell.qml](./shell.qml)
- System runtime root: [system/ui/SystemShell.qml](./system/ui/SystemShell.qml)
- Global theme tokens: [Theme.qml](./Theme.qml)
- Reusable UI primitives: [`system/ui/primitives/`](./system/ui/primitives)
- Singleton data/services: [`services/`](./services)
- Shell/data fetchers: [`scripts/`](./scripts)
- Runtime UI modules live under [`system/ui/modules/`](./system/ui/modules)

## Module Boundaries

- Bar runtime: [`system/ui/modules/bar/`](./system/ui/modules/bar)
- Notifications runtime: [`system/ui/modules/notifications/`](./system/ui/modules/notifications)
- OSD runtime: [`system/ui/modules/osd/`](./system/ui/modules/osd)
- Session runtime: [`system/ui/modules/session/`](./system/ui/modules/session)

### Weather Ownership

If a task is weather-specific, keep ownership inside:

- [system/ui/modules/bar/BarCenter.qml](./system/ui/modules/bar/BarCenter.qml)
- [system/ui/modules/bar/weather/](./system/ui/modules/bar/weather)
- [system/ui/modules/bar/popouts/WeatherPopout.qml](./system/ui/modules/bar/popouts/WeatherPopout.qml)
- [services/Weather.qml](./services/Weather.qml)
- [scripts/weather.sh](./scripts/weather.sh)

Avoid touching shared popup plumbing for weather-only work unless the task truly requires it.

## Popup Rules

- The bar popup system is shared state plus one shared popup surface.
- Do not reintroduce one `PanelWindow` per chip.
- Use the actual hovered chip as the geometry target. Do not use synthetic span items like the old `controlCenterTarget`.
- If a popup needs hover handoff, preserve a shared bridge region and keep close logic centralized.

Relevant files:

- [system/ui/modules/bar/BarScreen.qml](./system/ui/modules/bar/BarScreen.qml)
- [system/ui/modules/bar/BarPopoutState.qml](./system/ui/modules/bar/BarPopoutState.qml)
- [system/ui/modules/bar/BarPopoutSurface.qml](./system/ui/modules/bar/BarPopoutSurface.qml)

## Known Quickshell Gotchas

- `PanelWindow` already has a `screen` property. Do not redeclare it.
- Some QML types expose read-only `implicitWidth` or `implicitHeight`. If you need custom implicit sizing, wrap the content in an `Item`.
- Mask and clip must match. If a popup is visually clipped, the window mask must follow the clipped wrapper, not the moving child.
- Hover timing is fragile. Over-tight close timers make sliders and toggles unusable.

## Running And Debugging

- Hyprland autostarts Quickshell via [home/config/hypr/hyprland.conf](../hypr/hyprland.conf).
- `system/ui/SystemShell.qml` uses `settings.watchFiles: true`, so edits usually live-reload.
- Live logs are under `/run/user/$UID/quickshell/by-id/*/log.log`.
- The popup layer was reworked several times. If popup behavior regresses, compare the current approach against `ii` and Caelestia before improvising another model.
- Do not restart Quickshell from the sandbox. Hyprland IPC targeting goes stale there and `hyprctl` tends to point at a dead socket.
- Preferred restart path is [`scripts/restart-quickshell.sh`](./scripts/restart-quickshell.sh).
- Keep that script simple and aligned with the actual Hyprland autostart here: `hyprctl dispatch exec "pkill -x qs || true; qs -p /home/rbw/repo/dotfiles-rbw/home/config/quickshell"`.
- If a Codex session needs a manual restart, use that script and run it outside the sandbox.
- The only state that restart helper should resolve is the live `HYPRLAND_INSTANCE_SIGNATURE`, and it should resolve that from the newest `/run/user/$UID/hypr/*/.socket.sock`, not from inherited env.

## Testing

- Run `make test` from `home/config/quickshell/` for the local Quickshell baseline.
- Run `make format` to apply repo formatting for docs, JS, TOML, shell scripts, and `system/` QML.
- Run `make lint` for QML, JS, and shell linting. In dual-tree mode this statically lints `system/`, `tests/`, and lintable legacy modules rather than every live-runtime QML file.
- Run `make arch-check` for architecture guardrails on the legacy tree plus `system/`.
- Run `make cutover-status` for legacy-cutover posture checks (bootstrap contract, legacy-dir removal, bridge-allowlist emptiness, and singleton decommission status).
- Run `make review` to emit a machine-readable review artifact under `.review/`.
- Run `make refresh-review-evidence` to sync `.review/evidence/codex-secondary.json` with the current diff fingerprint after a local secondary pass.
- Run `make verify` for the default non-smoke verification path (includes `cutover-status` as a blocking stage).
- Run `make ci-verify` to match the blocking CI subset without requiring local secondary-review evidence.
- Run `make test-live` when you want the real `qs -p` smoke check too.
- Run `make smoke-system` for an explicit bar smoke check.
- Run `make migration-check` as the migration gate: format-check, lint, arch-check, cutover-status, tests, smoke-system.
- `make qmltest` runs headless QML tests via [`scripts/qml-test.sh`](./scripts/qml-test.sh).
- `make lint-shell` lints tracked shell helpers. It prefers `shellcheck`, but falls back to `sh -n` if `shellcheck` is not installed.
- `make pycheck` syntax-checks Python helpers such as [`scripts/fetch_meteo_forecast.py`](./scripts/fetch_meteo_forecast.py).
- `make smoke` launches the config in the current graphical session and asserts it reaches `Configuration Loaded`.
- `make smoke` is not sandbox-safe. Use it from a real Hyprland/desktop session or via an approved unsandboxed command.
- Keep unit tests focused on pure state/helpers. Geometry, hover timing, and Hyprland interaction are better covered by smoke tests plus live validation than by brittle UI automation.

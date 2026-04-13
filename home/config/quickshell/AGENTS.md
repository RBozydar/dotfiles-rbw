# Quickshell Agent Notes

This file applies to `home/config/quickshell/`.

## Required Workflow

- Use the `$linux-hyprland:quickshell` skill for Quickshell, QML, bar, popup, notification, or Hyprland-shell work here.
- Use `colgrep` first for code search. That is a repo-level rule and it works well for this tree.
- Prefer small, isolated edits. This config live-reloads and cross-file regressions show up immediately.

## Runtime Model

- Entry point: [shell.qml](./shell.qml)
- Global theme tokens: [Theme.qml](./Theme.qml)
- Reusable UI primitives: [`components/`](./components)
- Singleton data/services: [`services/`](./services)
- Shell/data fetchers: [`scripts/`](./scripts)
- Major UI modules live under [`modules/`](./modules)

## Module Boundaries

- Bar: [`modules/bar/`](./modules/bar)
- Notifications: [`modules/notifications/`](./modules/notifications)
- OSD: [`modules/osd/`](./modules/osd)
- Session overlay: [`modules/session/`](./modules/session)

### Weather Ownership

If a task is weather-specific, keep ownership inside:

- [modules/bar/BarCenter.qml](./modules/bar/BarCenter.qml)
- [modules/bar/weather/](./modules/bar/weather)
- [modules/bar/popouts/WeatherPopout.qml](./modules/bar/popouts/WeatherPopout.qml)
- [services/Weather.qml](./services/Weather.qml)
- [scripts/weather.sh](./scripts/weather.sh)

Avoid touching shared popup plumbing for weather-only work unless the task truly requires it.

## Popup Rules

- The bar popup system is shared state plus one shared popup surface.
- Do not reintroduce one `PanelWindow` per chip.
- Use the actual hovered chip as the geometry target. Do not use synthetic span items like the old `controlCenterTarget`.
- If a popup needs hover handoff, preserve a shared bridge region and keep close logic centralized.

Relevant files:

- [modules/bar/BarScreen.qml](./modules/bar/BarScreen.qml)
- [modules/bar/BarPopoutState.qml](./modules/bar/BarPopoutState.qml)
- [modules/bar/BarPopoutSurface.qml](./modules/bar/BarPopoutSurface.qml)

## Known Quickshell Gotchas

- `PanelWindow` already has a `screen` property. Do not redeclare it.
- Some QML types expose read-only `implicitWidth` or `implicitHeight`. If you need custom implicit sizing, wrap the content in an `Item`.
- Mask and clip must match. If a popup is visually clipped, the window mask must follow the clipped wrapper, not the moving child.
- Hover timing is fragile. Over-tight close timers make sliders and toggles unusable.

## Running And Debugging

- Hyprland autostarts Quickshell via [home/config/hypr/hyprland.conf](../hypr/hyprland.conf).
- `shell.qml` uses `settings.watchFiles: true`, so edits usually live-reload.
- Live logs are under `/run/user/$UID/quickshell/by-id/*/log.log`.
- The popup layer was reworked several times. If popup behavior regresses, compare the current approach against `ii` and Caelestia before improvising another model.
- Do not restart Quickshell from the sandbox. Hyprland IPC targeting goes stale there and `hyprctl` tends to point at a dead socket.
- Preferred restart path is [`scripts/restart-quickshell.sh`](./scripts/restart-quickshell.sh).
- Keep that script simple and aligned with the actual Hyprland autostart here: `hyprctl dispatch exec "pkill -x qs || true; qs"`.
- If a Codex session needs a manual restart, use that script and run it outside the sandbox.
- The only state that restart helper should resolve is the live `HYPRLAND_INSTANCE_SIGNATURE`, and it should resolve that from the newest `/run/user/$UID/hypr/*/.socket.sock`, not from inherited env.

## Testing

- Run `make test` from `home/config/quickshell/` for the local Quickshell baseline.
- Run `make test-live` when you want the real `qs -p` smoke check too.
- `make qmltest` runs headless QML tests via [`scripts/qml-test.sh`](./scripts/qml-test.sh).
- `make lint-shell` lints tracked shell helpers. It prefers `shellcheck`, but falls back to `sh -n` if `shellcheck` is not installed.
- `make pycheck` syntax-checks Python helpers such as [`scripts/fetch_meteo_forecast.py`](./scripts/fetch_meteo_forecast.py).
- `make smoke` launches the config in the current graphical session and asserts it reaches `Configuration Loaded`.
- `make smoke` is not sandbox-safe. Use it from a real Hyprland/desktop session or via an approved unsandboxed command.
- Keep unit tests focused on pure state/helpers. Geometry, hover timing, and Hyprland interaction are better covered by smoke tests plus live validation than by brittle UI automation.

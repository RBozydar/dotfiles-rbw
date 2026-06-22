# Quickshell Architecture

## Overview

This directory contains a Quickshell-based Hyprland shell replacement focused on:

- top bar
- notification center and popups
- volume OSD
- native session overlay

The shell is centered around a thin bootstrap [shell.qml](./shell.qml), system-owned runtime composition in [system/ui/SystemShell.qml](./system/ui/SystemShell.qml), shared singletons in `services/`, and system runtime modules under `system/ui/modules/`.

## Entry Points

- Startup root: [shell.qml](./shell.qml)
- System runtime root: [system/ui/SystemShell.qml](./system/ui/SystemShell.qml)
- Theme/design tokens: [Theme.qml](./Theme.qml)

## Directory Layout

- [`system/ui/primitives/`](./system/ui/primitives)
  Reusable visual primitives such as chips, sliders, toggle rows, tray items, and popup rows.

- [`services/`](./services)
  Singleton state and integrations for audio, brightness, connectivity, media, notifications, system stats, weather, and night mode.

- [`scripts/`](./scripts)
  Small shell fetchers and helpers used by services. Keep shelling-out logic here rather than embedding it deeply into UI files.

- [`system/ui/modules/`](./system/ui/modules)
  System-owned runtime modules for bar, notifications, OSD, session, and launcher surfaces.

## Bar Structure

- [shell.qml](./shell.qml)
  Bootstrap entrypoint required for Quickshell root import resolution.

- [system/ui/SystemShell.qml](./system/ui/SystemShell.qml)
  Canonical runtime composition root for bar, notifications, OSD, and session modules.

- [system/ui/modules/bar/BarRoot.qml](./system/ui/modules/bar/BarRoot.qml)
  Multi-screen system bar entrypoint.

- [system/ui/modules/bar/BarScreen.qml](./system/ui/modules/bar/BarScreen.qml)
  Per-screen bar composition. Owns popup routing and hover-to-popup mapping.

- [system/ui/modules/bar/BarCenter.qml](./system/ui/modules/bar/BarCenter.qml)
  Clock and weather chip.

- [system/ui/modules/bar/BarRight.qml](./system/ui/modules/bar/BarRight.qml)
  Media, control-center chips, resources, tray, notifications, and power.

- [system/ui/modules/bar/BarPopoutState.qml](./system/ui/modules/bar/BarPopoutState.qml)
  Shared popup state. This is the single source of truth for which bar popup is active.

- [system/ui/modules/bar/BarPopoutSurface.qml](./system/ui/modules/bar/BarPopoutSurface.qml)
  Shared popup surface. Handles popup geometry, reveal animation, and hover handoff.

- [system/ui/modules/bar/popouts/](./system/ui/modules/bar/popouts)
  Popup content files. These should stay presentational and avoid owning shared routing state.

## Notification Structure

- [system/ui/modules/notifications/NotificationPopups.qml](./system/ui/modules/notifications/NotificationPopups.qml)
  Toast-style popup notifications.

- [services/Notifications.qml](./services/Notifications.qml)
  Desktop notification state, actions, history, and popup queues.

- [system/ui/modules/bar/popouts/NotificationsPopout.qml](./system/ui/modules/bar/popouts/NotificationsPopout.qml)
  Bell-anchored notification history popout rendered through the shared bar popup surface.

## OSD Structure

- [system/ui/modules/osd/VolumeOsd.qml](./system/ui/modules/osd/VolumeOsd.qml)
  Ephemeral volume OSD surface.

## Session Structure

- [system/ui/modules/session/SessionOverlay.qml](./system/ui/modules/session/SessionOverlay.qml)
  Session/power overlay surface.

## Test Surface

- [Makefile](./Makefile)
  Local Quickshell test/governance entrypoint. Run `make test` for sandbox-safe checks, `make test-live` for the full suite including a live-session smoke run, and `make cutover-status` for legacy-cutover posture checks.

- [tests/](./tests)
  QML/JS unit tests for pure popup state and notification-store logic.

- [scripts/qml-test.sh](./scripts/qml-test.sh)
  Headless QML test runner wrapper around `qmltestrunner`.

- [scripts/lint-shell.sh](./scripts/lint-shell.sh)
  Shell script lint target. Uses `shellcheck` when installed and falls back to `sh -n`.

- [scripts/python-check.sh](./scripts/python-check.sh)
  Syntax-checks Python helpers without writing `__pycache__` into the repo.

- [scripts/smoke-load.sh](./scripts/smoke-load.sh)
  Config smoke test. Launches the shell in the current graphical session and asserts that Quickshell reaches `Configuration Loaded`.

## Ownership Boundaries

These boundaries are meant to reduce merge conflicts between parallel sessions.

- Weather:
  [system/ui/modules/bar/BarCenter.qml](./system/ui/modules/bar/BarCenter.qml),
  [system/ui/modules/bar/weather/](./system/ui/modules/bar/weather),
  [system/ui/modules/bar/popouts/WeatherPopout.qml](./system/ui/modules/bar/popouts/WeatherPopout.qml),
  [services/Weather.qml](./services/Weather.qml),
  [scripts/weather.sh](./scripts/weather.sh)

- Bar popup plumbing:
  [system/ui/modules/bar/BarScreen.qml](./system/ui/modules/bar/BarScreen.qml),
  [system/ui/modules/bar/BarPopoutState.qml](./system/ui/modules/bar/BarPopoutState.qml),
  [system/ui/modules/bar/BarPopoutSurface.qml](./system/ui/modules/bar/BarPopoutSurface.qml)

- Notifications:
  [system/ui/modules/notifications/](./system/ui/modules/notifications),
  [services/Notifications.qml](./services/Notifications.qml),
  [scripts/focus-codex-ghostty.sh](./scripts/focus-codex-ghostty.sh)

- Session overlay:
  [system/ui/modules/session/SessionOverlay.qml](./system/ui/modules/session/SessionOverlay.qml)

- OSD:
  [system/ui/modules/osd/VolumeOsd.qml](./system/ui/modules/osd/VolumeOsd.qml)

## Extension Rules

- New bar-facing features should usually add:
    1. a service in `services/` if data/state is needed
    2. a chip or reusable primitive in `system/ui/primitives/` if presentation is reused
    3. a popup content file in `system/ui/modules/bar/popouts/` if the feature opens from the bar

- Keep shell command parsing in `scripts/` when practical.

- Prefer real hovered target items for popup positioning.

- If a feature only changes one domain, keep edits inside that domain’s ownership boundary.

# Quickshell Architecture

## Overview

This directory contains a Quickshell-based Hyprland shell replacement focused on:

- top bar
- notification center and popups
- volume OSD
- native session overlay

The shell is centered around `shell.qml`, shared singletons in `services/`, and feature folders under `modules/`.

## Entry Points

- Shell root: [shell.qml](./shell.qml)
- Theme/design tokens: [Theme.qml](./Theme.qml)

## Directory Layout

- [`components/`](./components)
  Reusable visual primitives such as chips, sliders, toggle rows, tray items, and popup rows.

- [`services/`](./services)
  Singleton state and integrations for audio, brightness, connectivity, media, notifications, system stats, weather, and night mode.

- [`scripts/`](./scripts)
  Small shell fetchers and helpers used by services. Keep shelling-out logic here rather than embedding it deeply into UI files.

- [`modules/bar/`](./modules/bar)
  Bar composition, shared popout state, shared popout surface, and popup content.

- [`modules/notifications/`](./modules/notifications)
  Toast-style popup notifications.

- [`modules/osd/`](./modules/osd)
  Ephemeral OSD surfaces such as volume.

- [`modules/session/`](./modules/session)
  Session/power overlay.

## Bar Structure

- [modules/bar/Bar.qml](./modules/bar/Bar.qml)
  Multi-screen bar entrypoint.

- [modules/bar/BarScreen.qml](./modules/bar/BarScreen.qml)
  Per-screen composition. Owns popup routing, shell gating, and the mapping between hovered chips and popup content.

- [modules/bar/BarLeft.qml](./modules/bar/BarLeft.qml)
  Workspace strip cluster.

- [modules/bar/BarCenter.qml](./modules/bar/BarCenter.qml)
  Clock and weather chip.

- [modules/bar/BarRight.qml](./modules/bar/BarRight.qml)
  Media, control-center chips, resources, tray, notifications, and power.

- [modules/bar/BarPopoutState.qml](./modules/bar/BarPopoutState.qml)
  Shared popup state. This is the single source of truth for which bar popup is active.

- [modules/bar/BarPopoutSurface.qml](./modules/bar/BarPopoutSurface.qml)
  Shared popup surface. Handles popup geometry, reveal animation, and hover handoff.

- [modules/bar/popouts/](./modules/bar/popouts)
  Popup content files. These should stay presentational and avoid owning shared routing state.

## Notification Structure

- [modules/notifications/NotificationPopups.qml](./modules/notifications/NotificationPopups.qml)
  Toast-style popup notifications.

- [services/Notifications.qml](./services/Notifications.qml)
  Desktop notification state, actions, history, and popup queues.

- [modules/bar/popouts/NotificationsPopout.qml](./modules/bar/popouts/NotificationsPopout.qml)
  Bell-anchored notification history popout rendered through the shared bar popup surface.

## Test Surface

- [Makefile](./Makefile)
  Local Quickshell test entrypoint. Run `make test` for sandbox-safe checks and `make test-live` for the full suite including a live-session smoke run.

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
  [modules/bar/BarCenter.qml](./modules/bar/BarCenter.qml),
  [modules/bar/weather/](./modules/bar/weather),
  [modules/bar/popouts/WeatherPopout.qml](./modules/bar/popouts/WeatherPopout.qml),
  [services/Weather.qml](./services/Weather.qml),
  [scripts/weather.sh](./scripts/weather.sh)

- Bar popup plumbing:
  [modules/bar/BarScreen.qml](./modules/bar/BarScreen.qml),
  [modules/bar/BarPopoutState.qml](./modules/bar/BarPopoutState.qml),
  [modules/bar/BarPopoutSurface.qml](./modules/bar/BarPopoutSurface.qml)

- Notifications:
  [modules/notifications/](./modules/notifications),
  [services/Notifications.qml](./services/Notifications.qml),
  [scripts/focus-codex-ghostty.sh](./scripts/focus-codex-ghostty.sh)

- Session overlay:
  [modules/session/SessionOverlay.qml](./modules/session/SessionOverlay.qml)

- OSD:
  [modules/osd/VolumeOsd.qml](./modules/osd/VolumeOsd.qml)

## Extension Rules

- New bar-facing features should usually add:
  1. a service in `services/` if data/state is needed
  2. a chip or reusable primitive in `components/` if presentation is reused
  3. a popup content file in `modules/bar/popouts/` if the feature opens from the bar

- Keep shell command parsing in `scripts/` when practical.

- Prefer real hovered target items for popup positioning.

- If a feature only changes one domain, keep edits inside that domain’s ownership boundary.

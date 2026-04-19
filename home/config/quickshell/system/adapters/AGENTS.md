# Adapters AGENTS

## Metadata

- `scope`: `home/config/quickshell/system/adapters/`
- `owner`: `rbw`
- `linked-adrs`: `ADR-0007`, `ADR-0008`, `ADR-0009`, `ADR-0020`, `ADR-0022`
- `architecture-version`: `shell-arch-2026-04-14`
- `last-reviewed`: `2026-04-18`

Adapters isolate external systems from the core.

This is the only layer that should know the details of:

- Hyprland
- Quickshell bridge/runtime specifics
- shell tools like `cliphist` and `qalc`
- DBus-backed services
- persistence backends

## Allowed Here

- external API/tool calls
- parsing and normalization
- availability/readiness/error surfacing
- command execution requested by the core

## Forbidden Here

- UI rendering logic
- importing UI modules to make business decisions
- hidden canonical state that should live in a core store
- broad “misc adapter” dumping grounds

## Golden Paths

### Good

- one adapter per external capability area
- normalize external data before handing it to the core
- expose explicit readiness/degraded/error state
- use helper scripts only when they make the adapter simpler and more stable

Canonical example:

- [search/example-launcher-search-adapter.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/adapters/search/example-launcher-search-adapter.js)
- [search/system-launcher-search-adapter.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/adapters/search/system-launcher-search-adapter.js)
- [search/DesktopAppCatalogAdapter.qml](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/adapters/search/DesktopAppCatalogAdapter.qml)
- [search/desktop-app-catalog-model.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/adapters/search/desktop-app-catalog-model.js)
- [hyprland/workspace-snapshot-adapter.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/adapters/hyprland/workspace-snapshot-adapter.js)
- [notifications/NotificationServerAdapter.qml](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/adapters/notifications/NotificationServerAdapter.qml)
- [notifications/notification-server-model.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/adapters/notifications/notification-server-model.js)
- [theming/static-theme-provider.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/adapters/theming/static-theme-provider.js)
- [theming/matugen-theme-provider.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/adapters/theming/matugen-theme-provider.js)

### Bad

- adapter returns raw external payload shape directly to UI
- adapter imports UI files
- one giant shell-out adapter for everything
- adapter silently swallows missing dependency state

## Hazard APIs

The following belong here or in tightly controlled bridge code, not in UI:

- `hyprctl`
- `Hyprland.dispatch(...)`
- `Quickshell.execDetached(...)`
- raw file writes for persistence

## Agent Rule

Contain dependency-specific weirdness here.

The core should see normalized capability, not backend trivia.

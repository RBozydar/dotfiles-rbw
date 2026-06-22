# System AGENTS

This subtree is the scaffold for the future shell system.

## Metadata

- `scope`: `home/config/quickshell/system/`
- `owner`: `rbw`
- `linked-adrs`: `ADR-0007`, `ADR-0008`, `ADR-0018`, `ADR-0019`, `ADR-0020`, `ADR-0022`
- `architecture-version`: `shell-arch-2026-04-14`
- `last-reviewed`: `2026-04-18`

Treat it as a separate architecture from the current live shell.

## Boundary Model

- `core/`
  Application logic, state ownership, policies, ports, and normalized models.
- `adapters/`
  External-system integration and side effects.
- `ui/`
  Quickshell frontend only.
- `tests/`
  Core-heavy tests and targeted adapter tests.

## Non-Negotiable Dependency Direction

```text
ui -> core contracts/selectors/presentation models + ui bridges
adapters -> core ports/contracts
core -> nothing outside itself
```

Forbidden:

- `core/` importing `ui/`
- UI directly talking to Hyprland or shell tools
- adapters importing UI modules to make business decisions

## Agent Priorities

When working under `system/`, optimize for:

- machine-checkable boundaries
- explicit contracts
- golden-path implementations
- minimal exceptions

Do not optimize for cleverness or premature abstraction.

## Golden Paths

### Good

- define a contract as plain serializable data
- put side effects in adapters
- mutate stores through use cases
- shape presentation through selectors or presentation models
- keep local hover/animation state in UI

Canonical example paths:

- contracts:
    - [core/contracts/operation-outcome.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/contracts/operation-outcome.js)
    - [core/contracts/launcher-contracts.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/contracts/launcher-contracts.js)
    - [core/contracts/compositor-contracts.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/contracts/compositor-contracts.js)
    - [core/contracts/ipc-command-contracts.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/contracts/ipc-command-contracts.js)
    - [core/contracts/settings-contracts.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/contracts/settings-contracts.js)
    - [core/contracts/notification-contracts.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/contracts/notification-contracts.js)
    - [core/contracts/theme-contracts.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/contracts/theme-contracts.js)
- store:
    - [core/domain/launcher/launcher-store.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/domain/launcher/launcher-store.js)
    - [core/domain/compositor/workspace-store.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/domain/compositor/workspace-store.js)
    - [core/domain/settings/settings-store.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/domain/settings/settings-store.js)
    - [core/domain/notifications/notification-store.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/domain/notifications/notification-store.js)
- use case:
    - [core/application/launcher/run-launcher-search.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/application/launcher/run-launcher-search.js)
    - [core/application/launcher/activate-launcher-item.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/application/launcher/activate-launcher-item.js)
    - [core/application/compositor/sync-workspace-snapshots.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/application/compositor/sync-workspace-snapshots.js)
    - [core/application/ipc/dispatch-shell-command.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/application/ipc/dispatch-shell-command.js)
    - [core/application/settings/hydrate-settings.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/application/settings/hydrate-settings.js)
    - [core/application/settings/update-settings.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/application/settings/update-settings.js)
    - [core/application/settings/persist-settings.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/application/settings/persist-settings.js)
    - [core/application/notifications/ingest-notification.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/application/notifications/ingest-notification.js)
    - [core/application/notifications/activate-notification-entry.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/application/notifications/activate-notification-entry.js)
    - [core/application/notifications/clear-notification-history.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/application/notifications/clear-notification-history.js)
    - [core/application/notifications/clear-notification-entry.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/application/notifications/clear-notification-entry.js)
    - [core/application/notifications/dismiss-notification-popup.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/application/notifications/dismiss-notification-popup.js)
    - [core/application/notifications/mark-all-notifications-read.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/application/notifications/mark-all-notifications-read.js)
    - [core/application/notifications/expire-notification-popups.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/application/notifications/expire-notification-popups.js)
- policy:
    - [core/policies/launcher/launcher-scoring-policy.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/policies/launcher/launcher-scoring-policy.js)
- selector:
    - [core/selectors/launcher/select-launcher-sections.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/selectors/launcher/select-launcher-sections.js)
    - [core/selectors/bar/select-bar-workspace-strip.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/selectors/bar/select-bar-workspace-strip.js)
- adapter:
    - [adapters/search/example-launcher-search-adapter.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/adapters/search/example-launcher-search-adapter.js)
    - [adapters/search/system-launcher-search-adapter.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/adapters/search/system-launcher-search-adapter.js)
    - [adapters/search/DesktopAppCatalogAdapter.qml](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/adapters/search/DesktopAppCatalogAdapter.qml)
    - [adapters/search/desktop-app-catalog-model.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/adapters/search/desktop-app-catalog-model.js)
    - [adapters/hyprland/workspace-snapshot-adapter.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/adapters/hyprland/workspace-snapshot-adapter.js)
    - [adapters/persistence/FilePersistenceAdapter.qml](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/adapters/persistence/FilePersistenceAdapter.qml)
    - [adapters/persistence/settings-file-migrations.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/adapters/persistence/settings-file-migrations.js)
    - [adapters/persistence/in-memory-persistence-adapter.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/adapters/persistence/in-memory-persistence-adapter.js)
    - [adapters/theming/static-theme-provider.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/adapters/theming/static-theme-provider.js)
    - [adapters/theming/matugen-theme-provider.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/adapters/theming/matugen-theme-provider.js)
    - [adapters/quickshell/ShellIpcAdapter.qml](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/adapters/quickshell/ShellIpcAdapter.qml)
    - [adapters/notifications/NotificationServerAdapter.qml](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/adapters/notifications/NotificationServerAdapter.qml)
    - [adapters/notifications/notification-server-model.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/adapters/notifications/notification-server-model.js)
- bridge:
    - [ui/bridges/HyprlandWorkspaceBridge.qml](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/ui/bridges/HyprlandWorkspaceBridge.qml)
    - [ui/bridges/NotificationBridge.qml](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/ui/bridges/NotificationBridge.qml)
    - [ui/bridges/ShellChromeBridge.qml](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/ui/bridges/ShellChromeBridge.qml)
    - [ui/bridges/ThemeBridge.qml](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/ui/bridges/ThemeBridge.qml)
- presentation model:
    - [ui/modules/launcher/LauncherPresentationModel.qml](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/ui/modules/launcher/LauncherPresentationModel.qml)
    - [ui/modules/bar/BarPresentationModel.qml](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/ui/modules/bar/BarPresentationModel.qml)

### Bad

- calling `hyprctl` from a QML surface
- using `execDetached` from UI code
- putting scoring logic into a store
- letting a selector become a hidden source of truth
- adding a plugin or registry system without repeated demand

## Hazard APIs

These APIs are architectural hazards and should be tightly controlled:

- `hyprctl`
- `Hyprland.dispatch(...)`
- `Quickshell.execDetached(...)`
- direct persistence writes
- raw external command parsing in UI code

## Status

System-owned runtime entry is active at `system/ui/SystemShell.qml`, bootstrapped
by root `shell.qml` because Quickshell path roots cannot import outside the configured directory.

`scripts/legacy-system-bridge-allowlist.txt` is intentionally empty after
entrypoint cutover.

The role of this subtree is:

- define the future architecture concretely
- provide canonical patterns for agent-authored implementation
- prevent the new shell from degenerating into another monolithic QML config
- host the migrated shell-chrome runtime while deeper core/adapters layering continues

- do not depend on legacy runtime modules by default
- use `make format`, `make lint`, `make arch-check`, `make review`, and `make verify` from `home/config/quickshell/` as the default enforcement entrypoints
- high-risk `system/` changes should attach secondary-review evidence under `.review/evidence/*.json`

# Core AGENTS

## Metadata

- `scope`: `home/config/quickshell/system/core/`
- `owner`: `rbw`
- `linked-adrs`: `ADR-0004`, `ADR-0005`, `ADR-0008`, `ADR-0009`, `ADR-0020`, `ADR-0022`
- `architecture-version`: `shell-arch-2026-04-14`
- `last-reviewed`: `2026-04-18`

The `core/` layer defines the shell as an application.

It should remain conceptually valid even if:

- the frontend runtime changes
- the compositor changes
- a backend tool changes

## Allowed Here

- canonical domain state
- use cases
- pure policies
- selectors
- normalized read models
- plain contract definitions

## Forbidden Here

- imports from `ui/`
- raw `hyprctl`
- `execDetached`
- Quickshell geometry/window logic
- direct persistence formatting/writes
- backend/tool-specific parsing

## Golden Paths

### Good

- `Store` owns canonical mutable state
- `UseCase` orchestrates work and mutates stores
- `Policy` is pure
- `Selector` derives pure presentation shape
- contracts are plain validated objects

Canonical examples:

- contracts:
    - [contracts/operation-outcome.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/contracts/operation-outcome.js)
    - [contracts/launcher-contracts.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/contracts/launcher-contracts.js)
    - [contracts/compositor-contracts.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/contracts/compositor-contracts.js)
    - [contracts/notification-contracts.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/contracts/notification-contracts.js)
    - [contracts/theme-contracts.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/contracts/theme-contracts.js)
- store:
    - [domain/launcher/launcher-store.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/domain/launcher/launcher-store.js)
    - [domain/compositor/workspace-store.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/domain/compositor/workspace-store.js)
    - [domain/notifications/notification-store.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/domain/notifications/notification-store.js)
- use case:
    - [application/launcher/run-launcher-search.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/application/launcher/run-launcher-search.js)
    - [application/compositor/sync-workspace-snapshots.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/application/compositor/sync-workspace-snapshots.js)
    - [application/notifications/ingest-notification.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/application/notifications/ingest-notification.js)
    - [application/notifications/activate-notification-entry.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/application/notifications/activate-notification-entry.js)
- policy:
    - [policies/launcher/launcher-scoring-policy.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/policies/launcher/launcher-scoring-policy.js)
- selector:
    - [selectors/launcher/select-launcher-sections.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/selectors/launcher/select-launcher-sections.js)
    - [selectors/bar/select-bar-workspace-strip.js](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/core/selectors/bar/select-bar-workspace-strip.js)

### Bad

- store calls an adapter directly
- use case becomes a generic helper bucket
- policy mutates state
- core object exposes UI-specific methods
- raw QML object becomes the domain contract

## Practical Heuristic

If it is:

- a noun and the source of truth: it is probably a `Store`
- a verb: it is probably a `UseCase`
- pure decision logic: it is probably a `Policy`
- pure derivation: it is probably a `Selector`

## Agent Rule

Default to the smallest correct abstraction.

Do not invent:

- a new store
- a new policy type
- a new registry

unless the existing model clearly fails.

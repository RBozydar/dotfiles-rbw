# UI AGENTS

## Metadata

- `scope`: `home/config/quickshell/system/ui/`
- `owner`: `rbw`
- `linked-adrs`: `ADR-0005`, `ADR-0006`, `ADR-0007`, `ADR-0018`, `ADR-0019`, `ADR-0020`, `ADR-0022`
- `architecture-version`: `shell-arch-2026-04-14`
- `last-reviewed`: `2026-04-18`

The `ui/` layer is the Quickshell frontend.

It renders state and captures user intent.

It is not the application core.

## Allowed Here

- windows and surfaces
- composition
- local hover/focus/animation/geometry state
- binding to selectors or presentation models
- forwarding intents into the core

## Forbidden Here

- raw `hyprctl`
- `Hyprland.dispatch(...)` except in explicitly allowed bridge code
- `Quickshell.execDetached(...)`
- direct persistence writes
- search orchestration
- domain truth that should live in a store
- direct `import qs.services` usage outside dedicated bridge modules

## Golden Paths

### Good

- direct-bind a small single-domain surface
- use selectors when shaping is needed
- use a presentation model when the surface has earned a real presentation boundary
- keep purely visual feedback local

Canonical example:

- [modules/launcher/LauncherPresentationModel.qml](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/ui/modules/launcher/LauncherPresentationModel.qml)
- [bridges/HyprlandWorkspaceBridge.qml](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/ui/bridges/HyprlandWorkspaceBridge.qml)
- [bridges/NotificationBridge.qml](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/ui/bridges/NotificationBridge.qml)
- [bridges/ShellChromeBridge.qml](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/ui/bridges/ShellChromeBridge.qml)
- [bridges/ThemeBridge.qml](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/ui/bridges/ThemeBridge.qml)
- [modules/bar/BarPresentationModel.qml](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/ui/modules/bar/BarPresentationModel.qml)
- [modules/bar/BarScreen.qml](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/ui/modules/bar/BarScreen.qml)
- [modules/notifications/NotificationPopups.qml](/home/rbw/repo/dotfiles-rbw/home/config/quickshell/system/ui/modules/notifications/NotificationPopups.qml)

### Bad

- view computes business policy inline
- widget shells out directly
- UI owns canonical notification/workspace/launcher state
- every surface gets a heavyweight view model by default

## Interaction Model

Prefer the lightest binding tier that works:

1. direct-bound
2. selector-shaped
3. presentation-model

Do not promote upward until the code clearly earns it.

## Agent Rule

If a change feels easier because the UI can “just call the thing directly,” stop.

That is exactly how architecture erosion starts in an agent-authored codebase.

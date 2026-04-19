# Core Ports

Ports define what the core expects from the outside world.

They should be stable, narrow, and phrased in shell-system terms rather than dependency-specific terms.

## Initial Ports

- `CompositorPort`
  Monitors, workspaces, windows, focus, and dispatch actions.
- `AppCatalogPort`
  Desktop entries and app metadata.
- `ClipboardPort`
  History, copy, delete, and clear operations.
- `CalculatorPort`
  Math evaluation.
- `NotificationPort`
  Notification intake, replies, dismissals, and action dispatch.
- `PersistencePort`
  Settings, history, pinned items, and frecency storage.
- `CommandExecutionPort`
  Command execution and command discovery.
- `MediaPort`
  MPRIS/media state.
- `AudioPort`
  Device and volume state.
- `ThemeProviderPort`
  Theme scheme generation and provider diagnostics.

## Port Rules

- ports describe capability, not implementation
- ports should return normalized shapes
- ports should surface `available`, `ready`, and error state when relevant
- ports should be coarse enough to be stable but narrow enough to mock

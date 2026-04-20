# Shell System Bootstrap Plan

## Goal

Turn the shell-system architecture into an implementable program of work.

This plan assumes:

- the shell is being treated as a greenfield system
- the future architecture is `core + adapters + ui`
- the current live shell is not the constraint

## Success Criteria

The bootstrap is successful when:

- the repo has a clear system-oriented structure
- the first subsystems can be implemented without architecture churn
- core logic can be developed without burying it in QML
- Hyprland and Quickshell are contained behind explicit roles
- the launcher can be built as a subsystem, not as the architecture

## Roadmap Status (as of 2026-04-21)

- Phase 0 (`Foundation`): completed
    - `system/` scaffold, ADR set, architecture guardrails, and verification harness are in place.
- Phase 1 (`Core Session and Compositor Spine`): completed for initial scope
    - workspace/session state contracts and Hyprland adapter slice are live through the system bar composition.
- Phase 2 (`Settings and Persistence Spine`): completed for current scope
    - delivered hydration, file-backed persistence with migration hooks, mutation use cases, explicit `settings.persist`, and debounced auto-persist with revision tracking.
    - delivered launcher state mutations (`lastQuery`, pinned command ids) and wired launcher search flows to update durable state.
    - delivered Option 2 persistence hardening: snapshot-level writes, generation metadata, backup-aware recovery, and snapshot read/write port support.
    - delivered subsystem persistence partition for wallpaper workflow state:
      runtime wallpaper history/cursor now hydrate from settings durable state and sync back through explicit mutation use case (`settings.wallpaper.history.updated`).
    - delivered theme settings persistence partition:
      provider/mode/variant/source fields now flow through config validation, migration, runtime projection, and explicit mutation use cases (`settings.theme.*`), and theme IPC setters now persist through the settings spine.
    - delivered optional-integration settings partition:
      integration toggles are now persisted in `settings.config.integrations.*`, exposed through explicit settings IPC mutations (`settings.integrations.*`), and still support env-var override precedence for forced runtime policy.
    - ongoing policy:
      future subsystem persistence partitioning is now BAU work and should be handled as each new domain introduces durable state.
- Phase 3 + 3.5 (`UI Bootstrap` + first vertical slice): completed
    - `system/ui/SystemShell.qml` is the canonical composition root and the first end-to-end slice is live.
- Phase 3.6 (`Shell IPC v1`): completed for v1 command surface
    - `shellctl`, command registry, typed outcomes, and IPC adapter path are in place.
- Phase 4 (`Launcher Core`): completed
    - delivered launcher IPC v1 commands (`launcher.search`, `launcher.activate`, `launcher.describe`), command-mode (`>` prefix) autocomplete from command registry, calculator expression results, and action activation use-case.
    - delivered pinned-command prioritization via settings commands (`settings.launcher.pin_command`, `settings.launcher.unpin_command`).
    - delivered real desktop app catalog integration with cache-backed refresh (`DesktopAppCatalogAdapter`) and runtime diagnostics (`launcher.catalog.describe`).
    - delivered launcher telemetry persistence foundation:
      async batched query-history logging, usage counters (`itemId -> count + lastUsedAt`), retention compaction (90 days / 20k entries), and reset command (`settings.launcher.personalization.reset`).
    - delivered provider-registry orchestration in launcher adapter (mode-aware provider routing, deterministic provider order, async-provider pending callback surface).
    - delivered persisted-signal-aware ranking policy (`usageByItemId` frequency/recency boosts) with per-item score metadata for diagnostics.
    - delivered full async provider commit lifecycle:
      generation-validated late-result merge into launcher store state, pending-provider tracking, and async-provider failure handling.
    - delivered first native launcher UI module and polish:
      launcher overlay surface + bar entrypoint + launcher IPC open/close/toggle command path, keyboard navigation (including command-mode tab completion), highlighted-item auto-scroll, and richer result rendering with icon/detail metadata.
    - delivered async-provider timeout governance + diagnostics:
      pending-registry tracking with timeout sweeps, late-result suppression, failure history capture, and diagnostics command (`launcher.providers.describe`).
    - delivered routed launcher command surface and command-execution suggestions:
      `>cmd`, `>web`, `>emoji`, `>clip`, `>file`, `>home`, `>wall`, `>app` routing,
      command-catalog adapter integration, and query-history-backed recent external command suggestions.
    - delivered launcher file quick-preview action:
      highlighted `file.open` results now support preview dispatch (`sushi`) via
      launcher overlay navigation (`Ctrl+Space`) without closing the launcher.
    - delivered explicit pinned-command ordering controls:
      `settings.launcher.pin_command.move_up` and
      `settings.launcher.pin_command.move_down` are now part of the command
      surface, launcher command ranking now respects pin order, and launcher UI
      provides day-1 keyboard controls (`Ctrl+Shift+P`, `Ctrl+Shift+↑/↓`) for
      manual pin toggle/reorder on stable IPC commands.
    - delivered launcher windows provider parity slice:
      launcher search now supports `>win` / `>window` / `>windows` route aliases,
      can surface live compositor windows as launcher results, and dispatches
      direct focus through `window_switcher.focus <address>`.
    - delivered pinned-section UX parity slice:
      pinned stable IPC commands now render in a dedicated `Pinned` section at
      top of launcher results with duplicate suppression in provider sections,
      and pinned metadata survives normalization + scoring projections.
- Phase 5 (`Notifications Subsystem`): completed for planned core scope
    - delivered notification policy depth:
      replace-by-id handling, content deduplication windowing, repeat-count tracking, and policy diagnostics in ingest outcomes.
    - delivered richer action routing:
      notification actions are now preserved from `NotificationServer`, default/explicit notification actions can be invoked, and IPC includes `notifications.activate_action <key> <action-id>`.
    - delivered notification persistence decisions and implementation:
      notification history is now persisted through settings durable state (`settings.notifications.history.updated`) with debounced sync from notification bridge mutations and restore-on-reload hydration.
    - follow-up alignment:
      stale action payloads are stripped on restore to avoid post-reboot unusable actions, and system timeout semantics are aligned to freedesktop expectations (`>0` ms, `0` persistent, `<0` server-default timeout path).
    - verification rerun (2026-04-18):
      `make format`, `make lint`, `make arch-check`, `make refresh-review-evidence`, and `VERIFY_ALLOW_SANDBOX=1 make verify` all pass.
    - system notification UI surfaces (popup overlay + bar notification center + bar unread chip) continue consuming bridge-owned state instead of direct `qs.services.Notifications`.
- Phase 6 (`Shell Chrome and Session Actions`): completed for current scope
    - bar/OSD/session runtime composition runs under system ownership.
    - shell chrome modules now consume a dedicated `ShellChromeBridge` instead of importing `qs.services` directly.
    - architecture enforcement now blocks `import qs.services` under `system/ui` outside `system/ui/bridges/`.
    - delivered native window-switcher slice (Alt+Tab overlay + bridge + IPC command surface):
      `window_switcher.next`, `window_switcher.previous`, `window_switcher.accept`,
      `window_switcher.cancel`, `window_switcher.describe`.
- Theming boundary scaffold (`provider + contracts + bridge`): completed for initial slice
    - delivered canonical theme contracts (`shell.theme.generate`, `shell.theme.scheme`) and provider port boundary.
    - delivered static + matugen provider adapters with explicit fallback behavior and diagnostics surface.
    - delivered `ThemeBridge` + IPC theme control/diagnostics (`theme.describe`, `theme.regenerate`, provider/mode/variant setters).
    - delivered UI token application into `Theme.qml` via canonical role mapping (`applyThemeScheme`), including mode sync from generated schemes.
    - delivered persistent theme control path for shell UI:
      control-center dark/light toggle now routes through system settings mutation flow instead of direct singleton mutation.
- Theming contract standardization (`MD3 canonical role vocabulary`): completed for current scope
    - migrated `theme-contracts.js` required role set to MD3 canonical names.
    - migrated static provider defaults to MD3 canonical role maps.
    - migrated existing `Theme.qml` + active system UI usage to MD3 role names without compatibility aliases.
    - updated tests/docs/ADR references to MD3 canonical schema language.
    - reran full verification (`format`, `lint`, `arch-check`, `refresh-review-evidence`, `verify`) and recorded passing results.
- Phase 7 (`Optional Integrations`): completed for current scope
    - pre-start decision gate resolved: ADR-0014 (`Optional Integration Policy`) is accepted with owner-approved defaults.
    - delivered batch 1 integrations under launcher provider contracts:
      emoji search (low-risk) and clipboard history (`cliphist`) recall (medium-risk).
    - delivered batch 2 integration under launcher provider contracts:
      file search (`fd`) with async provider flow and `file.open` activation.
    - tuned batch 2 runtime defaults to respect async timeout constraints:
      no symlink-following by default and heavy-directory excludes for home-root search.
    - delivered optional integration diagnostics command (`launcher.integrations.describe`) with readiness/degraded snapshots for delivered integrations.
    - delivered activation support for optional integration actions:
      `clipboard.copy_text`, `clipboard.copy_history_entry`, and `file.open`.
    - delivered batch 3 integration under shell-chrome adapter contracts:
      Home Assistant light controls migrated to a system-owned adapter with explicit diagnostics and IPC command surface.
    - delivered batch 4 integration under launcher provider contracts:
      wallpaper catalog/search with `swww` apply actions, diagnostics, and IPC control surface (`wallpaper.describe`, `wallpaper.refresh_catalog`, `wallpaper.set`).
    - delivered hardening slice:
      consolidated health/reporting command (`integrations.health`) with per-integration remediation hints and prioritized recommendations.
    - delivered batch 5 wallpaper workflow controls:
      runtime + persistent history navigation (`wallpaper.random`, `wallpaper.previous`, `wallpaper.next`, `wallpaper.history.describe`) with settings-backed restore/sync.
    - delivered batch 6 Home Assistant launcher/action expansion:
      new launcher provider (`optional.homeassistant`) with action routing for
      light toggle/on/off and scene activation, plus IPC command-surface
      expansion (`homeassistant.turn_on_light`,
      `homeassistant.turn_off_light`, `homeassistant.activate_scene`).
    - delivered integration control-plane hardening:
      `launcher/homeassistant/emoji/clipboard/file/wallpaper` integration toggles
      moved from env-only wiring to settings-backed runtime policy with explicit
      command control and deterministic persistence.
    - delivered integration diagnostics harness stage:
      `integration-smoke` is now first-class in `verify`/`migration-check`
      sequences and checks both `launcher.integrations.describe` and
      `integrations.health`.
    - ongoing policy:
      any future integration expansion (for example online wallpaper providers
      or broader Home Assistant domains) is BAU backlog work under ADR-0014
      guardrails, not a blocking roadmap phase.
- BAU UX delivery snapshot:
    - weather module pass delivered:
      current-hour anchoring for bar chip state, deterministic preview-current
      indexing, persistent meteorogram "now" marker, split cloud panels
      (coverage + altitude), and side legend support in the weather popout.
    - control-center audio pass delivered:
      explicit default output/input switching (device catalog probe + previous/
      next controls) through the `Audio` service boundary and system-owned
      control-center popup.
    - tray interaction reliability pass delivered:
      tray icon activation now dispatches on click semantics (`onClicked`)
      rather than press semantics to improve app-open behavior consistency.
    - static theme preset pass delivered:
      named variants (`evangelion`, `moon-space`) now apply through the
      existing theme control plane (`theme.variant.set`) with canonical MD3
      role output and test coverage.
- Legacy cutover + packaging hardening: completed for current scope
    - removed stale backup artifacts (`*.bak`) from active system UI paths and elevated this to an architecture gate.
    - decommissioned dead legacy Home Assistant singleton wiring from `qs.services`; system adapter remains the sole runtime path.
    - `arch-check` now enforces thin bootstrap contract for `shell.qml`, strict removal of decommissioned `components/` + `modules/` legacy directories, and zero backup artifacts under `home/config/quickshell/`.
    - added dedicated cutover governance surface:
      `scripts/cutover-status.sh`, wired as a blocking step in both `verify` and `migration-check`.
    - physically removed decommissioned empty legacy runtime directories:
      `home/config/quickshell/components/` and `home/config/quickshell/modules/`.
    - `package.json` now exposes npm wrappers for governance commands (`format`, `lint`, `arch-check`, `review`, `verify`, `migration-check`, `qmltest`, `pycheck`, `ci-verify`) so tooling can run without Make as a hard prerequisite.
- Verification posture (`QML lint`): now blocking for warning-level diagnostics
    - import/module and unqualified-access debt was burned down to zero warnings.
    - `uncreatable-type` for `PanelWindow` remains informational due `qmllint` type-knowledge limits with Quickshell window types.
- Performance governance posture:
    - ADR-0016 SLA enforcement is explicitly deferred until baseline functionality delivery is complete.

## Implementation Phases

### Phase 0: Foundation

Objective:

- lock in architecture and naming before feature work starts

Deliverables:

- `system/` scaffold
- overall architecture doc
- initial port list
- dependency direction rules
- initial contract shapes for intents, events, commands, and read models
- first ADRs for runtime topology and dependency boundaries
- explicit core implementation decision for Phase 1

Acceptance criteria:

- the future shell has a clear home in the repo
- the intended boundaries are documented in the scaffold itself
- the first structural decisions are captured explicitly rather than left implicit
- the team knows what concrete implementation path Phase 1 will use

### Phase 1: Core Session and Compositor Spine

Objective:

- create the minimal shell core that can represent session and compositor state

First files to create:

- `system/core/domain/ShellSession.*`
- `system/core/domain/WorkspaceState.*`
- `system/core/domain/WindowState.*`
- `system/core/application/InitializeShell.*`
- `system/core/application/HandleCompositorEvent.*`
- `system/core/ports/CompositorPort.*`
- `system/adapters/hyprland/HyprlandCompositorAdapter.*`
- `system/protocol/` or equivalent shared contract location if needed

Key decisions:

- define normalized monitor/workspace/window models
- define the core event shape for compositor updates
- define a minimal dispatch API for shell actions
- decide whether compositor access is one port or several capability ports

Acceptance criteria:

- core can represent focused monitor, workspaces, windows, and session readiness
- Hyprland details are contained inside the adapter
- the UI-facing shape of compositor data is explicit

### Phase 2: Settings and Persistence Spine

Objective:

- make runtime configuration and persistence explicit early

First files to create:

- `system/core/domain/SettingsState.*`
- `system/core/application/LoadSettings.*`
- `system/core/application/ValidateSettings.*`
- `system/core/ports/PersistencePort.*`
- `system/adapters/persistence/FilePersistenceAdapter.*`

Key decisions:

- define config schema and defaults
- separate persistent state from transient UI state
- define migration policy for persisted data

Acceptance criteria:

- settings load through a port
- runtime config is validated before the UI depends on it

### Phase 3: UI Bootstrap

Objective:

- create a minimal frontend that consumes core state without owning business logic

First files to create:

- expand `system/ui/SystemShell.qml`
- `system/adapters/quickshell/ShellFrontendBridge.*`
- `system/ui/theme/Theme.qml`
- `system/ui/modules/session-status/`
- optional minimal `system/ui/modules/debug/`

Key decisions:

- how the UI binds to core state in a single-process build
- how screen-scoped surfaces are modeled
- what local visual state remains in QML
- which interactions are fast-path UI behavior vs state-path core behavior

Acceptance criteria:

- the UI can render shell session and compositor state
- the UI does not call Hyprland directly
- no business logic is introduced just to make the first surface render

### Phase 3.5: First Vertical Slice

Objective:

- prove the architecture with one running end-to-end feature

Suggested slice:

- focused monitor and focused workspace state
- flowing from Hyprland adapter
- through core state and read model
- into one minimal UI surface

Acceptance criteria:

- the slice is usable in the running shell
- there is no direct adapter leakage into the UI
- the amount of code is small enough to still refactor cheaply

### Phase 3.6: Shell IPC v1 (Thin Command Surface)

Objective:

- ship a minimal local command interface early so control paths do not sprawl as direct UI calls

First files to create:

- `system/core/contracts/ipc-command-contracts.*`
- `system/core/application/ipc/DispatchShellCommand.*`
- `system/core/ports/ShellCommandPort.*`
- `system/adapters/ipc/LocalIpcServerAdapter.*`
- `system/adapters/ipc/ShellCtlClientAdapter.*`
- `scripts/shellctl` (or equivalent CLI wrapper)
- completion script generated from the command registry/spec

Key decisions:

- transport choice for v1 (local Unix socket vs existing runtime IPC if available)
- command registry ownership and naming (for example `launcher.toggle`, `session.open`)
- operation outcome envelope and error taxonomy
- idempotency semantics for command actions

Acceptance criteria:

- shell actions are invokable through one command interface rather than direct UI object calls
- `shellctl --help` and shell completion are generated from the same command spec
- unknown commands and invalid payloads return explicit typed errors
- smoke tests cover IPC startup/reload behavior and one happy-path toggle command

### Phase 4: Launcher Core

Objective:

- build the launcher as the first serious subsystem

First files to create:

- `system/core/domain/launcher/LauncherStore.*`
- `system/core/domain/launcher/LauncherItem.*`
- `system/core/application/launcher/RunLauncherSearch.*`
- `system/core/application/launcher/ActivateLauncherItem.*`
- `system/core/policies/LauncherScoring.*`
- `system/core/ports/AppCatalogPort.*`
- `system/core/ports/CommandExecutionPort.*`
- `system/core/ports/CalculatorPort.*`
- `system/adapters/search/AppCatalogAdapter.*`
- `system/adapters/search/CommandCatalogAdapter.*`
- `system/adapters/search/QalcCalculatorAdapter.*`
- `system/ui/modules/launcher/`

Key decisions:

- normalized launcher item shape
- provider boundary location
- scoring and staged search policy
- command mode and autocomplete contract

Acceptance criteria:

- launcher search lives in the core
- adapters provide apps, commands, and calculator results
- UI only renders and dispatches intents
- provider contracts are explicit before optional providers are added
- ranking persistence responsibilities are explicit

### Phase 5: Notifications Subsystem

Objective:

- build notification policy as a proper subsystem

First files to create:

- `system/core/domain/notifications/NotificationStore.*`
- `system/core/application/notifications/IngestNotification.*`
- `system/core/application/notifications/DismissNotification.*`
- `system/core/policies/NotificationPolicy.*`
- `system/core/ports/NotificationPort.*`
- `system/adapters/notifications/NotificationDaemonAdapter.*`
- `system/ui/modules/notifications/`

Key decisions:

- popup vs history split
- dedup and replacement rules
- unread policy

Acceptance criteria:

- notification logic is not trapped in popup UI code

### Phase 6: Shell Chrome and Session Actions

Objective:

- add the standard visible shell products on top of the core spine

Products:

- bar
- OSD
- session modal
- optional dashboard

Acceptance criteria:

- these modules consume core state and actions
- they do not create new shadow state models for the same domains

### Phase 7: Optional Integrations

Objective:

- add only after the spine is stable

Candidates:

- clipboard history (delivered)
- emoji search (delivered)
- file search (delivered)
- Home Assistant (delivered for light-control scope; expandable)
- wallpaper subsystem (delivered for local catalog + workflow history controls)

Acceptance criteria:

- every optional integration arrives through an adapter and a domain contract

## Initial Subsystems To Prioritize

Prioritize in this order:

1. session/compositor spine
2. shell IPC v1 (thin command surface)
3. settings/persistence
4. launcher
5. notifications
6. shell chrome

Reason:

- these create the architectural backbone
- everything else can attach to them later
- this order proves one vertical slice, then freezes a stable command surface before launcher complexity expands

## First Milestone

The first milestone should not be "make a pretty bar".

It should be:

- boot a minimal shell frontend
- through a core shell session model
- fed by a compositor adapter
- with validated settings
- and one thin end-to-end rendered slice

That milestone proves the architecture is real.

## Recommended Naming Conventions

- `*Port` for core-facing external contracts
- `*Adapter` for implementations of those ports
- `*Store` for canonical domain state
- `*Policy` for scoring/routing/decision logic
- `*UseCase` or action-oriented application files for workflows

Avoid inventing more categories unless they solve a real coordination problem.

## Risks To Watch

- QML reabsorbing core logic because it is convenient
- a search controller becoming a god object
- Hyprland-specific details leaking beyond the compositor adapter
- premature plugin architecture
- shelling out spreading across the codebase
- building layers horizontally without shipping a real slice through them
- routing transient UI feedback through the core and degrading responsiveness
- leaving the core implementation strategy undefined
- building layers horizontally without shipping a real slice through them
- overusing `Store` as a catch-all instead of keeping policies and use cases separate

## Practical Next Step

After this bootstrap, the next implementation step should be:

1. create the first core port and normalized models for compositor state
2. create the Hyprland adapter
3. create the Quickshell frontend bridge
4. render a minimal vertical slice from core state
5. ship thin IPC v1 for shell action dispatch and `shellctl` completion

Only after that should launcher and notification products be added.

## Architecture Guardrails

Add lightweight checks early.

Examples:

- fail CI if `hyprctl` appears outside `system/adapters/hyprland/`
- fail CI if `execDetached` appears in `system/ui/`
- fail CI if `core/` imports `ui/`

These checks are cheap and will do more to preserve maintainability than another page of architecture prose.

## Decision Gates

The plan should include explicit reevaluation points.

Gate 1:

- after the first vertical slice
- decide whether the single-process boundary is holding cleanly

Gate 1 should explicitly review:

- whether UI fast paths stayed out of the core
- whether the boundary introduced visible latency
- whether the chosen core implementation path is still paying for itself

Gate 2:

- after launcher core lands
- decide whether the core should remain in QML/JS or move toward a separate typed runtime

Gate 3:

- before optional integrations
- decide whether any new extension mechanism is actually justified

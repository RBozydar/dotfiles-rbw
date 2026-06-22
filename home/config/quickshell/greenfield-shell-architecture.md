# Shell System Architecture

## Scope

This document defines the architecture of the **overall shell system**.

It is not a Quickshell layout guide and it is not a Hyprland integration note.

`Quickshell` is a UI runtime.
`Hyprland` is a compositor dependency.
The shell itself is the product.

So the architecture must describe:

- the system boundaries
- the runtime model
- the subsystem boundaries
- state ownership
- dependency direction
- boot and failure behavior
- how UI, compositor, and system integrations fit into the whole

## System Context

The shell system sits between:

- the user
- the compositor
- the operating system and local tools
- external services

The shell needs to:

- observe compositor state
- render desktop surfaces
- react to system and media state
- launch apps and commands
- manage notifications, session actions, and overlays
- expose its own products such as launcher, bar, OSD, dashboard, and lock screen

That means this is a **stateful event-driven system**, not just a set of windows.

## Architectural Position

The shell should be built as a **real software system with ports and adapters**.

Recommended model:

- **Core**
  The shell application logic.
- **Adapters**
  Integrations with external systems.
- **UI**
  The rendering frontend and interaction layer.

This is a hexagonal architecture adapted to a desktop shell.

It should also be treated as a **contract-driven system**:

- the core exposes intents, commands, events, and read models
- adapters implement ports and translate external systems into those contracts
- the UI renders read models and emits intents

## Design Principles

### 1. Core first

The shell's behavior should be defined by the core, not by the UI framework.

The core owns:

- state models
- policies
- orchestration
- ranking
- workflows
- contracts for integrations

### 2. External systems are dependencies, not architecture

Hyprland, Quickshell, `cliphist`, `qalc`, DBus, PipeWire, MPRIS, Home Assistant, and local scripts are all external systems.

They belong behind adapters.

### 3. State must have one owner

If multiple places can mutate the same truth, the system will decay.

Every important domain needs a clear state owner.

### 4. UI is thin

The UI may own:

- focus
- hover
- animation
- geometry
- temporary local selection

The UI should not own:

- business state
- policy
- orchestration
- persistence rules
- integration logic

### 4.5. Separate fast path from state path

Not every interaction should go through the full core pipeline.

**Fast path** stays in the UI layer:

- hover reactions
- cursor feedback
- scroll position
- local list highlight movement
- animation state
- transient visual affordances

**State path** belongs to the core:

- launcher query and results
- notification lifecycle
- session actions
- workspace/window state
- persistence-affecting actions

If this distinction is ignored, the system may be architecturally clean but operationally sluggish.

### 5. Abstractions must be earned

Do not build general plugin systems or registries before there are enough real use cases.

The shell should start with strict boundaries and a few explicit extension points, not a framework for hypothetical future work.

### 6. Optimize for local reasoning

A maintainer should be able to answer:

- where does this state live?
- what updates it?
- what consumes it?
- what external dependency does it rely on?

If the answer is spread across random QML files, the architecture is wrong.

## High-Level System Model

```text
User
  ↓ intents
UI Layer
  ↓ commands / intents
Core Application
  ↓ ports
Adapters
  ↓
Hyprland / DBus / PipeWire / MPRIS / shell tools / files / network

External events
  ↑
Adapters
  ↑ normalized events
Core Application
  ↑ state changes
UI Layer
```

## Main Architectural Layers

## 1. Core

The core is the shell application.

It should not depend on Quickshell-specific layout concerns and should not be shaped around Hyprland APIs directly.

The core contains:

- domain models
- application services and use cases
- state stores
- ranking/scoring logic
- normalization rules
- subsystem contracts
- ports for external integration

Suggested internal split:

```text
core/
├── domain/
├── application/
├── ports/
├── models/
└── policies/
```

### `domain/`

Contains domain concepts and invariants.

Examples:

- launcher item model
- notification model
- workspace/window model
- audio device model
- session action model

### `application/`

Contains use cases and orchestration.

Examples:

- perform launcher search
- activate launcher item
- dismiss notification
- lock session
- switch window
- open dashboard

Application logic must also handle stale state gracefully.

Examples:

- activating a window that no longer exists
- dismissing a notification that already expired
- launching an item whose source disappeared during reload

Core actions should therefore be:

- idempotent where possible
- resilient to stale identifiers
- explicit about no-op outcomes

### `ports/`

Defines the interfaces the core expects from the outside world.

Examples:

- compositor port
- app index port
- clipboard port
- calculator port
- notification port
- settings port
- persistence port

Avoid one giant "generic compositor port" if it becomes a thin mirror of Hyprland.

Prefer capability-oriented boundaries where needed, such as:

- monitor state
- workspace state
- window management
- session/overlay coordination

### `models/`

Contains normalized read models exposed to the UI.

Examples:

- launcher result list
- current workspace state
- visible notifications
- audio summary for the bar

### `policies/`

Contains ranking, routing, fallback, throttling, and other decision logic.

Examples:

- launcher scoring
- notification dedup policy
- startup sequencing policy
- degraded-mode policy

## 2. Adapters

Adapters are the only part of the system that should know the details of external systems.

Suggested split:

```text
adapters/
├── hyprland/
├── quickshell/
├── audio/
├── media/
├── notifications/
├── clipboard/
├── search/
├── persistence/
├── shell/
└── homeassistant/
```

### Adapter responsibilities

- talk to external APIs and tools
- normalize data
- translate external events into internal events
- execute side effects requested by the core
- surface availability and error state

### Adapter examples

`hyprland/`

- subscribe to workspace/window/monitor changes
- normalize compositor state
- execute compositor actions through one dispatch API

If Hyprland-specific capabilities do not map cleanly to a generic compositor concept, keep those capabilities explicit rather than hiding them behind a fake abstraction.

`quickshell/`

- host the UI runtime
- wire UI intents into core commands
- map core state into renderable bindings

`clipboard/`

- talk to `cliphist` or another backend
- expose availability, loading, items, copy, delete, clear

`search/`

- app indexing
- file search
- command discovery from `$PATH`
- calculator execution through `qalc` or another engine

`persistence/`

- settings storage
- history storage
- usage/frecency storage

### Adapter rule

No random shell-outs from views.

All process execution should pass through explicit adapters or narrow helper scripts called by adapters.

## 3. UI

The UI is the frontend layer.

In this project, that frontend is Quickshell/QML.

The UI should contain:

- windows and surfaces
- view composition
- user interaction handling
- local visual state
- reusable components and theming

The UI should not contain:

- business logic
- core state ownership
- integration policy
- search orchestration
- persistence policy

Suggested split:

```text
ui/
├── shell.qml
├── modules/
├── components/
├── theme/
└── bindings/
```

`bindings/` is optional but useful if the UI runtime needs glue objects that translate core models to QML-friendly surfaces.

## Runtime Topology

There are two viable runtime shapes.

### Option A: Single process

Everything runs in one Quickshell process.

Pros:

- simpler to build initially
- less IPC overhead
- easier iteration

Cons:

- weaker isolation
- QML/JS tends to absorb more logic than intended
- harder to enforce clean boundaries

### Option B: Split core and frontend

- shell core daemon
- Quickshell frontend process
- typed local IPC between them

Pros:

- much cleaner architecture
- core can be implemented in Rust or Go
- better fault isolation
- easier testing of core logic
- UI framework becomes replaceable

Cons:

- more initial complexity
- requires protocol design

### Recommendation

Architect for Option B even if you implement Option A first.

That means:

- define ports and contracts now
- keep UI thin now
- isolate integrations now
- avoid QML-as-core now

If the shell grows, the split can happen without a rewrite.

Before implementation starts, one explicit decision is still required:

- **Decision A**
  single-process core implemented in JS/QML-adjacent modules, with protocol-shaped contracts from day one
- **Decision B**
  separate typed core process from day one, with real IPC contracts

Leaving this ambiguous will make the bootstrap plan inconsistent.

## Contracts and Protocol

This is the biggest missing piece in many shell codebases: boundaries are named, but the traffic across them is not.

The shell should define four explicit contract shapes:

- **intents**
  User or UI requests such as `OpenLauncher`, `ActivateLauncherItem`, `DismissNotification`, `LockSession`.
- **commands**
  Core-to-adapter requests such as `DispatchCompositorAction`, `RunCommand`, `CopyClipboardItem`.
- **events**
  Adapter-to-core notifications such as `WorkspaceChanged`, `WindowFocused`, `NotificationReceived`, `AudioDeviceChanged`.
- **read models**
  UI-facing normalized state such as `LauncherViewModel`, `BarViewModel`, `NotificationCenterViewModel`.

This matters because it prevents:

- UI code from calling arbitrary core internals
- adapters from leaking dependency-specific payloads
- state from being shaped differently in every subsystem

Even in a single-process build, these contracts should be treated as real interfaces.

If the shell later becomes split-process, these contracts become the protocol boundary.

## Dependency Direction

The dependency direction must be strict.

Allowed:

- UI depends on core contracts and UI helpers
- adapters implement core ports
- core depends only on its own abstractions and internal models

Forbidden:

- core importing UI modules
- core knowing Quickshell window layout
- core depending directly on `hyprctl` or raw QML APIs
- views mutating external systems directly
- adapters calling into random view state

In short:

```text
UI -> Core contracts
Adapters -> Core ports
Core -> nothing outside itself
```

If the system later splits into multiple processes, add a `protocol/` package or folder rather than letting transport concerns leak into `core/`.

## State Ownership

The system should use explicit domain-owned state.

Recommended top-level state domains:

- `ShellSession`
- `Launcher`
- `Notifications`
- `WindowsAndWorkspaces`
- `Audio`
- `Media`
- `PowerAndSession`
- `Wallpaper`
- `Settings`

For each domain:

- one canonical store
- one clear action surface
- optional read models derived from the store

### Good state pattern

- canonical store owns truth
- use cases update stores
- UI reads from stores or read models

### Bad state pattern

- giant global state singleton with unrelated booleans
- several modules each caching the same system state
- domain truth hidden inside a window component

## Event Model

The shell is event-driven, so event flow should be explicit.

### User intent flow

1. UI captures interaction
2. UI emits intent
3. core use case handles intent
4. core calls adapter port if side effects are required
5. adapters execute side effects
6. core state updates
7. UI re-renders

### External event flow

1. external system emits event
2. adapter observes event
3. adapter normalizes event
4. core store/use case updates state
5. UI re-renders

Do not short-circuit these flows by letting views directly own system logic.

Also avoid introducing a generic shell-wide event bus too early.

Prefer:

- explicit use cases
- explicit subscriptions
- explicit store updates

over:

- stringly-typed event fanout
- global event dispatch for unrelated domains

For concurrency-sensitive operations, define whether the system uses:

- last-write-wins
- rejection of stale actions
- reconciliation on fresh adapter state

Do not leave that behavior implicit.

## Subsystem Boundaries

The shell should be decomposed into real subsystems.

Recommended subsystems:

- launcher
- notifications
- compositor/session model
- shell chrome
- audio/media
- power/session actions
- wallpaper/background
- settings and persistence
- optional integrations

Each subsystem should own:

- its domain state
- its core use cases
- its adapter contracts
- its UI read models

but not:

- unrelated global state
- raw access to another subsystem's adapters

## Launcher Subsystem

The launcher is a subsystem of the shell, not the architecture of the shell.

Its architecture should still be strong because it is one of the highest-complexity products.

Recommended internal structure:

- core launcher domain
- adapters for apps, commands, clipboard, calculator, windows, settings
- UI module that renders normalized results

Recommended concepts:

- launcher store
- launcher search controller/use case
- provider registry only for launcher providers
- normalized launcher item model
- scoring policy

The launcher should be implemented as:

- provider-based in the core
- adapter-fed
- UI-rendered through one stable item model

## Notifications Subsystem

The notifications subsystem should include:

- daemon integration adapter
- notification store
- notification policy
- popup and history views

The policy layer should own:

- dedup
- replacement
- expiry
- unread tracking
- popup queueing

The UI layer should not decide those policies ad hoc.

## Compositor and Windowing Subsystem

This subsystem should hide compositor details behind a normalized internal model.

Responsibilities:

- monitors
- workspaces
- windows
- focus
- dispatch actions

Critical rule:

Only the compositor adapter should speak raw Hyprland dialect.

The rest of the shell should use normalized commands and models.

## Shell Chrome Subsystem

This includes:

- bar
- OSD
- dashboard
- lock surfaces
- session modal

These are products in the UI layer, but they should consume core state rather than owning system truth themselves.

## Settings and Persistence Subsystem

This subsystem should define:

- settings schema
- validation
- migration
- defaults
- persistence backend

Persistent state:

- settings
- history
- frecency
- pinned items
- wallpaper choices

Transient state:

- hover
- geometry
- selection
- temporary expansion
- animation state

These must remain separate.

## Boot Architecture

Boot should be staged, not incidental.

### Stage 1: critical

- load settings
- initialize logging
- initialize core shell session
- initialize compositor adapter
- initialize notification path
- render first stable UI surfaces

### Stage 2: important

- audio/media
- launcher app index
- system status feeds

### Stage 3: optional/heavy

- clipboard history
- file search
- Home Assistant
- optional services

Rules:

- heavy services do not block first paint
- every subsystem exposes readiness and degraded state
- missing optional dependencies are handled explicitly

Boot must also define ownership of startup sequencing.

Recommended:

- one shell bootstrap use case in the core
- one frontend bootstrap bridge in the UI adapter

Avoid:

- every subsystem inventing its own startup choreography independently

## Failure and Degradation Model

Every adapter should expose:

- `available`
- `ready`
- `loading`
- `error`

The core should define degraded behavior for missing integrations.

Examples:

- no clipboard backend: launcher still works, clipboard provider disabled
- no calculator backend: math provider unavailable
- no Home Assistant: HA providers hidden
- compositor mismatch: shell boots in reduced mode or exits with a clear error

Silent failure is not acceptable architecture.

## Observability

The shell should be observable like a real application.

Minimum:

- structured logs per subsystem
- startup timing visibility
- adapter error logging
- explicit warnings for degraded mode

If the shell becomes large enough:

- health dashboard or debug overlay
- reload diagnostics
- event trace for critical subsystems

## Architecture Governance

The architecture will only hold if there are guardrails.

At minimum, introduce:

- ADRs for major structural decisions
- architecture fitness checks in CI
- grep-based or script-based checks for forbidden patterns

Recommended first checks:

- no `hyprctl` usage outside `adapters/hyprland/`
- no `Quickshell.execDetached` outside adapters or explicitly allowed bridge code
- no imports from `ui/` into `core/`
- no raw persistence writes from `ui/`

Recommended first ADRs:

- ADR-001: single-process bootstrap with split-process target
- ADR-002: contract shapes for intents, events, commands, and read models
- ADR-003: Hyprland as an adapter boundary, not a global dependency

Without these checks, the architecture will regress silently.

## Delivery Strategy

Do not implement this as a purely horizontal layering exercise.

Bad delivery shape:

- build all of `core/`
- then all of `adapters/`
- then all of `ui/`

That approach maximizes abstract code and delays proof that the boundaries actually work.

Good delivery shape:

- define boundaries first
- then deliver thin vertical slices through those boundaries
- prove the architecture with running end-to-end features early

The first good vertical slice is not "pretty UI".

It is:

- a minimal compositor model
- surfaced through the core
- rendered by the UI
- with no direct Hyprland leakage into view code

## Testing Strategy

Testing should follow the architecture.

Test the core heavily:

- launcher scoring
- result normalization
- notification policies
- state transitions
- settings validation

Test adapters selectively:

- parser correctness
- normalization logic
- retry/failure handling

Test UI lightly but intentionally:

- binding sanity
- smoke startup
- focus and modal behavior
- per-screen surface composition

The more logic you keep in the core, the more testable the shell becomes.

## Quickshell and Hyprland in This Architecture

This is the key framing.

### Quickshell

Quickshell is:

- the frontend runtime
- the window/surface system
- the QML composition environment

Quickshell is not:

- the core architecture
- the place where domain truth should live

### Hyprland

Hyprland is:

- the compositor dependency
- a source of events
- a target for dispatch commands

Hyprland is not:

- the programming model for the shell
- the place where internal domain contracts should come from

The shell should survive a future compositor swap conceptually, even if you never actually perform one.

That is the test for whether Hyprland has been contained properly.

## Recommended Repository Shape

If the system is kept single-process for now, a practical repository structure is:

```text
shell/
├── core/
│   ├── domain/
│   ├── application/
│   ├── ports/
│   ├── models/
│   └── policies/
├── adapters/
│   ├── hyprland/
│   ├── quickshell/
│   ├── clipboard/
│   ├── notifications/
│   ├── search/
│   ├── persistence/
│   └── shell/
├── ui/
│   ├── shell.qml
│   ├── modules/
│   ├── components/
│   └── theme/
├── scripts/
└── tests/
```

If the system is later split:

```text
shell/
├── shell-core/
├── shell-ui-quickshell/
├── shell-protocol/
└── tests/
```

## What To Avoid

- giant global QML state singletons
- monolithic launcher/search service files
- raw `hyprctl` usage scattered through the codebase
- random shell-outs from UI delegates
- plugin frameworks before domain boundaries are stable
- controller files that become god objects
- UI modules as hidden business-state owners

## Practical Recommendation

If the goal is to build this properly:

- treat the shell as a system first
- keep a real core even if it starts in the same process as the UI
- isolate Hyprland and Quickshell behind clear roles
- design around subsystem contracts, not around files or windows
- move complexity into testable policies and domain logic, not into ad hoc QML

## Final Recommendation

The shell should be architected as:

- a **core shell application**
- with **adapters** for compositor, system integrations, and persistence
- and a **Quickshell frontend** that renders and captures intent

That is the correct overall shell architecture.

Everything else, including launcher design, bar design, and Hyprland integration, should fit underneath that system model.

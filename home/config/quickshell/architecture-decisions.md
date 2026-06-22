# Architecture Decisions

## Context

This shell should be treated as a real software system, not as a Quickshell config with some engineering layered on top.

Important context for these decisions:

- the implementation may start relatively small
- it is expected to grow toward the size and complexity of the larger Quickshell shells
- even the current shell work, focused mostly on bar-related features, is already in the low-thousands-of-lines range

That means the architecture should optimize for:

- maintainability over time
- clear boundaries
- controlled growth
- the ability to refactor without tearing the whole shell apart

## Decision 1: Core Runtime

This is the most important decision.

### Path A: Single-process core in JS/QML-adjacent modules

Shape:

- the shell runs in one Quickshell process
- core logic lives in plain JS modules
- QML singletons expose reactive state and call into those modules
- there is no IPC boundary yet

Strengths:

- fastest to start
- lowest implementation overhead
- easiest to iterate while the product is still moving
- works naturally with Quickshell's reactive model

Risks:

- boundaries are only real if enforced
- QML can slowly absorb business logic again
- extracting a separate daemon later is possible, but not free

### Path B: Split typed core from day one

Shape:

- core runs as a separate process, likely Rust or Go
- Quickshell is purely the frontend
- all communication is explicit and protocol-based

Strengths:

- best long-term maintainability
- strongest separation of concerns
- better fault isolation
- better testing story
- much easier to keep UI and integration concerns contained

Risks:

- slower start
- protocol and IPC overhead from day one
- more moving parts before the shell even works
- easy to overbuild

### Decision

Use **Path A now**, but make it **Path-B-shaped**.

That means:

- put core logic in plain JS modules
- define explicit data contracts early
- define intents, commands, events, and read models explicitly
- keep Quickshell and Hyprland-specific concerns out of the core modules
- add guardrails so the single-process implementation does not degenerate

### Revisit Conditions

Revisit this after:

- the first real launcher implementation
- the first substantial background indexing or async-heavy subsystem
- the first signs that cross-domain orchestration is becoming painful in one process

If the shell reaches the size class of Noctalia or DMS and the JS core starts to feel like glue rather than a system, move toward Path B deliberately.

## Decision 2: Compositor Boundary

### Path A: One generic compositor port

Idea:

- one abstract interface for monitors, workspaces, windows, and actions

Risk:

- either too generic to expose useful features
- or just a disguised mirror of Hyprland

### Path B: Capability-oriented compositor ports

Idea:

- separate capabilities such as monitor state, workspace state, window management, and compositor actions

Strengths:

- easier to keep honest
- easier to evolve
- less likely to become fake abstraction

### Decision

Use **Path B**.

Do not invent a fake generic compositor abstraction.
Normalize the capabilities the shell actually uses.

Hyprland should be contained, but not erased through dishonest abstraction.

### Revisit Conditions

Revisit only if:

- a second compositor becomes a real target
- or the shell accumulates multiple subsystems that truly need a shared higher-level compositor model

## Decision 3: State and Reactivity

### Path A: Global singleton / event bus style

Strengths:

- fast to build initially

Risks:

- weak ownership
- hidden coupling
- hard refactoring
- impossible local reasoning after growth

### Path B: Per-domain state ownership

Shape:

- one canonical store per domain
- explicit use cases or actions
- read models for the UI
- explicit updates rather than ambient mutation

Strengths:

- maintainable
- testable
- easier to reason about
- scalable as subsystem count grows

### Decision

Use **Path B**.

Recommended top-level domains:

- `ShellSession`
- `WindowsAndWorkspaces`
- `Launcher`
- `Notifications`
- `Audio`
- `Media`
- `PowerAndSession`
- `Settings`
- `Wallpaper`

### Revisit Conditions

This decision should only be revisited if:

- the store model becomes too fragmented
- or multiple domains clearly need a higher-level coordination layer

Even then, prefer coordination use cases over a generic event bus.

## Decision 4: Fast Path vs State Path

This decision is operationally important.

### Fast Path

Keep in the UI layer:

- hover
- cursor feedback
- animation state
- local list movement
- scroll state
- transient visual affordances

### State Path

Route through the core:

- launcher query and result state
- notifications lifecycle
- session actions
- compositor-driven shell state
- persistence-affecting actions

### Decision

Keep a hard separation between fast-path UI responsiveness and state-path domain behavior.

The shell must feel immediate.
Do not route every micro-interaction through the core just because the architecture diagram looks cleaner that way.

## Decision 5: Delivery Strategy

### Path A: Horizontal layer buildout

Shape:

- build all of `core/`
- then all of `adapters/`
- then all of `ui/`

Risk:

- too much abstract code before a working slice exists
- hard to know whether the architecture actually fits the product

### Path B: Vertical slices through fixed boundaries

Shape:

- define the architecture and contracts first
- then implement one small end-to-end feature through those boundaries
- refine while still cheap

### Decision

Use **Path B**.

The first meaningful slice should be:

- focused monitor and focused workspace state
- from the Hyprland adapter
- through core state
- into a minimal UI surface

That proves:

- the boundaries are real
- the system remains responsive
- the architecture is not just paper

## Decision 6: Extension Strategy

### Path A: Early plugin/registry system

Strengths:

- feels future-proof

Risks:

- overengineering
- accidental framework-building
- maintenance burden before real demand exists

### Path B: Internal modules first, narrow registries only when proven

Strengths:

- lower complexity
- fewer premature abstractions
- easier to evolve from real needs

### Decision

Use **Path B**.

Allowed early:

- a launcher provider registry, if the launcher truly has multiple providers

Not allowed early:

- shell-wide plugin system
- dynamic module loading
- generic extension framework

### Revisit Conditions

Revisit only after:

- at least three real consumers need the same extension point
- and that need is demonstrated in code, not imagined

## Decision 7: Boundary Enforcement

Architecture rules without enforcement are wishful thinking.

### Decision

Add guardrails early.

At minimum:

- CI checks preventing `hyprctl` outside Hyprland adapters
- CI checks preventing `execDetached` in UI modules
- import boundary checks preventing `core` from depending on `ui`
- ADRs for major structural decisions

If the runtime stays single-process, these checks are what make the architecture real.

## Decision Gates

### Gate 1: After the first vertical slice

Evaluate:

- did UI fast paths stay out of the core?
- did the boundary introduce visible latency?
- did the core shape remain simple enough to reason about?

### Gate 2: After launcher core lands

Evaluate:

- is the JS/QML-adjacent core still manageable?
- are contracts staying stable?
- is one-process orchestration becoming painful?

If yes, stay the course.
If no, begin planning a real split core/frontend architecture.

### Gate 3: Before optional integrations

Evaluate:

- do optional integrations still fit the existing architecture?
- is a new extension mechanism truly justified?
- are adapters containing external-system complexity successfully?

## Final Recommendation

Given the current context:

- start with a single-process implementation
- make the contracts explicit from day one
- keep core logic in plain modules, not in views
- isolate Hyprland and Quickshell behind their roles
- use capability-based compositor boundaries
- deliver vertical slices
- delay plugin systems until they are earned

This is the best balance between:

- engineering rigor
- implementation speed
- future growth
- and maintainability at the scale this shell is likely to reach

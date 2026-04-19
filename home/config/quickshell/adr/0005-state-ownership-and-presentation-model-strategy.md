# ADR-0005: State Ownership and Presentation Model Strategy

- Status: `Proposed`
- Date: `2026-04-13`

## Context

The architecture needs a clear answer to four related questions:

- what owns canonical mutable state?
- what is allowed to mutate that state?
- where does pure decision logic live?
- when should a UI surface get a dedicated presentation model instead of binding directly to stores?

Without this decision:

- `Store` becomes a dumping ground
- use cases become god objects
- presentation logic leaks into views
- everything gets called "complex" without a useful threshold

## Decision

Use the following role split:

- **Store**
  Owns canonical mutable state for one domain.
- **Use case**
  Orchestrates work, talks to adapters, and is allowed to mutate stores.
- **Policy**
  Pure decision logic with no side effects.
- **Selector**
  Pure derivation of state for consumption by a surface or component.
- **Presentation model**
  A named UI-facing projection for a surface that has earned a dedicated presentation boundary.

UI binding strategy should follow three tiers:

1. **Direct-bound surface**
   UI binds directly to one store, with little or no shaping.
2. **Selector-shaped surface**
   UI binds to pure selectors derived from one or more stores.
3. **Presentation-model surface**
   UI binds to an explicit named presentation model because the surface has significant presentation logic or cross-domain shaping.

This replaces the vague language of "simple vs complex surfaces" with a more operational model.

## Role Definitions

### Store

A store owns canonical mutable state for one domain.

Allowed:

- canonical state
- simple derived flags
- reset/apply/update helpers
- revision/version counters when useful

Not allowed:

- direct adapter calls
- shelling out
- scoring/routing policy
- persistence policy
- UI-only geometry, hover, or focus state

Examples:

- `LauncherStore`
- `NotificationStore`
- `WindowsStore`
- `SettingsStore`

### Use Case

A use case is the verb layer.

Allowed:

- call adapters
- validate preconditions
- mutate stores
- coordinate multiple domains
- handle stale state and no-op outcomes

Not allowed:

- own long-lived canonical state
- become a generic helper bucket
- contain rendering logic

Examples:

- `RunLauncherSearch`
- `ActivateLauncherItem`
- `IngestNotification`
- `DismissNotification`
- `HandleCompositorEvent`

### Policy

A policy is pure decision logic.

Allowed:

- ranking
- dedup
- fallback
- prioritization
- replacement rules
- filtering

Not allowed:

- adapter calls
- store mutation
- hidden state beyond constants/config inputs

Examples:

- `LauncherScoringPolicy`
- `NotificationDedupPolicy`
- `DegradedModePolicy`

### Selector

A selector is a pure derivation of existing state.

Allowed:

- filtering
- sorting
- grouping
- flattening
- small presentation-oriented reshaping

Not allowed:

- side effects
- owning truth
- hidden caching unless explicitly justified

Examples:

- `selectVisibleWorkspaces`
- `selectLauncherSections`
- `selectUnreadNotificationCount`

### Presentation Model

A presentation model is a named UI-facing projection for a surface that has earned a dedicated presentation boundary.

It is still not canonical state.

It may own **discardable surface-local interaction state** when a Tier 3 surface
needs one local interaction coordinator.

It exists because:

- the surface needs more than a few selectors
- the surface combines multiple domains
- the surface has modes, degraded states, sections, or a meaningful presentation state machine

Allowed:

- pure projection of domain state for one surface
- surface-local selection, local mode, or focus state that can be discarded when
  the surface closes or is rebuilt
- coordination of transient interaction state across components inside that
  surface

Not allowed:

- canonical cross-surface truth
- persistence ownership
- domain mutations outside use cases
- hidden duplication of store state that should be authoritative elsewhere

Rules for mutable presentation-model state:

- it must be local to one surface
- it must have a clear reset condition
- it must not be persisted
- it must not outlive the surface that owns it
- it must not mirror authoritative store fields unless there is a documented
  shadow-state need covered by ADR-0006

Examples:

- `LauncherPresentationModel`
- `BarPresentationModel`
- `NotificationCenterPresentationModel`

## Binding Tier Decision Tree

Use this decision tree when implementing a surface.

### Step 1: Is the surface reading one domain with trivial shaping?

Examples:

- one chip showing one value
- one OSD reading one store
- one simple workspace strip

If yes:

- use **Tier 1: Direct-bound surface**

### Step 2: Does the surface need pure shaping but no real presentation boundary?

Signals:

- filtering or sorting existing state
- grouping for display
- a few derived labels or badges
- maybe reads from more than one store, but remains obviously a pure derivation

If yes:

- use **Tier 2: Selector-shaped surface**

### Step 3: Does the surface have enough presentation logic that direct binding or ad hoc selectors would become messy?

Signals:

- reads from multiple domains
- has modes, sections, or a state machine
- has loading, error, or degraded states
- requires many derived fields
- needs stable UI-facing structure independent of raw store shapes
- selector logic is reused or getting hard to understand

If yes:

- use **Tier 3: Presentation-model surface**
- place shared transient interaction state for that surface in the presentation
  model rather than duplicating it across child views

## Promotion Rules

Start with the lightest tier that works.

Promote a surface upward only when it earns it.

### Promote from Tier 1 to Tier 2 when:

- the view starts carrying nontrivial shaping logic
- the same derivation appears more than once
- raw store binding becomes noisy or repetitive

### Promote from Tier 2 to Tier 3 when:

- the surface consumes multiple domains in a meaningful way
- it needs 10+ nontrivial derived fields
- it gets modes, sections, or degraded states
- it needs a stable presentation contract
- it becomes difficult to understand from selectors alone

## Naming Recommendation

Avoid describing surfaces as merely "complex" or "non-complex".

Use:

- `direct-bound`
- `selector-shaped`
- `presentation-model`

These names are better because they describe the architectural treatment, not a subjective feeling.

## Examples

### Likely Tier 1 early

- volume OSD
- one weather chip
- one battery chip
- one simple toast notification

### Likely Tier 2 early

- workspace strip
- media chip with a few derived labels
- simple session overlay options

### Likely Tier 3 early

- launcher
- notification center/history
- aggregate bar model
- workspace overview, if built

## Consequences

Positive:

- stores stay smaller and clearer
- view files do less hidden shaping work
- not every surface gets a heavyweight presentation model
- the architecture scales with actual surface complexity

Negative:

- the team must exercise judgment about promotion timing
- there will be gray areas between Tier 2 and Tier 3

## Guardrail

Default to the lighter tier.

Do not create a presentation model just because a surface might become complicated later.

Earn it through real pressure in the code.

## Revisit Conditions

Revisit this ADR if:

- selectors start turning into hidden mini-view-models everywhere
- stores repeatedly accumulate presentation concerns
- or the distinction between Tier 2 and Tier 3 proves too fuzzy in practice

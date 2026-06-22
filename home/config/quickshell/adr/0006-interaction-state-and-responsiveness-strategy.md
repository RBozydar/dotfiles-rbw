# ADR-0006: Interaction State and Responsiveness Strategy

- Status: `Proposed`
- Date: `2026-04-13`

## Context

The shell must feel immediate, but not all state should be pushed through the core at interaction speed.

A binary split of "fast path vs state path" is too coarse for a desktop shell. Many interactions need:

- immediate local feedback
- authoritative reconciliation from the real system
- clear rules for when disagreement should be shown to the user

This ADR defines the interaction-state model and the default reconciliation behavior.

## Decision

Use a **3-tier interaction state model**:

1. **UI-local transient**
2. **UI-shadowed, core-authoritative**
3. **Core-authoritative**

Default reconciliation rule:

- optimistic or shadowed state should **revert by default** if authoritative state disagrees
- visible reconciliation should occur **only when the mismatch matters**

## Tier Definitions

### 1. UI-local transient

This state stays entirely in the UI layer.

Examples:

- hover
- pressed state
- cursor feedback
- animation progress
- scroll offset
- temporary focus ring
- local list highlight if it only matters inside one surface

Properties:

- does not need to survive close/reload
- does not need logging or persistence
- does not affect system correctness

### 2. UI-shadowed, core-authoritative

This state gets immediate local feedback, but the real system still owns the committed result.

Examples:

- slider dragging with immediate thumb movement
- launcher text input echo
- pending toggles
- temporary optimistic previews

Properties:

- local feedback is immediate
- authoritative state comes from core/adapters
- disagreement triggers reconciliation

### 3. Core-authoritative

This is real domain state.

Examples:

- launcher results
- notification lifecycle
- workspace/window/focus state
- unread counts
- settings
- pinned items
- history/frecency
- actual audio/media state

Properties:

- one canonical owner
- can affect multiple surfaces
- should be testable, inspectable, and loggable

## Mismatch Rule

The key rule is:

**A mismatch matters when the user could reasonably make a different next decision because the UI is showing the wrong state.**

### A mismatch matters if:

- the UI implies an action succeeded but it failed
- the UI implies the wrong target is active or selected
- the mismatch could cause the next action to hit the wrong thing
- the state is destructive, security-sensitive, or session-level
- the mismatch lasts long enough for a human to perceive and act on it
- the mismatch changes system meaning, not just presentation

### A mismatch usually does not matter if:

- it is purely visual
- it self-corrects before the user can act on it
- it does not change the next possible intent
- it is a small numeric drift with no semantic consequence
- it is just intermediate shaping while authoritative state catches up

## Reconciliation Policy

### Default

- UI-local transient state is not reconciled through the core
- UI-shadowed state reverts by default when authoritative state disagrees
- core-authoritative state always wins

### Visible reconciliation

Show visible reconciliation only when:

- the user needs to know their action did not succeed
- the mismatch changes the meaning of the state
- the mismatch affects the next interaction
- the operation is destructive, security-sensitive, or session-level

Otherwise:

- reconcile silently

## Agreed Examples

### Launcher

- query echo: `UI-shadowed`
- results: `Core-authoritative`
- selected row: `Presentation-model local` for a Tier 3 launcher surface,
  otherwise `UI-local transient`
- activation: use case through the core

Implementation implication:

- text input updates immediately in the UI
- core search can be debounced
- results replace shadow assumptions authoritatively
- selection state should have one local owner, not parallel copies in both the
  view tree and presentation model

### Volume Control

- thumb drag: `UI-shadowed`
- actual sink volume: `Core-authoritative`
- mute button press affordance: `UI-local transient`
- mute state: `Core-authoritative`

Default behavior:

- slider feels immediate
- authoritative state snaps/corrects it
- show visible failure only if the backend did not actually apply the meaningful user action

### Notifications

- popup hover/expansion: `UI-local transient`
- history, unread count, dismissal state: `Core-authoritative`

### Session Actions

- no optimistic committed state
- show pending, then success/failure

This category is too important to fake with optimistic final state.

## Operational Rules

### Rule 1

Do not route purely visual feedback through the core.

### Rule 2

Do not let shadow state become canonical state.

### Rule 3

Authoritative state must always be able to override optimistic/shadow state.

### Rule 4

If authoritative confirmation is expected quickly, default to silent correction unless the mismatch matters.

### Rule 5

High-frequency interactions that call adapters must be throttled, coalesced, or otherwise controlled.

## Consequences

Positive:

- responsive UI
- clearer ownership of authoritative state
- less temptation to centralize every interaction
- explicit rules for optimistic UI behavior

Negative:

- requires judgment about when a mismatch matters
- some surfaces will mix tiers and need discipline
- reconciliation behavior must be implemented consistently

## Revisit Conditions

Revisit this ADR if:

- shadow state starts spreading without clear boundaries
- the shell develops visible latency despite local interaction handling
- the team repeatedly disagrees about what belongs in UI vs core

At that point, this ADR may need concrete subsystem-specific addenda.

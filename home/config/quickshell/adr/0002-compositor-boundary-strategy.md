# ADR-0002: Compositor Boundary Strategy

- Status: `Accepted`
- Date: `2026-04-13`

## Context

The shell depends heavily on compositor state and actions.

The naive options are:

- let UI and services talk to Hyprland directly
- build one generic compositor abstraction

Both are risky:

- direct Hyprland usage leaks dependency details everywhere
- fake generic abstractions often become thin mirrors of the real API and buy little

## Decision

Use **capability-oriented compositor boundaries** rather than one giant generic compositor interface.

Examples of capabilities:

- monitor state
- workspace state
- window state
- compositor actions
- optional session/overlay coordination if truly needed

Hyprland-specific details are allowed inside the adapter layer, but should not leak beyond it.

## Rationale

This keeps the abstraction honest.

The shell does not need a fake universal compositor model. It needs normalized access to the capabilities it actually uses.

Capability-oriented boundaries:

- reduce abstraction dishonesty
- make contracts easier to reason about
- make degradation clearer
- avoid a single oversized compositor interface

## Consequences

Positive:

- clearer contracts
- less risk of building a useless abstraction
- easier to evolve as shell needs expand

Negative:

- some cross-capability coordination may need explicit orchestration
- if a second compositor ever becomes real, some capability models may need refinement

## Required Follow-Ons

- define the first compositor-facing contracts explicitly
- centralize raw `hyprctl` or Hyprland-specific behavior in the adapter layer
- prevent direct compositor calls from UI modules

## Revisit Conditions

Revisit this decision only if:

- a second compositor becomes a real target
- or multiple subsystems truly need a shared higher-level compositor contract beyond capability boundaries

# ADR-0003: Delivery Strategy

- Status: `Accepted`
- Date: `2026-04-13`

## Context

The architecture introduces real boundaries:

- core
- adapters
- UI

That creates a delivery choice:

- build layers horizontally first
- or define the boundaries and then prove them through thin vertical slices

Horizontal buildout is attractive on paper, but it tends to produce a lot of abstract code before the architecture is proven under real user-facing behavior.

## Decision

Use **vertical slices through fixed boundaries**.

The first meaningful slice should be:

- focused monitor and focused workspace state
- from the compositor adapter
- through core state and read models
- into a minimal UI surface

The architecture is defined first, but implementation should proceed slice by slice.

## Rationale

This approach proves:

- the boundaries are real
- the UI remains responsive
- the contracts are usable
- the architecture fits the product

early enough that correction is still cheap.

## Consequences

Positive:

- faster proof of architectural fitness
- less speculative code
- earlier feedback on latency, coupling, and awkward boundaries

Negative:

- requires discipline to avoid taking shortcuts through layers
- may feel slower than hacking a feature straight into the UI, even though it reduces long-term rework

## Required Follow-Ons

- keep milestones end-to-end, not layer-completion milestones
- add explicit review gates after the first slice and after launcher core
- prevent “just for now” shortcuts from bypassing the boundaries

## Revisit Conditions

Revisit only if:

- the slices are too thin to produce useful learning
- or the architecture proves so stable and repetitive that some supporting infrastructure can be built more horizontally without risk

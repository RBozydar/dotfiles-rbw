# ADR-0020: Legacy Tree Cutover and Migration Strategy

- Status: `Proposed`
- Date: `2026-04-14`

## Context

The repository currently has two architectural realities:

1. the active live shell under `home/config/quickshell/`
2. the future shell-system architecture scaffold under `home/config/quickshell/system/`

Without an explicit migration policy, agents will keep taking the easiest local
path:

- adding new architecture to the live tree
- bypassing the new `system/` boundaries
- mixing legacy runtime code with future architecture opportunistically
- making `system/` look like the intended architecture while the real product
  continues evolving somewhere else

That would defeat most of the agent-first guardrail work.

## Decision

Adopt an explicit **dual-tree migration mode** until cutover is complete.

There are two recognized trees:

- **legacy tree**
  The active live shell outside `system/`
- **system tree**
  The future shell-system implementation under `system/`

## Legacy Tree Rules

The legacy tree remains the active runtime until explicit cutover.

Allowed work in the legacy tree:

- bug fixes
- regressions and break/fix work
- operational scripts and smoke-test support for the active shell
- migration shims explicitly approved by this ADR or a structured exception
- user-requested legacy-shell feature work when building the same thing in
  `system/` would be disproportionate or out of scope

Disallowed by default in the legacy tree:

- new foundational architecture
- new reusable state-management patterns
- new extension/plugin systems
- architectural borrowing from `system/` by ad hoc imports

## System Tree Rules

The `system/` subtree is the only place where new greenfield architecture should
be introduced by default.

Preferred work in `system/`:

- canonical examples
- contracts
- stores, use cases, policies, selectors, presentation models
- adapters
- `verify`, `review`, and `arch-check`
- new subsystem architecture intended for the future shell

## Cross-Tree Dependency Rules

Until cutover:

- legacy tree code must not import from `system/` by default
- `system/` code must not depend on legacy runtime modules by default
- shared behavior should not be coupled across trees unless an explicit
  migration bridge exists

Approved cross-tree sharing by default:

- ADRs and documentation
- test and verification tooling
- explicitly shared static assets or scripts when documented

Any runtime bridge must be:

- explicit
- narrow
- time-bounded
- covered by structured exception metadata

## Review and Verification Policy

`verify` and `arch-check` must classify changes by tree:

- legacy-only change
- system-only change
- cross-tree change

Policy by change class:

- legacy-only:
    - enforce freeze rules and active-shell tests
- system-only:
    - enforce the new architecture rules
- cross-tree:
    - require elevated review and explicit justification

Cross-tree changes should default to higher-risk review handling.

## Cutover Milestones

Cutover should happen in explicit milestones:

1. **Dual-tree mode**
   Legacy shell remains active; `system/` is architecture and implementation
   work only.
2. **First system-backed runtime slice**
   A clearly bounded surface or subsystem is powered by `system/` through an
   explicit bridge.
3. **System-owned entrypoint**
   The primary runtime entrypoint is owned by `system/`.
4. **Legacy freeze**
   Legacy tree becomes read-mostly except for retirement or compatibility work.

Do not imply cutover merely because `system/` exists.

## AGENTS and Tooling Implications

`AGENTS.md` files should declare whether they govern:

- legacy tree behavior
- system tree behavior
- or migration/cross-tree policy

`arch-check` should be able to detect:

- legacy-tree architectural expansion that belongs in `system/`
- forbidden cross-tree imports
- missing migration justification for cross-tree changes

## Consequences

Positive:

- architecture work stops being silently bypassed by the active runtime tree
- migration becomes explicit and reviewable
- verification can enforce different policies for legacy and future code

Negative:

- the repo temporarily carries two rule sets
- some requested features will need explicit triage about which tree they belong
  in
- cross-tree work becomes intentionally slower

## Revisit Conditions

Revisit this ADR when:

- the first system-backed runtime slice lands
- a primary entrypoint cutover is proposed
- or legacy-tree exceptions start accumulating enough to indicate the freeze
  policy is not holding

At that point, tighten rather than relax the migration rules.

# ADR-0007: Agent-First Architecture Guardrails

- Status: `Proposed`
- Date: `2026-04-14`

## Context

This shell is expected to be authored primarily or entirely by coding agents.

That changes the architecture problem.

In an agent-authored codebase:

- prose guidance alone is weak
- warnings are easy to ignore
- the easiest local path tends to win
- architecture drifts unless the repo contains machine-checkable constraints and obvious golden paths

Therefore architecture guardrails are not optional hygiene.
They are part of the architecture itself.

## Decision

Use **machine-enforced architecture guardrails with explicit golden paths**.

The guardrail model should have four layers:

1. **Hard blockers**
   Fail CI for clear architecture violations.
2. **Golden paths**
   Provide one obvious, canonical way to perform common tasks.
3. **Structured exceptions**
   Narrowly scoped, explicitly annotated escape hatches.
4. **Smell metrics**
   Non-blocking signals for likely architectural decay.

Human review remains useful, but it is not the primary enforcement mechanism.

## Hard Blockers

The first blocked hazards should be:

### 1. No `hyprctl` outside Hyprland adapter code

Reason:

- compositor coupling spreads extremely quickly otherwise

### 2. No `Hyprland.dispatch(...)` outside allowed adapter/bridge code

Reason:

- direct compositor actions from UI or core bypass the architecture

### 3. No `Quickshell.execDetached(...)` in UI code

Reason:

- direct side effects from UI destroy the boundary model

### 4. No forbidden import direction

At minimum:

- `core/` must not depend on `ui/`

Required dependency shape:

- `core/` may depend only on core code and shared contract definitions
- `adapters/` may depend on `core/` and shared contracts, but not `ui/`
- `ui/` may depend on core-facing contracts, selectors, and explicitly approved
  bridge code, but not adapter internals or raw system APIs

Legacy-tree rule during migration:

- legacy runtime code outside `system/` must not import from `system/` by
  default
- `system/` code must not depend on the legacy runtime tree by default

Bridge code must be:

- explicit
- narrowly scoped
- confined to a dedicated bridge layer rather than scattered through the UI

Approved bridge locations:

- `system/ui/bridges/`
- any legacy-to-system bridge explicitly allowed by ADR-0020 or a documented
  exception

This is necessary because a single blocked edge is not enough to preserve the
intended architecture.

### 5. No direct persistence writes from UI code

Reason:

- persistence policy must stay below the UI

## Golden Paths

Agents need canonical examples and narrow approved entry points.

The repo should provide:

- one canonical way to dispatch compositor actions
- one canonical command execution path
- one canonical persistence write path
- one canonical store pattern
- one canonical use case pattern
- one canonical selector pattern
- one canonical presentation-model surface

If the right path is not easier than the wrong path, agents will drift.

## Structured Exceptions

Exceptions are allowed only when:

- they are explicit
- they are local
- they include a reason

Recommended annotation shape:

```json
// ARCH-EXCEPTION: {"adr":"ADR-0007","path":"system/ui/bridges/Example.qml","reason":"short reason","owner":"rbw","expiry":"2026-06-01","ticket":"ADR-0020"}
```

Required fields:

- `adr`
- `path`
- `reason`
- `owner`
- `expiry`
- `ticket`

`arch-check` should fail missing, malformed, expired, or over-broad exceptions.

Examples of valid temporary exceptions:

- bridge code during bootstrapping before an adapter exists
- one migration utility that must write persistence directly

Examples of invalid exceptions:

- broad allowlists for all UI code
- silent exceptions hidden in tooling config without local context

## Smell Metrics

These should usually start as non-blocking.

Examples:

- oversized files
- too many imports
- too many adapter dependencies in one use case
- too many mutable exports in one store
- selector/presentation-model proliferation

These are useful for review loops, but they should not replace the hard blockers.

## Agent-Facing Guidance

Architecture guidance should live close to the code.

Use nested `AGENTS.md` files for:

- the legacy live-shell scope
- `system/`
- `system/core/`
- `system/adapters/`
- `system/ui/`

These files should contain:

- rules
- golden paths
- good examples
- bad examples
- hazard APIs
- references to the approved bridge layer when one exists

## Review Loop

The repo should include an agent-facing architecture review loop.

This can take the form of:

- a review prompt
- a dedicated review command
- a scripted review mode that checks work against ADRs and guardrails

The purpose is:

- verify new code against architectural decisions
- surface active exceptions
- catch drift before it compounds

## Tooling Strategy

Start with cheap, explicit enforcement.

Preferred initial tools:

- grep-based checks
- path-aware scripts
- CI failure for hard blockers

Do not begin with a heavy custom linter unless the cheap checks stop being effective.

## Consequences

Positive:

- architecture is preserved more reliably in agent-authored code
- the repo teaches the right implementation paths by example
- boundary violations become visible immediately

Negative:

- more up-front repo scaffolding
- exceptions need discipline
- some checks may feel blunt initially

## Follow-On Work

This ADR implies future work on:

- architecture fitness scripts
- canonical example implementations
- a review prompt or review skill for shell changes
- formatter/linter strategy for the new system subtree

## Revisit Conditions

Revisit this ADR if:

- the guardrails create too many false positives
- the golden paths prove too vague to guide agent changes
- or the architecture begins to drift despite the current checks

If that happens, increase precision, not permissiveness.

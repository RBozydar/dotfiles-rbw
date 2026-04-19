# ADR-0009: Concurrency, Idempotency, and Stale State Handling

- Status: `Proposed`
- Date: `2026-04-14`

## Context

The shell operates in a volatile environment.

Between intent and effect:

- windows can disappear
- workspaces can change
- notifications can expire
- adapters can report newer state
- users can issue another action
- external systems can reject or replace the target

Without an explicit concurrency policy, these systems usually decay into:

- hidden race conditions
- brittle assumptions after async boundaries
- duplicate effects from retries or repeated events
- crashes for stale targets that should have been normal no-op cases
- UI drift because late results overwrite newer intent

This ADR defines how the shell should behave when the world changes underneath
ongoing work.

## Decision

Use a **volatile-world concurrency model** with four core rules:

1. **Assume state may be stale after any async boundary.**
2. **Return explicit operation outcomes instead of treating stale cases as exceptional by default.**
3. **Prefer idempotent use cases and desired-state commands over toggle-style mutation where practical.**
4. **Choose a concurrency strategy by operation class, not ad hoc per feature.**

## Rule 1: Staleness Is Normal

After any `await`, adapter call, or asynchronous boundary:

- do not assume the target still exists
- do not assume the target still has the same revision
- do not assume the selected item is still the active one

Revalidate before commit when the operation depends on a volatile target.

Examples:

- refetch a window by `windowId` before activating or moving it
- confirm a notification still exists before dismissing it
- confirm the relevant query generation before committing search results

Stale state is a routine condition, not an exceptional one.

## Rule 2: Structured Operation Outcomes

Use cases should return plain structured outcomes.

Recommended default statuses:

- `applied`
- `noop`
- `stale`
- `rejected`
- `failed`

Typical meanings:

- `applied`
  The intended effect was committed.
- `noop`
  The addressed target is still semantically valid and the requested postcondition already holds, or the action has no further work to do.
- `stale`
  The addressed target, generation, or preconditions no longer refer to the same world state, so the operation cannot be applied as requested.
- `rejected`
  The request was valid but policy or capability did not permit it.
- `failed`
  The operation attempted work but did not complete successfully.

These outcomes should be plain serializable objects, consistent with ADR-0004.

Outcome envelope recommendation:

- `{ status, code?, reason?, targetId?, generation?, meta? }`

Use `generation` for replaceable read-like work and any UI-shadowed interaction
whose late result could overwrite newer intent.

## Global Outcome Semantics

Use statuses consistently across subsystems.

Rules:

- `noop` means "same target, same intended postcondition, nothing left to do"
- `stale` means "the intended target or generation is no longer current"
- `rejected` means "the request was understood but not permitted or supported"
- `failed` means "the operation attempted execution and did not complete"

Example:

- dismissing a notification that still exists but is already dismissed: `noop`
- dismissing a notification that no longer exists: `stale`
- committing results for an older launcher query generation: `stale`

## Rule 3: Prefer Idempotent Semantics

Where practical, actions should be safe to repeat.

Prefer:

- `setMuted(true)`
- `setWorkspaceFocus("3")`
- `dismissNotification(id)`

Over:

- `toggleMute()`
- `focusNextWorkspace()`
- other mutation styles whose meaning depends on hidden intermediate state

This does not ban toggle-style UI interactions.

It means the use case and adapter boundary should prefer desired-state or
targeted commands where the underlying system supports them.

If true idempotency is not available:

- document the limitation
- constrain concurrency more tightly
- return explicit outcomes

## Rule 4: Concurrency Is Chosen by Operation Class

Do not let every subsystem invent its own concurrency behavior.

Use these default operation classes.

### 1. Replaceable Read-Like Work

Examples:

- launcher search
- filtering and ranking refreshes
- expensive derived queries

Policy:

- newest request wins
- older in-flight results must not overwrite newer intent
- generation or request tokens should guard commits
- cancellation or short-circuiting obsolete work is preferred when it is cheap
  and practical, but discarding late results is the minimum acceptable behavior

If an older result arrives late:

- discard it silently

### 2. Mutating Targeted Work

Examples:

- dismiss notification
- focus window
- pin item
- update setting

Policy:

- revalidate target on commit
- preserve user intent ordering per target or per domain key when needed
- duplicate requests should become `noop` where practical
- default implementation should use keyed single-flight or keyed queues when the
  same target can be mutated repeatedly in quick succession

These operations should not blindly race against themselves.

### 3. High-Frequency Interactive Work

Examples:

- slider-driven updates
- typeahead search
- live previews

Policy:

- debounce, throttle, or coalesce before expensive or external effects
- UI may use local or shadow state per ADR-0006
- authoritative commits still require explicit reconciliation

### 4. Critical Session or Destructive Work

Examples:

- lock
- suspend
- logout
- shutdown

Policy:

- single-flight
- no optimistic final-state assumption
- explicit success or failure handling
- no automatic retry unless the operation contract explicitly supports it

## Latest-Wins vs Ordered Operations

Use latest-wins only for replaceable work.

Do not apply latest-wins blindly to user mutations.

Examples:

- launcher query result computation: latest-wins
- setting a preference repeatedly while editing: latest committed value wins
- sequential dismiss actions on distinct notifications: preserve each intent
- session actions: do not race at all

This distinction matters because "newest request wins" is correct for query
work, but wrong for many user actions.

## Revalidation Strategy

When an operation depends on a volatile entity:

- carry a stable identifier, not a live reference
- optionally carry a known revision or generation when useful
- reacquire authoritative state before commit if the risk of drift matters

Recommended default:

- identifiers are stable
- revisions are used when stale overwrite risk is meaningful

Do not hold implicit trust in previously read live objects across async
boundaries.

## Handling Stale Targets

If a target vanished or changed incompatibly:

- return `stale` or `noop`
- do not crash
- do not treat normal staleness as an exceptional control-flow path

Whether the user sees the stale outcome depends on ADR-0006:

- surface it only when the mismatch matters

Examples:

- activating a window that already closed: `stale`
- dismissing a notification already gone: `noop` or `stale`
- writing late search results for an old query generation: silently discard

## Default UX Policy By Outcome

- `applied`
  Treat as success.
- `noop`
  Usually silent unless the surface explicitly needs affirmative feedback.
- `stale`
  Silent for replaceable work by default; visible only when ADR-0006 says the
  mismatch matters.
- `rejected`
  Usually visible for direct user-initiated actions.
- `failed`
  Visible or logged unless the caller explicitly downgrades the failure as
  expected noise.

## Event Ingestion and Reconciliation

Incremental events are useful, but drift is inevitable.

Therefore:

- event handlers may apply incremental updates
- periodic or explicit snapshot reconciliation should remain available
- authoritative snapshots may replace earlier inferred state

This is especially important for:

- compositor state
- notifications
- optional integrations with weaker event guarantees

## Persistence and Concurrency

Persistence should follow ADR-0008.

Additional concurrency rules:

- machine-managed state writes should be safe to repeat
- last-known durable state should be written intentionally, not on every tiny mutation by reflex
- caches may be rebuilt rather than merged when concurrency becomes awkward

Do not let persistence become an implicit lock or coordination mechanism.

## Retry Policy

Do not retry automatically by default.

Automatic retry is allowed only when:

- the operation is known to be idempotent
- the retry policy is explicit
- duplicate side effects are acceptable or prevented

Otherwise:

- return `failed` or `stale`
- let a higher layer decide what to do

## Logging and Diagnostics

Concurrency-sensitive outcomes should be diagnosable.

At minimum, systems should make it possible to inspect:

- operation type
- target identifier when applicable
- outcome status
- stale or rejection reason when available

This supports later observability work without forcing this ADR to define the
full logging strategy.

## Implementation Clarifications (2026-04-17)

The following clarifications were added after launcher/persistence hardening.

### 1. Generation and Revision Naming

Use explicit naming by responsibility:

- `revision`
  durable or domain state mutation counter
- `generation`
  replaceable read-like request/result lineage counter

Do not treat these as interchangeable even when both are numeric counters.

### 2. Stale Outcome Visibility Boundary

Core and adapter layers should return explicit stale/noop outcomes.

Whether stale/noop is surfaced to the user remains a product interaction policy
decision and should be aligned with:

- ADR-0006 interaction-state guidance
- ADR-0012 quality/release feedback policy
- ADR-0013 launcher-specific UX policy for async providers

### 3. Late Result Discarding Is Correctness, Not Optimization

For replaceable read-like operations, dropping superseded generation results is
a correctness rule.

This should not be treated as an optional performance optimization.

## Consequences

Positive:

- stale-target behavior becomes predictable
- use cases become safer under event-driven churn
- late results stop overwriting newer intent
- retries and duplicates become less dangerous

Negative:

- some operations need more explicit outcome handling
- generation/revision tracking adds structure
- teams must resist the temptation to treat stale cases as generic exceptions

## Revisit Conditions

Revisit this ADR if:

- multiple domains need different concurrency semantics than these classes allow
- stale/result generation handling becomes too repetitive and needs shared helpers
- the runtime moves to a split-process model and transport-level sequencing changes

If that happens, refine the operation classes rather than abandoning them.

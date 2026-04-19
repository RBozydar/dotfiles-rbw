# ADR-0004: Contract Model for Cross-Layer Data

- Status: `Proposed`
- Date: `2026-04-13`

## Context

The shell architecture depends on explicit boundaries between:

- core
- adapters
- UI

Those boundaries are only real if the data moving across them is well-defined.

The main options are:

- use plain serializable objects as contracts
- use richer objects or classes with attached behavior

This decision matters because these contracts may later:

- cross process boundaries
- be persisted
- be logged or diffed
- be validated
- be consumed by both JS modules and QML

## Decision

Use **plain serializable objects with runtime validation** for all cross-layer contracts.

This applies to:

- intents
- commands
- events
- read models
- adapter outputs
- persistence payloads

These contract objects should:

- be plain data
- avoid attached methods
- avoid hidden identity semantics
- be easy to serialize and inspect

Behavior should live in:

- use cases
- policies
- pure helper modules
- narrow factory/normalization functions that return plain objects

## Validation Mechanism

Use **contract-local runtime validators built on shared validation helpers**.

This means:

- each contract module defines its own expected shape
- validation runs at boundary entry points
- normalization/factory helpers may return validated plain objects
- ad hoc inline validation scattered through use cases should be avoided

This is a better fit than rich classes, and lower-risk than introducing a large
schema framework before the system has real implementation pressure.

## Contract Location

Place cross-layer contract definitions under:

- `system/core/contracts/`

Reason:

- the current system is single-process
- UI and adapters may import contracts without making core depend on them
- this keeps boundary definitions in one canonical place early

If the runtime later splits into a separate core process and frontend, revisit
this by extracting contracts into a shared protocol package rather than
duplicating them.

## Naming Rules

Use namespaced, dot-separated identifiers for cross-layer contract types.

Recommended rules:

- commands and intents use imperative names
- events use past-tense names
- read models use noun-based names
- persistence payloads use domain root objects with `schemaVersion`

Examples:

- command: `launcher.run_search`
- intent: `session.request_lock`
- event: `launcher.search_completed`
- read model kind: `launcher.result_list`

## Minimal Contract Envelopes

Use small, regular envelopes for message-like contracts.

Recommended defaults:

- command or intent:
    - `{ type, payload?, meta? }`
- event:
    - `{ type, payload?, meta? }`
- operation outcome:
    - `{ status, code?, reason?, targetId?, meta? }`
- read model root:
    - `{ kind, ...domainFields }`

Recommended metadata fields when needed:

- `requestId`
- `generation`
- `timestamp`
- `source`

Do not add optional fields speculatively.

Use the smallest envelope that preserves:

- validation
- tracing
- stale-result handling
- cross-layer consistency

## Examples

Preferred:

```js
{
  id: "app:foot",
  kind: "launcher_item",
  title: "Foot",
  subtitle: "Terminal",
  provider: "apps",
  action: {
    type: "launch_app",
    targetId: "foot.desktop"
  }
}
```

Avoid:

```js
{
  id: "app:foot",
  title: "Foot",
  activate() { ... },
  toUiModel() { ... },
  score(query) { ... }
}
```

## Rationale

Plain data contracts are a better fit because they are:

- easier to validate
- easier to serialize
- easier to persist
- easier to test
- easier to log and diff
- easier to move across an IPC boundary later
- less likely to smuggle business logic into the wrong layer

This is especially important in a shell because:

- the system is event-driven
- data crosses subsystem boundaries frequently
- debugging often depends on inspecting raw state
- the architecture may later evolve toward split-process

## Consequences

Positive:

- contracts remain stable and inspectable
- boundary crossing stays explicit
- future IPC migration is easier
- QML and JS interop stays simpler

Negative:

- invariants are not automatically enforced unless validation is present
- data and behavior are more separate
- there is some risk of “bags of fields” if schemas are sloppy

## Constraints

This ADR does **not** ban richer internal abstractions everywhere.

It only says that **cross-layer contracts** should be plain validated data.

Internal helpers may still use:

- pure functions
- factories
- normalization helpers
- domain-specific modules

If an internal abstraction is introduced, it should not become the boundary format unless there is a strong reason.

## Remaining Open Question

The remaining follow-up decision is:

- whether the contract package should stay under `system/core/contracts/` long
  term or be extracted into a shared protocol package once split-process becomes
  real rather than hypothetical

## Revisit Conditions

Revisit this only if:

- the core moves to a strongly typed separate runtime and richer internal types become materially beneficial
- or the contract model proves too weak to maintain invariants without excessive duplication

Even then, the default assumption should remain:

- rich internal types are acceptable
- cross-layer contract data should still stay plain

# ADR-0011: Logging, Observability, and Debuggability Strategy

- Status: `Proposed`
- Date: `2026-04-17`

## Context

As subsystems grow, operational failures become harder to diagnose:

- stale outcomes vs real failures can be confused
- adapter failures can be silent without explicit instrumentation
- cross-layer command paths become opaque without correlation identifiers

The shell already uses operation outcomes. This ADR defines the minimum
observability layer needed to debug and operate the system reliably.

## Decision

Adopt a **structured local observability model** based on:

1. normalized event fields
2. subsystem categories
3. correlation identifiers
4. local-first debug surfaces

## Event Schema

Diagnostics events should use a plain serializable envelope with these fields:

- `timestamp`
- `level` (`debug`, `info`, `warn`, `error`)
- `subsystem`
- `code`
- `message`
- optional: `status`, `targetId`, `requestId`, `generation`, `meta`

`status` values should align with ADR-0009 operation outcomes where applicable.

## Subsystem Categories

Use stable categories to keep logs queryable:

- `core.<domain>`
- `adapter.<integration>`
- `ui.<module>`
- `ops.<harness_or_cli>`

Examples:

- `core.launcher`
- `adapter.persistence`
- `ui.notifications`

## Correlation and Causality

- Introduce `requestId` for command or use-case entrypoints.
- Preserve `requestId` across adapter calls and returned outcomes.
- Include `generation` in logs for replaceable read-like paths (launcher search).

This is required to diagnose stale-result or late-commit behavior.

## Output and Storage

- Human-readable diagnostics may go to stderr for interactive runs.
- Structured diagnostics should support JSON lines for tooling.
- Persistent debug logs should live under `XDG_STATE_HOME`, not config.
- Log retention/rotation must be bounded and configurable.

## Debug Surfaces

Each major subsystem should expose an operator-friendly snapshot surface:

- command catalog and protocol describe surfaces (`shellctl describe`)
- domain snapshot describe commands (for example `settings.describe`,
  `launcher.describe`, `notifications.describe`)

These commands are part of observability, not just user features.

## Required Guardrails

- no ad hoc `console.log` noise in committed hot paths
- use stable `code` values for machine-readable diagnostics
- include sufficient context in `meta` for reproducible failures
- avoid logging sensitive content by default in non-debug levels

## Consequences

Positive:

- clearer failure triage across core/adapter/ui layers
- easier debugging of race/stale behavior from ADR-0009
- better basis for future performance instrumentation (ADR-0016)

Negative:

- some additional implementation overhead for consistent logging discipline
- teams must maintain event code and category quality over time

## Revisit Conditions

Revisit this ADR if:

- log volume becomes operationally expensive
- correlation fields prove insufficient for multi-step workflows
- split-process migration requires stronger trace/span semantics

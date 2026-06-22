# ADR-0014: Optional Integration Policy

- Status: `Accepted`
- Date: `2026-04-18`

## Context

Phase 7 introduces optional integrations (for example clipboard history, emoji
search, file search, Home Assistant, wallpaper subsystem).

Without an explicit policy:

- optional services can dictate architecture direction
- startup and interaction paths can become integration-coupled
- degraded behavior becomes inconsistent and user-hostile
- trust/privacy posture drifts across integrations

Core shell behavior (bar/session/launcher/notifications/settings/IPC) must stay
stable regardless of optional integration availability.

## Decision

Adopt a **contract-first optional integration policy** with explicit capability
declarations, degraded-mode behavior, and enablement rules.

## What Qualifies as Optional

A feature is optional if all are true:

- shell core remains usable without it
- it depends on external data/services/tooling not guaranteed on every machine
- its absence should degrade one bounded surface, not global shell operation

If any condition fails, it is not optional and should be handled as core scope.

## Integration Contract Requirements

Each optional integration must provide:

- stable integration id and owner
- typed readiness snapshot:
  `enabled`, `available`, `ready`, `degraded`, `reasonCode`, `lastUpdatedAt`
- explicit command/query surface with typed outcomes
- bounded failure behavior (timeouts/retries/backoff)
- no direct business logic in UI modules (bridge + adapter + contract only)

Integrations must not block shell startup composition.

## Capability Declaration

Each integration should declare capability metadata used in review/diagnostics:

- dependency class (`local_tool`, `local_service`, `network_service`)
- data sensitivity (`none`, `local_personal`, `remote_account`)
- effect type (`read_only`, `state_mutation`, `command_execution`)
- latency expectation (`interactive`, `background`)

This metadata drives default enablement and review policy.

## Enablement Policy

Default policy:

- default-enabled:
  local deterministic read-only capabilities with no personal-content access
- default-disabled (explicit opt-in required):
  network-backed integrations, remote-account integrations, and integrations
  accessing personal content or executing arbitrary external actions

Enablement must be operator-visible through settings and IPC diagnostics.

## Degraded Mode Policy

Required degraded behavior:

- core shell remains fully functional
- integration surfaces show explicit unavailable/degraded state
- no hard errors in unrelated modules
- no blocking waits on missing dependencies in interactive paths

Degraded reasons must use stable reason codes for operator tooling.

## Data and Persistence Policy

Optional integrations may persist bounded state only if:

- persisted shape is schema-versioned
- retention/size limits are explicit
- data ownership is documented by integration id

Integration persistence must follow ADR-0008 durability/migration rules.

## Testing and Quality Gates

Each optional integration requires:

- unit tests for normalization and degraded behavior
- integration/smoke path with dependency missing
- at least one happy-path verification run when dependency is present

Phase-7 integrations should not bypass architecture guardrails.

## Owner Decision Required

### 1. Trust-Tier Matrix Sign-Off

Decision needed:

- confirm default-on vs default-off rules by dependency/sensitivity/effect class

Consequence of wrong call:

- either unsafe defaults or excessive friction for benign capabilities

### 2. Day-1 Integration Allowlist

Decision needed:

- which specific optional integrations are allowed in the first Phase-7 batch

Consequence of wrong call:

- either architecture dilution from too many integrations at once
- or delayed value from over-restriction

### 3. Degraded-Mode UX Strictness

Decision needed:

- minimal UX requirements for unavailable/degraded surfaces
- whether any degraded-state omissions are merge blockers

Consequence of wrong call:

- inconsistent UX quality and hidden operational failures

## Recommended Owner Defaults (Ready for Sign-Off)

### 1. Trust-Tier Matrix

Recommended defaults:

- default-on:
  local deterministic read-only integrations with `dataSensitivity=none`
- default-off:
  any integration with `network_service`, `remote_account`,
  `local_personal`, or `command_execution`

### 2. Day-1 Integration Scope

Recommended defaults:

- start with one low-risk integration and one medium-risk integration only
- require a completed adapter+bridge+contract+degraded path before adding next

### 3. Degraded-Mode Merge Policy

Recommended defaults:

- missing-dependency smoke behavior is required and merge-blocking
- happy-path dependency-present checks are advisory until host automation is
  mature

## Owner Decision (2026-04-18)

Owner-approved defaults:

- trust-tier matrix:
  default-on for local deterministic read-only + non-sensitive integrations;
  default-off for network/remote-account/personal-content/command-execution
  integrations
- day-1 integration scope:
  start Phase 7 with one low-risk and one medium-risk integration, then expand
  incrementally
- degraded-mode merge policy:
  missing-dependency degraded behavior is merge-blocking; dependency-present
  checks remain advisory until host automation matures

## Consequences

Positive:

- optional integrations remain additive and bounded
- architecture ownership stays in core/contracts rather than integration quirks
- operational behavior is diagnosable and consistent

Negative:

- more up-front policy overhead per integration
- potential slower initial integration throughput

## Revisit Conditions

Revisit this ADR if:

- repeated integration patterns justify shared scaffolding changes
- trust/privacy posture requirements change
- optional integrations begin to dominate runtime complexity

# ADR-0013: Launcher Provider Model and Ranking Persistence

- Status: `Proposed`
- Date: `2026-04-17`

## Context

The launcher is becoming a major subsystem:

- app catalog results
- command-mode autocomplete
- calculator and action entries
- future async providers and optional integrations

Without an explicit provider and ranking model:

- provider behavior diverges by implementation
- ranking becomes opaque and hard to debug
- persistence strategy becomes accidental and privacy-risky

This ADR defines the launcher provider contract, orchestration behavior, and
ranking persistence model.

## Decision

Adopt a **provider-registry + deterministic orchestration model** with explicit
ranking persistence.

## Provider Contract

Each provider must declare:

- stable provider id
- provider kind (`sync` or `async`)
- supported modes (normal query, command mode, etc.)
- result schema compatibility

Each provider returns normalized launcher items with:

- stable `id`
- `providerId`
- `title`/`detail`
- `score` components or base score
- action payload for activation use case

## Orchestration Policy

- Sync providers are evaluated in the immediate search path.
- Async providers may resolve later, but commits require generation validation.
- Late results for superseded generations are discarded.
- Merging and sectioning are deterministic and policy-driven.

Generation behavior must align with ADR-0009 stale handling.

## Ranking Model

Ranking combines:

- match quality score
- deterministic policy boosts (exact match, pinned command boost)
- persisted behavioral signals (recency/frequency)

Ranking should remain explainable and diagnosable:

- include scoring metadata in debug/describe surfaces
- keep score components inspectable for tuning

## Ranking Persistence Strategy

Launcher ranking data is machine-managed durable state.

Recommended persisted shape:

- schema-versioned launcher ranking document
- usage counters and last-used timestamps keyed by stable item identifiers
- bounded history or decayed counters to prevent unbounded growth

Persistence writes should follow ADR-0008 durability guarantees.

## Provisional Engineering Defaults

Until owner sign-off:

- keep command pinning as explicit top-priority override in command mode
- persist only aggregated usage signals needed for ranking
- avoid storing full raw query history by default
- provide CLI-visible diagnostics for ranking state and provider health

## Owner Decision Required

These decisions materially impact product behavior and privacy.

### 1. Personalization Retention Policy

Decision needed:

- retention window for launcher behavioral data
- reset/clear behavior scope

Consequence of wrong call:

- either poor ranking quality or unacceptable privacy posture

### 2. Personalization Opt-In / Opt-Out Policy

Decision needed:

- whether personalized ranking is default-on, default-off, or first-run choice

Consequence of wrong call:

- user trust risk or reduced default launcher usefulness

### 3. Provider Trust and Capability Policy

Decision needed:

- which provider classes are allowed by default
- whether optional providers require explicit enablement

Consequence of wrong call:

- either excessive security/coupling risk or limited launcher capability growth

## Recommended Owner Defaults (Ready for Sign-Off)

### 1. Personalization Retention Policy

Default retention policy:

- persist V2 ranking signals from day 1:
  usage counters, last-used timestamps, pinned command ids
- persist launcher query history from day 1 as a non-blocking async write path
- keep query-history writes append-only and decoupled from the sync search path
- prune/query-log compact with explicit bounds:
  retain up to 90 days and cap at 20,000 entries (oldest dropped first)
- provide explicit reset command that clears launcher ranking/pinning and query
  history state

This keeps ranking and future analytics feasible without adding query latency.

### 2. Personalization Opt-In / Opt-Out Policy

Default personalization policy:

- default-on for local-only ranking signals and local query-history capture
- expose a first-run notice and a permanent toggle in settings/IPC
- when personalization is disabled, stop writing ranking/query-history signals
  immediately
- provide optional clear-on-disable behavior to remove existing ranking/query
  history data

This balances out-of-box usefulness with explicit user control.

### 3. Provider Trust and Capability Policy

Default provider policy:

- default-enabled:
  local deterministic providers (desktop app catalog, shell commands,
  calculator-like pure transforms)
- default-disabled (explicit opt-in required):
  network-backed providers, providers reading personal content, providers
  executing arbitrary external commands
- each provider must declare capability flags used for review and diagnostics

This keeps the launcher extensible without silently expanding trust boundaries.

## Owner Decision (2026-04-17)

Owner-selected policy for ADR-0013:

- adopt V2 launcher behavioral persistence now
- start query-history logging on day 1
- keep query logging asynchronous so launcher interactions do not block on
  persistence
- defer query-history analytics/feature usage to later phases
- use day-1 query-log bounds:
  90-day retention window and 20,000-entry cap

## Consequences

Positive:

- launcher complexity is managed by explicit contracts
- stale-result behavior is consistent with global concurrency policy
- ranking evolves predictably with clear persistence ownership

Negative:

- more up-front policy and contract work before provider expansion
- ranking tuning requires ongoing calibration

## Revisit Conditions

Revisit this ADR if:

- provider diversity exceeds current registry assumptions
- ranking explainability is insufficient for debugging/tuning
- privacy or retention policy changes require different storage granularity

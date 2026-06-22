# ADR-0012: Testing Strategy and Quality Gates

- Status: `Proposed`
- Date: `2026-04-17`

## Context

The shell is largely agent-authored and rapidly evolving.

Without explicit testing and gate policy:

- verification quality drifts by subsystem
- failures are found late in runtime smoke or production use
- merge decisions become inconsistent and person-dependent

This ADR defines what is tested, which checks block, and where owner sign-off is
required.

## Decision

Use a **layered quality gate model** with distinct scopes:

1. static correctness gates
2. deterministic slice tests
3. runtime smoke gates
4. architecture/review governance gates

## Test Taxonomy

### 1. Static and Contract Gates

- format checks
- language lint checks
- architecture fitness checks

### 2. Deterministic Test Slices

- core contract and use-case tests
- adapter slice tests with deterministic stubs
- bridge/model tests for UI-facing projections

### 3. Runtime Smoke Gates

- live Quickshell startup and composition checks
- migration/cutover smoke checks where relevant

### 4. Governance Review Gates

- architecture review classification
- required secondary review evidence for high-risk change classes

## Provisional Gate Policy (Engineering Default)

Until owner sign-off finalizes the release policy:

- `verify` remains required for normal completion claims
- `format`, `lint`, `arch-check`, deterministic tests are blocking
- host runtime smoke remains required for migration-sensitive flows
- required secondary review remains enforced for high-risk changes

## Owner Decision Required

The following are product/delivery policy decisions and need owner sign-off.

### 1. Blocking Matrix by Change Class

Decision needed:

- which change classes require host runtime smoke before merge
- whether any low-risk classes may bypass secondary review requirements

Consequence of wrong call:

- either unacceptable regression risk or excessive delivery friction

### 2. Waiver and Escalation Policy

Decision needed:

- who may approve temporary waivers
- maximum waiver lifetime
- mandatory follow-up conditions

Consequence of wrong call:

- either governance bypass or blocked delivery during urgent fixes

### 3. Release Readiness Threshold

Decision needed:

- whether passing CI verify is sufficient for release
- or whether live smoke and manual scenario checks are mandatory for release tags

Consequence of wrong call:

- either runtime regressions in released configs or unnecessary release delays

## Recommended Owner Defaults (Ready for Sign-Off)

### 1. Blocking Matrix by Change Class

Use three risk classes for merge gating:

- `R0` Documentation/meta-only changes (no executable behavior changes)
- `R1` Regular code changes inside existing boundaries
- `R2` Boundary and runtime-sensitive changes

Classify a change as `R2` if any of the following are touched:

- IPC command protocol shape or command registry behavior
- persistence schema, migration logic, or snapshot durability behavior
- adapter command execution/parsing/lifecycle logic
- shell entrypoints/composition wiring used by live startup

Default merge requirements:

- `R0`
  `format` + `lint`; no secondary review requirement
- `R1`
  full `verify`; secondary review recommended, not blocking
- `R2`
  full `verify` + host runtime smoke; secondary review required and blocking

### 2. Waiver and Escalation Policy

Default waiver policy:

- only owner may approve a waiver
- waiver must include:
  check(s) waived, reason, risk statement, rollback note, follow-up issue/task
- maximum waiver lifetime:
  72 hours
- after expiry, merges are blocked again until checks pass or waiver is renewed

This keeps emergency flexibility while preventing silent permanent bypasses.

### 3. Release Readiness Threshold

Default release threshold:

- passing CI `verify` is required but not sufficient
- release tags additionally require:
  host runtime smoke pass and manual scenario pass for launcher, notifications,
  bar, and IPC command surface
- active unresolved waivers block release tags unless owner issues explicit
  release waiver with expiry

## Consequences

Positive:

- clearer and more predictable quality bar
- fewer late-stage regressions from agent-authored changes
- explicit ownership for risk acceptance decisions

Negative:

- higher upfront cost for writing and maintaining tests
- potential iteration slowdown if blocking scope is set too broadly

## Revisit Conditions

Revisit this ADR if:

- verify runtime grows materially and harms throughput
- blocker rates indicate over-strict or under-strict gating
- the change-risk taxonomy no longer matches actual regression patterns

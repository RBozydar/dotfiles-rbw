# ADR-0016: Performance Budgets and Startup SLAs

- Status: `Proposed`
- Date: `2026-04-17`

## Context

As subsystem complexity increases, performance regressions become easier to
introduce and harder to argue about.

Without explicit budgets:

- performance tradeoffs become subjective
- optimization work is delayed until regressions are severe
- quality gates cannot enforce meaningful responsiveness guarantees

This ADR defines a budget framework, measurement approach, and owner sign-off
decisions for final SLA values.

## Decision

Adopt a **measure-first budget model**:

1. instrument critical flows with consistent metrics
2. establish baseline distributions
3. set and enforce explicit budgets per flow class

## Budget Classes

Track budgets for at least:

- shell startup (cold and warm)
- launcher query-to-results latency
- IPC command round-trip latency
- notification ingestion-to-visible latency

Budgets should be expressed at multiple percentiles (for example `p50` and
`p95`), not only averages.

## Measurement Policy

- instrument intent-to-outcome paths with timestamps and request identifiers
- keep measurements local and reproducible in dev/CI harnesses
- separate sandbox/CI constraints from host-runtime measurements
- store baseline artifacts for trend comparison over time

## Provisional Engineering Defaults

Until owner SLA sign-off:

- enforce no-regression checks against recent baselines for measured flows
- treat severe regressions as blockers in high-risk change classes
- keep budget checks advisory for flows not yet measured on host runtime

## Owner Decision Required

These are product commitments and require owner sign-off.

As of `2026-04-17`, owner selected a deferral policy (see Owner Decision
section). The items below remain the eventual sign-off set once enforcement is
re-enabled.

### 1. Final SLA Numbers

Decision needed:

- target `p50`/`p95` numbers for startup, launcher, IPC, and notifications

Consequence of wrong call:

- either unrealistic commitments or weak responsiveness guarantees

### 2. Merge Blocking Thresholds

Decision needed:

- what regression percentage or absolute delta blocks merges
- whether thresholds differ by change-risk class

Consequence of wrong call:

- either noisy false blockers or unnoticed performance drift

### 3. Release Performance Policy

Decision needed:

- whether release candidates require host-runtime performance checks
- and what waiver process exists for temporary exceptions

Consequence of wrong call:

- either runtime regressions in release builds or unnecessary release friction

## Owner Decision (2026-04-17)

Owner-selected policy for ADR-0016:

- defer performance budget/SLA enforcement until basic functionality milestones
  are complete
- during this phase, do not block merges on SLA thresholds
- during this phase, do not require release-performance suite gates
- handle performance reactively:
  if slowdown is observed in practice, treat it as a prioritized bug and fix it

Revisit trigger:

- after the baseline feature set is complete and stabilized, promote this ADR
  from deferred policy to active enforceable budgets

## Deferred Proposed Defaults (Parking Lot for Later Sign-Off)

### 1. Final SLA Numbers

Use these initial SLA targets (host runtime, reference machine profile):

- shell startup warm:
  `p50 <= 350 ms`, `p95 <= 800 ms`
- shell startup cold:
  `p50 <= 1200 ms`, `p95 <= 2200 ms`
- launcher query to first results (sync providers path):
  `p50 <= 35 ms`, `p95 <= 90 ms`
- IPC command round-trip (simple command):
  `p50 <= 25 ms`, `p95 <= 80 ms`
- notification ingest to visible:
  `p50 <= 80 ms`, `p95 <= 180 ms`

These are deliberately conservative first targets and should be tightened after
baseline data stabilizes.

### 2. Merge Blocking Thresholds

Default merge threshold policy:

- `R2` runtime-sensitive changes:
  block if measured `p95` regresses by more than `20%` and `30 ms` versus
  baseline, or if SLA ceiling is exceeded
- `R1` regular changes:
  advisory warnings on first regression breach; block on repeated breach across
  two consecutive runs
- `R0` docs/meta changes:
  no performance gate blocking

This reduces noisy blockers while still preventing sustained performance drift.

### 3. Release Performance Policy

Default release policy:

- release candidates require host-runtime performance suite execution
- release tags require no unresolved blocking performance regressions
- waivers are owner-only, time-bounded (maximum 7 days), and must include:
  mitigation note plus follow-up task

## Consequences

Positive:

- performance becomes an explicit engineering and product contract
- regressions are caught earlier and debated with evidence
- architecture tradeoffs can be evaluated against concrete budgets

Negative:

- instrumentation and benchmark harness maintenance overhead
- risk of overfitting to measured scenarios if coverage is too narrow

## Revisit Conditions

Revisit this ADR if:

- measured workloads stop representing real usage patterns
- split-process or major architecture shifts change latency characteristics
- budget enforcement causes consistent false positives in normal development

# Owner Decision Packet: ADR-0012 / ADR-0013 / ADR-0016

- Date: `2026-04-17`
- Purpose: convert open owner-decision sections into concrete defaults for
  approval or adjustment

## How To Use This Packet

For each decision below, choose one:

- `Approve as proposed`
- `Approve with edits`
- `Reject and replace`

All recommendations assume:

- agent-authored codebase
- rapid subsystem growth
- preference for strong foundations over local optimizations

## ADR-0012: Testing Strategy and Quality Gates

Reference:

- `adr/0012-testing-strategy-and-quality-gates.md`

### Proposed Defaults

1. Blocking matrix

- `R0` docs/meta-only: `format` + `lint`
- `R1` regular code: full `verify`
- `R2` boundary/runtime-sensitive: full `verify` + host runtime smoke + blocking
  secondary review

2. Waivers

- owner-only approval
- max 72h
- waiver record must include waived checks, risk note, rollback note, follow-up
  task

3. Release threshold

- CI `verify` required
- host smoke + manual scenario pass required for release tags
- active unresolved waivers block release unless owner issues explicit release
  waiver

### Why this is the recommended baseline

- keeps day-to-day flow workable (`R1` path is straightforward)
- reserves strictness for failure-prone boundary changes (`R2`)
- avoids permanent waiver creep

### Alternative paths

- stricter:
  require host smoke on all code changes
- looser:
  remove mandatory host smoke from `R2` and rely on CI-only checks

## ADR-0013: Launcher Provider Model and Ranking Persistence

Reference:

- `adr/0013-launcher-provider-model-and-ranking-persistence.md`

### Proposed Defaults

1. Retention

- persist V2 aggregate ranking signals from day 1
- log query history from day 1 via async non-blocking persistence
- keep retention bounded and prune automatically:
  90-day window and 20,000-entry cap
- provide explicit personalization reset command for ranking + query history

2. Personalization default

- default-on (local only, including query-history logging)
- first-run notice + persistent toggle
- disabling personalization stops writes immediately (ranking + query history)
- optional clear-on-disable behavior

3. Provider trust policy

- default-on:
  local deterministic providers (apps, shell commands, calculator)
- explicit opt-in:
  network providers, personal-content readers, arbitrary command executors
- provider capability declaration required for review and diagnostics

### Why this is the recommended baseline

- achieves Spotlight-like usefulness on day 1
- captures training/analytics data early without risking query-path latency
- avoids accidental trust-boundary expansion as providers grow

### Alternative paths

- privacy-max:
  personalization default-off
- convenience-max:
  broader provider auto-enable (including network-backed providers)

## ADR-0016: Performance Budgets and Startup SLAs

Reference:

- `adr/0016-performance-budgets-and-startup-slas.md`

### Proposed Defaults

Decision update (owner-selected):

- defer ADR-0016 enforcement until basic functionality milestones are complete
- for now:
  no SLA-based merge blocks and no mandatory release performance suite gate
- treat observed slowness as prioritized bug-fix work

Deferred defaults retained below as a parking lot for later sign-off:

1. Initial SLA targets

- warm startup: `p50 <= 350 ms`, `p95 <= 800 ms`
- cold startup: `p50 <= 1200 ms`, `p95 <= 2200 ms`
- launcher query (sync path): `p50 <= 35 ms`, `p95 <= 90 ms`
- IPC round-trip (simple command): `p50 <= 25 ms`, `p95 <= 80 ms`
- notification ingest-visible: `p50 <= 80 ms`, `p95 <= 180 ms`

2. Merge blocking thresholds

- `R2`:
  block on `p95` regression `>20%` and `>30 ms`, or SLA ceiling breach
- `R1`:
  advisory on first breach, block on repeated breach in two consecutive runs
- `R0`:
  no performance block

3. Release performance policy

- release candidates require host-runtime perf suite run
- release tags require no unresolved blocking regressions
- waivers owner-only, max 7 days, mitigation + follow-up required

### Why this is the recommended baseline

- gives concrete budgets now instead of indefinite “measure later”
- avoids flake-driven blocker noise by differentiating `R1` and `R2`
- makes release-performance regressions explicit policy decisions

### Alternative paths

- stricter:
  block all `R1` breaches immediately
- looser:
  advisory-only performance gates until mature benchmark harness

## Cross-ADR Coupling To Confirm

- `R2` classification is shared between quality gates and performance blocking.
- Waiver policy should be harmonized between ADR-0012 and ADR-0016.
- Launcher personalization policy in ADR-0013 should align with eventual public
  UX and docs language.

## Suggested Discussion Order

1. Approve or tune `R0/R1/R2` classification and gate matrix.
2. Approve launcher privacy/trust defaults.
3. Approve initial SLA numbers and blocker thresholds.

## Decision Log Template

- ADR-0012:
  decision: Approved as proposed
  edits: none
- ADR-0013:
  decision: Approved with edits
  edits:
  V2 + day-1 async query history; retention set to 90 days and 20,000 entries
- ADR-0016:
  decision: Deferred for now
  edits:
  revisit after baseline functionality is complete

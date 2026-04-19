# ADR Backlog

These are the next architectural decisions worth discussing.

They are not yet accepted ADRs, but they are likely to matter early enough that leaving them implicit would be a mistake.

## High Priority

### ADR-0004: Contract Model for Intents, Events, Commands, and Read Models

Status:

- now drafted as `Proposed` in `0004-contract-model-for-cross-layer-data.md`

Question:

- what are the actual shapes and naming rules for cross-layer contracts?

Why it matters:

- this determines whether the boundary model is real or just vocabulary

When to decide:

- before or during Phase 1

### ADR-0005: State Ownership and Store Model

Status:

- now drafted as `Proposed` in `0005-state-ownership-and-presentation-model-strategy.md`

Question:

- what qualifies as a store, what qualifies as a policy, and what qualifies as a use case?

Why it matters:

- otherwise `Store` becomes a catch-all dumping ground

When to decide:

- before Phase 1 grows beyond the first slice

### ADR-0006: Fast Path vs State Path Rules

Status:

- now drafted as `Proposed` in `0006-interaction-state-and-responsiveness-strategy.md`

Question:

- which interactions stay entirely in UI and which must travel through the core?

Why it matters:

- shell responsiveness depends on this

When to decide:

- before the first interactive UI slice expands

### ADR-0007: Architecture Guardrails and Fitness Checks

Status:

- now drafted as `Proposed` in `0007-agent-first-architecture-guardrails.md`

Question:

- what import checks, grep checks, lint rules, or CI checks enforce the architecture?

Why it matters:

- in a single-process JS/QML system, these checks are what make the architecture real

When to decide:

- immediately after ADR-0001

### ADR-0018: Agent Authoring Constraints, Golden Paths, and Skill Packaging

Status:

- now drafted as `Proposed` in `0018-agent-authoring-constraints-golden-paths-and-skill-packaging.md`

Question:

- what canonical examples, templates, nested instructions, and skill packaging should exist so agents reliably take the intended implementation path?

Why it matters:

- in an agent-authored codebase, examples and local instructions are part of the architecture, not just documentation

When to decide:

- immediately after ADR-0007

### ADR-0019: Formatter, Linter, and Architecture Review Loop Strategy

Status:

- now drafted as `Proposed` in `0019-formatter-linter-and-architecture-review-loop-strategy.md`

Question:

- what formatter/linter stack should exist for the new system subtree, and what review loop should agents run to verify changes against ADRs and principles?

Why it matters:

- without a standardized review loop and mechanical formatting/linting, agent output quality will drift quickly even if the high-level architecture is good

When to decide:

- before active implementation begins under `system/`

### ADR-0020: Legacy Tree Cutover and Migration Strategy

Status:

- now drafted as `Proposed` in `0020-legacy-tree-cutover-and-migration-strategy.md`

Question:

- how does the repo operate while the legacy live shell and the future `system/`
  architecture coexist?

Why it matters:

- without an explicit cutover policy, agents will keep expanding the live tree
  and bypass the new architecture

When to decide:

- immediately, before more system-only guardrails are assumed to govern the
  whole repo

### ADR-0021: Shell IPC Command Surface and Protocol Strategy

Question:

- what is the v1 shell command protocol boundary (transport, command shape, outcome envelope, error taxonomy, idempotency)?

Why it matters:

- introducing IPC without a tight contract creates a second ad hoc control path instead of a stable automation boundary

When to decide:

- immediately, before or during the first IPC v1 implementation slice

### ADR-0022: Theming Provider and Token Boundary Strategy

Status:

- now drafted as `Proposed` in
  `0022-theming-provider-and-token-boundary-strategy.md`

Question:

- how does dynamic theming evolve (matugen and beyond) without coupling UI
  modules to provider-specific behavior?

Why it matters:

- theme generation is a cross-cutting concern touching UX, ops diagnostics, and
  integration strategy; without an explicit boundary it becomes ad hoc quickly

When to decide:

- before theme generation moves beyond static palette defaults

## Medium Priority

### ADR-0008: Settings and Persistence Strategy

Status:

- now drafted as `Proposed` in `0008-settings-and-persistence-strategy.md`

Question:

- what is persisted, what is transient, how are settings versioned, and how are migrations handled?

Why it matters:

- persistence mistakes spread everywhere and are expensive to undo later

When to decide:

- during Phase 2

### ADR-0009: Concurrency, Idempotency, and Stale State Handling

Status:

- now drafted as `Proposed` in `0009-concurrency-idempotency-and-stale-state-handling.md`

Question:

- how do use cases behave when the world changed underneath them?

Examples:

- a window vanished before activation
- a notification expired before dismissal
- a command target disappeared during reload

Why it matters:

- shells are highly event-driven and race-prone

When to decide:

- before launcher and notification subsystems become real

### ADR-0010: Adapter Implementation Policy

Status:

- now drafted as `Proposed` in `0010-adapter-implementation-policy.md`

Question:

- when is a shell command acceptable, when should there be a dedicated helper script, and when is a richer implementation justified?

Why it matters:

- without a policy, shelling out spreads arbitrarily and becomes unmaintainable

When to decide:

- before search, persistence, and optional integrations expand

### ADR-0011: Logging, Observability, and Debuggability

Status:

- now drafted as `Proposed` in `0011-logging-observability-and-debuggability-strategy.md`

Question:

- what are the logging conventions, subsystem categories, and debug surfaces?

Why it matters:

- large shells are hard to operate without explicit diagnostics

When to decide:

- before multiple subsystems are running concurrently

### ADR-0012: Testing Strategy and Quality Gates

Status:

- now drafted as `Proposed` in `0012-testing-strategy-and-quality-gates.md`

Question:

- what gets unit tested, what gets smoke tested, and what blocks merges?

Why it matters:

- otherwise the quality bar will drift with every new subsystem

When to decide:

- before Phase 4

## Medium-to-Later Priority

### ADR-0013: Launcher Provider Model and Ranking Persistence

Status:

- now drafted as `Proposed` in `0013-launcher-provider-model-and-ranking-persistence.md`

Question:

- how are launcher providers registered, and how is usage/frecency persisted and evolved?

Why it matters:

- the launcher will become one of the most complex subsystems quickly

When to decide:

- during Phase 4

### ADR-0014: Optional Integration Policy

Status:

- now `Accepted` in `0014-optional-integration-policy.md` (owner-approved on
  2026-04-18)

Question:

- what qualifies as an optional integration, how is degraded mode surfaced, and how much architecture should optional services be allowed to impose?

Why it matters:

- integrations like Home Assistant, clipboard history, and file search can distort the architecture if they are allowed to dictate it

Decision timing:

- resolved before Phase 7 start gate

### ADR-0015: Extension Strategy Beyond Launcher Providers

Question:

- under what conditions is a new registry or plugin-like extension point justified?

Why it matters:

- this is the main overengineering trap for shells

When to decide:

- only after real repeated demand exists

### ADR-0016: Performance Budgets and Startup SLAs

Status:

- now drafted as `Proposed` in `0016-performance-budgets-and-startup-slas.md`

Question:

- what startup time, interaction latency, and indexing budget are acceptable?

Why it matters:

- architecture tradeoffs are easier when there are actual budgets

When to decide:

- after the first vertical slice and before heavy integrations

### ADR-0017: Split-Process Migration Trigger

Question:

- what concrete signals mean the shell should stop being single-process?

Possible triggers:

- core JS exceeds a tolerable complexity threshold
- background work introduces responsiveness problems
- fault isolation becomes necessary
- protocol shapes are stable enough to justify extraction

Why it matters:

- without a trigger, “we can split later” becomes a vague promise forever

When to decide:

- after launcher core and before optional integrations become numerous

## Additional Topics Worth Watching

These may or may not need full ADRs, but they are worth noticing early:

- security posture for command execution and untrusted content
- screen model and multi-monitor semantics for global vs per-screen surfaces
- caching and data freshness policy for expensive adapters
- naming conventions for files, stores, policies, and read models beyond the first few examples

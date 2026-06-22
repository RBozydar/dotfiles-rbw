# ADR Index

This directory contains Architecture Decision Records for the shell system.

ADRs exist to make structural decisions explicit, reviewable, and revisitable.

## Status Meanings

- `Proposed`
  The decision is under discussion and not yet adopted.
- `Accepted`
  The decision is the current intended direction.
- `Superseded`
  The decision was replaced by a later ADR.
- `Deprecated`
  The decision still explains history, but should not guide new work.

## Current ADRs

- [ADR-0001: Core Runtime Strategy](./0001-core-runtime-strategy.md)
  Status: `Accepted`
- [ADR-0002: Compositor Boundary Strategy](./0002-compositor-boundary-strategy.md)
  Status: `Accepted`
- [ADR-0003: Delivery Strategy](./0003-delivery-strategy.md)
  Status: `Accepted`
- [ADR-0004: Contract Model for Cross-Layer Data](./0004-contract-model-for-cross-layer-data.md)
  Status: `Proposed`
- [ADR-0005: State Ownership and Presentation Model Strategy](./0005-state-ownership-and-presentation-model-strategy.md)
  Status: `Proposed`
- [ADR-0006: Interaction State and Responsiveness Strategy](./0006-interaction-state-and-responsiveness-strategy.md)
  Status: `Proposed`
- [ADR-0007: Agent-First Architecture Guardrails](./0007-agent-first-architecture-guardrails.md)
  Status: `Proposed`
- [ADR-0008: Settings and Persistence Strategy](./0008-settings-and-persistence-strategy.md)
  Status: `Proposed`
- [ADR-0009: Concurrency, Idempotency, and Stale State Handling](./0009-concurrency-idempotency-and-stale-state-handling.md)
  Status: `Proposed`
- [ADR-0010: Adapter Implementation Policy](./0010-adapter-implementation-policy.md)
  Status: `Proposed`
- [ADR-0011: Logging, Observability, and Debuggability Strategy](./0011-logging-observability-and-debuggability-strategy.md)
  Status: `Proposed`
- [ADR-0012: Testing Strategy and Quality Gates](./0012-testing-strategy-and-quality-gates.md)
  Status: `Proposed`
- [ADR-0013: Launcher Provider Model and Ranking Persistence](./0013-launcher-provider-model-and-ranking-persistence.md)
  Status: `Proposed`
- [ADR-0014: Optional Integration Policy](./0014-optional-integration-policy.md)
  Status: `Accepted`
- [ADR-0016: Performance Budgets and Startup SLAs](./0016-performance-budgets-and-startup-slas.md)
  Status: `Proposed`
- [ADR-0018: Agent Authoring Constraints, Golden Paths, and Skill Packaging](./0018-agent-authoring-constraints-golden-paths-and-skill-packaging.md)
  Status: `Proposed`
- [ADR-0019: Formatter, Linter, and Architecture Review Loop Strategy](./0019-formatter-linter-and-architecture-review-loop-strategy.md)
  Status: `Proposed`
- [ADR-0020: Legacy Tree Cutover and Migration Strategy](./0020-legacy-tree-cutover-and-migration-strategy.md)
  Status: `Proposed`
- [ADR-0022: Theming Provider and Token Boundary Strategy](./0022-theming-provider-and-token-boundary-strategy.md)
  Status: `Proposed`

## ADRs To Discuss Next

See [backlog.md](./backlog.md).

## Decision Packets

- [Owner Decision Packet (2026-04-17)](./owner-decision-packet-2026-04-17.md)

## ADR Format

Each ADR should include:

- status
- date
- context
- decision
- consequences
- revisit conditions when appropriate

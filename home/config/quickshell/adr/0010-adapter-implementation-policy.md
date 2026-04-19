# ADR-0010: Adapter Implementation Policy

- Status: `Proposed`
- Date: `2026-04-17`

## Context

The shell depends on external systems:

- Hyprland IPC
- desktop app catalog tooling
- system commands
- optional integrations

Without an explicit adapter policy, these integrations usually decay into:

- direct `exec` calls from UI components
- duplicated shell snippets with inconsistent parsing and error handling
- hidden coupling between view code and system commands
- untestable edge cases around timeouts and partial failures

This ADR defines how external side effects enter the system and when each
integration form is appropriate.

## Decision

Use a **three-tier adapter policy** with explicit selection criteria.

All side effects must be routed through adapter-owned boundaries and core ports.

### Tier 1: Direct Command Adapter

Use a direct adapter command call only when all of the following are true:

- one external command is executed
- arguments are deterministic and passed as an argv array
- no complex parsing is required
- no long-lived process/watch state is required
- failure can be expressed as a simple operation outcome

Typical examples:

- launching an application by desktop entry command
- dispatching a single compositor command

### Tier 2: Helper Script Adapter

Use a helper script when any of the following are true:

- command sequencing or branching is required
- output parsing/normalization is non-trivial
- command behavior needs portability shims
- testability is materially improved by isolating behavior in one script

Helper scripts remain adapter-owned integration details.

### Tier 3: Full Service Adapter

Use a full adapter/service module when any of the following are true:

- long-lived process management is required
- reactive/watch streams are required
- caching or refresh policies are required
- domain-specific normalization logic is substantial

Typical examples:

- notification server adapter
- desktop app catalog refresh/cache adapter

## Required Rules

- UI modules must not call system commands directly.
- Core application use cases must not call shell commands directly.
- Command execution must be routed through ports and adapter ownership.
- No string-concatenated shell command execution for normal operation paths.
- Adapter outputs must be converted into explicit operation outcomes or plain contracts.
- Timeouts/retry behavior must be explicit in adapter logic where relevant.

## Testing Expectations

- Tier 1
  Contract-level tests for port behavior and outcome handling.
- Tier 2
  Script tests plus adapter mapping tests for parse/error paths.
- Tier 3
  Adapter slice tests for lifecycle, stale data handling, and failure recovery.

## Rationale

This policy keeps the architecture enforceable while preserving delivery speed.

It avoids two failure modes:

- overengineering every integration into heavyweight services
- underengineering with uncontrolled shell-out sprawl

## Consequences

Positive:

- clearer boundaries between UI/core and external systems
- more predictable error and timeout behavior
- better testability for integration-heavy features

Negative:

- slightly more boilerplate for simple one-off integrations
- adapter/port abstractions must be maintained consistently

## Revisit Conditions

Revisit this ADR if:

- the Tier 2/Tier 3 boundary proves unclear in repeated reviews
- helper scripts become too numerous and require consolidation policy
- split-process migration introduces stricter transport or privilege boundaries

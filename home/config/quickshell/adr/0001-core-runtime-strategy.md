# ADR-0001: Core Runtime Strategy

- Status: `Accepted`
- Date: `2026-04-13`

## Context

The shell is expected to start relatively small but grow toward the size and complexity class of the larger Quickshell shells.

The architecture therefore needs:

- fast iteration early
- real boundaries
- a plausible path to stronger isolation later

The main options are:

- a single-process shell where core logic lives in JS/QML-adjacent modules
- a split system with a typed core process and a Quickshell frontend

## Decision

Use a **single-process implementation initially**, but shape it as if it may later become split-process.

Concretely:

- core logic lives in plain JS modules
- the UI stays in Quickshell/QML
- adapters isolate Hyprland, shell tools, and other external systems
- contracts are made explicit as intents, commands, events, and read models
- guardrails are required so the single-process implementation does not collapse into UI-driven logic

## Rationale

This gives the best balance of:

- speed of delivery
- low initial complexity
- maintainability
- future optional migration path

Starting with a separate daemon and IPC would provide stronger enforcement, but it is too expensive this early and too likely to become architecture overhead before the shell proves itself.

## Consequences

Positive:

- fast start
- natural fit with Quickshell reactivity
- fewer moving parts
- easier experimentation while the product is still changing

Negative:

- boundaries are only real if enforced
- QML can reabsorb core logic if discipline slips
- later extraction to a separate process is possible but not free

## Required Follow-Ons

- define contracts explicitly
- add architecture guardrails in CI
- prevent direct external integrations from leaking into UI modules
- keep core logic in plain modules rather than view files

## Revisit Conditions

Revisit this decision after:

- the first substantial launcher implementation
- the first async-heavy or indexing-heavy subsystem
- the first signs that cross-domain orchestration is becoming painful in one process

If the JS core starts to feel like glue instead of a real application core, create a new ADR for split-process migration.

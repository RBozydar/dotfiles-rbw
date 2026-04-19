# ADR-0018: Agent Authoring Constraints, Golden Paths, and Skill Packaging

- Status: `Proposed`
- Date: `2026-04-14`

## Context

This shell is expected to be authored primarily or entirely by coding agents.

ADR-0007 establishes that architecture must be enforced through machine-checkable
guardrails and explicit golden paths.

That still leaves an operational problem:

- how agents discover the intended implementation path
- how local rules override broad architectural prose
- how the repo teaches patterns without forcing agents to reread the full
  architecture every time
- when examples are enough and when templates become justified

In an agent-authored codebase, this is an architectural concern, not just a
documentation concern.

## Decision

Use an **agent control surface** made of:

1. **failing checks and fitness scripts**
2. **nested `AGENTS.md` files**
3. **a reusable shell skill**
4. **canonical golden-path examples**
5. **ADRs and architecture docs as rationale and reference**

The repo should prefer **canonical examples first** and introduce **templates
later only after repeated implementation and review prove the need**.

## Instruction Hierarchy

Agents should follow this precedence order:

1. failing checks, tests, and architecture fitness scripts
2. nearest applicable `AGENTS.md`
3. the shell architecture skill
4. ADRs
5. broader architecture and planning documents

Reason:

- agents follow short local instructions more reliably than long central prose
- failing checks are clearer than interpretation
- ADRs should explain and justify decisions, not be the primary operational
  interface

## Golden Paths

The repo should provide one approved path for common architectural actions.

Priority golden paths include:

- compositor action dispatch
- command execution
- persistence writes
- store creation
- use-case orchestration
- selector creation
- presentation-model creation
- launcher provider implementation

These should be taught through canonical examples and narrow approved entry
points.

If multiple patterns remain equally plausible, agents will fork the codebase.

## Canonical Examples

Canonical examples are required before templates.

Good examples should:

- live near real code
- be copyable
- represent the currently preferred pattern
- be explicitly referenced from local `AGENTS.md` and the shell skill
- be updated in the same change whenever the governing golden path changes

Expected canonical examples include:

- one store
- one use case
- one selector
- one presentation-model surface
- one adapter
- one launcher provider

Bad examples should usually not exist as fake code files.

Instead, anti-patterns should live in:

- `AGENTS.md`
- the shell skill
- architecture review prompts or review scripts

Examples of anti-patterns:

- UI code dispatching compositor actions directly
- a store importing adapters
- policy logic mutating canonical state
- selector logic becoming a hidden source of truth

## Templates

Do **not** introduce templates by default.

Templates should be added only when:

- agents are creating the same architectural unit repeatedly
- review shows recurring structural drift
- the canonical example alone is no longer enough to produce consistent output

This means:

- canonical examples first
- templates later, when earned by repeated use

Template creation policy is intentionally deferred until implementation begins
to produce repeated real patterns.

## `AGENTS.md` Strategy

Nested `AGENTS.md` files are the primary local instruction surface.

They should contain:

- metadata header
- local boundary rules
- approved golden paths
- hazard APIs
- references to canonical examples
- short good/bad pattern notes

They should not duplicate full ADR prose.

Their job is operational guidance close to the code, not historical context.

Required metadata fields:

- `scope`
- `owner`
- `linked-adrs`
- `architecture-version`
- `last-reviewed`

`arch-check` should fail:

- missing metadata
- orphaned `AGENTS.md` files with no linked ADRs
- local instructions that contradict the ADRs they claim to implement

If a change alters:

- a golden path
- a hazard API rule
- the required review workflow

then the affected `AGENTS.md`, canonical example references, and skill pointers
should be updated in the same change.

## Skill Packaging Strategy

The shell should eventually have a dedicated skill for agent authoring and
review.

That skill should be:

- short
- operational
- layered on top of local `AGENTS.md`
- focused on workflow, not encyclopedic architecture restatement

The skill should point agents to:

- architectural hazard APIs
- required review steps
- canonical examples
- approved entry points

The skill should not duplicate entire ADRs.

## Task Shaping

Work should be phrased in architectural terms where possible.

Good task shape:

- add a selector-shaped surface using an existing store
- add a new launcher provider following the canonical provider example
- add a persistence-backed setting through the approved persistence path

Bad task shape:

- implement feature X with no layer or pattern guidance

Architectural task shaping reduces drift before code is even written.

## Exceptions

Exceptions should follow ADR-0007.

This ADR does not create a second exception mechanism.

If an agent must deviate from the golden path:

- the deviation should be local
- the reason should be explicit
- the exception should remain narrow

## Out of Scope

This ADR does not decide:

- formatter choice
- linter choice
- review command implementation
- CI pipeline structure

Those belong in the formatter, lint, and review-loop ADR.

## Consequences

Positive:

- agent behavior becomes more predictable
- the repo teaches preferred patterns by example
- architecture becomes easier to preserve during rapid implementation
- templates are deferred until they are justified by real repetition

Negative:

- maintaining canonical examples becomes important operational work
- local `AGENTS.md` files must stay disciplined and current
- the skill and examples can drift if they are not reviewed together

## Revisit Conditions

Revisit this ADR if:

- agents still drift despite the instruction hierarchy
- canonical examples are not enough to produce consistent output
- template creation becomes obviously justified by repeated real work
- the skill becomes too large or starts duplicating local instructions

If that happens, increase specificity only where repeated evidence justifies it.

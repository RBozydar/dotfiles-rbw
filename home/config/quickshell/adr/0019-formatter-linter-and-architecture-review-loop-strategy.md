# ADR-0019: Formatter, Linter, and Architecture Review Loop Strategy

- Status: `Proposed`
- Date: `2026-04-14`

## Context

This shell is expected to be authored primarily or entirely by coding agents.

Earlier ADRs establish:

- architectural boundaries and delivery strategy
- contract and state-model expectations
- agent-first architecture guardrails
- instruction hierarchy and golden-path examples

That still leaves a practical execution problem:

- how code style drift is prevented
- how local code defects are caught
- how architectural violations are blocked
- how semantic review happens after mechanical checks pass

These concerns should not be collapsed into one vague concept of "linting."

## Decision

Adopt a **four-part verification model**:

1. **Formatting**
   Deterministic code and document shape.
2. **Language linting**
   Language-specific validity and suspicious-code checks.
3. **Architecture fitness**
   Repo-owned checks for ADR-0007 hazards and boundary enforcement.
4. **Semantic review**
   An agent review pass against ADRs, `AGENTS.md`, and the diff.

The system should expose these as explicit commands:

- `format`
- `lint`
- `arch-check`
- `test`
- `review`
- `verify`

## Tooling Choices

Use dedicated tools per language and concern.

### QML

- `qmlformat` for formatting
- `qmllint` for linting

### JavaScript and TypeScript

- `ESLint` for linting

`ESLint` is preferred over `Biome` because the shell system is expected to grow,
and `ESLint` gives more flexibility for layered rule sets, custom policy
expression, and future repo-specific enforcement.

### Text and Config Files

- `Prettier` for Markdown, JSON, YAML, and similar repo text/config files
- `Taplo` for `TOML` formatting and validation

### Shell Scripts

- `shfmt` for formatting
- `shellcheck` for linting

### Python Helper Scripts

- `ruff` when Python helper scripts become part of the maintained system

### Architecture Fitness

- a repo-owned `arch-check` command or script

This should enforce hazards such as:

- forbidden APIs
- forbidden import directions
- direct side effects from disallowed layers
- exception annotation rules
- golden-path entry-point requirements where practical
- `AGENTS.md` metadata validity and ADR linkage
- legacy-tree versus `system/` migration policy coverage from ADR-0020

## Why Multiple Tools

Do not optimize for the fewest tools.

The goal is:

- deterministic output
- non-interactive behavior
- machine-checkable results
- enough precision to support agent-authored code at scale

QML already requires dedicated tooling, so a single-tool fantasy is not worth
the compromise.

## Review Loop

The default verification order should be:

1. `format`
2. `lint`
3. `arch-check`
4. targeted `test`
5. `review`

`verify` should orchestrate the appropriate subset in that order.

This matters because:

- formatting should settle surface churn first
- linting should catch cheap defects early
- architecture fitness should block invalid structure before semantic review
- semantic review should reason over already-clean code

## Review Semantics

Semantic review is not the primary structural gate.

Static and scripted checks are the primary gate for:

- formatting
- language correctness
- architectural hazards

The semantic review pass should focus on:

- architectural fit
- violations of ADR intent not caught mechanically
- missing tests
- residual design and behavior risks

Recommended review output shape:

- blockers
- architectural drift
- test gaps
- residual risks

## Blocking Policy

From day one:

- `format` should be required before completion
- `lint` should be blocking
- `arch-check` should be blocking

Initially:

- `review` should be advisory for low-risk leaf changes
- required secondary-model review should be blocking for the categories listed
  below

Reason:

- architectural and language correctness need strong enforcement immediately
- semantic review prompts and review quality will need calibration early on
- not every change needs the same semantic review cost

## Secondary-Model Review

Secondary-model review should be required for higher-risk changes, not every
change.

Require it when a change:

- touches two or more architectural layers
- crosses between the legacy tree and `system/`
- modifies ADRs
- modifies `AGENTS.md`
- modifies the shell skill
- introduces a new subsystem skeleton
- is large enough that single-review blind spots become likely

It should remain optional for narrow leaf changes.

This keeps review cost proportional to architectural risk.

For required cases:

- `verify` should fail if the required secondary review has not been run
- the review result should be emitted in a machine-readable form that can mark
  the change as pass, pass-with-risks, or blocker

The review content may still be semantically rich, but the gating outcome must
be mechanically consumable.

## Agent Workflow Expectations

Every implementation agent should run `verify` before claiming work complete.

The review step should read:

- the diff
- the relevant `AGENTS.md`
- the relevant ADRs

It should not default to rereading the whole repo.

This keeps review focused, repeatable, and cheap enough to run consistently.

## CI Gate

CI should run the blocking subset of verification, not rely only on local agent
discipline.

Minimum blocking CI set:

- `lint`
- `arch-check`
- required targeted tests
- required secondary-review classification checks for high-risk changes

Local `verify` may have a faster developer-oriented mode, but it must not be
more permissive than the blocking CI policy for the same change class.

## Out of Scope

This ADR does not define:

- the exact command-line flags for each tool
- CI vendor or pipeline layout
- package-manager choice
- the implementation details of the shell skill

Those can be decided later without changing the architectural direction here.

## Consequences

Positive:

- verification concerns are separated cleanly instead of conflated
- agent workflow becomes more uniform
- architecture checks have explicit first-class status
- semantic review is used where it adds value instead of carrying the whole
  quality burden

Negative:

- the repo will carry multiple tools
- initial setup cost is higher
- review prompts and `arch-check` rules will need calibration

## Revisit Conditions

Revisit this ADR if:

- `ESLint` proves materially harder to maintain than the value it provides
- the multi-tool stack becomes too slow for normal agent workflows
- semantic review becomes reliable enough to justify stronger blocking behavior
- `arch-check` becomes too broad or too weak to be useful

If that happens, simplify only with evidence, not convenience.

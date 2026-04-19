# ADR-0022: Theming Provider and Token Boundary Strategy

- Status: `Proposed`
- Date: `2026-04-18`

## Context

The shell currently uses static semantic color tokens (`Theme.qml`) and needs a
clear path to dynamic theming without locking architecture to one generator.

We want to try `matugen` early, but we do not want:

- UI modules directly coupled to a specific theming tool
- hard dependencies on one generator's output shape
- color-generation logic leaking into presentation modules

Given expected growth (multi-KLoC shell surface, eventually similar to other
large Quickshell shells), theming needs an explicit boundary now, not an
implicit script path later.

## Decision

Adopt a **provider-bound theming architecture** with explicit contracts:

1. `core/contracts/theme-contracts.js`
    - canonical request contract: `shell.theme.generate`
    - canonical scheme contract: `shell.theme.scheme`
    - required semantic role set aligned to MD3 canonical role names
2. `core/ports/theme-provider-port.js`
    - stable provider API (`generate`, `describe`)
    - provider resolution/fallback utilities
3. `adapters/theming/*`
    - `static-theme-provider.js` as guaranteed baseline provider
    - `matugen-theme-provider.js` as non-mandatory integration scaffold
4. `ui/bridges/ThemeBridge.qml`
    - owns provider selection, generation request creation, fallback behavior,
      and runtime diagnostics surface
5. `SystemShell` IPC surface
    - expose theme diagnostics/control commands through command registry

This preserves UI semantic tokens while allowing generator evolution behind a
stable port.

## Provider Policy

For current scope:

- default provider: `static`
- default fallback provider: `static`
- optional provider: `matugen` (allowed to be unavailable/degraded)
- provider failure behavior: return typed failure outcome and fall back when
  possible

No plugin registry architecture is introduced now. Two providers with explicit
selection/fallback are enough for current complexity.

## Token Policy

- UI modules consume semantic roles, not provider-specific palettes.
- Theme generation adapters output role maps matching contract-required role
  names.
- Non-semantic extension tokens (for example terminal 16-color sets) are out of
  scope for this ADR and can be added later through additive contract evolution.

## Runtime Control and Diagnostics

Expose theme state as runtime snapshots (provider request/resolution, mode,
variant, scheme metadata, and last outcome). This keeps operations observable
without adding hidden debug-only paths.

## Implementation Notes (Initial Slice)

Initial scaffolding includes:

- contract + port modules
- static/matugen provider adapters
- theme bridge with provider fallback and regeneration
- shell IPC commands for describe/regenerate/provider/mode/variant adjustments
- regression tests for contracts and provider port behavior

Applying generated schemes directly into the existing `Theme.qml` singleton is
explicitly deferred to a follow-up slice so boundary shape is stabilized first.

## Consequences

Positive:

- generator choice is decoupled from UI composition
- degraded mode is explicit and testable
- matugen can be trialed early without lock-in
- future provider replacements are constrained to adapter boundary

Negative:

- one additional bridge/contract layer to maintain
- temporary duplication while static `Theme.qml` and provider scaffolding
  coexist

## Revisit Conditions

Revisit this ADR if:

- UI token surface expands beyond current semantic role set
- provider count grows enough to justify a registry abstraction
- generation latency or failure profile requires async/background execution
  policy changes

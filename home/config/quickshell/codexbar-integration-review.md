---
title: "CodexBar Integration Review"
summary: "Assessment of whether CodexBar can be integrated directly into this Quickshell setup, or should only be used as a backend."
date: 2026-04-13
status: final
recommendation: "Use CodexBarCLI as a backend adapter only. Do not try to reuse the macOS app UI inside Quickshell."
verification:
    - "Static source review of ~/repo/CodexBar and home/config/quickshell"
    - "`swift test` could not be run in this environment because `swift` is not installed"
tags:
    - quickshell
    - codexbar
    - integration
    - review
---

# CodexBar Integration Review

Review date: 2026-04-13

## Question

Can `~/repo/CodexBar` be used as-is inside this Quickshell config, or does it need work, or should the feature be built natively here?

## Short Answer

Not as-is.

`CodexBar` is usable on Linux as a CLI/backend, but not as a UI module for Quickshell. The practical path is:

- keep the Quickshell UI native
- call `CodexBarCLI` from a Quickshell service or wrapper script
- parse JSON output and render a normal shell chip/popout here

This is a backend reuse decision, not a direct app integration.

## Why The App Itself Does Not Fit

The app target is macOS-only, while the reusable Linux surface is the CLI/core split.

Relevant code:

- `~/repo/CodexBar/Package.swift`
    - package platform is declared as `macOS(.v14)`
    - macOS app targets are added only inside `#if os(macOS)`
    - Linux-targeted pieces are `CodexBarCore`, `CodexBarCLI`, and `CodexBarLinuxTests`

That matches the repo architecture on the Quickshell side, where shell integrations belong in:

- `services/`
- `scripts/`
- native QML presentation in `modules/bar/` and `components/`

It does not match an approach where a separate UI stack is embedded or ported wholesale.

## Main Findings

### 1. Reuse boundary: CLI/core yes, app UI no

CodexBar is structurally split into:

- `Sources/CodexBarCore` for fetch/parse/provider logic
- `Sources/CodexBarCLI` for terminal/script usage
- `Sources/CodexBar` for AppKit/SwiftUI menu bar UI

For Quickshell, only the first two are relevant.

### 2. Linux default behavior is not safe enough to treat as plug-and-play

The CLI docs say Linux does not support `web/auto` for web-capable providers. The implementation confirms that non-macOS exits early when the effective source needs web support.

That matters because:

- provider config defaults to `source = auto`
- missing config also falls back to `auto`
- Codex supports `.auto`, `.web`, `.cli`, `.oauth`
- on CLI runtime, Codex `auto` resolves strategies as `[web, cli]`
- non-macOS rejects that `auto` path before the CLI fallback runs

Practical consequence:

- if Quickshell ever uses CodexBar on Linux, it should force `--source cli`
- do not rely on implicit defaults

### 3. Polling cost is acceptable for a slow service, not for a high-frequency chip

CodexBar’s fetch path is not just a cheap file read.

For Codex it does:

- RPC client startup against Codex app-server when available
- fallback to a PTY `/status` probe
- timeout and parse-retry logic

That is reasonable for a bar service polling every `60-300s`, but not for the kind of `2s` loop used by `SystemStats.qml`.

### 4. The JSON contract is good enough for integration, but use the real output shape

The CLI is suitable for shell integration because it supports JSON output and machine-only mode:

```bash
codexbar usage --provider codex --source cli --format json --json-only
```

Important detail:

- `usage --format json` prints an array of payloads, even for one provider
- a Quickshell adapter should parse the array and take the first payload

Do not build against the text output.

### 5. Secret handling stays outside this repo, which is good

CodexBar reads provider config from:

- `~/.codexbar/config.json`

That keeps provider tokens/cookies out of this Quickshell repo, which is the right separation.

## Recommendation

Use a thin adapter pattern if this feature is ever implemented:

1. Add a small wrapper script under `home/config/quickshell/scripts/`.
2. Add a singleton service under `home/config/quickshell/services/`.
3. Have the service call `CodexBarCLI` on a slow timer.
4. Normalize the JSON into stable fields like:
    - `available`
    - `error`
    - `primary`
    - `secondary`
    - `credits`
    - `accountEmail`
    - `source`
5. Render a native `StatusChip` and optional native Quickshell popout.

This gives the shell:

- native visuals
- native popup behavior
- low integration churn
- reuse of CodexBar’s provider parsing and fallback logic

## Decision

Recommended approach:

- do not try to integrate the CodexBar app directly
- do not fully DIY provider parsing unless the goal is a very small Codex-only widget
- reuse `CodexBarCLI` as backend output and keep the rest native to Quickshell

## Notes

- This review was based on source inspection and repo architecture comparison.
- Runtime verification of `swift test` was not possible in the current environment because `swift` is not installed.

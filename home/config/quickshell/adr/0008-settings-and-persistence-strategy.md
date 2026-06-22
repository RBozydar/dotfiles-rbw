# ADR-0008: Settings and Persistence Strategy

- Status: `Proposed`
- Date: `2026-04-14`

## Context

As the shell grows, persistence mistakes become expensive and sticky.

Without a clear persistence model, codebases tend to drift into one or more bad
patterns:

- stores serializing themselves opportunistically
- external system state being mirrored to disk without a real need
- user-editable settings and machine-managed state getting mixed together
- migrations becoming ad hoc and dangerous
- caches quietly becoming sources of truth

This shell is expected to start relatively small but grow into a larger system.

That means persistence should be structured early, before:

- settings fan out across subsystems
- launcher history and frecency appear
- notification history grows
- optional integrations start adding their own storage assumptions

## Decision

Use a **tiered persistence model** with explicit ownership:

1. **Config**
   User-owned, durable settings expressing user intent.
2. **State**
   Machine-managed but durable user-affecting state.
3. **Cache**
   Rebuildable, non-authoritative derived data.
4. **Runtime**
   Non-persistent in-memory state only.

Persistence should be:

- explicit
- domain-owned
- schema-versioned
- routed through persistence adapters

The system should **not** persist stores wholesale by default.

## Persistence Tiers

### 1. Config

Config is for stable user intent.

Examples:

- theme choice
- enabled modules
- layout preferences
- launcher provider preferences
- user-visible feature toggles
- user custom actions

Config should be:

- human-editable
- stable across restarts
- portable enough to move between machines when reasonable
- low-churn compared to runtime state

Default format:

- per-domain `TOML`

Reason:

- human-readable
- better suited to user-owned configuration than JSON
- less ambiguous and less overpowered than YAML

### 2. State

State is for durable system-managed data that still materially affects the user
experience.

Examples:

- launcher frecency and recents
- pinned or dismissed items when they are user-meaningful
- notification read state or retained history, if the product keeps it
- per-domain last-known choices that are part of UX continuity

State should be:

- machine-managed
- durable across restarts
- authoritative **at rest** for bootstrap and recovery only
- not treated as hand-edited configuration

Default format:

- per-domain `JSON`

Reason:

- easy to serialize
- easy to inspect
- easy to rewrite canonically
- a good fit for machine-owned persisted objects

### 3. Cache

Cache is rebuildable and must never become the source of truth.

Examples:

- search indexes
- precomputed metadata
- thumbnail or preview artifacts
- expensive derived lookup tables

Cache should be:

- disposable
- safe to delete
- reconstructable from config, state, and external systems

Format is implementation-defined by the owning subsystem.

The default assumption is file-based cache data unless a stronger need emerges.

### 4. Runtime

Runtime state is not persisted.

Examples:

- current window/workspace topology
- current media playback state
- active monitor geometry
- transient notification popup state
- current search results
- UI-local transient state

These are either:

- external system truth
- ephemeral interaction state
- cheap to recompute

Do not persist them unless they are deliberately promoted into `State`.

## XDG Placement

Use XDG-style separation conceptually:

- config under `XDG_CONFIG_HOME`
- durable machine-managed state under `XDG_STATE_HOME`
- disposable cache under `XDG_CACHE_HOME`

The shell should not collapse all persistent artifacts into one directory.

## Domain Ownership

Each persisted artifact should have one owning domain.

That domain is responsible for:

- schema definition
- defaults
- validation
- migrations
- load and save policy
- corruption handling

Avoid giant cross-domain persistence blobs.

Per-domain artifacts are the default because they:

- reduce coupling
- localize migrations
- reduce blast radius for corruption
- make ownership obvious

## Authoritative Truth Model

Persistence and stores do not own runtime truth equally.

Rules:

- persisted state is the domain's **authoritative at-rest input**
- after hydration, the store is the domain's **sole authoritative in-memory
  truth**
- successful saves update the at-rest snapshot; failed saves do not change
  runtime truth
- rehydrate or reload flows must reconcile into the store explicitly rather than
  treating disk as a second live authority

This avoids dual-source-of-truth behavior during:

- startup
- save failure
- reload
- corruption recovery

## Versioning and Schema

Every persisted artifact should carry an explicit schema version.

Recommended default:

- integer `schemaVersion`

Schema versioning applies to:

- config files
- state files
- cache metadata when needed

Cross-layer payload rules from ADR-0004 still apply:

- persisted payloads should be plain serializable objects

## Migration Policy

Migrations should be:

- domain-local
- monotonic
- idempotent
- testable

Default migration flow:

1. read raw persisted data
2. parse
3. validate current or older schema
4. migrate forward stepwise as needed
5. hydrate domain state

## Write Safety

Persistent writes for config and state should be atomic per artifact.

Recommended default:

1. write to a temporary file in the same directory
2. flush and `fsync` when appropriate for the platform/runtime
3. replace the target via atomic rename

Additional rules:

- destructive rewrites and migrations should keep a last-known-good backup
- one domain should serialize writes to its own artifact rather than letting
  concurrent writes race opportunistically
- machine-managed state writes should usually be debounced or coalesced rather
  than emitted on every tiny mutation
- startup should detect partial writes or unreadable temp artifacts and recover
  from the last-known-good file or domain defaults instead of guessing silently

This is part of the persistence contract, not an implementation detail to leave
implicit.

## Settings Rewrite Policy

Do not eagerly rewrite user config files on normal reads.

Reason:

- user-owned files should not be churned just because the shell started
- comments, ordering, or local edits should not be destroyed casually

Config rewrites should happen only when:

- the user explicitly saves settings through the shell
- a migration requires a rewrite
- a repair operation is explicitly invoked

If a migration rewrites config, the old file should be backed up first.

Machine-managed state files may be rewritten canonically as needed.

## Corruption and Invalid Data Handling

Config and state should not fail the entire shell equally.

Policy:

- invalid config in one domain should degrade that domain and fall back to
  defaults where possible
- corrupted machine-managed state should be quarantined or backed up and then
  recreated
- corrupted cache should be discarded and rebuilt

All such events should be diagnosable.

## Persistence Boundaries

Persistence writes should go through persistence adapters and domain use cases.

This implies:

- UI does not write config or state directly
- stores do not serialize themselves directly as a default pattern
- adapters do not become owners of domain meaning

The boundary is:

- domains decide what persistence means
- adapters decide how bytes are stored

## What Should Be Persisted

Persist when data is:

- explicit user intent
- durable user-affecting learned behavior
- expensive derived data worth caching

Do not persist when data is:

- a mirror of external system state
- UI-local transient interaction state
- temporary coordination state
- easily recomputed and not worth caching

## Secrets

Secrets should not be stored in normal config or state files by default.

If a future integration requires secrets:

- use an explicit secret-handling path
- keep it separate from ordinary persistence

This ADR does not define that path yet.

## Use of Databases

The default persistence strategy is file-based and per-domain.

Do not introduce SQLite or another database as the default persistence backend
up front.

A database may become justified later for a specific subsystem if:

- query patterns become meaningfully relational or indexed
- file-based state becomes awkward or slow
- the subsystem clearly benefits from structured querying

That should be an explicit follow-up decision, not an accidental drift.

## Consequences

Positive:

- settings, state, cache, and runtime are clearly separated
- migrations stay localized
- user-owned config is treated differently from machine-owned state
- caches are less likely to become hidden truth
- future subsystems get a persistence default that scales

Negative:

- more concepts to teach early
- per-domain persistence requires discipline
- some borderline cases will need explicit classification

## Revisit Conditions

Revisit this ADR if:

- the file-based default becomes a material operational burden
- multiple domains prove to need shared structured querying
- user configuration needs are better served by a different format than TOML
- the separation between config and state proves too awkward in practice

If that happens, change the backend or format deliberately, not by erosion.

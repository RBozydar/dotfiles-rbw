# Launcher Plan

## Goal

Replace `wofi` on `SUPER+SPACE` with a Quickshell-native launcher that feels closer to Spotlight than a plain app drawer.

Primary goals:

- app search
- inline math
- explicit shell command mode
- keyboard-first navigation
- room for clipboard, emoji, windows, settings, and session actions

Current shell context:

- already has a clean top-level shell split in `shell.qml`
- already has bar, notifications, volume OSD, and session overlay
- does **not** yet have a launcher module

This makes a standalone `modules/launcher/` overlay the right fit.

## Command Mode Decision

`>cmd` is acceptable and recommended.

The important requirement is autocomplete:

- typing `>` should open a command palette of launcher providers and actions
- typing `>c` should fuzzy-filter provider commands like `>cmd`, `>clip`, `>emoji`, `>win`, `>settings`
- typing `>cmd ` should switch into shell-command mode
- inside `>cmd`, the launcher should offer executable suggestions from `$PATH`
- command history should be mixed into those suggestions

This follows Noctalia's command-mode shape, where `>` enters provider-command mode and partial input filters available commands.

Phase 1 autocomplete scope:

- executable names from a cached `$PATH` scan
- recent commands run from the launcher
- simple completion acceptance with `Tab`, `Right`, or `Enter`

Phase 2 autocomplete scope:

- fish completion integration for subcommands and flags
- snippet/alias commands like `>cmd update-system`

I would **not** try to build a full shell parser in the first pass.

## Recommended Architecture

Copy from Noctalia:

- provider-based launcher core
- one provider per domain
- command discovery when search starts with `>`
- centered overlay window, separate from the bar popout system

Keep from current shell:

- existing top-level module pattern
- shared `Theme.qml` tokens
- service-first split for stateful integrations

Recommended local structure:

```text
home/config/quickshell/
├── modules/launcher/
│   ├── LauncherOverlay.qml
│   ├── LauncherCore.qml
│   ├── LauncherListDelegate.qml
│   ├── LauncherSearchField.qml
│   └── providers/
│       ├── ApplicationsProvider.qml
│       ├── CalculatorProvider.qml
│       ├── CommandProvider.qml
│       ├── ClipboardProvider.qml
│       ├── EmojiProvider.qml
│       ├── SessionProvider.qml
│       ├── SettingsProvider.qml
│       └── WindowsProvider.qml
└── services/
    ├── LauncherState.qml
    ├── AppIndex.qml
    ├── CommandIndex.qml
    └── LauncherHistory.qml
```

## Proposed Build Order

### Phase 1: Replace `wofi`

- centered launcher overlay
- app provider
- inline calculator provider
- `>cmd` provider with autocomplete
- fuzzy ranking
- keyboard navigation
- Hyprland keybind swap from `wofi` to Quickshell launcher

### Phase 2: Spotlight Features

- clipboard provider
- emoji provider
- web search fallback
- custom actions
- recent apps / recent commands

### Phase 3: Shell Integration

- windows provider
- session provider
- settings provider
- `>home` / `>lights` provider backed by the shell HA service
- optional preview pane for clipboard or rich items

### Phase 4: Nice-to-Haves

- wallpaper actions
- provider-specific chips or categories
- usage/frecency tuning
- plugins, if the launcher grows enough to justify them

## Feature Comparison

Legend:

- `Strong`: worth copying directly
- `Useful`: worth borrowing ideas from
- `Skip for now`: interesting but not needed for the first launcher

| Shell                 | Main Strengths                                                             | Launcher-Relevant Features                                                                                                         | Other Notable Features                                                     | Copy Priority |
| --------------------- | -------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- | ------------- |
| **Noctalia**          | Clean provider architecture, broad feature coverage, strong widget library | provider-based launcher, clipboard provider, emoji provider, command mode, calculator provider, settings/session/windows providers | advanced notifications, wallpaper engine, dock, settings UI, plugin system | **Strong**    |
| **illogical-impulse** | Aggressive feature mix, action-heavy workflow, many shell overlays         | mixed results model, math, shell commands, web search, custom actions, clipboard, emoji                                            | OCR translation, AI chat, recorder, dock, overview, virtual keyboard       | **Strong**    |
| **Caelestia**         | Polished architecture, refined control center, good UX details             | fuzzy app search, wallpaper picker in launcher, calculator row, configurable launcher actions                                      | dynamic colors, lock screen, dashboard, notifications, audio visualizer    | **Useful**    |
| **DMS**               | Large MD3 system, strong service layer, ranking and settings search        | app search service, frecency logic, settings search, app drawer mechanics                                                          | Go IPC, dock, task manager, notepad, greeter, plugins                      | **Useful**    |

## Cross-Shell Feature Matrix

| Feature                       | Noctalia                       | illogical-impulse                | Caelestia                 | DMS                      |
| ----------------------------- | ------------------------------ | -------------------------------- | ------------------------- | ------------------------ |
| Provider-style launcher       | Yes                            | No, more monolithic mixed search | No                        | Partial                  |
| App search                    | Yes                            | Yes                              | Yes                       | Yes                      |
| Inline calculator             | Yes                            | Yes                              | Yes                       | Not obvious              |
| Shell commands                | Yes                            | Yes                              | Action-based, not primary | Not obvious              |
| Command palette after `>`     | Yes                            | Prefix-driven, similar outcome   | Action prefix model       | Settings trigger only    |
| Clipboard launcher mode       | Yes                            | Yes                              | No                        | Clipboard service exists |
| Emoji launcher mode           | Yes                            | Yes                              | No                        | Not obvious              |
| Settings search in launcher   | Yes                            | No                               | Control-center oriented   | Yes                      |
| Windows search/switch         | Yes                            | Overview-focused                 | Not obvious               | Not obvious              |
| Custom launcher actions       | Limited/provider command model | Yes, strong                      | Yes                       | Limited                  |
| Wallpaper actions in launcher | Not central                    | Some actions                     | Yes                       | Some wallpaper tools     |
| Frecency / ranking logic      | Some usage logic               | Basic mixed-result ordering      | Fuzzy launcher            | Strong                   |
| Plugin extension model        | Yes                            | No                               | No                        | Yes                      |

## Pick-And-Choose Recommendations

### Copy Now

- **Noctalia launcher core**
    - provider registration
    - `>` command discovery
    - provider-per-domain split
- **II mixed-result ideas**
    - math
    - shell commands
    - web search fallback
    - custom action hooks
- **DMS ranking ideas**
    - frecency
    - result scoring
- **Caelestia launcher polish**
    - cleaner action UX
    - calculator presentation

### Copy Later

- Noctalia windows/session/settings providers
- II clipboard/emoji ergonomics
- Caelestia wallpaper launcher actions
- DMS settings search patterns

### Skip For Now

- Noctalia plugin system
- DMS Go backend and full external CLI
- II AI chat, OCR translator, virtual keyboard
- Caelestia C++ plugin work

## Concrete Launcher Feature List

### First Version

- app search
- app launch
- fuzzy result ranking
- inline math result
- `>` command palette
- `>cmd` shell command mode
- autocomplete for `>cmd`
- recent command history
- `SUPER+SPACE` opens launcher
- `Esc` closes
- `Enter` activates
- arrow keys or `Ctrl+n`/`Ctrl+p` navigate

### Second Version

- `>clip` clipboard history
- `>emoji` emoji picker
- `>web` web search
- custom actions like restart shell, lock, power, open config
- result sections or provider badges

### Third Version

- `>win` window switcher
- `>settings` settings jump
- `>home` or `>lights` smart-home actions
- session commands
- previews for clipboard and rich content

## Home Assistant Follow-up

- keep Home Assistant launcher integration behind system-owned boundaries:
  `system/adapters/homeassistant/*` + `scripts/homeassistant.py` + shell IPC
  commands
- first launcher scope stays narrow: named lights (toggle/on/off) and scene
  activation
- do not embed raw REST calls in launcher UI; route all HA actions through
  existing typed shell command surface

## Implementation Notes

Do not attach the launcher to the bar popup system.

Reasons:

- Spotlight is modal and keyboard-driven
- the existing bar popup system already has fragile hover behavior
- launcher open/close, focus, and search state should stay isolated

Use a dedicated overlay window instead:

- centered on the focused monitor
- exclusive keyboard focus when open
- darkened or lightly frosted backdrop
- simple open/close animation

## Current Recommendation

If you want the shortest path to a strong result:

1. Copy Noctalia's launcher structure.
2. Add II-style mixed results and actions.
3. Add DMS-style frecency later.
4. Borrow Caelestia only for interaction polish.

That yields a launcher that is:

- structurally clean
- easy to extend
- Spotlight-like instead of app-drawer-like
- aligned with the rest of this shell's module layout

## Open Decisions

- Should plain text with spaces default to app search only, or also offer web search by default?
- Should `>cmd` suggestions include only executables, or also user-defined snippets and aliases in v1?
- Should recent commands be stored in JSON under the shell config, or derived from shell history?
- Do you want a narrow Spotlight-style list, or a wider launcher with optional preview pane?

## Shell Decomposition

This section answers the vague phrases from earlier like "broad feature coverage" and "many overlays".

### Noctalia

Noctalia is structured like a shell platform, not just a themed config.

- `shell.qml` boots shared state first, then starts critical services, then mounts the rest of the shell scene.
- `PanelService.qml` is a real coordination layer for panels, menus, and the overlay launcher.
- `BarWidgetRegistry.qml` lets the shell map widget ids to components and settings UIs, which is why it can expose a large configurable bar/control-center surface.
- `CompositorService.qml` hides Hyprland/Niri/Sway/Labwc differences behind one interface.
- `PluginService.qml` adds plugin loading, plugin state, translation handling, update tracking, and plugin UI injection.
- `NotificationService.qml` is not just a popup list; it keeps history, applies rules, replaces duplicates, and manages popup/history models.
- `WallpaperService.qml` is a subsystem with per-screen state, transitions, favorites, browsing, and automation.

What "broad feature coverage" means in practice:

- the shell has many visible features
- those features are usually implemented through shared registries and services
- settings and modules are expected to compose cleanly
- the architecture is designed for extension, not just for one personal layout

That is why Noctalia is the best donor for launcher architecture. It already thinks in providers, registries, and coordinated overlays.

### illogical-impulse

II is structured more like a feature-heavy personal shell distro.

- `shell.qml` can switch between entire shell families like `ii` and `waffle`.
- `IllogicalImpulseFamily.qml` mounts a large set of independent shell modules: bar, dock, lock, OSD, overview, overlay, translator, sidebars, wallpaper selector, media controls, and more.
- `GlobalStates.qml` is the shared state bus. Most shell modules exist behind a boolean such as `overviewOpen`, `sidebarRightOpen`, or `screenTranslatorOpen`.
- overlay modules like `SidebarRight.qml`, `Overview.qml`, and `Overlay.qml` are independent windows tied together through that state bus and global shortcuts.
- `HyprlandData.qml` does a lot of direct Hyprland shelling-out and event stitching instead of relying on a heavier abstraction layer.

What "many overlays" means in practice:

- many separate windows/panels can appear independently
- each feature tends to own its own `PanelWindow` or overlay
- the shell grows by adding new modules and new booleans
- the architecture is very effective for shipping features quickly, but less disciplined than Noctalia's registry-driven model

That is why II is the best donor for interaction ideas, prefix workflows, and Hyprland-centric power-user behavior, but not the best donor for launcher structure.

### Caelestia

Caelestia sits in the middle.

- it is smaller and calmer than Noctalia or II
- services like `Apps.qml` and `Actions.qml` are compact and focused
- the launcher is more of a polished drawer with explicit modes than a huge mixed-result search engine
- frequency tracking is built into app launching through `AppDb`

What it gives you:

- clear launcher modes
- refined interaction details
- good action ergonomics
- a lighter architecture that is easier to reason about

It is a good donor for polish and deterministic command modes, not for "search everything" breadth.

### DMS

DMS treats the launcher as a modal application.

- `LauncherContent.qml` is a full interaction surface with mode switching, history, edit mode, action panels, and context menus
- `Controller.qml` owns search state, modes, sections, selection, cache, plugin integration, file search, and scoring
- `Scorer.js` and `ItemTransformers.js` normalize and rank different item types into one model
- `AppSearchService.qml` exposes built-in launcher plugins such as settings search

What this means in practice:

- the launcher is not just an app list
- it is a general search hub with apps, files, plugins, built-in tools, and per-section presentation logic
- it behaves more like a power-user console than a clean Spotlight clone

That makes DMS a good donor for scoring, sectioning, history, and multi-source normalization.

## Launcher Decomposition

This section focuses only on the launchers: what they do, how queries are routed, how results are built, and why each launcher feels different.

### Noctalia Launcher

#### Shape

Noctalia has a real launcher subsystem, not just a search widget.

- `LauncherCore.qml` is the brain
- `LauncherOverlayWindow.qml` is the fullscreen overlay window
- providers live in `Modules/Panels/Launcher/Providers/`

It can run as:

- a centered overlay above everything
- an embedded SmartPanel launcher

That is already a strong match for your shell, because you want a dedicated launcher overlay rather than another bar popup.

#### Query Routing

The routing model is provider-based.

- if the query starts with `>`, `LauncherCore.qml` asks each provider `handleCommand(query)`
- the first provider that claims the command becomes the active provider
- if no provider claims it, the launcher shows provider commands from every provider and fuzzy-filters them
- if the query is normal text, every provider with `handleSearch: true` contributes results

This is the key design choice: the launcher core does not know much about apps, clipboard, math, or settings. It just asks providers for results.

#### Result Model

Providers return normalized result objects with fields like:

- `name`
- `description`
- `icon`
- `_score`
- `provider`
- `onActivate`

`LauncherCore.qml` then:

- merges the results
- sorts by `_score`
- optionally boosts tracked items by usage
- resets selection to the top result

So the core is a result coordinator, not a search implementation.

#### What Each Provider Actually Does

Applications provider:

- loads desktop entries
- deduplicates entries that share the same desktop id and executable
- exposes categories like `Pinned`, `Development`, `Office`, `System`
- when the query is empty, shows pinned or most-used apps
- when the query is non-empty, fuzzy-searches `name`, `comment`, `genericName`, and `executableName`
- can pin/unpin apps and track usage

Calculator provider:

- contributes to normal search
- checks whether the query looks like a math expression
- evaluates inline and returns a synthetic "copy result" item

Command provider:

- owns `>cmd`
- exposes `>cmd` in command discovery
- when active, returns a single synthetic "run this shell command" result

Clipboard provider:

- owns `>clip`
- loads clipboard history asynchronously through `ClipboardService`
- shows loading and disabled states cleanly
- supports category chips like images, links, files, code, and colors
- can expose preview UI through a preview component

Settings, session, emoji, and windows providers follow the same pattern.

#### UI and Interaction

The overlay window is fairly sophisticated.

- `LauncherOverlayWindow.qml` uses a full-screen overlay `PanelWindow`
- it dims the background
- it can blur only the launcher and preview regions
- it supports a side preview panel
- it positions the launcher independently from the bar, but can still "follow" bar position rules

Why it feels good:

- the input surface is isolated
- providers stay independent
- the core supports multiple layouts and previews
- the overlay is clearly modal and keyboard-first

Why it matters for you:

- this is the cleanest structural base for a Spotlight clone
- the exact providers can be cut down without damaging the architecture

### illogical-impulse Launcher

#### Shape

II does not really have a standalone launcher window.

- the launcher is the search half of the full-screen overview
- `Overview.qml` owns the overlay window
- `SearchWidget.qml` owns the search input and results list
- `LauncherSearch.qml` is one big singleton that produces mixed results

This is why II feels fast and hackable, but also more entangled.

#### Query Routing

II uses a monolithic prefix-and-branch service.

- the input writes to `LauncherSearch.query`
- `LauncherSearch.results` is computed from that single query
- different prefixes branch into different result builders

The main branches are:

- clipboard prefix
- emoji prefix
- math prefix or number-started queries
- shell-command prefix
- web-search prefix
- action prefix
- plain app search

It is one service deciding everything, not a provider mesh.

#### Result Sources

Apps:

- app results come from `AppSearch.fuzzyQuery(...)`
- `AppSearch.qml` keeps a deduped desktop-entry list
- it fuzzy-searches prepared app names
- it also contains icon-guessing heuristics for window classes and fallback names

Math:

- a timer debounces non-app results
- a `Process` runs `qalc -t`
- the result becomes a synthetic "copy math result" item

Clipboard and emoji:

- clipboard routes through `Cliphist.fuzzyQuery`
- emoji routes through `Emojis.fuzzyQuery`
- both return synthetic launcher items with copy/delete actions

Shell commands:

- the command branch does not autocomplete a shell AST
- it creates a synthetic "run this command" item from the current query
- activation runs `bash -c ...`

Web search:

- creates a synthetic search item that opens the configured engine

Actions:

- built-in actions are listed in `searchActions`
- user action scripts are loaded from `~/.config/illogical-impulse/actions/`
- matching actions become launcher results
- activation can pass query tail arguments into the script

#### UI and Interaction

`SearchWidget.qml` is worth copying from for a few details.

- the search field and list are tightly integrated
- typing while the list has focus pushes characters back into the input
- Backspace still edits the query even when focus has drifted
- `Tab` on a selected result copies that result's text back into the input field

That last part is a real autocomplete-like interaction, even though the data model itself is monolithic.

`Overview.qml` also adds quick entry paths:

- open overview normally
- toggle straight into clipboard mode by pre-filling the clipboard prefix
- toggle straight into emoji mode by pre-filling the emoji prefix

#### Why It Feels Different

II feels like a command palette mixed into a workspace overview.

- good at mixing apps with actions and utilities
- good at "just add another prefix"
- less clean for long-term extension because every new source wants to live in the same singleton

What to steal:

- action scripts
- prefix ergonomics
- tab-to-fill interaction
- quick-entry modes like clipboard or emoji

What not to steal:

- the monolithic search service as the foundation

### Caelestia Launcher

#### Shape

Caelestia is a mode-based launcher, not a mixed-result one.

- `Content.qml` owns the search field and input behavior
- `AppList.qml` switches launcher state based on the current prefix
- the services are small and specialized

The important thing is that the current mode decides which list is shown.

#### Query Routing

`AppList.qml` turns the query into a launcher state:

- `apps`
- `actions`
- `calc`
- `scheme`
- `variant`

So instead of merging providers, it swaps the active model and delegate.

This is much more deterministic than II or Noctalia.

#### Result Sources

Apps:

- `Apps.qml` searches desktop entries
- it increments frequency in `AppDb` on launch
- it supports special search prefixes for app metadata like id, categories, comment, exec, generic name, keywords, or terminal-only apps

Actions:

- `Actions.qml` exposes configured actions
- those actions can do normal exec
- they can also do launcher-specific behaviors like `autocomplete` and `setMode`

Calculator:

- calculator is a dedicated launcher mode rather than a mixed result among apps

Wallpaper and theme tools:

- wallpaper, scheme, and variant modes are separate launcher paths rather than generic results mixed into the same list

#### UI and Interaction

The launcher is polished because the mode model is simple.

- the placeholder explicitly teaches the command prefix
- Enter behavior is mode-aware
- keyboard navigation is straightforward
- vim-like navigation is supported
- actions can rewrite the input text, which is a lightweight form of autocomplete

Why it feels different:

- it is closer to a drawer with explicit command modes
- it avoids noisy mixed-result ranking problems
- it is less "search everything" and more "switch to the right tool mode"

What to steal:

- explicit action modes
- launcher-side `autocomplete` actions
- app frequency tracking
- the calm UX

What not to steal as the core:

- the hard mode-switching model if you want Spotlight-style mixed results

### DMS Launcher

#### Shape

DMS is the heaviest launcher of the group.

- `LauncherContent.qml` is the interaction shell
- `Controller.qml` owns nearly all logic
- `Scorer.js` ranks mixed items
- `ItemTransformers.js` normalizes many item types into one shape

It is a launcher framework inside the shell.

#### Query Routing

DMS has both modes and triggers.

Modes:

- `all`
- `apps`
- `files`
- `plugins`

Triggers:

- plugin triggers from `PluginService`
- built-in launcher triggers from `AppSearchService`
- for example, built-in settings search is exposed as a launcher plugin behind `?`

So a query can be handled in several ways:

- by the current mode
- by a trigger prefix that activates a plugin
- by automatic file-mode switching when the query starts with `/`

#### Result Sources

Apps:

- app results come from `searchApps(query)`
- that merges normal desktop apps with DMS core apps like settings, notepad, sysmon, and color picker

Files:

- file mode delegates to a file search service and transforms results into launcher items with secondary actions like open folder or copy path

Plugins:

- plugin items come from plugin-provided launcher data
- built-in launcher plugins can also inject items
- `ItemTransformers.js` turns apps, files, plugins, and built-in launcher items into a single common item shape

Settings search:

- `AppSearchService.qml` defines a built-in launcher plugin `dms_settings_search`
- its trigger defaults to `?`
- it calls `SettingsSearchService.search(query)` and returns navigable settings results

#### Search Pipeline

The interesting part is the controller flow.

- the controller caches default sections for empty search
- empty search can load from disk cache before live search finishes
- in `all` mode with a real query, it first gets app results quickly
- then it schedules a second plugin phase that injects plugin items afterward
- plugin items can be pre-scored so they land in a predictable order
- everything is then grouped into sections and flattened for the UI

This is much closer to a real search product pipeline than the other shells.

#### Scoring

`Scorer.js` is one of the best reusable pieces across all shells.

It scores by:

- exact match
- prefix match
- word-boundary match
- substring
- fuzzy distance
- frecency bonus
- type bonus

Then it groups by section, keeps per-section limits, and flattens for the visible list.

That is why DMS feels deliberate even though it mixes many result types.

#### UI and Interaction

`LauncherContent.qml` adds a lot of operator UX.

- mode hotkeys like `Ctrl+1` through `Ctrl+4`
- history navigation with `Ctrl+Up` and `Ctrl+Down`
- section view modes
- context menus
- an edit mode for per-app overrides
- auto-switch to file mode when the query starts with `/`

Why it feels different:

- it is not trying to be pure Spotlight
- it is trying to be a general-purpose search console for the shell

What to steal:

- scoring
- item normalization
- staged search pipeline ideas
- history
- sectioning for advanced mode later

What not to steal up front:

- the whole controller complexity
- file/plugin modes unless you explicitly want the launcher to become a general shell console

## Launcher Comparison Summary

| Launcher              | Core Model                            | Query Router                                           | Best Features                                                                       | Main Risk                                                |
| --------------------- | ------------------------------------- | ------------------------------------------------------ | ----------------------------------------------------------------------------------- | -------------------------------------------------------- |
| **Noctalia**          | provider-based                        | provider commands plus merged search providers         | clean architecture, preview support, category/layout ownership, usage-aware sorting | easy to overbuild if you copy all providers and settings |
| **illogical-impulse** | monolithic mixed-result service       | prefix branches inside one singleton                   | scripts, mixed utilities, tab-to-fill, very fast feature growth                     | launcher logic becomes one giant branching file          |
| **Caelestia**         | mode-based drawer                     | prefix changes active mode and delegate                | polish, deterministic actions, frequency tracking, lightweight autocomplete         | less Spotlight-like because results do not mix naturally |
| **DMS**               | controller plus normalized item model | mode selection plus plugin triggers plus staged search | scoring, history, plugin/files/settings search, sectioning                          | significantly heavier than you need for v1               |

## Recommendation After Decomposition

For your shell, the best combination is still:

- **Noctalia as the structural base**
- **II for interaction ideas and action scripts**
- **Caelestia for action/autocomplete ergonomics**
- **DMS for scoring and maybe history**

Concretely, that means:

- keep a Noctalia-style `LauncherCore` with providers
- let providers return normalized items like DMS does
- let `>cmd` and future actions support Caelestia-style autocomplete behavior
- add II-style quick utility providers for clipboard, emoji, web search, and custom actions

That gets you a Spotlight-style launcher without inheriting the worst complexity from II or DMS.

## Shell Architecture Review

This section is broader than the launcher. It explains how each shell is organized as a software system.

### Architecture Axes

To compare these shells usefully, it helps to evaluate them across the same axes:

- **boot model**: how the shell starts and sequences work
- **composition model**: how visible modules get mounted into the scene
- **state model**: where long-lived shared state lives
- **service model**: where side effects, IPC, and external integration live
- **extension model**: how new features are added without rewriting the core
- **platform strategy**: whether the shell is tightly tied to Hyprland or abstracts the compositor

### Noctalia Architecture

#### Boot Model

Noctalia has the most deliberate startup pipeline.

- `shell.qml` waits for translations, settings, and shell state before mounting the main shell scene
- it initializes critical services first
- it defers non-critical services with `Qt.callLater`
- it delays even more setup behind timers for post-boot work like hooks, updates, and changelog/wizard flows

This is effectively a staged boot process:

1. load prerequisites
2. render a stable first frame
3. initialize background services
4. run secondary UX and maintenance flows

That is a strong architecture choice for a large shell.

#### Composition Model

The shell scene is composed from major feature modules:

- background
- desktop widgets
- bars
- dock
- notifications
- toast overlay
- OSD
- launcher
- lock screen
- settings
- plugin container

The important part is that those modules are mounted from the top, while coordination logic is pushed into services like `PanelService`.

#### State and Services

Noctalia relies heavily on singletons and service objects.

- UI state and panel coordination live in dedicated services
- system integrations live in dedicated services
- settings and shell state are loaded before most UI appears
- providers and registries are used where the surface must be extensible

This is closest to a service-oriented frontend architecture.

#### Extension Model

Noctalia is explicitly designed for extension.

- widget registries
- provider registries
- plugin loading
- normalized compositor access

That means features are often added by plugging into an existing abstraction, not by editing one giant central file.

#### Platform Strategy

Noctalia abstracts the compositor more than the others.

- Hyprland is supported
- but the shell also tries to normalize Niri/Sway/Labwc and related backends

That improves portability, but increases abstraction cost.

### illogical-impulse Architecture

#### Boot Model

II has a lighter and more direct boot process.

- `shell.qml` imports common modules and services
- loads a selected panel family through `LazyLoader`
- initializes a set of always-on helpers in `Component.onCompleted`

This is not as staged or defensive as Noctalia, but it is simpler and fast to reason about.

#### Composition Model

II is composed as a family of independently toggled windows and panels.

- a panel family mounts many modules
- each module tends to own one visible concern
- overview, sidebars, overlays, wallpaper selector, translator, dock, and other surfaces are separate modules

This is a modular visible architecture, but not a strongly normalized internal one.

#### State and Services

The core state pattern is shared booleans plus utility services.

- `GlobalStates.qml` holds many visibility and interaction flags
- modules observe those flags and show/hide themselves
- side effects often happen directly inside modules or direct services
- Hyprland integration is fairly close to the metal

This is effectively a global-state evented shell architecture.

#### Extension Model

II grows by adding more modules, more state flags, and more helper services.

That makes it easy to add features quickly, especially one-off overlays or utilities. The cost is that the shell does not force new features through a disciplined abstraction boundary.

#### Platform Strategy

II is strongly Hyprland-first.

- it uses Quickshell Hyprland APIs
- and augments them with direct `hyprctl`-driven data services

That gives it a lot of power on Hyprland, but it is not trying to be portable.

### Caelestia Architecture

#### Boot Model

Caelestia is compact and direct.

- `shell.qml` mounts background, drawers, area picker, lock, and shortcut helpers
- it uses `Variants` heavily for per-screen surfaces
- hot reload is enabled directly

The shell does less startup choreography because the system is smaller and less feature-heavy.

#### Composition Model

Caelestia is organized around a few large subsystems:

- background layer
- drawer system
- lock
- control center
- per-screen helper windows

The composition feels intentionally constrained. It does not try to expose a huge plugin ecosystem or dozens of loosely related overlays.

#### State and Services

Caelestia uses focused services and configuration-driven behavior.

- services like `Apps.qml`, `Actions.qml`, and visibility helpers do one job each
- shortcut and IPC handling toggle known drawers and shell surfaces
- app state like frequency is stored in a concrete persistence layer such as `AppDb`

This is the most "small, cohesive app" architecture of the set.

#### Extension Model

Caelestia is extensible, but mostly through:

- adding modules
- adding actions
- adding configuration

It does not have the same registry-heavy extension system as Noctalia or the plugin-driven launcher surface of DMS.

#### Platform Strategy

Caelestia is still shell-specific, but its internal shape is calmer than II's.

- it assumes the shell owns the whole UX
- but it does not centralize everything into one giant global-state singleton

### DMS Architecture

#### Boot Model

DMS separates entry selection from shell composition.

- `shell.qml` chooses between the normal shell and a greeter mode using environment flags
- `DMSShell.qml` mounts the actual shell and initializes some services on completion

This is a useful architectural split: entrypoint concerns are separated from runtime shell concerns.

#### Composition Model

DMS mounts a large but structured set of major modules:

- wallpaper and desktop widgets
- lock and fade windows
- bars
- dock
- control center
- launcher
- notifications
- OSD
- process list
- notepad
- plugin daemons

The composition is broad, but more centralized than Noctalia. `DMSShell.qml` is a strong top-level orchestrator.

#### State and Services

DMS puts a lot of logic into services and controller-style components.

- settings and session data are heavily consulted from controllers
- launcher behavior is mediated by `Controller.qml`
- search, plugins, and app metadata are normalized through services
- plugins can also run daemon components

This is the most app-framework-like architecture of the four.

#### Extension Model

DMS extends through:

- services
- built-in launcher plugins
- external plugins
- controller-managed modal surfaces

Compared with Noctalia, DMS is less registry-oriented at the shell-wide level but quite extensible in launcher and plugin workflows.

#### Platform Strategy

DMS looks more like a desktop application framework sitting on Quickshell.

- it is still Wayland-shell-specific
- but the internal architecture often resembles a traditional app more than a loose shell config

## Software Engineering Review

This section reviews the shells against concrete engineering practices rather than taste.

### Evaluation Criteria

- **cohesion**: does each file or module do one clear job?
- **coupling**: how hard is it to change one subsystem without breaking others?
- **state ownership**: is it obvious where truth lives?
- **extensibility**: can new features be added through stable interfaces?
- **operational discipline**: startup sequencing, caching, graceful fallback, dependency checks
- **maintainability**: how understandable and editable is the code over time?
- **testability in practice**: even in QML, can logic be isolated enough to reason about or extract?

### Noctalia vs Best Practices

#### What It Does Well

- strong separation of concerns through services, providers, registries, and modules
- clear boot staging and deferred initialization
- explicit extension points instead of ad hoc feature injection
- good abstraction around compositor differences
- feature domains like wallpaper, notifications, launcher, and plugins have recognizable subsystem boundaries

These align well with best practices:

- modularity
- stable interfaces
- explicit lifecycle management
- reduced duplication

#### Where It Deviates

- a large singleton/service graph can become hard to reason about
- plugin and registry systems add incidental complexity
- many features are configurable, which increases the number of interactions to debug
- QML singletons still make unit-style testing and dependency injection awkward

Engineering judgment:

- architecturally the strongest shell here
- also the easiest to over-engineer if copied blindly

### illogical-impulse vs Best Practices

#### What It Does Well

- high feature velocity
- visible features are decomposed into separate windows and modules
- direct Hyprland integration avoids unnecessary abstraction layers
- user action scripts are a pragmatic extension mechanism

These are good practices when optimizing for iteration speed and user-facing capability.

#### Where It Deviates

- `GlobalStates.qml` is a giant shared mutable state hub
- monolithic services like the launcher search mix many responsibilities
- direct shell/tool calls are powerful but increase hidden runtime dependencies
- feature logic can be spread across shortcuts, global state, modules, and helper services at once

That creates classic engineering risks:

- high coupling
- weak ownership boundaries
- harder local reasoning
- harder refactoring as the shell grows

Engineering judgment:

- excellent at rapid product experimentation
- weaker on long-term maintainability and disciplined abstraction

### Caelestia vs Best Practices

#### What It Does Well

- strong cohesion in many services and modules
- relatively small and understandable top-level composition
- state transitions are clearer because fewer systems are competing
- app frequency persistence and action modeling are concrete and localized

This lines up well with:

- single-responsibility thinking
- low conceptual overhead
- maintainable code paths

#### Where It Deviates

- some launcher logic is intentionally specialized rather than generalized
- extension patterns are lighter and less formal
- if the shell grows a lot, the current simplicity may stop scaling without stronger registries or abstraction layers

Engineering judgment:

- best balanced shell for readability and cohesion
- not the most extensible, but probably the least mentally expensive to maintain

### DMS vs Best Practices

#### What It Does Well

- explicit controller pattern for complex UI workflows
- strong normalization of heterogeneous data into common item models
- deliberate scoring and staged-search pipeline
- history, caching, and plugin routing are treated as first-class design concerns
- top-level entrypoint split between shell and greeter is clean

These align with strong engineering practices:

- normalized internal representations
- performance-conscious design
- clear user-flow orchestration
- explicit caching strategy

#### Where It Deviates

- some controller files are very large and approach "god object" territory
- complexity is centralized rather than distributed into smaller composable units
- plugin, settings, history, and routing concerns can accumulate in the same controller path
- the system can become harder to change because a few central files know too much

Engineering judgment:

- stronger engineering than II in the launcher/search stack
- but with real risk of controller bloat

## Best-Practices Ranking

This is not a quality ranking in the abstract. It is specifically a software-engineering ranking.

### Best Modularity

1. Noctalia
2. Caelestia
3. DMS
4. illogical-impulse

### Best Extensibility

1. Noctalia
2. DMS
3. illogical-impulse
4. Caelestia

### Best Local Readability

1. Caelestia
2. Noctalia
3. DMS
4. illogical-impulse

### Best Search/Launcher Engineering

1. Noctalia for architecture
2. DMS for scoring and pipeline design
3. Caelestia for interaction simplicity
4. illogical-impulse for rapid feature breadth

## What To Emulate In Your Shell

If the goal is a launcher that stays maintainable, the best-practices translation is:

- take **Noctalia's separation of concerns**
- take **DMS's scoring and normalization discipline**
- take **Caelestia's cohesion and small-scope UX decisions**
- take **II's behavior ideas only when they can be isolated behind a provider or service boundary**

More concretely:

- do not build a `GlobalStates`-style mega-singleton just for launcher state
- do not build a DMS-sized launcher controller in v1
- do build small, explicit providers with one responsibility each
- do keep shell integrations behind service singletons
- do normalize all provider results into one item shape before rendering
- do keep startup and async loading explicit, especially for clipboard, command index, and optional Home Assistant providers

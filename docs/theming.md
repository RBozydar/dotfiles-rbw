# Theming in Hyprland/Quickshell Shells

How the shells in this repo collection handle colors, palettes, and theming — with deep dives on Noctalia and Caelestia, who both rolled their own palette engines instead of using matugen.

---

## Part 1: What is Material Design 3?

**Material Design 3 (MD3)** is Google's current design system (2021+), the successor to Material Design 2. It's what Android 12+ and most modern Google apps use. Two parts matter for shell theming:

### 1.1 The color system ("Material You")

MD3 introduced **dynamic color**: instead of a fixed palette, extract a *source color* (usually from wallpaper) and algorithmically derive a full palette from it.

- **HCT color space** (Hue, Chroma, Tone) — Google's perceptually-uniform space, better than HSL for tonal math. Built on top of CAM16 (a color appearance model).
- From one source color, generate 5 **tonal palettes**: `primary`, `secondary`, `tertiary`, `neutral`, `neutral-variant`.
- Each palette has 13 **tones** (0=black, 100=white, with 10/20/…/90 in between).
- Tones are mapped into ~30 **semantic roles**: `primary`, `onPrimary`, `primaryContainer`, `onPrimaryContainer`, `surface`, `surfaceContainer`, `surfaceContainerLow/High/Highest`, `onSurface`, `outline`, `error`, `scrim`, `shadow`, etc.
- Light/dark schemes are just different tone mappings of the same palettes (e.g., `primary` = tone 40 in light, tone 80 in dark).

This is why every MD3 shell has a `Theme.qml` / `Colors.qml` singleton with properties like `Colors.primary`, `Colors.surfaceContainer`, `Colors.onSurface`.

### 1.2 Variants / scheme types

Google defines several **dynamic scheme variants** that change how tertiary/neutral palettes are derived from the source color. Common ones:

- **TonalSpot** — default Android 12/13 look. Balanced, slightly muted.
- **Content** — preserves source chroma, temperature-based tertiary. What matugen uses by default.
- **Vibrant** — high-chroma primaries.
- **Expressive** — bold, saturated.
- **FruitSalad** — playful, -50° hue rotation on tertiary.
- **Rainbow** — chromatic accents with grayscale neutrals.
- **Monochrome** — pure grayscale (chroma = 0), only `error` keeps color.
- **Fidelity** — very close to source.

### 1.3 Component + motion guidelines

- Shape scale (corner radii: none / xs / sm / md / lg / xl / full).
- Typography scale (display/headline/title/body/label × large/medium/small).
- Elevation via tonal overlays, not drop shadows.
- State layers (hover/focus/pressed as semi-transparent overlays).
- Specific motion curves and durations (emphasized, standard, etc.).

### 1.4 Why shells adopt MD3

- **Algorithmic palette from wallpaper** = cohesive look with zero manual work.
- **Semantic roles** mean widget authors write `color: Colors.surfaceContainer` instead of hex codes — retheming is free.
- Well-documented, battle-tested, and tools exist (`matugen`, `material-color-utilities`).

### 1.5 matugen

Rust port of Google's `material-color-utilities`. Implements HCT extraction + tonal palettes + scheme generation, then pipes the result through user-defined templates (Jinja-like). Outputs hex colors per role; templates substitute them into config files for GTK, terminal, Discord, etc.

---

## Part 2: Theming approach per shell (summary)

| Shell | Palette engine | MD3? | Notes |
|---|---|---|---|
| **DankMaterialShell** | matugen | Yes | `Theme.qml` (~100KB) holds MD3 tokens |
| **dots-hyprland (end-4)** | matugen | Yes | Widest cascade: GTK, Hyprlock, Fuzzel, KDE, Discord |
| **hyprland-shells/Ilyamiro** | matugen | Partial | `/tmp/qs_colors.json` polled every 1s |
| **hyprland-shells/nixos** | matugen | Yes | home-manager module |
| **Noctalia** | **custom Python (~7,100 LOC)** | Yes | HCT engine, matugen-compatible templates |
| **Caelestia** | **custom C++ + external CLI** | Yes | C++ plugin = dominant-colour only; full MD3 in separate `caelestia` CLI |
| **hyprland-shells/shell** | Hand-rolled | No | Bespoke/anime aesthetic, not MD3 |

---

## Part 3: Noctalia — deep dive

**Approach:** full MD3 pipeline re-implemented in Python, from scratch. No matugen binary dependency.

### 3.1 Location

```
noctalia-shell/Scripts/python/src/theming/
├── template-processor.py         # CLI entry point (347 LOC)
├── gtk-refresh.py                # GTK/GSettings theme push (188 LOC)
├── kde-apply-scheme.py           # KDE color scheme apply (51 LOC)
├── migrate-colorschemes.py       # Config migration helper
├── vscode-helper.py              # VS Code theme apply
└── lib/
    ├── hct.py            # HCT color space, CAM16, TonalPalette (1,071 LOC)
    ├── material.py       # MaterialScheme + all scheme variants (540 LOC)
    ├── palette.py        # Extract palette from image (672 LOC)
    ├── quantizer.py      # Wu quantizer + Score algorithm (815 LOC)
    ├── renderer.py       # Matugen-compatible template renderer (1,201 LOC)
    ├── image.py          # Image decode (366 LOC)
    ├── theme.py          # High-level theme generation (878 LOC)
    ├── scheme.py         # Predefined scheme expand, terminal injection (351 LOC)
    ├── color.py          # RGB/HSL utils (353 LOC)
    └── contrast.py       # Contrast ratio, WCAG enforcement (123 LOC)
```

~7,100 LOC of Python. Every algorithm is re-implemented from the Dart reference (`material-color-utilities`).

### 3.2 Scheme variants

Nine variants, more than matugen ships:

- `tonal-spot` (default, Android 12/13 look)
- `content` (matugen's default)
- `fruit-salad`, `rainbow`, `monochrome` — from MD3 spec
- `vibrant`, `faithful`, `dysfunctional`, `muted` — Noctalia originals. `faithful` prioritizes area coverage in wallpaper; `dysfunctional` picks the 2nd dominant color family; `muted` caps saturation for near-monochrome wallpapers.

### 3.3 Pipeline

```
wallpaper.png
  → image.read_image()                    # decode
  → quantizer.extract_source_color()      # Wu quantizer + Score (Google's algo)
  → palette.extract_palette()             # full palette for variant algos
  → material.SchemeTonalSpot.from_rgb()   # or other scheme class
  → scheme.get_dark_scheme() / get_light_scheme()  # ~30 MD3 role → hex
  → contrast.ensure_contrast()            # WCAG guarantee
  → renderer.TemplateRenderer             # matugen-compatible rendering
  → write theme outputs for ~30 app templates
```

### 3.4 Templates

`noctalia-shell/Assets/Templates/` ships templates for ~30 apps:

btop, cava, VS Code, Discord (material + midnight), Emacs, Fuzzel, GTK3/4, Helix, Hyprland, Hyprtoolkit, KDE kcolorscheme, labwc, mango, niri, Noctalia itself, pywalfox, qtct, scroll, spicetify, steam, sway, telegram, terminal, vicinae, walker, yazi, zathura, zed.

Templates use matugen-compatible Jinja syntax, so the community ecosystem of matugen templates works unchanged.

### 3.5 QML integration

- `Services/Theming/ColorSchemeService.qml` — singleton. Loads scheme JSON from disk, watches `Settings.data.colorSchemes`, toggles dark/light, invokes Python helpers via `Quickshell.execDetached`.
- `Services/Theming/TemplateProcessor.qml` — builds a dynamic TOML config pointing at enabled app templates, shells out to `template-processor.py`, listens for completion.
- `Services/Theming/TemplateRegistry.qml` — catalog of known app templates (user enables/disables).
- `Services/Theming/AppThemeService.qml` — applies scheme to running apps (GTK via gsettings, KDE via `kde-apply-scheme.py`, VS Code via `vscode-helper.py`).
- `Commons/Style.qml` — design-token singleton consumed by widgets (`Style.color.surface`, spacing, radii, etc.).
- `Commons/Color.qml` — color manipulation helpers (lighten, darken, adjust alpha).

### 3.6 Extra: predefined schemes

Besides wallpaper-derived schemes, Noctalia ships curated schemes in `Assets/ColorScheme/` and lets users download more from community packs into `~/.config/noctalia/colorschemes/`. Same MD3 role JSON format, no extraction step needed.

### 3.7 Why reinvent?

Likely reasons (inferred from code comments and the variant set):

- Fine-grained control over tone mapping and contrast enforcement beyond what matugen exposes.
- Custom variants (`faithful`, `dysfunctional`, `muted`) that address specific wallpaper categories matugen handles poorly.
- No external binary dependency — shell is self-contained with Python 3.
- Synchronous API they can drive from QML without waiting on a subprocess startup per-invocation.

---

## Part 4: Caelestia — deep dive

**Approach:** split between an in-repo C++ QML plugin (fast dominant-colour + luminance) and an external `caelestia` CLI (full MD3 scheme generation, separate repo).

### 4.1 In-shell C++ plugin

Location: `shell/plugin/src/Caelestia/imageanalyser.{hpp,cpp}` (~290 LOC total).

Exposes an `ImageAnalyser` QML type with:

```cpp
Q_PROPERTY(QString source ...)              // image file path
Q_PROPERTY(QQuickItem* sourceItem ...)      // or live QML item grab
Q_PROPERTY(int rescaleSize ...)             // downscale target
Q_PROPERTY(QColor dominantColour ...)       // output
Q_PROPERTY(qreal luminance ...)             // output
```

What it does under the hood:

1. Load `QImage` (or grab a QML item via `grabToImage()`).
2. Downscale to max 128px (default) on a background thread via `QtConcurrent::run`.
3. Convert to `Format_ARGB32`.
4. Histogram pass: quantize each pixel to 5 bits per channel (`pixel & 0xF8`), count occurrences.
5. Compute per-pixel perceptual luminance (`√(0.299·R² + 0.587·G² + 0.114·B²)`), average it.
6. Emit `dominantColour` = most-frequent quantized bucket; `luminance` = mean.

This is **not** MD3. It's a fast approximate dominant-colour detector used for **adaptive UI tweaks** — specifically, the `Colours.qml` service uses `wallLuminance` to compensate transparency (brighter wallpapers get more opacity to keep UI readable).

### 4.2 Full scheme generation (external)

Caelestia's shell is paired with a separate `caelestia` CLI (not in this repo collection). The QML `Colours.qml` service talks to it via:

```qml
Quickshell.execDetached(["caelestia", "scheme", "set", "--notify", "-m", mode])
```

And reads the resulting JSON via `FileView` on `${Paths.state}/scheme.json`. The CLI is what actually runs MD3 extraction.

### 4.3 QML consumption

`shell/services/Colours.qml` is the singleton every widget consumes:

- Holds two `M3Palette` sub-objects (`current` + `preview`) with ~55 role properties: `m3primary`, `m3onPrimary`, `m3primaryContainer`, `m3surfaceContainerLowest` through `m3surfaceContainerHighest`, `m3outline`, plus extended roles (`m3success`/`onSuccess`/`successContainer`/`onSuccessContainer`) and the MD3 "fixed" role family (`m3primaryFixed`, `m3primaryFixedDim`, `m3onPrimaryFixed`, etc.).
- Also holds terminal colors `term0`…`term15`.
- `tPalette` (Transparent Palette) wraps every role through a `layer()` function that applies alpha and a luminance-aware brightness scale. This is where the C++ plugin's output feeds in — wallpaper luminance modulates how much transparency the UI gets.
- `setMode(mode)` just shells out to the CLI.
- Reacts to `scheme.json` changes via `FileView.watchChanges: true`.

### 4.4 Hyprland coupling

`Colours.qml` also drives Hyprland `layerrule`s: when transparency settings change, it tells Hyprland to toggle blur and ignore_alpha for the caelestia drawer layers. Palette change → Hyprland reconfig on the fly.

### 4.5 Extended roles vs standard MD3

Caelestia adds roles not in the Google spec:

- `success` / `onSuccess` / `successContainer` / `onSuccessContainer` — green confirmation states (MD3 only has `error`).
- `term0`…`term15` — terminal palette embedded in the scheme, so Kitty/Foot/etc. retheme with the shell.

### 4.6 Where the CLI lives

Not in this repo collection — the `caelestia-dots` ecosystem has a separate `caelestia-cli` repo (Python) implementing `caelestia scheme set` with Google's `material-color-utilities`. It writes `scheme.json` that the shell watches.

---

## Part 5: Noctalia vs Caelestia side-by-side

| Aspect | Noctalia | Caelestia |
|---|---|---|
| Extraction | Python (Wu + Score) | External CLI (Python, material-color-utilities) |
| MD3 scheme | Python re-impl of HCT/CAM16 | External CLI |
| Adaptive UI input | — | C++ ImageAnalyser (dominant colour + luminance) |
| Scheme variants | 9 (5 MD3 + 4 custom) | Whatever the CLI supports |
| Template engine | matugen-compatible Jinja, own renderer | matugen (via CLI) |
| Shipped app templates | ~30 | Similar, shipped with CLI |
| Extended roles | Standard MD3 | MD3 + success + terminal palette |
| Compositor coupling | Multi-compositor abstraction (6 WMs) | Hyprland-specific (layer rules) |
| Runtime cost | Python subprocess per regen | CLI subprocess + C++ background thread |
| Self-contained | Yes (Python 3 only) | No (needs external caelestia CLI) |

**Design philosophy difference:**

- **Noctalia** owns the whole pipeline. One repo, one Python package, one shell. Easy to fork, hard to reuse in other projects.
- **Caelestia** splits concerns. The shell consumes a scheme file; the CLI produces it. Other caelestia tools (launcher, wallpaper picker) also consume the same scheme.json. More UNIX-y, more moving parts to install.

---

## Part 6: What to steal for your own shell

1. **MD3 semantic roles as a singleton.** `Colors.qml` or `Theme.qml` with ~30 color role properties. Widgets reference `Colors.surfaceContainer`, never hex. This alone makes retheming free.
2. **Scheme file on disk + FileView watcher.** Decouple generation from consumption. Any tool that writes `scheme.json` in the agreed format can retheme your shell.
3. **Matugen-compatible templates.** Even if you roll your own engine (Noctalia-style), stay compatible so users can reuse community templates.
4. **Luminance-aware UI tweaks.** A tiny dominant-colour/luminance extractor like Caelestia's lets you adapt transparency, blur, or shadow intensity per wallpaper.
5. **Start with matugen.** Unless you need a specific variant or control matugen doesn't give you, the build/deps savings are massive. Only escalate to custom engines if you have a concrete reason.

---

## Part 7: Noctalia's theme contract

Noctalia defines a theme shape, but it's **code-enforced, not schema-enforced** — no JSON Schema file, no runtime validator that rejects malformed input. The contract lives in two places:

- `Services/Theming/ColorSchemeService.qml:245-263` — `JsonAdapter` that defines the 16 required roles and writes `~/.config/noctalia/colors.json`.
- `Commons/Color.qml:60-82` — QML singleton exposing one property per role.

### 7.1 Top-level shape

```json
{
  "dark":  { ...16 color roles + optional "terminal" block },
  "light": { ...16 color roles + optional "terminal" block }
}
```

Both `dark` and `light` are optional individually — if only one is present, it's used for both modes.

### 7.2 The 16 required color roles

```
mPrimary, mOnPrimary
mSecondary, mOnSecondary
mTertiary, mOnTertiary
mError, mOnError
mSurface, mOnSurface
mSurfaceVariant, mOnSurfaceVariant
mOutline
mShadow
mHover, mOnHover
```

The `m` prefix is Noctalia's convention (stands for "material"). Naming is loose — the `pick()` helper in `writeColorsToDisk()` accepts either `mPrimary` or `primary`, so bare matugen output also works.

### 7.3 Optional terminal block

```json
"terminal": {
  "normal":  { "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white" },
  "bright":  { same 8 keys },
  "foreground": "...", "background": "...",
  "selectionFg": "...", "selectionBg": "...",
  "cursorText": "...", "cursor": "..."
}
```

Used when the `terminal` template is enabled — feeds 16 ANSI colors + cursor/selection pairs to Alacritty/Kitty/Foot config.

### 7.4 Validation posture

**Loose.** `writeColorsToDisk()` uses a fallback helper:

```js
pick(obj, "mPrimary", "primary", fallback)
```

Behavior:

- Missing keys silently retain the previous value. No hard failure.
- Both naming conventions accepted (`mPrimary` **or** `primary`).
- Malformed JSON is caught, logged, and the scheme is ignored.
- No per-field color validation (a malformed hex string just becomes an invalid QColor).

Partial schemes "work" but mix old and new values — a footgun for theme authors.

---

## Part 8: Noctalia contract vs full MD3 contract

Noctalia deliberately ships a **reduced** MD3 surface. Here's what's in and what's out.

### 8.1 Side-by-side role count

| Category | Full MD3 | Noctalia | Notes |
|---|---|---|---|
| Primary | `primary`, `onPrimary`, `primaryContainer`, `onPrimaryContainer` | `mPrimary`, `mOnPrimary` | Containers dropped |
| Secondary | `secondary`, `onSecondary`, `secondaryContainer`, `onSecondaryContainer` | `mSecondary`, `mOnSecondary` | Containers dropped |
| Tertiary | `tertiary`, `onTertiary`, `tertiaryContainer`, `onTertiaryContainer` | `mTertiary`, `mOnTertiary` | Containers dropped |
| Error | `error`, `onError`, `errorContainer`, `onErrorContainer` | `mError`, `mOnError` | Containers dropped |
| Surface | `surface`, `onSurface`, `surfaceVariant`, `onSurfaceVariant`, `surfaceDim`, `surfaceBright` | `mSurface`, `mOnSurface`, `mSurfaceVariant`, `mOnSurfaceVariant` | `surfaceDim`/`surfaceBright` dropped |
| Surface containers | `surfaceContainerLowest`, `surfaceContainerLow`, `surfaceContainer`, `surfaceContainerHigh`, `surfaceContainerHighest` | — | **Entire 5-tier system dropped** |
| Inverse | `inverseSurface`, `inverseOnSurface`, `inversePrimary` | — | Dropped |
| Outline | `outline`, `outlineVariant` | `mOutline` | Variant dropped |
| Background | `background`, `onBackground` | — | Use `mSurface` |
| Other | `shadow`, `scrim`, `surfaceTint` | `mShadow` | `scrim`, `surfaceTint` dropped |
| Fixed family | `primaryFixed`, `primaryFixedDim`, `onPrimaryFixed`, `onPrimaryFixedVariant` × (primary/secondary/tertiary) = 12 roles | — | **Entire fixed family dropped** |
| **Noctalia originals** | — | `mHover`, `mOnHover` | Not in MD3 spec |
| **Total** | **~50 roles** | **16 roles** | ~68% reduction |

### 8.2 What's lost by dropping the extras

- **No container hierarchy** — MD3 uses `primaryContainer` for filled buttons, chips, FABs with a "soft" primary feel. Without it, Noctalia widgets likely render primary buttons with alpha-modulated `mPrimary` or just `mSurfaceVariant` as a stand-in. Less visual depth.
- **No surface elevation tiers** — MD3's 5-tier `surfaceContainer*` system encodes elevation via tonal overlay (lower = further back, higher = closer). Noctalia has one `mSurface` + `mSurfaceVariant`, so elevation has to come from alpha/blur/border rather than color.
- **No inverse palette** — used in MD3 for snackbars, tooltips that invert the theme. Noctalia would hand-roll these per widget.
- **No fixed palette** — used in MD3 for content that should stay consistent across light/dark (e.g., branded chips). Not a common shell need, reasonable drop.
- **No `scrim`** — the semi-transparent overlay for modals/sheets. Noctalia likely hardcodes `Qt.rgba(0,0,0,0.5)` or similar.

### 8.3 What's gained

- **`mHover`/`mOnHover`** — explicit hover-state colors as first-class roles. MD3 computes hover via state-layer math on top of base roles (primary + 8% alpha overlay). Noctalia makes it a palette decision — themes can set hover independently of primary. Simpler for theme authors, less algorithmic.
- **Much lower authoring bar** — a theme author needs to pick 16 colors, not 50. Catppuccin, Gruvbox, etc. were easy to port (they ship 10 predefined schemes).

### 8.4 What this means for theme portability

- **matugen templates work** — matugen outputs the full 50-role MD3 set; Noctalia just picks the 16 it cares about via `pick()`. No format mismatch.
- **MD3 themes from other shells don't fully port** — if you pull a Caelestia `scheme.json` (which has containers, surface tiers, fixed family), Noctalia consumes it fine but throws away ~34 roles. The inverse is lossy: a Noctalia scheme feeding an MD3-heavy shell would leave 34 roles blank.
- **Reduced surface is a design choice, not a bug** — the shell's widgets were built against the 16-role vocabulary. Adding MD3 containers back would require rewriting every widget that currently fakes them with alpha-tricks.

### 8.5 Recommendation if you're building your own shell

Pick a point on the spectrum consciously:

- **Full MD3 (~50 roles)** — max visual richness, max theme-authoring burden, easiest matugen drop-in, easiest to port themes in/out of the broader MD3 ecosystem. Caelestia's approach.
- **Reduced MD3 (~16 roles)** — easier authoring, fewer widget variants to design, but you lose elevation-via-color and will reinvent container visuals. Noctalia's approach.
- **Custom** — diverge only when you know which MD3 roles you're rejecting and why. Usually a bad idea.

---

## Part 9: Our Shell Theming Contract (Current)

Sections 7 and 8 above describe **Noctalia's** contract and tradeoffs.

Our current shell contract is defined by:

- `home/config/quickshell/system/core/contracts/theme-contracts.js`
- `home/config/quickshell/system/core/ports/theme-provider-port.js`
- `home/config/quickshell/system/ui/bridges/ThemeBridge.qml`
- ADR-0022 (`home/config/quickshell/adr/0022-theming-provider-and-token-boundary-strategy.md`)

### 9.1 Request contract (`shell.theme.generate`)

```json
{
  "kind": "shell.theme.generate",
  "schemaVersion": 1,
  "provider": "static|matugen|...",
  "mode": "dark|light",
  "variant": "tonal-spot|...",
  "sourceKind": "static|wallpaper|color|file|generated",
  "sourceValue": "string",
  "meta": { "...": "..." }
}
```

### 9.2 Scheme contract (`shell.theme.scheme`)

```json
{
  "kind": "shell.theme.scheme",
  "schemaVersion": 1,
  "themeId": "string",
  "provider": "string",
  "mode": "dark|light",
  "variant": "string",
  "sourceKind": "static|wallpaper|color|file|generated",
  "sourceValue": "string",
  "generatedAt": "ISO-8601",
  "roles": { "...": "#RRGGBB|#RRGGBBAA" },
  "meta": { "...": "..." }
}
```

### 9.3 Required semantic roles (strict)

Our contract currently requires an MD3 canonical vocabulary (37 required keys):

`primary`, `onPrimary`, `primaryContainer`, `onPrimaryContainer`,
`secondary`, `onSecondary`, `secondaryContainer`, `onSecondaryContainer`,
`tertiary`, `onTertiary`, `tertiaryContainer`, `onTertiaryContainer`,
`error`, `onError`, `errorContainer`, `onErrorContainer`,
`background`, `onBackground`, `surface`, `onSurface`,
`surfaceVariant`, `onSurfaceVariant`, `outline`, `outlineVariant`,
`shadow`, `scrim`, `inverseSurface`, `inverseOnSurface`, `inversePrimary`,
`surfaceTint`, `surfaceContainerLowest`, `surfaceContainerLow`,
`surfaceContainer`, `surfaceContainerHigh`, `surfaceContainerHighest`,
`surfaceBright`, `surfaceDim`

### 9.4 Validation posture

Unlike Noctalia's loose fallback behavior, our contract is **strictly validated**:

- `mode` must be `dark` or `light`
- `sourceKind` must be one of the allowed enum values
- all required roles must exist
- role values must be hex colors (`#RRGGBB` or `#RRGGBBAA`)
- invalid documents are rejected

### 9.5 Provider boundary and fallback

- Default provider: `static`
- Fallback provider: `static`
- Optional provider scaffold: `matugen`
- Generation happens through `ThemeBridge` + `ThemeProviderPort`
- Provider failure yields typed outcome and fallback behavior

### 9.6 Runtime command surface

Current shell commands:

- `theme.describe`
- `theme.regenerate`
- `theme.provider.set <provider-id>`
- `theme.mode.set <dark|light>`
- `theme.variant.set <variant>`

### 9.7 Known gap (intentional)

The provider contract and diagnostics path are live.

Applying generated scheme roles into the existing `Theme.qml` token singleton is
still a follow-up slice (deferred intentionally in ADR-0022 to stabilize the
boundary first).

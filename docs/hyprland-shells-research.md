# Hyprland / Quickshell Shells — Research & Feature Survey

Survey of 7 existing Hyprland/Quickshell shells to inform building a new one.

Repos analyzed:
- `noctalia-shell` — minimal, multi-compositor, plugin-driven
- `shell` (caelestia-dots/shell) — MD3 with native C++ plugin
- `DankMaterialShell` — Quickshell + Go backend + rich CLI
- `dots-hyprland` (end-4 illogical-impulse) — feature-heavy with AI
- `hyprland-shells-repo/Ilyamiro-CachyOS-port` — minimalist port
- `hyprland-shells-repo/nixos-configuration` — NixOS declarative
- `hyprland-shells-repo/shell` — Python-backed media/AI platform

---

## 1. Noctalia Shell

**Pitch:** "Quiet by design." Minimal, beautiful Wayland shell. Native compositor support for Niri, Hyprland, Sway, Scroll, Labwc, MangoWC. Wallpaper-driven Material You theming. ~100 plugins available.

**Modules/Widgets:**

| Module | Purpose |
|---|---|
| Bar | Multi-monitor status bar, per-screen density, auto-hide, floating mode, widget registry. Left/center/right sections with hot-corner activation. |
| MainScreen | Unified multi-monitor orchestration (AllScreens, BarContentWindow, BarExclusionZone, BarTriggerZone, PopupMenuWindow, SmartPanel, ScreenCorners). |
| Dock | App dock with window previews, pinning, favorites, recent apps, context menus. |
| LockScreen | Swipe-to-unlock, `.face` avatar, password fallback, idle integration. |
| Notification | D-Bus daemon + NotificationRulesService (DND, stacking, history). |
| OSD | Brightness/volume feedback via HardwareService + AudioService. |
| DesktopWidgets | Floating clock/media/weather/sysmon on desktop. |
| Panels | Launcher (grid/list + preview), Settings, ControlCenter (9 cards), SetupWizard, Changelog, NotificationHistory, Plugins, SystemStats, Dock, Wallpaper, Tray. |
| Cards | Control-center components: Audio, Brightness, Media, Profile, CalendarHeader, CalendarMonth, Weather, Shortcuts, SystemMonitor. |
| Toast | Success/notice/error toasts via ToastService. |
| Background | Shader-based wallpaper transitions (fade, wipe, disc, honeycomb, pixelate, stripes). |

**Widget library:** 57+ reusable QML primitives (NButton, NSlider, NTextInput, NComboBox, NColorPicker, NClock, NBattery, NGraph, NAudioSpectrum, etc.).

**Services (18 modules, 50+ singletons):**
- *Compositor:* CompositorService + Niri/Hyprland/Sway/Labwc/Mango/ExtWorkspace
- *Hardware:* Battery, Brightness (brightnessctl + DDC)
- *Keyboard:* Clipboard (cliphist), Emoji, Layout, LockKeys
- *Media:* Media (MPRIS), Audio (Pulse/PipeWire), Spectrum
- *Networking:* Network, Bluetooth, BluetoothRssi, VPN
- *Location:* Location, Calendar (khal/EDS), DarkMode (sunset), NightLight (wlsunset)
- *Power:* Idle, IdleInhibitor, PowerProfile
- *System:* Host, Notification, NotificationRules, Sound, SystemStat, Font, ProgramChecker
- *Theming:* ColorScheme (10 palettes), AppTheme (Material You), TemplateProcessor/Registry (gtk/kde/vscode/qt5ct/qt6ct)
- *UI:* Bar/ControlCenter/DesktopWidget/LauncherProvider registries, ImageCache, Panel, SettingsPanel, SettingsSearch, Toast, Tooltip, Wallpaper, Wallhaven
- *Custom:* PluginRegistry (SHA256 source hashing), Plugin, Telemetry, Update, Supporter, GitHub, IPC, Hooks, CurrentScreenDetector

**Commons/Helpers:**
- `Settings.qml` (1296 LOC): JSON singleton, 59 schema versions, hot-reload, migrations
- `Style.qml`: design tokens (fonts 8-24px, weights, radii, margins, opacity, shadows, animation durations, scaled by uiScaleRatio)
- `Color.qml`: RGB/HSL/HCT conversion, adaptive opacity
- `I18n.qml`: translation with lazy loading
- `Icons.qml`, `ThemeIcons.qml`: Tabler Icons (208KB)
- `Keybinds.qml`, `ShellState.qml`, `Logger.qml`

**Scripts:**
- Python: `template-processor.py` (~50KB, Material You engine: quantization, HCT, tone curves, 8 schemes), calendar integration (khal/EDS), bluetooth-pair, build-settings-search-index
- Bash: `template-apply.sh`, `colorscheme-registry.sh`, `qmlfmt.sh`, `shaders-compile.sh`

**Shaders (16 GLSL):**
- UI: appicon_colorize, progress_border, rounded_image, color_picker, graph
- Weather: sun (God rays), rain, snow, cloud, stars
- Audio: wave_spectrum
- Wallpaper transitions: fade, wipe, disc, honeycomb, pixelate, stripes

**Theming:** 10 curated schemes (Catppuccin, Dracula, Eldritch, Gruvbox, Kanagawa, Nord, Rose Pine, Tokyo Night, Ayu) + Material You from wallpaper + multi-template cascade (GTK 3/4, KDE Plasma, Qt 5/6, VSCode, custom).

**Tech:** Pure QML/Qt6 on custom Quickshell fork, Python for Material You + calendar, Nix flake with home-manager/NixOS modules. No C++ plugins.

---

## 2. Caelestia Shell

**Pitch:** Production-grade Hyprland shell with MD3 aesthetic, C++ plugin for performance-critical rendering, deep system integration. Available on AUR + NixOS.

**Modules:**

| Module | Purpose |
|---|---|
| bar | Top panel: logo, workspaces, window title, tray, status icons, clock, power. |
| dashboard | Central hub (logo click): profile, time, media, weather, sysmon, wallpaper/scheme switcher. |
| launcher | Fuzzy search, actions (calculator via Qalculate, wallpaper, power), scheme/variant selector, favorites. |
| lock | PAM auth, notification display, configurable GIFs, WlSessionLock. |
| controlcenter | Multi-pane: Appearance, Audio, Bluetooth, Network, Notifications, Dashboard config, Taskbar. Split-pane with live preview. |
| notifications | Daemon + DND + persistent history + morphing blob backgrounds. |
| sidebar | Quick toggles (WiFi, BT, mic, game mode, DND, VPN), sliders. |
| osd | Brightness/mic feedback, auto-hide. |
| utilities | Toast notifications, tray, game mode indicator. |
| session | Power menu with optional vim keybinds. |
| areapicker | Screenshot/screencast area selection, freeze mode. |
| background | Desktop clock, audio visualizer bars, wallpaper. |
| windowinfo | Active window title. |
| drawers | Collapsible panel framework. |

**Services (20 singletons):**
Audio (PipeWire + cava), Players (MPRIS + aliasing), Notifs (daemon + DND), Colours (MD3 + image analysis), Brightness (brightnessctl + DDC), Hypr (IPC), Network (NM), GameMode, Weather, Recorder (wf-recorder), VPN (WireGuard), SystemUsage, Time, Wallpapers, Screens, LyricsService, Visibilities, NotifData, Nmcli, NetworkUsage, IdleInhibitor.

**Components (~80 QML):** StyledWindow/Rect/Text, StyledFlickable/ListView, SectionContainer/Header, IconButton/TextButton/ToggleButton/SplitButton, StyledSlider/FilledSlider/CircularProgress, StyledSwitch/RadioButton, StyledInputField, Menu/MenuItem/Tooltip, CustomSpinBox, Colouriser, ColouredIcon, Elevation, InnerBorder, OpacityMask, StateLayer (ripple), SplitPaneLayout, CollapsibleSection, Anim/CAnim, PaneTransition, CachingImage, CircularIndicator, Logo.

**Utils:** Config.qml (hierarchical JSON accessor + file watcher), Icons (500+ Material Symbols), SysInfo, Paths (XDG), Searcher (fuzzy/regex), NetworkConnection, Shortcuts, IpcHandler.

**Native C++ Plugin (56 files, Qt QML modules):**
- `Caelestia.Blobs` — BlobShape/Group/Rect/InvertedRect, blob.frag/vert shaders, BlobMaterial
- `Caelestia.Components` — LazyListView (virtualized)
- `Caelestia.Internal` — ArcGauge, CircularBuffer, VisualizerBars (libcava + beat), CachingImageManager (LRU), SparklineItem, HyprDevices, HyprExtras, LoginDManager
- `Caelestia.Models` — FilesystemModel (async)
- `Caelestia.Services` — BeatTracker (libaubio), AudioCollector/Provider, CavaProvider

**Dependencies:** Qt6, PipeWire, Aubio, Cava, Qalculate, C++20.

**Config:** `~/.config/caelestia/shell.json` (700+ line example), hierarchical (appearance/general/background/bar/dashboard/launcher/lock/notifs/osd/session/sidebar/utilities), hot-reload via Config singleton. In-shell Appearance pane with live preview.

**Theming:** MD3 with dynamic scheme generation from wallpaper (image analyzer in C++), light/dark auto, transparency/blur layers based on luminance. Fonts: Material Symbols, Rubik (sans), CaskaydiaCove Nerd (mono).

**Flourishes:** Morphing blob backgrounds (GLSL), MD3 easing curves, StateLayer ripple, blur backgrounds (Wayland compositor blur), realtime FFT visualizer with beat-detection pulse, lazy/virtualized lists, async cached images, threaded render loop.

**Tech:** QML + Qt6 + C++20 + GLSL. CMake 3.19+ with Ninja. Nix flake + AUR. Singleton services, IPC via Unix sockets (`caelestia shell ...`).

---

## 3. DankMaterialShell (DMS)

**Pitch:** Complete desktop shell replacement — consolidates waybar/swaylock/swayidle/mako/fuzzel/polkit into one cohesive MD3 ecosystem. Multi-compositor (niri, Hyprland, Sway, MangoWC, labwc, Scroll, Miracle). Wallpaper-driven dynamic theming via matugen + dank16. Go backend + Quickshell UI.

**Modules:**

*Panels/Bars:* DankBar (66KB main, per-monitor Variants, plugin widgets), TopBar, Dock (6 components, context menus, pinned apps, overflow).

*Overlays/Dialogs:* DankDash, AppDrawer, DankLauncherV2 (Spotlight-style: emoji, app search, file search via dsearch, windows, calculator), Overview.

*System Controls:* ControlCenter (WiFi, BT, audio, display, night mode), Notifications (swipe-to-dismiss, center with keyboard nav), OSD, Lock (greeter + fade-to-lock).

*Monitoring/Utilities:* ProcessList (search/kill), Greetd login greeter, Notepad, Calendar (iCal), Weather, Settings (39 tabs, ~1.4MB).

*Desktop Widgets:* DesktopWidgetLayer (floating clock, dgop metrics).

*Backgrounds:* WallpaperBackground (26KB, 8 shader transitions: fade/wipe/disc/pixelate/iris_bloom/stripes/portal/ripple), BlurredWallpaperBackground (niri).

*Modals (19):* power, BT pairing, WiFi password, color picker, file browser, process list, window rule editor, workspace rename, keybinds editor, Polkit, print, system update, notif detail, changelog, clipboard, mux (tmux/zellij).

**Services (50+):**
- *Audio/Media:* AudioService, MprisController, MultimediaService, CavaService, TrackArtService
- *Network:* NetworkService + DMS/Legacy variants, BluetoothService, VPNService
- *Display:* DisplayService (brightness + DDC + night + DPMS), DgopService (CPU/RAM/GPU via Go dgop), WallpaperService + WallpaperCyclingService, WlrOutputService, BlurService
- *System:* BatteryService, IdleService (AC/battery timers, inhibit), PowerProfileWatcher, SessionService, DesktopService, PolkitService
- *Theming:* Theme (100KB MD3 singleton), SettingsData (107KB, 100+ properties), SessionData (45KB), Appearance, FirstLaunchService, ChangelogService
- *Data:* ClipboardService, NotepadStorageService, CacheData
- *Compositor:* CompositorService (23KB), NiriService (49KB), HyprlandService, DwlService, ExtWorkspaceService
- *Search:* AppSearchService (fzf.js), DSearchService, SettingsSearchService
- *Integrations:* DMSService, PluginService (30KB, plugin lifecycle + data persistence), KeybindsService, BarWidgetService, DesktopWidgetRegistry, PopoutService, MuxService, CupsService (printers), PortalService, LocationService, CalendarService, WeatherService, UserInfoService, PrivacyService (cam/mic indicators), SystemUpdateService, ToastService
- *IPC:* DMSShellIPC (61KB, 50+ targets)

**Core abstractions:**
- `Theme.qml` (100KB) — MD3 color system (primary/secondary/tertiary, light/dark, elevation tokens 0-24, typography, Inter Variable + Fira Code)
- `Anims.qml` — MD3 motion (emphasized/decel/accel/standard, durations 200/450/600ms)
- `StockThemes.js` — 12+ palettes (Gruvbox, Nord, Rose Pine, Tokyo Night, Synthwave, Miami Vice, Cyberpunk, Hotline Miami, Everforest)
- `DankSocket.qml` — Unix socket IPC
- `SettingsData.qml` — JSON config synced with Go backend
- `fzf.js` (34KB, ported fuzzy match), `suncalc.js`, `markdown2html.js`, `KeyUtils.js`

**DankWidgets library (45 components):** DankTextField, DankToggle, DankSlider, DankDropdown, DankNumberStepper, DankFilterChips, DankIcon, DankCircularImage, DankAlbumArt, DankNFIcon, DankSVGIcon, DankPopout, DankFlickable, DankListView, DankGridView, DankSlideout, DankCollapsibleSection, DankBackdrop, DankButton, DankActionButton, DankRipple, StateLayer, DankTooltip, DankOSD, DankSeekbar, M3WaveProgress, KeybindItem (81KB).

**CLI (dms):** `run`, `ipc call <target> <fn>`, `restart/kill`, `brightness list/set/inc/dec`, `color pick` (native Wayland picker with magnifier), `screenshot`, `blur`, `chroma`, `notify`, `dpms`, `keystate`, `plugins search/install/browse`, `download`, `matugen`, `dank16`, `setup`, `doctor`, `greeter install`, `config get/set`, `keybinds`, `window-rules`.

**Settings UI (39 tabs):** Appearance, DankBar, Dock, Audio, Displays, Network, Notifications, Keybinds, Launcher, Lock, Plugins, Printers, Window rules, Workspaces, Power/Sleep, etc.

**Theming:** matugen (external) + dank16 (custom 16-color). Templates auto-generate: GTK 3/4, Qt5/6ct, Alacritty, Kitty, Ghostty, Foot, Wezterm, Neovim, VSCode, Firefox. Light/dark auto via sunset/sunrise (suncalc).

**Packaging:** Nix flake (pinned quickshell), Makefile, Arch/Fedora COPR/Debian/Ubuntu/openSUSE/Gentoo. systemd user service.

**Tech:** QML + Qt6 + Go 1.25+. Wayland protocol bindings (wlr-gamma/screencopy/layer-shell/output-management/etc.), DBus (BlueZ/NM/iwd/logind/Portal/CUPS), external: matugen/dgop/dsearch.

---

## 4. dots-hyprland (end-4 illogical-impulse)

**Pitch:** Flagship Hyprland dotfiles with MD3 aesthetic via matugen. Feature-rich: AI chat (Gemini/OpenAI/Mistral/Ollama), screen translator, anti-flashbang shader, live window previews. Quickshell-powered (replacing older AGS).

**Structure:** `/dots/.config/quickshell/ii/` — 2 panel families: `ii` (primary) + `waffle` (alt, `Super+Y`).

**UI Modules (21):**

| Module | Purpose |
|---|---|
| bar | Top taskbar + widget panels (28 files) |
| dock | App launcher dock |
| sidebarLeft | AI chat, anime player, translator (344+ LOC) |
| sidebarRight | Notifications, calendar, BT, WiFi, pomodoro, volume mixer, quick toggles |
| overview | Live window previews + search |
| onScreenDisplay | Brightness/volume OSD |
| onScreenKeyboard | Virtual keyboard |
| mediaControls | MPRIS controls |
| lock | Hyprlock UI |
| cheatsheet | Keybind reference |
| notificationPopup | Toasts |
| regionSelector | Screenshot/record region |
| screenTranslator | Real-time text translation overlay |
| overlay | Floating taskbar, crosshair, FPS limiter, notes, recording status |
| wallpaperSelector | Matugen-integrated picker |
| verticalBar | Alt variant |
| background | Wallpaper |
| screenCorners | Hot corners |
| sessionScreen | Power menu |
| polkit | Auth prompts |

**Services (50+):** Audio, Brightness (DDC), Battery, Network, Bluetooth, Idle, Notifications, Cliphist, KeyringStorage, Ydotool, GlobalFocusGrab, MprisController, EasyEffects, SongRec (music recognition), **Ai** (39KB multi-LLM), GoogleCloud, Translation (translate-shell), DateTime, ResourceUsage, SystemInfo, HyprlandData/Keybinds/Xkb, Hyprsunset, HyprlandAntiFlashbangShader, Updates, Weather, LauncherSearch/Apps, MaterialThemeLoader, Booru, LatexRenderer, Todo, TimerService, ConflictKiller, FirstRunExperience, Wallpapers, Privacy, SessionWarnings, Polkit, TrayService.

**AI:** Gemini + OpenAI + Mistral + Ollama. Token counting, keyring credentials, system prompts with `{DISTRO}/{DATETIME}/{WINDOWCLASS}/{DE}` substitutions. Features: saved chat history, streaming, clipboard image input, preset prompts (ii-Default, ii-Imouto, Nyarch Acchan), `/help /clear /load /save` commands.

**Theming:** matugen → Hyprland/Hyprlock/GTK 3/4/Fuzzel/KDE Plasma/AGS/Quickshell. Pre-generated MD3 palettes. Colloid Kvantum (Qt), Adwaita GTK, Breeze KDE, Material Symbols + JetBrains Mono.

**dots-extra:** emacs, fcitx5 (CJK), fedora configs, fontsets, swaylock alt, via-nix.

**Installer (`./setup`):** install/install-deps/install-setups/install-files/resetfirstrun/uninstall/exp-update/exp-merge/virtmon/checkdeps. One-liner via `bash <(curl -s https://ii.clsty.link/get)`.

**sdata/:** lib (env/package-manager/distro detection), dist-arch/fedora/gentoo/nix, subcmd-* logic, deps-info.md.

**diagnose/:** validates repo/submodules/distro/XDG/Hyprland/Quickshell versions/Python venv. Optional auto-upload to 0x0.st.

**Flourishes:** anti-flashbang shader, MD3 easing, frosted-glass blur, workspace number hold-overlay, live window previews, floating widgets, OSK, OCR (tesseract), region-based screenshot, FPS counter, screen corner hotspots, hypridle auto-sleep.

**Tech:** QML + Qt6 + JS + Python 3 (uv venv) + bash + GLSL. Quickshell pinned git. KDE Frameworks (Kirigami, Syntax Highlighting). External: ripgrep, jq, ImageMagick, tesseract.

---

## 5. Ilyamiro-CachyOS-port

**Pitch:** Minimalist CachyOS port of ilyamiro's nixos-configuration. Clean top bar + widget popups. For Arch/CachyOS users wanting pixel-perfect lightweight Hyprland.

**UI:** Top Bar (36px) with workspaces/clock/WiFi/status/tray. Music popup (MPRIS + album art). Network popup. Wallpaper picker (carousel). Lock screen.

**Services:** Audio (pactl), Network (WiFi polling), MPRIS (playerctl), Screenshots (script + wl-copy), Wallpaper, Workspaces (Hyprctl).

**Flourishes:** Matugen via `/tmp/qs_colors.json` (1s refresh). Catppuccin Mocha fallback (25-color). Widget morph animations (500ms). Master-window-with-XOR-region-mask. Startup cascade (10ms → 1000ms stagger). State file `/tmp/qs_active_widget`.

**Tech:** QML (Quickshell), NixOS dotfiles. Main.qml ~364 LOC, TopBar.qml 36KB, MatugenColors.qml.

**Unique tricks:** Minimalist popup-widget approach; one-file JSON color hot-reload; master window off-screen parking (prevents Wayland surface destruction).

---

## 6. nixos-configuration (ilyamiro original)

**Pitch:** Full-featured NixOS Hyprland desktop. Battery/calendar/focus/guide popups, sysmon, quick settings, wallpaper. For power users valuing declarative reproducibility.

**UI:** Top Bar (65px) with workspaces, CPU, battery, clock, BT, centered media pill, network, volume, temp, memory, tray. Popups: battery, calendar + clock, focus (pomodoro), guide, monitor, music, network, volume, wallpaper. Lock screen (68KB QML).

**Services:** Audio (PipeWire), Network, Battery, MPRIS, temperature, monitor/resolution (Hyprctl), workspaces, wallpaper.

**Flourishes:** Matugen + Catppuccin fallback. Modal widget system with morph + configurable UI scale via settings.json. Master window with XOR mask. WindowRegistry.js. Settings persisted to `~/.config/hypr/settings.json` (polled by settingsReader).

**Tech:** QML + NixOS home-manager. Main.qml ~357 LOC, TopBar.qml 73KB, Lock.qml 68KB.

**Unique:** Per-widget startup cascade; feature-complete lock screen; home-manager declarative packaging.

---

## 7. shell (hyprland-shells-repo/shell)

**Pitch:** Industrial-strength shell for Arch. Shell-as-platform with Python HTTP backends. Media readers (anime/manga/novel), AI chat (Aikira roleplay + Ollama), clipboard/emoji/kaomoji, GitHub contributions, Wallhaven browser.

**UI (50+ components):**
- Top Bar (42px) — workspaces, CPU, battery, clock, BT | media pill | network, volume, temp, memory, tray
- Control Center (450px slide-in) — quick tiles, sliders, CPU/mem/temp graphs, uptime, power, notifications, PipeWire sink
- Launcher (edge-trigger, left 2px) — pinned grid, app search, persistent pins
- Window Switcher — live thumbnails + search
- Network Panel (2-tab WiFi + BT)
- Media Panel + CAVA visualizer
- Calendar (month + clock)
- OSD (vol/brightness)
- Notes Drawer (900px bottom) — multi-category notes with shell command execution (`$text`, `$note` substitution), keep-open terminal
- Clipboard Manager (3-tab: history, 400+ emojis, kaomoji)
- Power Menu
- GitHub Contributions (right edge) — 40-week heatmap, 10min refresh (jogruber.de API)
- Wallpaper — 3D skewed carousel (Matrix4x4) + Wallhaven API browser (categories, purity, sorting, resolution, API key, incremental paging)
- Anime Reader (left panel) — AllAnime GraphQL, multi-provider streaming, library, Detail/Stream views
- Manga Reader (left panel) — WeebCentral scraping (curl_cffi for Cloudflare bypass), favorites + auto-update (15min), chapter downloads, library
- Novel Reader (right panel) — novelbin + freewebnovel, runtime switch, library
- Spotify Lyrics — track-synced from local API (2s polling)
- Aikira AI Chat (1100x720) — character library, multi-persona, proxy mgmt, conversation history, SSE streaming, response reroll
- Ollama Chat — local LLM selection, multi-turn, cancellation

**Services:**
- *QML:* System, Volume, Anime, Manga, Novel, Github, Wallhaven, Lyrics, Ollama
- *Python servers:*
  - `anime_server.py` :5050 — AllAnime API wrapper
  - `manga_server.py` :5150 — WeebCentral scraper (curl_cffi)
  - `novel_server/main.py` :5151 — novelbin/freewebnovel
  - `aikira/run.py` :7842 — FastAPI + PostgreSQL, characters/personas/proxies/conversations, SSE streaming

**Flourishes:** Lazy-loaded Loaders (600ms deactivation timers for memory). Material 3 / Vibrant schemes via `colors/Colors.json` with live reloads from `~/.cache/quickshell/settings.json`. 3D wallpaper carousel (Matrix4x4 + scale-on-focus). CAVA at top/bottom, fullscreen toggle. 280-day GitHub heatmap. SSE token streaming. IPC (`qs ipc call`). Edge-hover triggers (left launcher, right GH contributions, bottom notes). Persistent settings (pins, dock, player, Wallhaven params, scheme, grid layout).

**Tech:** QML + Python 3 (Flask, FastAPI, requests, beautifulsoup4, curl_cffi, alembic) + PostgreSQL (Aikira). Venv-based Python envs. ~627 LOC shell.qml + ~3000+ total QML. 27 reusable components.

---

# Cross-Repo Comparison Matrix

| Dimension | noctalia | caelestia | DMS | dots-hyprland | Ilyamiro | nixos-config | shell (hs) |
|---|---|---|---|---|---|---|---|
| **Framework** | Quickshell (fork) | Quickshell + C++20 | Quickshell + Go | Quickshell | Quickshell | Quickshell | Quickshell + Python |
| **Compositor scope** | 6 (Niri/Hypr/Sway/Scroll/Labwc/Mango) | Hyprland | 7 (niri/Hypr/Sway/Mango/labwc/Scroll/Miracle) | Hyprland | Hyprland | Hyprland | Hyprland |
| **Native code** | None (Python helpers) | C++ plugin | Go backend | None (Python) | None | None | Python HTTP servers |
| **Config** | JSON + settings panel (59 schema versions) | JSON + Appearance pane | JSON + 39-tab UI + dms CLI | Module QML + settings | Minimal JSON | settings.json | settings.json |
| **Theming engine** | Python Material You + 10 schemes | MD3 (C++ image analyzer) | matugen + dank16 + 12 themes | matugen | matugen (file poll) | matugen | matugen + Material 3 |
| **Template cascade** | GTK/KDE/Qt5-6ct/VSCode/custom | integrated | GTK/Qt/Alacritty/Kitty/Ghostty/Foot/Wezterm/Neovim/VSCode/Firefox | GTK/Hyprlock/Fuzzel/Plasma | — | — | — |
| **IPC/CLI** | Custom IPC | `caelestia shell` | `dms ipc call` (50+) | `qs ipc` | minimal | minimal | `qs ipc` |
| **Plugin system** | Registry + SHA256 (100+) | — | Plugin browser | — | — | — | — |
| **AI integration** | — | — | — | Gemini/OpenAI/Mistral/Ollama | — | — | Aikira roleplay + Ollama |
| **Shaders** | 16 GLSL | Blob morphing + GLSL | 8 wallpaper transitions | anti-flashbang | — | — | CAVA visualizer |
| **Lock screen** | Full | PAM + notifs | fade + greeter | Hyprlock | Full | Full (68KB) | Power menu |
| **Launcher** | Grid/list + preview | Fuzzy + Qalculate | Spotlight + emoji + file + calc | Full-text | — | — | Pinned grid |
| **Dock** | Yes (previews, pins) | — | Yes (6 components) | Yes | — | — | — |
| **Desktop widgets** | Clock/media/weather/sysmon | Clock/visualizer | Clock/metrics | — | — | — | — |
| **Control center** | 9 cards | Multi-pane | Unified popout | sidebarRight | — | — | Slide-in |
| **System tray** | Yes | Yes | Yes | Yes | Yes | Yes | Yes |
| **Notifications** | Daemon + rules + history | Daemon + blobs | Swipe + history | Full | — | — | In control center |
| **Weather** | Card + shaders | Widget | Widget | Service | — | — | — |
| **Calendar** | Panel (khal/EDS) | — | Panel + iCal | sidebarRight | — | Popup | Month view |
| **Media/MPRIS** | Service + spectrum | Players + lyrics | Mpris + TrackArt | Mpris + SongRec | Popup | Pill + popup | Panel + CAVA + lyrics |
| **Clipboard** | cliphist | — | Full manager | cliphist | — | — | Tab + emoji + kaomoji |
| **Screenshot** | Service | areapicker + wf-recorder | Built-in | regionSelector | Script | — | — |
| **Color picker** | Widget | — | `dms color pick` + magnifier | — | — | — | — |
| **Wallpaper** | Transitions + Wallhaven | Local picker | Cycling + per-monitor | Matugen selector | Carousel | Carousel | Wallhaven + 3D skew |
| **Multi-monitor** | Per-screen | Per-monitor variants | Per-monitor bars+wp | Variants | Single | Single | Single |
| **Packaging** | Nix + NixOS module | Nix + AUR + CMake | Nix + COPR + AUR + deb + rpm + gentoo | AUR + Fedora + Gentoo + NixOS | NixOS | NixOS | venv |
| **USP** | Compositor abstraction + plugins | Blob morphing + C++ audio | Go backend + packaging + CLI | AI + screen translator | Minimalism | NixOS reproducibility | Media readers + AI platform |

---

# Master Feature List — Ranked by Frequency

## Tier S — Universal (7/7, "table stakes")

| Feature | Notes |
|---|---|
| Top bar / status bar | Workspaces, clock, tray, status icons. Per-monitor in mature shells. |
| Workspace indicator | Click-to-switch, scroll-to-cycle, active highlight. |
| Clock/date widget | Often triggers calendar popup. |
| System tray | StatusNotifierItem protocol. |
| Audio/volume service | PipeWire/Pulse, sink switching in mature ones. |
| MPRIS media control | Metadata, play/pause/seek, active-player. |
| Wallpaper management | Minimum: set + swap. Polish: transitions + cycling. |
| Notification daemon | FreeDesktop, popups, history in 6/7. |
| Matugen / Material You theming | Wallpaper → palette → apply. Near-universal expectation. |

## Tier A — Very common (5-6/7)

| Feature | Count | Notes |
|---|---|---|
| Lock screen (PAM) | 6 | Often with notif display + `.face` avatar. |
| App launcher | 6 | Fuzzy + calculator + action prefixes. |
| Control center / quick settings | 6 | WiFi, BT, brightness, volume, night mode. |
| Battery service | 6 | Charge %, state, warnings. |
| Network service (NM) | 6 | WiFi scan + connection mgmt. |
| Bluetooth service | 6 | Pairing UI in mature ones. |
| Brightness control | 6 | brightnessctl + DDC/CI. |
| OSD (volume/brightness) | 6 | Auto-hiding toast. |
| Calendar widget | 5 | Month view ± event sync. |
| Weather widget/service | 5 | Often with animated shaders. |
| Idle / auto-lock | 5 | With inhibitor for video. |
| Power menu / session controls | 5 | Shutdown/reboot/suspend/logout. |
| Clipboard history (cliphist) | 5 | Image preview bonus. |
| Screenshot tool | 5 | Region select + clipboard. |
| System stats (CPU/RAM/temp) | 5 | /proc or helper binary. |
| Per-monitor bars/wallpapers | 5 | Quickshell `Variants` pattern. |
| Hot-reload config | 5 | File watcher on JSON. |

## Tier B — Differentiators (3-4/7)

| Feature | Count | Notes |
|---|---|---|
| Application dock | 4 | Pins, previews, context menus. |
| In-shell settings UI | 4 | Tabbed, searchable, live preview. |
| Workspace overview / window previews | 4 | Live thumbnails. |
| Screen recorder | 4 | wf-recorder wrapper. |
| Shader wallpaper transitions | 4 | fade/wipe/disc/pixelate. |
| Audio visualizer (CAVA) | 4 | Bars or wave. |
| VPN service | 4 | WireGuard status. |
| Night light / gamma | 4 | wlsunset or built-in. |
| Custom keybinds UI | 3 | Editor + conflict detection. |
| Notification history panel | 3 | Searchable archive. |
| Multi-compositor abstraction | 3 | Noctalia/DMS/caelestia. Huge scope cost. |
| Desktop widgets (floating) | 3 | Clock/sysmon on wallpaper. |
| Light/dark auto-toggle | 3 | Suncalc-based. |
| Template/theme cascade | 3 | GTK/Qt/terminal/VSCode. |
| Toast notifications | 3 | Beyond notif daemon. |
| IPC CLI (rich) | 3 | `dms ipc`, `caelestia shell`, `qs ipc`. |
| C++ / native plugin | 2 | caelestia C++, DMS Go. Performance-only. |
| Polkit agent | 2 | Integrated vs external. |
| Wallhaven API browser | 2 | Online wallpaper search. |
| Plugin system | 2 | Noctalia (100+) + DMS. |

## Tier C — Niche flourishes (1-2/7)

| Feature | Count | Notes |
|---|---|---|
| AI chat (Gemini/OpenAI/Ollama) | 2 | dots-hyprland + shell. |
| Screen translator / OCR | 1 | dots-hyprland. |
| Anti-flashbang shader | 1 | dots-hyprland. |
| Anime/manga/novel readers | 1 | shell. |
| Aikira roleplay backend | 1 | shell. |
| GitHub contribution heatmap | 1 | shell. |
| Lyrics sync (MPRIS + API) | 2 | caelestia + shell. |
| Emoji + kaomoji picker | 1 | shell. |
| Notes with shell commands | 1 | shell. |
| Pomodoro / focus timer | 2 | nixos-config + dots-hyprland. |
| Virtual keyboard (OSK) | 1 | dots-hyprland. |
| Music recognition (SongRec) | 1 | dots-hyprland. |
| LaTeX math renderer | 1 | dots-hyprland. |
| Booru image search | 1 | dots-hyprland. |
| Printer UI (CUPS) | 1 | DMS. |
| Greeter (greetd) | 1 | DMS. |
| Telemetry (opt-in) | 1 | Noctalia. |
| Terminal multiplexer (tmux/zellij) | 1 | DMS mux. |
| Blob-morphing UI | 1 | caelestia C++. |
| Beat-synced visualizer pulse | 1 | caelestia (libaubio). |

---

# Shell-Builder Recommendations

## What to steal, from whom

- **Noctalia** → *architecture*. Services-as-singletons pattern, `Settings.qml` with versioned JSON schema + migrations, `Style.qml` design tokens, plugin registry with SHA256 source hashing. Their Python `template-processor.py` (Material You + HCT color space) is the best standalone theming engine in the survey.
- **caelestia** → *performance + polish*. When QML isn't enough, drop to C++ (beat detection, cava, lazy lists, image caching). MD3 elevation/state-layer/ripple components. Blob shaders for morphing UI.
- **DankMaterialShell** → *system integration*. Go backend with direct Wayland protocol bindings + rich `dms ipc call` CLI. Best distro packaging story (Nix + COPR + deb + AUR + Gentoo). 39-tab settings UI is the benchmark.
- **dots-hyprland (end-4)** → *feature breadth + AI*. `Ai.qml` multi-provider pattern with prompt template substitution. Screen translator, anti-flashbang shader, hotspot interactions.
- **shell (hyprland-shells)** → *platform thinking*. Python HTTP microservices backing QML UI. Lazy-loaded modules with deactivation timers. Aikira + anime/manga stack is the template for "shell as platform."
- **Ilyamiro / nixos-configuration** → *minimalist patterns*. Master-window-with-region-mask trick, startup cascade animations, `/tmp/qs_colors.json` one-file hot-reload.

## Recommended build order

**Phase 1 — Vitals (Tier S+A, ~2 weeks):** bar (workspaces + clock + tray), audio + MPRIS services, notifications daemon, wallpaper + matugen, launcher, lock screen, OSD, control center with WiFi/BT/brightness/volume, thin IPC CLI (`toggle/open/close/run` + completion).

**Phase 2 — Expected (rest of Tier A, ~2 weeks):** battery, calendar, weather, clipboard history, screenshot, system stats, idle/auto-lock, per-monitor, hot-reload config, power menu.

**Phase 3 — Polish (Tier B cherry-pick):** in-shell settings UI (copy DMS structure), dock, workspace overview, wallpaper transitions (steal Noctalia's 16 shaders wholesale), CAVA.

**Phase 4 — Signature feature:** pick *one* from Tier C that defines your shell. That's what people will remember.

## Architectural decisions worth making early

1. **Native-code strategy**: pure-QML (Noctalia), Python helpers (dots-hyprland), C++ plugin (caelestia), or Go backend (DMS). Hardest to change later.
2. **Compositor scope**: Hyprland-only is 10× simpler than 6-compositor abstraction. Only expand if you personally use multiple.
3. **Settings as versioned JSON schema from day 1** — with migrations. You'll regret retrofitting this.
4. **Design tokens singleton** (Style.qml / Theme.qml / Appearance.qml) — every shell that grew without one later suffered.
5. **IPC from day 1** — even a tiny `yourshell toggle launcher` proves out the pattern and unblocks scripting.

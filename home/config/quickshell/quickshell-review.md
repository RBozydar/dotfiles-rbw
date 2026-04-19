# Quickshell Audit Review

Audit date: 2026-04-13

Scope:

- Reviewed the current `home/config/quickshell/` tree, including QML modules, singleton services, shell/Python helpers, tests, docs, and local test scripts.
- Did not modify runtime shell code.

## Verification Notes

- `python3 -m py_compile home/config/quickshell/scripts/fetch_meteo_forecast.py` passed.
- `sh -n` on the main shell helpers passed.
- The local test helpers and test files are in active churn and were treated as out of scope after initial inspection.

## Findings

### 1. Medium: notification expiry handling is almost certainly wrong for short timeouts

Files:

- `services/notifications-store.js:13-20`
- `services/Notifications.qml:17-20`

Why it matters:

- `popupTimeoutMs()` treats any positive timeout `<= 1000` as seconds and multiplies it by `1000`.
- If Quickshell follows the usual desktop-notification timeout semantics, `expireTimeout` is already in milliseconds.
- That means a `250ms` timeout becomes `250000ms`, and exactly `1000ms` becomes `1000000ms`.

Impact:

- Popup lifetime can be off by orders of magnitude for apps that send short explicit timeouts.
- The notification queue can feel sticky or broken in exactly the cases where senders tried to keep it brief.

### 2. Medium: the daemon advertises notification actions, but the shell does not actually preserve or invoke them

Files:

- `services/Notifications.qml:45-58`
- `services/Notifications.qml:70-79`
- `services/notifications-store.js:23-35`

Why it matters:

- `NotificationServer` sets `actionsSupported: true`.
- The stored history entry drops `notification.actions` entirely.
- Clicking a notification does not invoke a default action; it only marks the entry read and runs a Ghostty/Codex-specific focus helper for a narrow special case.

Impact:

- Senders can believe actionable notifications are supported when they are not.
- The UI exposes clickability, but for most notifications the click path is effectively a no-op.

### 3. Medium: fallback screen selection is using `ObjectModel` semantics against `Quickshell.screens`

Files:

- `modules/notifications/NotificationPopups.qml:14`
- `modules/osd/VolumeOsd.qml:23`

Why it matters:

- The Quickshell skill reference documents `Quickshell.screens` as `list<QScreen>`.
- Both files fall back to `Quickshell.screens.values[0]`, which is an `ObjectModel` pattern.
- If `Hyprland.focusedMonitor` is briefly unavailable during startup or reload, the fallback path is the one that runs.

Impact:

- This is a startup/reload race hazard in exactly the code that should be most resilient.
- It may work most of the time if the focused-monitor binding resolves first, but the fallback itself is brittle.

### 4. Medium: the dark/light mode toggle is exposed as a setting, but it is not persisted anywhere

Files:

- `Theme.qml:5-34`
- `components/ControlCenterPopup.qml:84-92`

Why it matters:

- The control center presents dark/light mode as a user-toggleable setting.
- The backing state is just `Theme.darkMode` in a singleton with a hardcoded default of `true`.
- There is no `FileView`, `JsonAdapter`, or other persistence path for that preference.

Impact:

- Any Quickshell reload or restart resets the theme mode.
- This is especially noticeable in a config with `settings.watchFiles: true`, where normal editing resets the user's selection.

### 5. Low: `weather.sh` emits invalid fallback JSON if the location name contains quotes or newlines

Files:

- `scripts/weather.sh:9-15`

Why it matters:

- The fallback path prints raw `$name` directly into JSON with `printf`.
- A location like `He said "north"` produces malformed JSON.
- This only shows up when Python is missing or the fetch fails, which is exactly when the fallback needs to be robust.

Impact:

- Weather failure handling can cascade into a parse failure in `services/Weather.qml`.
- The shell can keep stale data or log parse errors instead of showing a clean unavailable state.

## Strengths

- The bar popup architecture is sound: one shared `BarPopoutState`, one shared `BarPopoutSurface`, and real hovered chip geometry rather than per-chip `PanelWindow`s.
- The weather stack is sensibly layered: fetch/cache logic in Python, shell wrapper for Quickshell integration, normalization in `services/Weather.qml`, and presentation in the bar/popout/chart files.
- The notification logic is moving in a good direction by factoring shared state transitions into `services/notifications-store.js`.
- `scripts/restart-quickshell.sh` follows the local AGENTS guidance and resolves the live `HYPRLAND_INSTANCE_SIGNATURE` from the runtime socket tree instead of trusting inherited env.

## Skill Feedback / Upstream Contribution

Review of `QUICKSHELL_SKILL_FEEDBACK.md`:

- The existing feedback is valid and worth contributing back to `~/repo/rbw-claude-code`.
- The current Quickshell skill still does not foreground the "shared popout state + shared popout surface + hovered target geometry" pattern strongly enough for interactive top bars.
- The data-heavy widget feedback is also justified: this shell uses exactly the kind of `Process`/script/cache/service/`Canvas` pipeline that newer Quickshell users run into quickly.

Recommended upstream additions:

- Add an explicit section for interactive bar popouts:
  shared popup state, one popup surface, real hovered target geometry, hover bridge region, centralized close timer, and why per-chip `PanelWindow`s are the wrong default.
- Add a concrete data-heavy widget pattern:
  external fetcher, cached normalized payload, singleton service shaping data for QML, and `Canvas`/custom chart rendering for weather or metrics.
- Clarify that `Quickshell.screens` is not an `ObjectModel` like `Hyprland.workspaces`, so `.values` should not be the default mental model.

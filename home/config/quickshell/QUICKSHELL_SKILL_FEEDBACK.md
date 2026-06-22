# Quickshell Skill Feedback

- The reference-repo mapping was the most useful part of the skill. It made it easy to steal the right patterns from Caelestia and `ii` instead of inventing new popup behavior.
- The best-practices note about `readonly property`, `required property`, and splitting large QML files lined up well with the refactor work on the bar.
- The skill would be stronger with one explicit section on interactive bar popouts:
  per-widget `PanelWindow` hover popups are the wrong default for sliders and toggles, and a same-window shared surface should be recommended early.
- A short example of "shared popout state + shared surface + hovered target geometry" for top bars would help more than generic popup references.
- A small section on data-heavy widgets would help too:
  `Process` + cached script fetchers + `Canvas` charts is a useful Quickshell pattern, and weather/radar/metrics widgets run into it quickly.

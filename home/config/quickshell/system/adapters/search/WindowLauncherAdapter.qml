import "./window-launcher-model.js" as WindowLauncherModel
import QtQml
import Quickshell

Scope {
    id: root

    property bool enabled: true
    property int resultLimit: 24
    property string focusCommand: "window_switcher.focus"
    property var windowSwitcherState: null

    function snapshot(): var {
        const state = windowSwitcherState && typeof windowSwitcherState === "object" && !Array.isArray(windowSwitcherState) ? windowSwitcherState : {};

        return {
            open: state.open === true,
            focusedAddress: String(state.focusedAddress === undefined ? "" : state.focusedAddress),
            revision: Number(state.revision === undefined ? 0 : state.revision),
            entries: Array.isArray(state.entries) ? state.entries : []
        };
    }

    function search(command): var {
        if (!enabled)
            return [];

        const payload = command && command.payload ? command.payload : {};
        const query = payload.query === undefined ? "" : String(payload.query);
        return WindowLauncherModel.searchWindowSnapshot(snapshot(), query, resultLimit, {
            focusCommand: root.focusCommand
        });
    }

    function describe(): var {
        const state = snapshot();
        return {
            kind: "adapter.search.window_launcher",
            integrationId: "launcher.windows",
            dependencyClass: "local_runtime",
            dataSensitivity: "local_window_titles",
            effectType: "focus_window",
            latencyExpectation: "interactive",
            enabled: root.enabled,
            available: true,
            ready: Array.isArray(state.entries),
            degraded: false,
            reasonCode: "",
            revision: Number(state.revision),
            open: state.open === true,
            focusedAddress: String(state.focusedAddress),
            entryCount: Array.isArray(state.entries) ? state.entries.length : 0,
            lastError: ""
        };
    }
}

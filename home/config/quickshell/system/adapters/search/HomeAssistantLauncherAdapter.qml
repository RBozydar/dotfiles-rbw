import "./homeassistant-launcher-model.js" as HomeAssistantLauncherModel
import Quickshell
import QtQml

Scope {
    id: root

    property bool enabled: false
    property int resultLimit: 30
    property var homeAssistantState: null
    property string toggleLightCommand: "homeassistant.toggle_light"
    property string turnOnLightCommand: "homeassistant.turn_on_light"
    property string turnOffLightCommand: "homeassistant.turn_off_light"
    property string activateSceneCommand: "homeassistant.activate_scene"

    function snapshot(): var {
        if (!homeAssistantState || typeof homeAssistantState !== "object")
            return {
                lights: [],
                scenes: [],
                available: false,
                ready: false,
                degraded: true,
                reasonCode: "source_unavailable",
                lastUpdatedAt: "",
                lastError: "Home Assistant integration source is unavailable"
            };

        return {
            lights: Array.isArray(homeAssistantState.lights) ? homeAssistantState.lights : [],
            scenes: Array.isArray(homeAssistantState.scenes) ? homeAssistantState.scenes : [],
            available: homeAssistantState.available === true,
            ready: homeAssistantState.ready === true,
            degraded: homeAssistantState.degraded === true,
            reasonCode: String(homeAssistantState.reasonCode === undefined ? "" : homeAssistantState.reasonCode),
            lastUpdatedAt: String(homeAssistantState.lastUpdatedAt === undefined ? "" : homeAssistantState.lastUpdatedAt),
            lastError: String(homeAssistantState.lastError === undefined ? "" : homeAssistantState.lastError)
        };
    }

    function search(command): var {
        if (!enabled)
            return [];

        const payload = command && command.payload ? command.payload : {};
        const query = payload.query === undefined ? "" : String(payload.query);
        return HomeAssistantLauncherModel.searchHomeAssistantSnapshot(snapshot(), query, resultLimit, {
            toggleLightCommand: root.toggleLightCommand,
            turnOnLightCommand: root.turnOnLightCommand,
            turnOffLightCommand: root.turnOffLightCommand,
            activateSceneCommand: root.activateSceneCommand
        });
    }

    function describe(): var {
        const state = snapshot();
        return {
            kind: "adapter.search.homeassistant_launcher",
            integrationId: "launcher.home_assistant",
            dependencyClass: "network_service",
            dataSensitivity: "remote_account",
            effectType: "state_mutation",
            latencyExpectation: "interactive",
            enabled: root.enabled,
            available: state.available,
            ready: state.ready,
            degraded: state.degraded,
            reasonCode: state.reasonCode,
            lastUpdatedAt: state.lastUpdatedAt,
            lightCount: Array.isArray(state.lights) ? state.lights.length : 0,
            sceneCount: Array.isArray(state.scenes) ? state.scenes.length : 0,
            lastError: state.lastError
        };
    }
}

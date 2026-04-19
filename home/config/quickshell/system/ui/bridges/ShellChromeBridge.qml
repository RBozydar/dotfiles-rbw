import "../../adapters/homeassistant" as HomeAssistantAdapters
import QtQml
import Quickshell
import Quickshell.Hyprland
import qs.services

QtObject {
    id: root

    property bool homeAssistantEnabled: false

    readonly property var audio: Audio
    readonly property var media: Media
    readonly property var connectivity: Connectivity
    readonly property var systemStats: SystemStats
    readonly property var weather: Weather
    readonly property var homeAssistantAdapter: HomeAssistantAdapters.HomeAssistantAdapter {
        enabled: root.homeAssistantEnabled
    }
    readonly property var homeAssistant: homeAssistantAdapter
    readonly property var nightMode: NightMode
    readonly property var brightness: Brightness
    readonly property var brightnessMonitors: Brightness.monitors
    readonly property var focusedScreen: Quickshell.screens.find(screen => screen.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens.values[0] ?? null

    function brightnessMonitorForScreen(screen) {
        return Brightness.getMonitorForScreen(screen);
    }

    function describe() {
        return {
            kind: "shell.chrome.bridge",
            hasFocusedScreen: root.focusedScreen !== null,
            hasAudioSink: !!root.audio?.sink,
            networkConnected: !!root.connectivity?.networkConnected,
            weatherAvailable: !!root.weather?.available,
            homeAssistantEnabled: !!root.homeAssistant?.enabled,
            homeAssistantConfigured: !!root.homeAssistant?.configured,
            homeAssistantReady: !!root.homeAssistant?.ready
        };
    }
}

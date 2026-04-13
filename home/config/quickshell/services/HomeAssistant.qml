pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool configured: false
    property bool available: false
    property bool refreshing: false
    property bool refreshQueued: false
    property var queuedActionArgs: null
    property string error: ""
    property var lights: []

    readonly property bool busy: actionRunner.running
    readonly property int lightCount: Array.isArray(root.lights) ? root.lights.length : 0
    readonly property int activeLightCount: Array.isArray(root.lights) ? root.lights.filter(light => light?.isOn ?? false).length : 0
    readonly property bool anyOn: root.activeLightCount > 0
    readonly property string chipLabel: {
        if (!root.configured)
            return "";
        if (!root.available)
            return "ha";
        if (root.lightCount === 0)
            return "0";
        return `${root.activeLightCount}/${root.lightCount}`;
    }
    readonly property string summaryLabel: {
        if (!root.configured)
            return "Not configured";
        if (!root.available)
            return "Unavailable";
        if (root.lightCount === 0)
            return "No lights";
        if (root.activeLightCount === 0)
            return "All off";
        if (root.activeLightCount === root.lightCount)
            return "All on";
        return `${root.activeLightCount} of ${root.lightCount} on`;
    }

    function applyPayload(rawText): void {
        const text = rawText.trim();
        if (!text) {
            root.available = false;
            root.error = "Home Assistant returned no data";
            root.lights = [];
            return;
        }

        try {
            const payload = JSON.parse(text);
            root.configured = payload.configured ?? false;
            root.available = payload.available ?? false;
            root.error = payload.error ?? "";
            root.lights = Array.isArray(payload.lights) ? payload.lights : [];
        } catch (parseError) {
            root.available = false;
            root.error = `Home Assistant parse error: ${parseError}`;
            root.lights = [];
        }
    }

    function refresh(): void {
        if (fetcher.running) {
            root.refreshQueued = true;
            return;
        }

        root.refreshing = true;
        fetcher.running = true;
    }

    function runAction(args): void {
        if (actionRunner.running) {
            root.queuedActionArgs = args;
            return;
        }

        root.queuedActionArgs = null;
        root.error = "";
        actionRunner.exec(args);
    }

    function toggleLight(entityId): void {
        if (!entityId)
            return;

        root.runAction(["sh", Quickshell.shellPath("scripts/homeassistant.sh"), "action", "toggle", entityId]);
    }

    function setBrightness(entityId, brightnessPercent): void {
        if (!entityId)
            return;

        root.runAction(["sh", Quickshell.shellPath("scripts/homeassistant.sh"), "set-brightness", entityId, `${Math.round(brightnessPercent)}`]);
    }

    function setColorTemp(entityId, colorTempKelvin): void {
        if (!entityId)
            return;

        root.runAction(["sh", Quickshell.shellPath("scripts/homeassistant.sh"), "set-color-temp", entityId, `${Math.round(colorTempKelvin)}`]);
    }

    Component.onCompleted: root.refresh()

    Timer {
        interval: 20000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: refreshAfterAction

        interval: 900
        repeat: false
        onTriggered: root.refresh()
    }

    Process {
        id: fetcher

        command: ["sh", Quickshell.shellPath("scripts/homeassistant.sh"), "lights"]
        workingDirectory: Quickshell.shellDir

        stdout: StdioCollector {
            id: fetchCollector
        }

        stderr: StdioCollector {
            id: fetchErrors
        }

        onExited: {
            root.refreshing = false;

            const stdoutText = fetchCollector.text ?? "";
            const stderrText = (fetchErrors.text ?? "").trim();

            if (stdoutText.trim().length > 0) {
                root.applyPayload(stdoutText);
            } else {
                root.available = false;
                root.error = stderrText.length > 0 ? stderrText : "Home Assistant refresh failed";
                root.lights = [];
            }

            if (root.refreshQueued) {
                root.refreshQueued = false;
                Qt.callLater(root.refresh);
            }
        }
    }

    Process {
        id: actionRunner

        workingDirectory: Quickshell.shellDir

        stdout: StdioCollector {
            id: actionCollector
        }

        stderr: StdioCollector {
            id: actionErrors
        }

        onExited: {
            const stdoutText = (actionCollector.text ?? "").trim();
            const stderrText = (actionErrors.text ?? "").trim();

            if (stdoutText.length > 0) {
                try {
                    const payload = JSON.parse(stdoutText);
                    if (!(payload.success ?? false))
                        root.error = payload.error ?? "Home Assistant action failed";
                } catch (parseError) {
                    root.error = `Home Assistant action parse error: ${parseError}`;
                }
            } else if (stderrText.length > 0) {
                root.error = stderrText;
            }

            if (root.queuedActionArgs !== null) {
                const nextArgs = root.queuedActionArgs;
                root.queuedActionArgs = null;
                Qt.callLater(() => {
                    root.runAction(nextArgs);
                });
            } else {
                refreshAfterAction.restart();
            }
        }
    }
}

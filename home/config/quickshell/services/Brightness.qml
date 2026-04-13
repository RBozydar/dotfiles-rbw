pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property list<var> ddcMonitors: []
    readonly property list<Monitor> monitors: variants.instances

    function getMonitorForScreen(screen: ShellScreen): var {
        return root.monitors.find(monitor => monitor.modelData === screen) ?? null;
    }

    function refreshDetection(): void {
        if (!ddcDetect.running)
            ddcDetect.running = true;
    }

    function refreshMonitor(screen: ShellScreen): void {
        root.getMonitorForScreen(screen)?.refresh();
    }

    Component.onCompleted: refreshDetection()
    onMonitorsChanged: refreshDetection()

    Variants {
        id: variants

        model: Quickshell.screens

        Monitor {}
    }

    Process {
        id: ddcDetect

        command: ["ddcutil", "detect", "--brief"]

        stdout: StdioCollector {
            onStreamFinished: {
                const displays = text.trim().split("\n\n").filter(block => block.startsWith("Display "));
                root.ddcMonitors = displays.map(block => {
                    const connectorMatch = block.match(/DRM connector:\s+(.*)/);
                    const busMatch = block.match(/I2C bus:\s+\/dev\/i2c-([0-9]+)/);

                    return {
                        connector: connectorMatch ? connectorMatch[1].replace(/^card\d+-/, "") : "",
                        busNum: busMatch ? busMatch[1] : ""
                    };
                }).filter(entry => entry.connector.length > 0 && entry.busNum.length > 0);
            }
        }
    }

    component Monitor: QtObject {
        id: monitor

        required property ShellScreen modelData

        readonly property string screenName: modelData?.name ?? ""
        readonly property var ddcInfo: root.ddcMonitors.find(entry => entry.connector === screenName) ?? null
        readonly property bool available: ddcInfo !== null
        readonly property string busNum: ddcInfo?.busNum ?? ""
        property int maxBrightness: 100
        property real brightness: 0
        property real queuedBrightness: NaN
        readonly property int brightnessPercent: Math.round(brightness * 100)

        function changeBy(delta): void {
            monitor.setBrightness(monitor.brightness + delta);
        }

        function setBrightness(value: real): void {
            if (!monitor.available)
                return;

            const clamped = Math.max(0, Math.min(1, value));
            if (Math.round(monitor.brightness * 100) === Math.round(clamped * 100) && !isNaN(monitor.brightness))
                return;

            if (setProc.running) {
                monitor.queuedBrightness = clamped;
                return;
            }

            monitor.brightness = clamped;
            monitor.queuedBrightness = NaN;

            const rawValue = Math.max(1, Math.round(clamped * monitor.maxBrightness));
            setProc.exec(["ddcutil", "-b", monitor.busNum, "--noverify", "--enable-dynamic-sleep", "--sleep-multiplier=0.05", "setvcp", "10", `${rawValue}`]);
        }

        function refresh(): void {
            if (!monitor.available)
                return;

            if (!initProc.running)
                initProc.running = true;
        }

        onBusNumChanged: monitor.refresh()
        Component.onCompleted: monitor.refresh()

        readonly property Timer refreshAfterSet: Timer {
            interval: 450
            repeat: false
            onTriggered: monitor.refresh()
        }

        readonly property Process initProc: Process {
            command: ["ddcutil", "-b", monitor.busNum, "--enable-dynamic-sleep", "--sleep-multiplier=0.05", "getvcp", "10", "--brief"]

            stdout: SplitParser {
                onRead: data => {
                    const parts = data.trim().split(/\s+/);
                    if (parts.length < 5)
                        return;

                    const current = Number(parts[3]);
                    const maximum = Number(parts[4]);

                    if (!isNaN(current) && !isNaN(maximum) && maximum > 0) {
                        monitor.maxBrightness = maximum;
                        monitor.brightness = current / maximum;
                    }
                }
            }
        }

        readonly property Process setProc: Process {
            onExited: {
                if (!isNaN(monitor.queuedBrightness)) {
                    const nextBrightness = monitor.queuedBrightness;
                    monitor.queuedBrightness = NaN;
                    monitor.setBrightness(nextBrightness);
                } else {
                    monitor.refreshAfterSet.restart();
                }
            }
        }
    }
}

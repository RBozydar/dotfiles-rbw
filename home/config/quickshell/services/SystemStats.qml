pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int cpuUsage: 0
    property int ramUsage: 0
    property var gpuUsage: null
    property var gpuMemoryUsage: null
    property var cpuTemp: null
    property var gpuTemp: null
    property var ramUsedGiB: null
    property var ramTotalGiB: null
    property var gpuMemoryUsedMiB: null
    property var gpuMemoryTotalMiB: null

    function refresh(): void {
        if (!statsProcess.running)
            statsProcess.running = true;
    }

    function formatMetric(value): string {
        return value === null || value === undefined ? "--" : `${value}%`;
    }

    function formatCompactTemperature(value): string {
        return value === null || value === undefined ? "--" : `${value}C`;
    }

    function formatTemperature(value): string {
        return value === null || value === undefined ? "--" : `${value}°C`;
    }

    function formatGiB(value): string {
        return value === null || value === undefined ? "--" : `${value.toFixed(1)} GiB`;
    }

    function formatMiB(value): string {
        return value === null || value === undefined ? "--" : `${Math.round(value)} MiB`;
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: statsProcess

        command: ["sh", Quickshell.shellPath("scripts/system-stats.sh")]
        workingDirectory: Quickshell.shellDir

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (!line)
                    return;

                try {
                    const payload = JSON.parse(line);
                    root.cpuUsage = payload.cpu ?? 0;
                    root.ramUsage = payload.ram ?? 0;
                    root.gpuUsage = payload.gpu ?? null;
                    root.gpuMemoryUsage = payload.gpuMemory ?? null;
                    root.cpuTemp = payload.cpuTemp ?? null;
                    root.gpuTemp = payload.gpuTemp ?? null;
                    root.ramUsedGiB = payload.ramUsedGiB ?? null;
                    root.ramTotalGiB = payload.ramTotalGiB ?? null;
                    root.gpuMemoryUsedMiB = payload.gpuMemoryUsedMiB ?? null;
                    root.gpuMemoryTotalMiB = payload.gpuMemoryTotalMiB ?? null;
                } catch (error) {
                    console.log(`system-stats parse error: ${error}`);
                }
            }
        }
    }
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool available: false
    property bool active: false
    property int temperature: 4500

    function refresh(): void {
        if (!probe.running)
            probe.running = true;
    }

    function toggle(): void {
        if (!root.available)
            return;

        Quickshell.execDetached({
            command: ["sh", "-c", `pidof hyprsunset >/dev/null 2>&1 && pkill hyprsunset || hyprsunset -t ${root.temperature}`],
            workingDirectory: Quickshell.shellDir
        });
        root.refresh();
        refreshLater.restart();
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 8000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: refreshLater

        interval: 900
        repeat: false
        onTriggered: root.refresh()
    }

    Process {
        id: probe

        command: ["sh", "-c", "if ! command -v hyprsunset >/dev/null 2>&1; then echo unavailable; elif pidof hyprsunset >/dev/null 2>&1; then echo on; else echo off; fi"]

        stdout: SplitParser {
            onRead: data => {
                const state = data.trim();
                root.available = state !== "unavailable";
                root.active = state === "on";
            }
        }
    }
}

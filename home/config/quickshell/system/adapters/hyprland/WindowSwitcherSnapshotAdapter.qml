import "window-switcher-snapshot-adapter.js" as WindowSnapshotModel
import QtQml
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Scope {
    id: root

    property int eventDebounceMs: 40
    property string clientsRawText: "[]"
    property string activeWindowRawText: "{}"
    property bool pendingClientsRefresh: false
    property bool pendingActiveWindowRefresh: false
    readonly property var snapshot: WindowSnapshotModel.createSnapshotFromRaw(root.clientsRawText, root.activeWindowRawText)

    function requestRefresh(refreshClients, refreshActiveWindow) {
        root.pendingClientsRefresh = root.pendingClientsRefresh || refreshClients === true;
        root.pendingActiveWindowRefresh = root.pendingActiveWindowRefresh || refreshActiveWindow === true;

        if (Number(root.eventDebounceMs) <= 0) {
            flushPendingRefresh();
            return;
        }

        eventDebounceTimer.interval = Number(root.eventDebounceMs);
        eventDebounceTimer.restart();
    }

    function flushPendingRefresh() {
        if (root.pendingClientsRefresh && !clientsProcess.running) {
            root.pendingClientsRefresh = false;
            clientsProcess.running = true;
        }

        if (root.pendingActiveWindowRefresh && !activeWindowProcess.running) {
            root.pendingActiveWindowRefresh = false;
            activeWindowProcess.running = true;
        }
    }

    function refresh() {
        requestRefresh(true, true);
    }

    Process {
        id: clientsProcess

        command: ["hyprctl", "clients", "-j"]
        running: false

        stdout: StdioCollector {
            id: clientsCollector

            onStreamFinished: {
                root.clientsRawText = clientsCollector.text || "[]";
                root.flushPendingRefresh();
            }
        }
    }

    Process {
        id: activeWindowProcess

        command: ["hyprctl", "activewindow", "-j"]
        running: false

        stdout: StdioCollector {
            id: activeWindowCollector

            onStreamFinished: {
                root.activeWindowRawText = activeWindowCollector.text || "{}";
                root.flushPendingRefresh();
            }
        }
    }

    Timer {
        id: eventDebounceTimer

        interval: 40
        repeat: false
        onTriggered: root.flushPendingRefresh()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            const eventName = `${event?.name ?? event?.event ?? event?.type ?? ""}`;

            if (eventName === "openwindow" || eventName === "closewindow" || eventName === "movewindow" || eventName === "movewindowv2" || eventName === "windowtitle") {
                root.requestRefresh(true, true);
                return;
            }

            if (eventName === "activewindow" || eventName === "activewindowv2" || eventName === "workspace" || eventName === "workspacev2" || eventName === "focusedmon" || eventName === "focusedmonv2") {
                root.requestRefresh(false, true);
                return;
            }
        }
    }

    Component.onCompleted: {
        root.requestRefresh(true, true);
        root.flushPendingRefresh();
    }
}

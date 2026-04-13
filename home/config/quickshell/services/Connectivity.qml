pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string networkLabel: "offline"
    property string networkKind: "offline"
    property bool networkConnected: false
    property bool wifiAvailable: false
    property bool wifiEnabled: false
    property string wifiDevice: ""
    property bool ethernetAvailable: false
    property bool ethernetConnected: false
    property string ethernetDevice: ""
    property string ethernetLabel: "unavailable"
    property string networkUpRate: "0B"
    property string networkDownRate: "0B"
    property string bluetoothLabel: "off"
    property bool bluetoothAvailable: false
    property bool bluetoothEnabled: false
    property int bluetoothCount: 0

    function runCommand(command): void {
        Quickshell.execDetached({
            command: command,
            workingDirectory: Quickshell.shellDir
        });
        refresh();
        refreshLater.restart();
    }

    function toggleWifi(): void {
        if (root.wifiAvailable)
            runCommand(["nmcli", "radio", "wifi", root.wifiEnabled ? "off" : "on"]);
    }

    function toggleEthernet(): void {
        if (root.ethernetAvailable && root.ethernetDevice.length > 0) {
            runCommand(["nmcli", "device", root.ethernetConnected ? "disconnect" : "connect", root.ethernetDevice]);
        }
    }

    function toggleBluetooth(): void {
        if (root.bluetoothAvailable)
            runCommand(["bluetoothctl", "power", root.bluetoothEnabled ? "off" : "on"]);
    }

    function refresh(): void {
        if (!probe.running)
            probe.running = true;
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: refreshLater

        interval: 1400
        repeat: false
        onTriggered: root.refresh()
    }

    Process {
        id: probe

        command: ["sh", Quickshell.shellPath("scripts/connectivity-status.sh")]
        workingDirectory: Quickshell.shellDir

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (!line)
                    return;

                try {
                    const payload = JSON.parse(line);
                    root.networkLabel = payload.networkLabel ?? "offline";
                    root.networkKind = payload.networkKind ?? "offline";
                    root.networkConnected = payload.networkConnected ?? false;
                    root.wifiAvailable = payload.wifiAvailable ?? false;
                    root.wifiEnabled = payload.wifiEnabled ?? false;
                    root.wifiDevice = payload.wifiDevice ?? "";
                    root.ethernetAvailable = payload.ethernetAvailable ?? false;
                    root.ethernetConnected = payload.ethernetConnected ?? false;
                    root.ethernetDevice = payload.ethernetDevice ?? "";
                    root.ethernetLabel = payload.ethernetLabel ?? "unavailable";
                    root.networkUpRate = payload.networkUpRate ?? "0B";
                    root.networkDownRate = payload.networkDownRate ?? "0B";
                    root.bluetoothLabel = payload.bluetoothLabel ?? "off";
                    root.bluetoothAvailable = payload.bluetoothAvailable ?? false;
                    root.bluetoothEnabled = payload.bluetoothEnabled ?? false;
                    root.bluetoothCount = payload.bluetoothCount ?? 0;
                } catch (error) {
                    console.log(`connectivity parse error: ${error}`);
                }
            }
        }
    }
}

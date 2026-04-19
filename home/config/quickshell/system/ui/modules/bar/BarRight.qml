import QtQuick
import qs
import "../../primitives" as BarPrimitives

Item {
    id: root

    required property var shell
    required property var screen
    required property var chromeBridge
    required property var notificationsBridge

    property var brightnessMonitor: null
    property var runCommand
    readonly property int notificationUnreadCount: notificationsBridge ? Number(notificationsBridge.unreadCount) : 0
    readonly property var audioState: root.chromeBridge ? root.chromeBridge.audio : null
    readonly property var mediaState: root.chromeBridge ? root.chromeBridge.media : null
    readonly property var connectivityState: root.chromeBridge ? root.chromeBridge.connectivity : null
    readonly property var systemStatsState: root.chromeBridge ? root.chromeBridge.systemStats : null
    readonly property var homeAssistantState: root.chromeBridge ? root.chromeBridge.homeAssistant : null

    readonly property alias mediaChip: mediaChip
    readonly property alias audioChip: audioChip
    readonly property alias brightnessChip: brightnessChip
    readonly property alias homeChip: homeChip
    readonly property alias resourcesChip: resourcesChip
    readonly property alias networkChip: networkChip
    readonly property alias bluetoothChip: bluetoothChip
    readonly property alias launcherChip: launcherChip
    readonly property alias notificationChip: notificationChip
    readonly property Item hoveredControlCenterTarget: audioChip.hovered ? audioChip : (brightnessChip.visible && brightnessChip.hovered ? brightnessChip : (networkChip.hovered ? networkChip : (bluetoothChip.hovered ? bluetoothChip : null)))
    readonly property bool controlCenterHovered: hoveredControlCenterTarget !== null

    implicitWidth: rightRow.implicitWidth
    implicitHeight: rightRow.implicitHeight

    Row {
        id: rightRow

        anchors.centerIn: parent
        spacing: Theme.gap

        BarPrimitives.StatusChip {
            id: mediaChip

            visible: root.mediaState ? root.mediaState.available : false
            icon: root.mediaState && root.mediaState.playing ? "󰏤" : ""
            accent: Theme.secondary
            label: root.mediaState ? `${root.mediaState.title}${root.mediaState.artist.length > 0 ? ` • ${root.mediaState.artist}` : ""}` : "No media"
            maximumLabelWidth: 190
            onClicked: {
                if (root.mediaState)
                    root.mediaState.raise();
            }
        }

        BarPrimitives.StatusChip {
            id: audioChip

            icon: root.audioState && root.audioState.muted ? "󰖁" : (root.audioState && root.audioState.volumePercent < 34 ? "" : (root.audioState && root.audioState.volumePercent < 67 ? "" : ""))
            accent: Theme.primary
            label: root.audioState && root.audioState.muted ? "muted" : `${root.audioState ? root.audioState.volumePercent : 0}%`
            onWheelUp: {
                if (root.audioState)
                    root.audioState.setVolume(root.audioState.volumePercent + 5);
            }
            onWheelDown: {
                if (root.audioState)
                    root.audioState.setVolume(root.audioState.volumePercent - 5);
            }
            onClicked: {
                if (root.audioState)
                    root.audioState.toggleMute();
            }
        }

        BarPrimitives.StatusChip {
            id: brightnessChip

            visible: root.brightnessMonitor?.available ?? false
            icon: "󰃞"
            accent: Theme.tertiary
            label: `${root.brightnessMonitor?.brightnessPercent ?? "--"}%`
            onWheelUp: root.brightnessMonitor?.changeBy(0.05)
            onWheelDown: root.brightnessMonitor?.changeBy(-0.05)
        }

        BarPrimitives.StatusChip {
            id: homeChip

            visible: root.homeAssistantState ? root.homeAssistantState.configured : false
            icon: !root.homeAssistantState || !root.homeAssistantState.available ? "󰔎" : (root.homeAssistantState.anyOn ? "󰖨" : "󰖧")
            accent: !root.homeAssistantState || !root.homeAssistantState.available ? Theme.tertiary : (root.homeAssistantState.anyOn ? Theme.tertiary : Theme.roleOnSurfaceVariant)
            active: homeChip.hovered
            label: root.homeAssistantState ? root.homeAssistantState.chipLabel : ""
            onClicked: {
                if (root.homeAssistantState)
                    root.homeAssistantState.refresh();
            }
        }

        BarPrimitives.StatusChip {
            icon: "󰣇"
            accent: Theme.tertiary
            label: ""
            onClicked: root.runCommand(["cachyos-hello"])
        }

        BarPrimitives.StatusChip {
            id: resourcesChip

            icon: ""
            accent: Theme.tertiary
            label: root.systemStatsState ? `CPU ${root.systemStatsState.cpuUsage}% ${root.systemStatsState.formatCompactTemperature(root.systemStatsState.cpuTemp)}  GPU ${root.systemStatsState.formatMetric(root.systemStatsState.gpuUsage)} ${root.systemStatsState.formatCompactTemperature(root.systemStatsState.gpuTemp)}  VRAM ${root.systemStatsState.formatMetric(root.systemStatsState.gpuMemoryUsage)}  RAM ${root.systemStatsState.ramUsage}%` : "CPU -- GPU -- VRAM -- RAM --"
            maximumLabelWidth: 400
            onClicked: root.runCommand(["ghostty", "-e", "btop"])
        }

        BarPrimitives.StatusChip {
            id: launcherChip

            icon: "󰍉"
            accent: Theme.primary
            active: root.shell.launcherOverlayOpen
            label: ""
            onClicked: root.shell.toggleLauncherOverlay()
        }

        BarPrimitives.StatusChip {
            id: networkChip

            icon: root.connectivityState && root.connectivityState.networkKind === "wifi" ? "" : (root.connectivityState && root.connectivityState.networkKind === "ethernet" ? "" : "")
            accent: root.connectivityState && root.connectivityState.networkConnected ? Theme.secondary : Theme.roleOnSurfaceVariant
            label: ` ${root.connectivityState ? root.connectivityState.networkUpRate : "0B"}   ${root.connectivityState ? root.connectivityState.networkDownRate : "0B"}`
            maximumLabelWidth: 180
            onClicked: root.runCommand(["nm-connection-editor"])
        }

        BarPrimitives.StatusChip {
            id: bluetoothChip

            icon: ""
            accent: root.connectivityState && root.connectivityState.bluetoothEnabled ? Theme.primary : Theme.roleOnSurfaceVariant
            label: ""
            onClicked: root.runCommand(["blueman-manager"])
        }

        BarPrimitives.TrayStrip {}

        BarPrimitives.StatusChip {
            id: notificationChip

            icon: ""
            accent: root.notificationUnreadCount > 0 ? Theme.tertiary : Theme.roleOnSurfaceVariant
            active: notificationChip.hovered
            label: ""
            badgeVisible: root.notificationUnreadCount > 0
            badgeText: root.notificationUnreadCount > 0 ? `${Math.min(root.notificationUnreadCount, 99)}` : ""
            badgeColor: Theme.tertiary
        }

        BarPrimitives.StatusChip {
            icon: ""
            accent: Theme.error
            label: ""
            onClicked: root.shell.toggleSessionOverlay()
        }
    }
}

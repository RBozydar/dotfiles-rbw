import QtQuick
import qs
import qs.components
import qs.services

Item {
    id: root

    required property var shell
    required property var screen

    property var brightnessMonitor: null
    property var runCommand

    readonly property alias mediaChip: mediaChip
    readonly property alias audioChip: audioChip
    readonly property alias brightnessChip: brightnessChip
    readonly property alias homeChip: homeChip
    readonly property alias resourcesChip: resourcesChip
    readonly property alias networkChip: networkChip
    readonly property alias bluetoothChip: bluetoothChip
    readonly property alias notificationChip: notificationChip
    readonly property Item hoveredControlCenterTarget: audioChip.hovered ? audioChip : (brightnessChip.visible && brightnessChip.hovered ? brightnessChip : (networkChip.hovered ? networkChip : (bluetoothChip.hovered ? bluetoothChip : null)))
    readonly property bool controlCenterHovered: hoveredControlCenterTarget !== null

    implicitWidth: rightRow.implicitWidth
    implicitHeight: rightRow.implicitHeight

    Row {
        id: rightRow

        anchors.centerIn: parent
        spacing: Theme.gap

        StatusChip {
            id: mediaChip

            visible: Media.available
            icon: Media.playing ? "󰏤" : ""
            accent: Theme.accentStrong
            label: `${Media.title}${Media.artist.length > 0 ? ` • ${Media.artist}` : ""}`
            maximumLabelWidth: 190
            onClicked: Media.raise()
        }

        StatusChip {
            id: audioChip

            icon: Audio.muted ? "󰖁" : (Audio.volumePercent < 34 ? "" : (Audio.volumePercent < 67 ? "" : ""))
            accent: Theme.success
            label: Audio.muted ? "muted" : `${Audio.volumePercent}%`
            onWheelUp: Audio.setVolume(Audio.volumePercent + 5)
            onWheelDown: Audio.setVolume(Audio.volumePercent - 5)
            onClicked: Audio.toggleMute()
        }

        StatusChip {
            id: brightnessChip

            visible: root.brightnessMonitor?.available ?? false
            icon: "󰃞"
            accent: Theme.warning
            label: `${root.brightnessMonitor?.brightnessPercent ?? "--"}%`
            onWheelUp: root.brightnessMonitor?.changeBy(0.05)
            onWheelDown: root.brightnessMonitor?.changeBy(-0.05)
        }

        StatusChip {
            id: homeChip

            visible: HomeAssistant.configured
            icon: !HomeAssistant.available ? "󰔎" : (HomeAssistant.anyOn ? "󰖨" : "󰖧")
            accent: !HomeAssistant.available ? Theme.warning : (HomeAssistant.anyOn ? Theme.warning : Theme.textMuted)
            active: homeChip.hovered
            label: HomeAssistant.chipLabel
            onClicked: HomeAssistant.refresh()
        }

        StatusChip {
            icon: "󰣇"
            accent: Theme.warning
            label: ""
            onClicked: root.runCommand(["cachyos-hello"])
        }

        StatusChip {
            id: resourcesChip

            icon: ""
            accent: Theme.warning
            label: `CPU ${SystemStats.cpuUsage}% ${SystemStats.formatCompactTemperature(SystemStats.cpuTemp)}  GPU ${SystemStats.formatMetric(SystemStats.gpuUsage)} ${SystemStats.formatCompactTemperature(SystemStats.gpuTemp)}  VRAM ${SystemStats.formatMetric(SystemStats.gpuMemoryUsage)}  RAM ${SystemStats.ramUsage}%`
            maximumLabelWidth: 400
            onClicked: root.runCommand(["ghostty", "-e", "btop"])
        }

        StatusChip {
            id: networkChip

            icon: Connectivity.networkKind === "wifi" ? "" : (Connectivity.networkKind === "ethernet" ? "" : "")
            accent: Connectivity.networkConnected ? Theme.accentStrong : Theme.textMuted
            label: ` ${Connectivity.networkUpRate}   ${Connectivity.networkDownRate}`
            maximumLabelWidth: 180
            onClicked: root.runCommand(["nm-connection-editor"])
        }

        StatusChip {
            id: bluetoothChip

            icon: ""
            accent: Connectivity.bluetoothEnabled ? Theme.accent : Theme.textMuted
            label: ""
            onClicked: root.runCommand(["blueman-manager"])
        }

        TrayStrip {
        }

        StatusChip {
            id: notificationChip

            icon: ""
            accent: Notifications.unreadCount > 0 ? Theme.warning : Theme.textMuted
            active: notificationChip.hovered
            label: ""
            badgeVisible: Notifications.unreadCount > 0
            badgeText: Notifications.unreadCount > 0 ? `${Math.min(Notifications.unreadCount, 99)}` : ""
            badgeColor: Theme.warning
        }

        StatusChip {
            icon: ""
            accent: Theme.danger
            label: ""
            onClicked: root.shell.toggleSessionOverlay()
        }
    }
}

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services

PanelWindow {
    id: root

    required property var shell

    property bool armed: false
    property bool open: false

    screen: Quickshell.screens.find(item => item.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens.values[0] ?? null
    visible: root.open && !shell.notificationCenterOpen && !shell.sessionOverlayOpen
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:volume-osd"

    anchors {
        top: true
        right: true
    }

    implicitWidth: 252
    implicitHeight: osdCard.implicitHeight + Theme.barOuterHeight + Theme.barMargin + 16

    function reveal(): void {
        if (!root.armed)
            return;

        root.open = true;
        hideTimer.restart();
    }

    Timer {
        interval: 600
        running: true
        repeat: false
        onTriggered: root.armed = true
    }

    Timer {
        id: hideTimer

        interval: 1600
        repeat: false
        onTriggered: root.open = false
    }

    Connections {
        target: Audio.sink?.audio ?? null

        function onVolumeChanged(): void {
            root.reveal();
        }

        function onMutedChanged(): void {
            root.reveal();
        }
    }

    Rectangle {
        id: osdCard

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Theme.barOuterHeight + Theme.barMargin + 8
        anchors.rightMargin: Theme.barMargin
        width: 236
        height: osdColumn.implicitHeight + (Theme.padding * 2)
        radius: Theme.radius
        color: Theme.panel
        border.width: 1
        border.color: Theme.border
        x: root.open ? 0 : 24
        opacity: root.open ? 1 : 0

        Behavior on x {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }

        Column {
            id: osdColumn

            anchors.fill: parent
            anchors.margins: Theme.padding
            spacing: 10

            RowLayout {
                width: parent.width
                spacing: 8

                Text {
                    text: Audio.muted ? "󰖁" : (Audio.volumePercent < 34 ? "" : (Audio.volumePercent < 67 ? "" : ""))
                    color: Audio.muted ? Theme.warning : Theme.success
                    font.family: Theme.fontSans
                    font.pixelSize: 16
                    font.weight: Font.Black
                }

                Text {
                    text: "Volume"
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }

                Text {
                    text: Audio.muted ? "muted" : `${Audio.volumePercent}%`
                    color: Audio.muted ? Theme.warning : Theme.success
                    font.family: Theme.fontMono
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
            }

            Rectangle {
                width: parent.width
                height: 14
                radius: 7
                color: Theme.chip
                border.width: 1
                border.color: Theme.border

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: Math.max(12, parent.width * Audio.volumeLevel)
                    radius: parent.radius
                    color: Audio.muted ? Theme.textMuted : Theme.success
                }
            }
        }
    }
}

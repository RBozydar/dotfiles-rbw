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
    property int bridgeHeight: 22
    property int bridgeOverlapIntoBar: 10
    property real slideDistance: 18

    readonly property int cardWidth: 276
    readonly property int cardHeight: osdColumn.implicitHeight + (Theme.padding * 2)

    screen: Quickshell.screens.find(item => item.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens.values[0] ?? null
    visible: root.open && !shell.sessionOverlayOpen
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:volume-osd"

    anchors {
        top: true
        left: true
        right: true
    }

    margins.top: Theme.barOuterHeight - Theme.barMargin - root.bridgeOverlapIntoBar

    implicitHeight: root.bridgeHeight + root.cardHeight
    mask: Region {
        item: bridge

        Region {
            item: cardClip
        }
    }

    function reveal(): void {
        if (!root.armed)
            return;

        root.open = true;
        hideTimer.restart();
        osdCard.revealed = false;
        Qt.callLater(() => {
            osdCard.revealed = root.open;
        });
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
        id: bridge

        visible: root.visible
        x: Math.round((root.width - width) / 2)
        y: 0
        width: 112
        height: root.bridgeHeight
        radius: Math.min(height / 2, Theme.chipRadius)
        color: Theme.panel
        border.width: 0
    }

    Item {
        id: cardClip

        visible: root.visible
        x: Math.round((root.width - root.cardWidth) / 2)
        y: root.bridgeHeight - 1
        width: root.cardWidth
        height: root.cardHeight
        clip: true

        Rectangle {
            id: osdCard

            property bool revealed: false

            width: parent.width
            height: parent.height
            y: revealed ? 0 : -root.slideDistance
            opacity: revealed ? 1 : 0
            radius: Theme.radius
            color: Theme.panel
            border.width: 1
            border.color: Theme.border

            Behavior on y {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 150
                }
            }

            Column {
                id: osdColumn

                anchors.fill: parent
                anchors.margins: Theme.padding
                spacing: 10

                RowLayout {
                    width: parent.width
                    spacing: 10

                    Text {
                        text: Audio.muted ? "󰖁" : (Audio.volumePercent < 34 ? "" : (Audio.volumePercent < 67 ? "" : ""))
                        color: Audio.muted ? Theme.warning : Theme.success
                        font.family: Theme.fontSans
                        font.pixelSize: 17
                        font.weight: Font.Black
                    }

                    Text {
                        text: "Volume"
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                    }

                    Text {
                        text: Audio.muted ? "muted" : `${Audio.volumePercent}%`
                        color: Audio.muted ? Theme.warning : Theme.success
                        font.family: Theme.fontMono
                        font.pixelSize: 14
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
                        width: Math.max(12, parent.width * Math.max(0, Math.min(1, Audio.volumeLevel)))
                        radius: parent.radius
                        color: Audio.muted ? Theme.textMuted : Theme.success
                    }
                }
            }
        }
    }
}

pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs

PanelWindow {
    id: root

    required property var shell
    required property var notificationsBridge
    readonly property int notificationsRevision: notificationsBridge ? Number(notificationsBridge.storeRevision) : 0
    readonly property var popupEntries: {
        const revision = notificationsRevision;
        return notificationsBridge ? notificationsBridge.popupList : [];
    }

    screen: Quickshell.screens.find(screen => screen.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens.values[0] ?? null
    visible: popupEntries.length > 0 && !shell.sessionOverlayOpen
    color: "transparent"
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay

    anchors {
        top: true
        right: true
    }

    implicitWidth: 392
    implicitHeight: popupColumn.implicitHeight + Theme.barOuterHeight + Theme.barMargin + 24

    Column {
        id: popupColumn

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: Theme.barOuterHeight + Theme.barMargin + 12
        anchors.rightMargin: Theme.barMargin
        spacing: Theme.gap

        Repeater {
            model: root.popupEntries

            Item {
                id: popupEntry

                required property var modelData

                width: 368
                height: popupCard.height
                property bool revealed: false

                Component.onCompleted: Qt.callLater(() => {
                    revealed = true;
                })

                Rectangle {
                    id: popupCard

                    width: parent.width
                    radius: Theme.radius
                    color: Theme.surface
                    border.width: 1
                    border.color: popupEntry.modelData.urgency === 2 ? Theme.error : Theme.outline
                    height: popupBody.visible ? popupHeader.implicitHeight + popupBody.implicitHeight + 34 : popupHeader.implicitHeight + 24
                    x: parent.revealed ? 0 : 28
                    opacity: parent.revealed ? 1 : 0

                    Behavior on x {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 160
                        }
                    }

                    Column {
                        id: popupHeader

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.padding
                        spacing: 8

                        RowLayout {
                            width: parent.width

                            Text {
                                text: popupEntry.modelData.appName
                                color: Theme.primary
                                font.family: Theme.fontSans
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: Qt.formatDateTime(new Date(popupEntry.modelData.timestamp), "hh:mm:ss")
                                color: Theme.onSurfaceVariant
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                            }
                        }

                        Text {
                            text: popupEntry.modelData.summary
                            color: Theme.onSurface
                            font.family: Theme.fontSans
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        }
                    }

                    Text {
                        id: popupBody

                        visible: popupEntry.modelData.body.length > 0
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: popupHeader.bottom
                        anchors.leftMargin: Theme.padding
                        anchors.rightMargin: Theme.padding
                        text: popupEntry.modelData.body
                        color: Theme.onSurfaceVariant
                        font.family: Theme.fontSans
                        font.pixelSize: 13
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        textFormat: Text.PlainText
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (root.notificationsBridge)
                                root.notificationsBridge.activateEntry(popupEntry.modelData.key);
                        }
                    }
                }
            }
        }
    }
}

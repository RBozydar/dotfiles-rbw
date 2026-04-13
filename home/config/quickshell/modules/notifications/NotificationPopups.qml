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

    screen: Quickshell.screens.find(screen => screen.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens.values[0] ?? null
    visible: Notifications.popupList.length > 0 && !shell.sessionOverlayOpen
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
            model: Notifications.popupList

            Item {
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
                    color: Theme.panel
                    border.width: 1
                    border.color: modelData.urgency === 2 ? Theme.danger : Theme.border
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
                                text: modelData.appName
                                color: Theme.accent
                                font.family: Theme.fontSans
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: Qt.formatDateTime(new Date(modelData.timestamp), "hh:mm:ss")
                                color: Theme.textMuted
                                font.family: Theme.fontMono
                                font.pixelSize: 11
                            }
                        }

                        Text {
                            text: modelData.summary
                            color: Theme.text
                            font.family: Theme.fontSans
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        }
                    }

                    Text {
                        id: popupBody

                        visible: modelData.body.length > 0
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: popupHeader.bottom
                        anchors.leftMargin: Theme.padding
                        anchors.rightMargin: Theme.padding
                        text: modelData.body
                        color: Theme.textMuted
                        font.family: Theme.fontSans
                        font.pixelSize: 13
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        textFormat: Text.PlainText
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: Notifications.activateEntry(modelData.key)
                    }
                }
            }
        }
    }
}

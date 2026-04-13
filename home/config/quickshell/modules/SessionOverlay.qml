import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs

Variants {
    id: root

    required property var shell

    model: Quickshell.screens

    PanelWindow {
        required property var modelData

        readonly property var actions: [
            {
                title: "Lock",
                detail: "hyprlock",
                accent: Theme.accent,
                command: ["hyprlock"]
            },
            {
                title: "Suspend",
                detail: "systemctl suspend",
                accent: Theme.accentStrong,
                command: ["systemctl", "suspend"]
            },
            {
                title: "Logout",
                detail: "hyprctl dispatch exit",
                accent: Theme.warning,
                command: ["hyprctl", "dispatch", "exit"]
            },
            {
                title: "Reboot",
                detail: "systemctl reboot",
                accent: Theme.warning,
                command: ["systemctl", "reboot"]
            },
            {
                title: "Shutdown",
                detail: "systemctl poweroff",
                accent: Theme.danger,
                command: ["systemctl", "poweroff"]
            }
        ]

        screen: modelData
        visible: shell.sessionOverlayOpen

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        color: "transparent"
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        function runCommand(command): void {
            shell.closeSessionOverlay();
            Quickshell.execDetached({
                command: command,
                workingDirectory: Quickshell.workingDirectory
            });
        }

        Item {
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    shell.closeSessionOverlay();
                    event.accepted = true;
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: shell.closeSessionOverlay()
            }

            Rectangle {
                anchors.fill: parent
                color: "#a609111f"
            }

            Rectangle {
                width: 720
                height: 320
                anchors.centerIn: parent
                radius: Theme.radius
                color: Theme.panel
                border.width: 1
                border.color: Theme.border

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.padding + 6
                    spacing: Theme.gap + 4

                    Text {
                        text: "Session Controls"
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: 28
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: "Replace the old wlogout flow with a native Quickshell overlay."
                        color: Theme.textMuted
                        font.family: Theme.fontSans
                        font.pixelSize: 13
                    }

                    GridLayout {
                        width: parent.width
                        columns: 5
                        columnSpacing: Theme.gap
                        rowSpacing: Theme.gap

                        Repeater {
                            model: actions

                            Rectangle {
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredHeight: 188
                                radius: Theme.radius
                                color: Theme.panelSolid
                                border.width: 1
                                border.color: Qt.rgba(modelData.accent.r, modelData.accent.g, modelData.accent.b, 0.45)

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: Theme.padding
                                    spacing: 12

                                    Text {
                                        text: modelData.title
                                        color: modelData.accent
                                        font.family: Theme.fontSans
                                        font.pixelSize: 24
                                        font.weight: Font.DemiBold
                                    }

                                    Text {
                                        text: modelData.detail
                                        color: Theme.textMuted
                                        font.family: Theme.fontMono
                                        font.pixelSize: 12
                                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                    }

                                    Rectangle {
                                        width: 54
                                        height: 2
                                        radius: 1
                                        color: modelData.accent
                                    }

                                    Text {
                                        text: "Click to run"
                                        color: Theme.text
                                        font.family: Theme.fontSans
                                        font.pixelSize: 13
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: runCommand(modelData.command)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

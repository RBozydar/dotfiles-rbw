pragma ComponentBehavior: Bound
import "../../../adapters/quickshell" as QuickshellAdapters
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs

Variants {
    id: root

    required property var shell
    property var commandAdapter: QuickshellAdapters.CommandExecutionAdapter {}

    model: Quickshell.screens

    PanelWindow {
        id: panel

        required property var modelData

        readonly property var actions: [
            {
                title: "Lock",
                detail: "hyprlock",
                accent: Theme.primary,
                command: ["hyprlock"]
            },
            {
                title: "Suspend",
                detail: "systemctl suspend",
                accent: Theme.secondary,
                command: ["systemctl", "suspend"]
            },
            {
                title: "Logout",
                detail: "systemctl --user exit",
                accent: Theme.tertiary,
                command: ["systemctl", "--user", "exit"]
            },
            {
                title: "Reboot",
                detail: "systemctl reboot",
                accent: Theme.tertiary,
                command: ["systemctl", "reboot"]
            },
            {
                title: "Shutdown",
                detail: "systemctl poweroff",
                accent: Theme.error,
                command: ["systemctl", "poweroff"]
            }
        ]

        screen: modelData
        visible: root.shell.sessionOverlayOpen

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
            root.shell.closeSessionOverlay();
            if (!root.commandAdapter)
                return;

            root.commandAdapter.exec(command);
        }

        Item {
            anchors.fill: parent
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.shell.closeSessionOverlay();
                    event.accepted = true;
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.shell.closeSessionOverlay()
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
                color: Theme.surface
                border.width: 1
                border.color: Theme.outline

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
                        color: Theme.onSurface
                        font.family: Theme.fontSans
                        font.pixelSize: 28
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: "Replace the old wlogout flow with a native Quickshell overlay."
                        color: Theme.onSurfaceVariant
                        font.family: Theme.fontSans
                        font.pixelSize: 13
                    }

                    GridLayout {
                        width: parent.width
                        columns: 5
                        columnSpacing: Theme.gap
                        rowSpacing: Theme.gap

                        Repeater {
                            model: panel.actions

                            Rectangle {
                                id: actionCard

                                required property var modelData

                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.preferredHeight: 188
                                radius: Theme.radius
                                color: Theme.surfaceContainer
                                border.width: 1
                                border.color: Qt.rgba(actionCard.modelData.accent.r, actionCard.modelData.accent.g, actionCard.modelData.accent.b, 0.45)

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: Theme.padding
                                    spacing: 12

                                    Text {
                                        text: actionCard.modelData.title
                                        color: actionCard.modelData.accent
                                        font.family: Theme.fontSans
                                        font.pixelSize: 24
                                        font.weight: Font.DemiBold
                                    }

                                    Text {
                                        text: actionCard.modelData.detail
                                        color: Theme.onSurfaceVariant
                                        font.family: Theme.fontMono
                                        font.pixelSize: 12
                                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                    }

                                    Rectangle {
                                        width: 54
                                        height: 2
                                        radius: 1
                                        color: actionCard.modelData.accent
                                    }

                                    Text {
                                        text: "Click to run"
                                        color: Theme.onSurface
                                        font.family: Theme.fontSans
                                        font.pixelSize: 13
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: panel.runCommand(actionCard.modelData.command)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

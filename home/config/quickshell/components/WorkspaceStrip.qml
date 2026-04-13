import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs

Rectangle {
    id: root

    required property var screen

    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property int activeWorkspaceId: monitor?.activeWorkspace?.id ?? Hyprland.focusedWorkspace?.id ?? 1
    readonly property bool specialWorkspaceOpen: (monitor?.lastIpcObject?.specialWorkspace?.name ?? "") !== ""

    function workspaceOccupied(index): bool {
        return Hyprland.workspaces.values.some(workspace => workspace.id === index && (workspace.lastIpcObject?.windows ?? 0) > 0);
    }

    radius: Theme.chipRadius
    color: Theme.panelSolid
    border.width: 1
    border.color: Theme.border
    height: Theme.barInnerHeight - 8
    width: workspaceRow.implicitWidth + 18

    Row {
        id: workspaceRow

        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: 10

            Rectangle {
                id: workspaceButton

                required property int index

                readonly property int workspaceId: index + 1
                readonly property bool active: root.activeWorkspaceId === workspaceId
                readonly property bool occupied: root.workspaceOccupied(workspaceId)

                width: 28
                height: 28
                radius: 11
                color: active ? Theme.chipActive : (hover.containsMouse ? Theme.chip : (occupied ? "#18283d" : "transparent"))
                border.width: active || occupied || hover.containsMouse ? 1 : 0
                border.color: active ? Theme.accent : Theme.border

                Text {
                    anchors.centerIn: parent
                    text: workspaceButton.workspaceId
                    color: workspaceButton.active ? Theme.accent : Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    visible: workspaceButton.active
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    width: 12
                    height: 3
                    radius: 2
                    color: Theme.accentStrong
                }

                Rectangle {
                    visible: workspaceButton.occupied && !workspaceButton.active
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: 3
                    anchors.bottomMargin: 3
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.textMuted
                }

                MouseArea {
                    id: hover

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Hyprland.dispatch(`workspace ${workspaceButton.workspaceId}`)
                }
            }
        }

        Rectangle {
            visible: root.specialWorkspaceOpen
            width: 28
            height: 28
            radius: 11
            color: Theme.chip
            border.width: 1
            border.color: Theme.warning

            Text {
                anchors.centerIn: parent
                text: "★"
                color: Theme.warning
                font.family: Theme.fontSans
                font.pixelSize: 13
                font.weight: Font.Black
            }
        }
    }
}

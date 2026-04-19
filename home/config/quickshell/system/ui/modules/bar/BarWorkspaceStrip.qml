pragma ComponentBehavior: Bound
import QtQuick
import qs

Rectangle {
    id: root

    required property var presentationModel
    readonly property var stripModel: presentationModel.workspaceStrip

    radius: 12
    color: Theme.withAlpha(Theme.surfaceContainerLow, Theme.moduleOpacity("bar.workspace.strip", Theme.workspaceStripOpacity))
    border.width: 1
    border.color: Theme.withAlpha(Theme.outline, Theme.moduleOpacity("bar.workspace.strip.border", Theme.workspaceStripBorderOpacity))
    height: 34
    width: workspaceRow.implicitWidth + 18

    Row {
        id: workspaceRow

        anchors.centerIn: parent
        spacing: 6

        Repeater {
            model: root.stripModel.buttons

            Rectangle {
                id: workspaceButton

                required property var modelData

                width: 24
                height: 24
                radius: 9
                color: modelData.active ? Theme.withAlpha(Theme.secondaryContainer, Theme.moduleOpacity("bar.workspace.button.active", Theme.workspaceButtonActiveOpacity)) : (hover.hovered ? Theme.withAlpha(Theme.surfaceContainerHigh, Theme.moduleOpacity("bar.workspace.button.hover", Theme.workspaceButtonHoverOpacity)) : (modelData.occupied ? Theme.withAlpha(Theme.surfaceContainer, Theme.moduleOpacity("bar.workspace.button.occupied", Theme.workspaceButtonOccupiedOpacity)) : "transparent"))
                border.width: modelData.active || modelData.occupied || hover.hovered ? 1 : 0
                border.color: modelData.active ? Theme.withAlpha(Theme.secondary, Theme.moduleOpacity("bar.workspace.button.active.border", 0.78)) : Theme.withAlpha(Theme.outline, Theme.moduleOpacity("bar.workspace.button.border", 0.62))

                Text {
                    anchors.centerIn: parent
                    text: workspaceButton.modelData.label
                    color: workspaceButton.modelData.active ? Theme.secondary : Theme.roleOnSurface
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    visible: workspaceButton.modelData.active
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 3
                    width: 10
                    height: 3
                    radius: 2
                    color: Theme.secondary
                }

                Rectangle {
                    visible: workspaceButton.modelData.occupied && !workspaceButton.modelData.active
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.rightMargin: 3
                    anchors.bottomMargin: 3
                    width: 5
                    height: 5
                    radius: 3
                    color: Theme.roleOnSurfaceVariant
                }

                HoverHandler {
                    id: hover
                }

                TapHandler {
                    onTapped: root.presentationModel.focusWorkspace(workspaceButton.modelData.id)
                }
            }
        }

        Rectangle {
            visible: root.stripModel.specialWorkspaceOpen
            width: 24
            height: 24
            radius: 9
            color: Theme.withAlpha(Theme.tertiaryContainer, Theme.moduleOpacity("bar.workspace.special", Theme.workspaceSpecialOpacity))
            border.width: 1
            border.color: Theme.withAlpha(Theme.tertiary, Theme.moduleOpacity("bar.workspace.special.border", 0.76))

            Text {
                anchors.centerIn: parent
                text: "*"
                color: Theme.tertiary
                font.family: "IBM Plex Sans"
                font.pixelSize: 14
                font.weight: Font.Black
            }
        }
    }
}

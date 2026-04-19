pragma ComponentBehavior: Bound
import QtQuick

Rectangle {
    id: root

    required property var presentationModel
    readonly property var stripModel: presentationModel.workspaceStrip

    radius: 12
    color: "#11161f"
    border.width: 1
    border.color: "#2b384d"
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
                color: modelData.active ? "#17395d" : (hover.hovered ? "#1a2432" : (modelData.occupied ? "#152130" : "transparent"))
                border.width: modelData.active || modelData.occupied || hover.hovered ? 1 : 0
                border.color: modelData.active ? "#7cc7ff" : "#2b384d"

                Text {
                    anchors.centerIn: parent
                    text: workspaceButton.modelData.label
                    color: workspaceButton.modelData.active ? "#7cc7ff" : "#d7e2f0"
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
                    color: "#9fd7ff"
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
                    color: "#8aa0b8"
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
            color: "#221713"
            border.width: 1
            border.color: "#ffb366"

            Text {
                anchors.centerIn: parent
                text: "*"
                color: "#ffb366"
                font.family: "IBM Plex Sans"
                font.pixelSize: 14
                font.weight: Font.Black
            }
        }
    }
}

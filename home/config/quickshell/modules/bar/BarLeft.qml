import QtQuick
import qs.components

Item {
    id: root

    required property var screen

    implicitWidth: workspaceStrip.width
    implicitHeight: workspaceStrip.height

    WorkspaceStrip {
        id: workspaceStrip

        anchors.centerIn: parent
        screen: root.screen
    }
}

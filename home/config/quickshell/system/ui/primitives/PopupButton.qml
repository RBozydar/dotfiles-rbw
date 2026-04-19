import QtQuick
import qs

Rectangle {
    id: root

    property string text: ""
    property color accent: Theme.primary

    signal clicked

    radius: 12
    color: buttonArea.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow
    border.width: 1
    border.color: Qt.rgba(accent.r, accent.g, accent.b, 0.45)
    implicitHeight: 34
    implicitWidth: label.implicitWidth + 18

    Text {
        id: label

        anchors.centerIn: parent
        text: root.text
        color: root.accent
        font.family: Theme.fontSans
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }

    MouseArea {
        id: buttonArea

        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
    }
}

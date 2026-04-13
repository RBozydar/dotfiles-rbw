import QtQuick
import QtQuick.Layouts
import qs

Rectangle {
    id: root

    property string icon: ""
    property string text: ""
    property bool checked: false
    property bool toggleEnabled: true
    property color accent: Theme.accent

    signal clicked()

    radius: Theme.chipRadius
    color: !root.toggleEnabled ? Qt.rgba(Theme.chip.r, Theme.chip.g, Theme.chip.b, 0.55) : (toggleArea.containsMouse ? Theme.chipHover : (root.checked ? Theme.chipActive : Theme.chip))
    border.width: 1
    border.color: root.checked ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.55) : Theme.border
    implicitHeight: 38

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.chipPadding
        anchors.rightMargin: Theme.chipPadding
        spacing: 8

        Text {
            visible: root.icon.length > 0
            text: root.icon
            color: root.toggleEnabled ? (root.checked ? root.accent : Theme.textMuted) : Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 14
            font.weight: Font.Black
        }

        Text {
            text: root.text
            color: root.toggleEnabled ? Theme.text : Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 13
            font.weight: Font.DemiBold
            Layout.fillWidth: true
        }
    }

    MouseArea {
        id: toggleArea

        anchors.fill: parent
        enabled: root.toggleEnabled
        hoverEnabled: true
        onClicked: root.clicked()
    }
}

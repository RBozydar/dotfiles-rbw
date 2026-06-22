import QtQuick
import QtQuick.Layouts
import qs

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property color accent: Theme.roleOnSurface
    property bool active: false
    property int maximumLabelWidth: 240
    property bool badgeVisible: false
    property string badgeText: ""
    property color badgeColor: Theme.tertiary
    readonly property bool hovered: mouseArea.containsMouse

    signal clicked
    signal wheelUp
    signal wheelDown

    radius: Theme.chipRadius
    color: mouseArea.containsMouse ? Theme.surfaceContainerHigh : (active ? Theme.surfaceContainerHighest : Theme.surfaceContainerLow)
    border.width: 1
    border.color: active ? Qt.rgba(accent.r, accent.g, accent.b, 0.55) : Theme.outline
    implicitHeight: Theme.barChipHeight
    implicitWidth: row.implicitWidth + (Theme.chipPadding * 2)

    RowLayout {
        id: row

        anchors.fill: parent
        anchors.leftMargin: Theme.chipPadding
        anchors.rightMargin: Theme.chipPadding
        spacing: 8

        Text {
            visible: root.icon.length > 0
            text: root.icon
            color: root.accent
            font.family: Theme.fontSans
            font.pixelSize: 15
            font.weight: Font.Black
        }

        Text {
            visible: root.label.length > 0
            text: root.label
            color: Theme.roleOnSurface
            font.family: Theme.fontSans
            font.pixelSize: 13
            font.weight: Font.Medium
            elide: Text.ElideRight
            Layout.maximumWidth: root.maximumLabelWidth
        }
    }

    Rectangle {
        visible: root.badgeVisible
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 3
        anchors.rightMargin: 3
        radius: implicitHeight / 2
        color: root.badgeColor
        implicitHeight: root.badgeText.length > 0 ? 16 : 10
        implicitWidth: root.badgeText.length > 0 ? Math.max(implicitHeight, badgeLabel.implicitWidth + 8) : implicitHeight

        Text {
            id: badgeLabel
            visible: root.badgeText.length > 0
            anchors.centerIn: parent
            text: root.badgeText
            color: Theme.surfaceContainer
            font.family: Theme.fontSans
            font.pixelSize: 10
            font.weight: Font.Black
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.clicked()
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) {
                root.wheelUp();
                wheel.accepted = true;
            } else if (wheel.angleDelta.y < 0) {
                root.wheelDown();
                wheel.accepted = true;
            }
        }
    }
}

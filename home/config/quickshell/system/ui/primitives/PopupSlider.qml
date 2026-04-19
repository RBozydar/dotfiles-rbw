import QtQuick
import QtQuick.Layouts
import qs

Column {
    id: root

    property string label: ""
    property string valueText: ""
    property color accent: Theme.primary
    property real value: 0
    property bool sliderEnabled: true

    signal moved(real value)

    spacing: 8

    RowLayout {
        id: sliderHeader

        width: parent.width
        spacing: 12

        Text {
            text: root.label
            color: Theme.roleOnSurfaceVariant
            font.family: Theme.fontSans
            font.pixelSize: 13
            Layout.fillWidth: true
        }

        Text {
            text: root.valueText
            color: root.sliderEnabled ? root.accent : Theme.roleOnSurfaceVariant
            font.family: Theme.fontMono
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }
    }

    Rectangle {
        id: sliderTrack

        width: parent.width
        implicitHeight: 16
        radius: 8
        color: Theme.surfaceContainerLow
        border.width: 1
        border.color: Theme.outline
        opacity: root.sliderEnabled ? 1 : 0.55

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(14, parent.width * Math.max(0, Math.min(1, root.value)))
            radius: parent.radius
            color: root.accent
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.sliderEnabled
            hoverEnabled: true

            function updateFromMouse(x): void {
                root.moved(Math.max(0, Math.min(1, x / width)));
            }

            onPressed: mouse => updateFromMouse(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    updateFromMouse(mouse.x);
            }
        }
    }
}

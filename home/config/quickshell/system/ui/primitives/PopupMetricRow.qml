import QtQuick
import QtQuick.Layouts
import qs

RowLayout {
    id: root

    property string label: ""
    property string value: ""
    property color valueColor: Theme.roleOnSurface

    spacing: 12
    implicitHeight: Math.max(metricLabel.implicitHeight, metricValue.implicitHeight)

    Text {
        id: metricLabel

        text: root.label
        color: Theme.roleOnSurfaceVariant
        font.family: Theme.fontSans
        font.pixelSize: 13
        Layout.fillWidth: true
    }

    Text {
        id: metricValue

        text: root.value
        color: root.valueColor
        font.family: Theme.fontMono
        font.pixelSize: 13
        font.weight: Font.DemiBold
    }
}

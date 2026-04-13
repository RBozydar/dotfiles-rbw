import QtQuick
import qs
import qs.components
import qs.services

Item {
    id: root

    required property var clock

    readonly property alias weatherChip: weatherChip

    implicitWidth: centerRow.implicitWidth
    implicitHeight: centerRow.implicitHeight

    Row {
        id: centerRow

        anchors.centerIn: parent
        spacing: Theme.gap

        StatusChip {
            id: weatherChip

            icon: Weather.icon
            accent: Theme.warning
            label: Weather.temperature
            maximumLabelWidth: 96
        }

        Rectangle {
            id: clockCard

            radius: Theme.chipRadius
            color: Theme.panelSolid
            border.width: 1
            border.color: Theme.border
            height: Theme.barInnerHeight - 4
            width: clockText.implicitWidth + 28

            Text {
                id: clockText

                anchors.centerIn: parent
                text: Qt.formatDateTime(root.clock.date, "hh:mm:ss yyyy-MM-dd")
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
        }
    }
}

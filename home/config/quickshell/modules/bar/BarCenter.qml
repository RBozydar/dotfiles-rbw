import QtQuick
import "weather" as WeatherWidgets
import qs

Item {
    id: root

    required property var clock

    readonly property alias weatherChip: weatherChip
    readonly property alias clockChip: clockCard

    implicitWidth: centerRow.implicitWidth
    implicitHeight: centerRow.implicitHeight

    Row {
        id: centerRow

        anchors.centerIn: parent
        spacing: Theme.gap

        WeatherWidgets.WeatherChip {
            id: weatherChip
        }

        Rectangle {
            id: clockCard

            property bool hovered: clockHover.hovered

            radius: Theme.chipRadius
            color: Theme.panelSolid
            border.width: 1
            border.color: Theme.border1
            height: Theme.barInnerHeight - 4
            width: clockText.implicitWidth + 28

            HoverHandler {
                id: clockHover
            }

            Text {
                id: clockText

                anchors.centerIn: parent
                text: Qt.formatDateTime(root.clock.date, "yyyy-MM-dd hh:mm:ss")
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
        }
    }
}

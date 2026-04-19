import QtQuick
import qs
import "weather" as WeatherWidgets

Item {
    id: root

    required property var clock
    required property var chromeBridge
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

            chromeBridge: root.chromeBridge
        }

        Rectangle {
            id: clockCard

            property bool hovered: clockHover.hovered

            radius: Theme.chipRadius
            color: Theme.surfaceContainer
            border.width: 1
            border.color: Theme.outline
            height: Theme.barChipHeight
            width: clockText.implicitWidth + 28

            HoverHandler {
                id: clockHover
            }

            Text {
                id: clockText

                anchors.centerIn: parent
                text: Qt.formatDateTime(root.clock.date, "yyyy-MM-dd hh:mm:ss")
                color: Theme.roleOnSurface
                font.family: Theme.fontMono
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
        }
    }
}

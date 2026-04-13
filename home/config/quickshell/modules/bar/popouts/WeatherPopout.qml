import QtQuick
import qs
import qs.components
import qs.services

Item {
    id: root

    implicitWidth: 320
    implicitHeight: weatherColumn.implicitHeight

    Column {
        id: weatherColumn

        width: root.implicitWidth
        spacing: 12

        Text {
            text: Weather.city.length > 0 ? Weather.city : "Weather"
            color: Theme.text
            font.family: Theme.fontSans
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }

        PopupMetricRow {
            width: parent.width
            label: "Condition"
            value: Weather.condition
            valueColor: Theme.warning
        }

        PopupMetricRow {
            width: parent.width
            label: "Temperature"
            value: `${Weather.temperature}  feels ${Weather.feelsLike}`
            valueColor: Theme.accent
        }

        PopupMetricRow {
            width: parent.width
            label: "Humidity"
            value: Weather.humidity
        }

        PopupMetricRow {
            width: parent.width
            label: "Wind"
            value: Weather.wind
        }

        PopupButton {
            text: "Refresh"
            accent: Theme.accent
            onClicked: Weather.refresh()
        }
    }
}

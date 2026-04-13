import QtQuick
import QtQuick.Layouts
import "../weather" as WeatherWidgets
import qs
import qs.services

Item {
    id: root

    readonly property int preferredWidth: 820
    readonly property int layoutWidth: Math.max(width, preferredWidth)

    implicitWidth: preferredWidth
    implicitHeight: weatherColumn.implicitHeight

    Column {
        id: weatherColumn

        width: root.layoutWidth
        spacing: 14

        RowLayout {
            width: parent.width
            spacing: 14

            Text {
                text: Weather.icon
                color: Theme.warning
                font.family: Theme.fontSans
                font.pixelSize: 28
            }

            Text {
                text: Weather.temperature
                color: Theme.text
                font.family: Theme.fontMono
                font.pixelSize: 26
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                text: `${Weather.condition} • ${Weather.city.length > 0 ? Weather.city : "Weather"}${Weather.modelLabel.length > 0 ? ` • ${Weather.modelLabel}` : ""}${Weather.runLabel.length > 0 ? ` • ${Weather.runLabel}` : ""}${Weather.stale ? " • cached" : ""}`
                color: Theme.textMuted
                font.family: Theme.fontSans
                font.pixelSize: 14
                elide: Text.ElideRight
            }
        }

        GridLayout {
            width: parent.width
            columns: 4
            columnSpacing: 8
            rowSpacing: 8

            Repeater {
                model: [
                    { label: "Feels", value: Weather.feelsLike, accent: Theme.warning },
                    { label: "Humidity", value: Weather.humidity, accent: Theme.accentStrong },
                    { label: "Wind", value: Weather.wind, accent: Theme.accent },
                    { label: "Pressure", value: Weather.pressure, accent: Theme.text }
                ]

                Rectangle {
                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 62
                    radius: Theme.chipRadius
                    color: Theme.panelSolid
                    border.width: 1
                    border.color: Qt.rgba(modelData.accent.r, modelData.accent.g, modelData.accent.b, 0.35)

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        Text {
                            text: modelData.label
                            color: Theme.textMuted
                            font.family: Theme.fontSans
                            font.pixelSize: 12
                        }

                        Text {
                            text: modelData.value
                            color: modelData.accent
                            font.family: Theme.fontMono
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }

        WeatherWidgets.WeatherMeteorogram {
            width: parent.width
            hours: Weather.hourlyPreview
        }
    }
}

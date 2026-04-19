import "../weather" as WeatherWidgets
import QtQuick
import QtQuick.Layouts
import qs

Item {
    id: root

    required property var chromeBridge
    readonly property var weatherState: root.chromeBridge ? root.chromeBridge.weather : null
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
                text: root.weatherState ? root.weatherState.icon : "☁"
                color: Theme.tertiary
                font.family: Theme.fontSans
                font.pixelSize: 28
            }

            Text {
                text: root.weatherState ? root.weatherState.temperature : "--°"
                color: Theme.roleOnSurface
                font.family: Theme.fontMono
                font.pixelSize: 26
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                text: root.weatherState ? `${root.weatherState.condition} • ${root.weatherState.city.length > 0 ? root.weatherState.city : "Weather"}${root.weatherState.modelLabel.length > 0 ? ` • ${root.weatherState.modelLabel}` : ""}${root.weatherState.runLabel.length > 0 ? ` • ${root.weatherState.runLabel}` : ""}${root.weatherState.stale ? " • cached" : ""}` : "Weather unavailable"
                color: Theme.roleOnSurfaceVariant
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
                    {
                        "label": "Feels",
                        "value": root.weatherState ? root.weatherState.feelsLike : "--°",
                        "accent": Theme.tertiary
                    },
                    {
                        "label": "Humidity",
                        "value": root.weatherState ? root.weatherState.humidity : "--%",
                        "accent": Theme.secondary
                    },
                    {
                        "label": "Wind",
                        "value": root.weatherState ? root.weatherState.wind : "--",
                        "accent": Theme.primary
                    },
                    {
                        "label": "Pressure",
                        "value": root.weatherState ? root.weatherState.pressure : "--",
                        "accent": Theme.roleOnSurface
                    }
                ]

                Rectangle {
                    id: metricCard

                    required property var modelData

                    Layout.fillWidth: true
                    implicitHeight: 62
                    radius: Theme.chipRadius
                    color: Theme.surfaceContainer
                    border.width: 1
                    border.color: Qt.rgba(metricCard.modelData.accent.r, metricCard.modelData.accent.g, metricCard.modelData.accent.b, 0.35)

                    Column {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 4

                        Text {
                            text: metricCard.modelData.label
                            color: Theme.roleOnSurfaceVariant
                            font.family: Theme.fontSans
                            font.pixelSize: 12
                        }

                        Text {
                            text: metricCard.modelData.value
                            color: metricCard.modelData.accent
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
            hours: root.weatherState ? root.weatherState.hourlyPreview : []
        }
    }
}

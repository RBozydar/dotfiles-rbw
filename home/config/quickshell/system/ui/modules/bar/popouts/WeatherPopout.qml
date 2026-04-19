import "../weather" as WeatherWidgets
import QtQuick
import QtQuick.Layouts
import qs

Item {
    id: root

    required property var chromeBridge
    readonly property var weatherState: root.chromeBridge ? root.chromeBridge.weather : null
    readonly property int preferredWidth: 1040
    readonly property int legendWidth: 248
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

        RowLayout {
            width: parent.width
            spacing: 12

            WeatherWidgets.WeatherMeteorogram {
                id: meteorogram

                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: Math.max(560, root.layoutWidth - root.legendWidth - 12)
                hours: root.weatherState ? root.weatherState.hourlyPreview : []
                currentIndex: root.weatherState ? root.weatherState.previewCurrentIndex : -1
            }

            Rectangle {
                Layout.preferredWidth: root.legendWidth
                Layout.alignment: Qt.AlignTop
                implicitHeight: legendColumn.implicitHeight + 24
                radius: Theme.chipRadius
                color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.82)
                border.width: 1
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.65)

                Column {
                    id: legendColumn

                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 9

                    Text {
                        text: "Legend"
                        color: Theme.roleOnSurface
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: "window: -3h / +48h"
                        color: Theme.roleOnSurfaceVariant
                        font.family: Theme.fontMono
                        font.pixelSize: 10
                    }

                    Repeater {
                        model: [
                            {
                                "label": "Now marker",
                                "detail": "vertical line (current hour)",
                                "accent": Theme.error
                            },
                            {
                                "label": "Air / dew",
                                "detail": "temperature + dew point",
                                "accent": Theme.tertiary
                            },
                            {
                                "label": "Rain / humidity",
                                "detail": "precip bars + humidity line",
                                "accent": Theme.secondary
                            },
                            {
                                "label": "Pressure",
                                "detail": "surface pressure curve",
                                "accent": Theme.tertiary
                            },
                            {
                                "label": "Wind / gust",
                                "detail": "speed area + gust line",
                                "accent": Theme.primary
                            },
                            {
                                "label": "Cloud layers",
                                "detail": "cover + very low/low/mid/high",
                                "accent": Theme.roleOnSurface
                            },
                            {
                                "label": "Cloud altitudes",
                                "detail": "base-to-top cloud band",
                                "accent": Theme.primary
                            },
                            {
                                "label": "Visibility",
                                "detail": "km line (lower cloud panel)",
                                "accent": Theme.tertiary
                            }
                        ]

                        delegate: Row {
                            id: legendEntry

                            required property var modelData

                            width: parent.width
                            spacing: 8

                            Rectangle {
                                width: 16
                                height: 4
                                radius: 2
                                anchors.verticalCenter: parent.verticalCenter
                                color: Qt.rgba(parent.modelData.accent.r, parent.modelData.accent.g, parent.modelData.accent.b, 0.95)
                            }

                            Column {
                                spacing: 1

                                Text {
                                    text: legendEntry.modelData.label
                                    color: Theme.roleOnSurface
                                    font.family: Theme.fontSans
                                    font.pixelSize: 11
                                }

                                Text {
                                    text: legendEntry.modelData.detail
                                    color: Theme.roleOnSurfaceVariant
                                    font.family: Theme.fontMono
                                    font.pixelSize: 9
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

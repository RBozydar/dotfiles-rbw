import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

Item {
    id: root

    implicitWidth: 360
    implicitHeight: popupColumn.implicitHeight

    Column {
        id: popupColumn

        width: root.implicitWidth
        spacing: 12

        Text {
            text: "Lights"
            color: Theme.text
            font.family: Theme.fontSans
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }

        PopupMetricRow {
            width: parent.width
            label: "Home Assistant"
            value: HomeAssistant.summaryLabel
            valueColor: HomeAssistant.available ? (HomeAssistant.anyOn ? Theme.warning : Theme.text) : Theme.warning
        }

        Text {
            visible: HomeAssistant.error.length > 0
            width: parent.width
            text: HomeAssistant.error
            wrapMode: Text.Wrap
            color: Theme.warning
            font.family: Theme.fontSans
            font.pixelSize: 12
        }

        RowLayout {
            width: parent.width
            spacing: 8

            PopupButton {
                text: HomeAssistant.refreshing || HomeAssistant.busy ? "Syncing..." : "Refresh"
                accent: Theme.accentStrong
                onClicked: HomeAssistant.refresh()
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: HomeAssistant.available ? `${HomeAssistant.activeLightCount}/${HomeAssistant.lightCount} on` : ""
                color: Theme.textMuted
                font.family: Theme.fontMono
                font.pixelSize: 12
            }
        }

        Text {
            visible: HomeAssistant.available && HomeAssistant.lightCount === 0
            width: parent.width
            text: "No light entities found."
            color: Theme.textMuted
            font.family: Theme.fontSans
            font.pixelSize: 13
        }

        Column {
            id: lightsColumn

            visible: HomeAssistant.available && HomeAssistant.lightCount > 0
            width: parent.width
            spacing: 10

            Repeater {
                model: HomeAssistant.lights

                delegate: Rectangle {
                    id: lightCard

                    required property var modelData

                    property real liveBrightnessValue: {
                        const brightness = modelData.brightnessPercent;
                        if (brightness === null || brightness === undefined)
                            return modelData.isOn ? 1 : 0;
                        return Math.max(0, Math.min(1, brightness / 100));
                    }
                    property real pendingBrightnessValue: liveBrightnessValue
                    property real liveColorTempValue: {
                        const minTemp = lightCard.colorTempMin();
                        const maxTemp = lightCard.colorTempMax();
                        const currentTemp = modelData.colorTempKelvin ?? minTemp;
                        if (maxTemp <= minTemp)
                            return 0;
                        return Math.max(0, Math.min(1, (currentTemp - minTemp) / (maxTemp - minTemp)));
                    }
                    property real pendingColorTempValue: liveColorTempValue

                    width: lightsColumn.width
                    implicitHeight: cardColumn.implicitHeight + 20
                    radius: Theme.radius
                    color: Theme.chip
                    border.width: 1
                    border.color: modelData.isOn ? Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.45) : Theme.border

                    function colorTempMin(): int {
                        return modelData.minColorTempKelvin ?? 2200;
                    }

                    function colorTempMax(): int {
                        return modelData.maxColorTempKelvin ?? 6500;
                    }

                    function colorTempKelvinFromValue(value): int {
                        const minTemp = lightCard.colorTempMin();
                        const maxTemp = lightCard.colorTempMax();
                        if (maxTemp <= minTemp)
                            return Math.round(minTemp);
                        return Math.round(minTemp + (Math.max(0, Math.min(1, value)) * (maxTemp - minTemp)));
                    }

                    onModelDataChanged: {
                        pendingBrightnessValue = liveBrightnessValue;
                        pendingColorTempValue = liveColorTempValue;
                    }

                    Column {
                        id: cardColumn

                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        PopupToggle {
                            width: parent.width
                            icon: !modelData.available ? "󰔎" : (modelData.isOn ? "󰖨" : "󰖧")
                            text: {
                                if (!modelData.available)
                                    return `${modelData.name} unavailable`;
                                if (modelData.isOn && modelData.brightnessPercent !== null)
                                    return `${modelData.name} ${modelData.brightnessPercent}%`;
                                return `${modelData.name} ${modelData.isOn ? "on" : "off"}`;
                            }
                            checked: modelData.isOn
                            toggleEnabled: modelData.available
                            accent: modelData.isOn ? Theme.warning : Theme.textMuted
                            onClicked: HomeAssistant.toggleLight(modelData.entityId)
                        }

                        PopupSlider {
                            width: parent.width
                            label: "Brightness"
                            valueText: `${Math.round(lightCard.pendingBrightnessValue * 100)}%`
                            accent: Theme.warning
                            value: lightCard.pendingBrightnessValue
                            sliderEnabled: modelData.available
                            onMoved: value => {
                                lightCard.pendingBrightnessValue = value;
                                brightnessCommit.restart();
                            }
                        }

                        PopupSlider {
                            visible: modelData.supportsColorTemp
                            width: parent.width
                            label: "Color Temp"
                            valueText: `${lightCard.colorTempKelvinFromValue(lightCard.pendingColorTempValue)}K`
                            accent: Theme.accentStrong
                            value: lightCard.pendingColorTempValue
                            sliderEnabled: modelData.available
                            onMoved: value => {
                                lightCard.pendingColorTempValue = value;
                                colorTempCommit.restart();
                            }
                        }
                    }

                    Timer {
                        id: brightnessCommit

                        interval: 140
                        repeat: false
                        onTriggered: HomeAssistant.setBrightness(modelData.entityId, Math.round(lightCard.pendingBrightnessValue * 100))
                    }

                    Timer {
                        id: colorTempCommit

                        interval: 140
                        repeat: false
                        onTriggered: HomeAssistant.setColorTemp(modelData.entityId, lightCard.colorTempKelvinFromValue(lightCard.pendingColorTempValue))
                    }
                }
            }
        }
    }
}

pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs
import "../../../primitives" as BarPrimitives

Item {
    id: root

    required property var chromeBridge
    readonly property var homeAssistantState: root.chromeBridge ? root.chromeBridge.homeAssistant : null
    implicitWidth: 360
    implicitHeight: popupColumn.implicitHeight

    Column {
        id: popupColumn

        width: root.implicitWidth
        spacing: 12

        Text {
            text: "Lights"
            color: Theme.onSurface
            font.family: Theme.fontSans
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }

        BarPrimitives.PopupMetricRow {
            width: parent.width
            label: "Home Assistant"
            value: root.homeAssistantState ? root.homeAssistantState.summaryLabel : "Unavailable"
            valueColor: root.homeAssistantState && root.homeAssistantState.available ? (root.homeAssistantState.anyOn ? Theme.tertiary : Theme.onSurface) : Theme.tertiary
        }

        Text {
            visible: root.homeAssistantState ? root.homeAssistantState.error.length > 0 : false
            width: parent.width
            text: root.homeAssistantState ? root.homeAssistantState.error : ""
            wrapMode: Text.Wrap
            color: Theme.tertiary
            font.family: Theme.fontSans
            font.pixelSize: 12
        }

        RowLayout {
            width: parent.width
            spacing: 8

            BarPrimitives.PopupButton {
                text: root.homeAssistantState && (root.homeAssistantState.refreshing || root.homeAssistantState.busy) ? "Syncing..." : "Refresh"
                accent: Theme.secondary
                onClicked: {
                    if (root.homeAssistantState)
                        root.homeAssistantState.refresh();
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Text {
                text: root.homeAssistantState && root.homeAssistantState.available ? `${root.homeAssistantState.activeLightCount}/${root.homeAssistantState.lightCount} on` : ""
                color: Theme.onSurfaceVariant
                font.family: Theme.fontMono
                font.pixelSize: 12
            }
        }

        Text {
            visible: root.homeAssistantState && root.homeAssistantState.available && root.homeAssistantState.lightCount === 0
            width: parent.width
            text: "No light entities found."
            color: Theme.onSurfaceVariant
            font.family: Theme.fontSans
            font.pixelSize: 13
        }

        Column {
            id: lightsColumn

            visible: root.homeAssistantState && root.homeAssistantState.available && root.homeAssistantState.lightCount > 0
            width: parent.width
            spacing: 10

            Repeater {
                model: root.homeAssistantState ? root.homeAssistantState.lights : []

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

                    width: lightsColumn.width
                    implicitHeight: cardColumn.implicitHeight + 20
                    radius: Theme.radius
                    color: Theme.surfaceContainerLow
                    border.width: 1
                    border.color: modelData.isOn ? Qt.rgba(Theme.tertiary.r, Theme.tertiary.g, Theme.tertiary.b, 0.45) : Theme.outline
                    onModelDataChanged: {
                        pendingBrightnessValue = liveBrightnessValue;
                        pendingColorTempValue = liveColorTempValue;
                    }

                    Column {
                        id: cardColumn

                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10

                        BarPrimitives.PopupToggle {
                            width: parent.width
                            icon: !lightCard.modelData.available ? "󰔎" : (lightCard.modelData.isOn ? "󰖨" : "󰖧")
                            text: {
                                if (!lightCard.modelData.available)
                                    return `${lightCard.modelData.name} unavailable`;

                                if (lightCard.modelData.isOn && lightCard.modelData.brightnessPercent !== null)
                                    return `${lightCard.modelData.name} ${lightCard.modelData.brightnessPercent}%`;

                                return `${lightCard.modelData.name} ${lightCard.modelData.isOn ? "on" : "off"}`;
                            }
                            checked: lightCard.modelData.isOn
                            toggleEnabled: lightCard.modelData.available
                            accent: lightCard.modelData.isOn ? Theme.tertiary : Theme.onSurfaceVariant
                            onClicked: {
                                if (root.homeAssistantState)
                                    root.homeAssistantState.toggleLight(lightCard.modelData.entityId);
                            }
                        }

                        BarPrimitives.PopupSlider {
                            width: parent.width
                            label: "Brightness"
                            valueText: `${Math.round(lightCard.pendingBrightnessValue * 100)}%`
                            accent: Theme.tertiary
                            value: lightCard.pendingBrightnessValue
                            sliderEnabled: lightCard.modelData.available
                            onMoved: value => {
                                lightCard.pendingBrightnessValue = value;
                                brightnessCommit.restart();
                            }
                        }

                        BarPrimitives.PopupSlider {
                            visible: lightCard.modelData.supportsColorTemp
                            width: parent.width
                            label: "Color Temp"
                            valueText: `${lightCard.colorTempKelvinFromValue(lightCard.pendingColorTempValue)}K`
                            accent: Theme.secondary
                            value: lightCard.pendingColorTempValue
                            sliderEnabled: lightCard.modelData.available
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
                        onTriggered: {
                            if (root.homeAssistantState)
                                root.homeAssistantState.setBrightness(lightCard.modelData.entityId, Math.round(lightCard.pendingBrightnessValue * 100));
                        }
                    }

                    Timer {
                        id: colorTempCommit

                        interval: 140
                        repeat: false
                        onTriggered: {
                            if (root.homeAssistantState)
                                root.homeAssistantState.setColorTemp(lightCard.modelData.entityId, lightCard.colorTempKelvinFromValue(lightCard.pendingColorTempValue));
                        }
                    }
                }
            }
        }
    }
}

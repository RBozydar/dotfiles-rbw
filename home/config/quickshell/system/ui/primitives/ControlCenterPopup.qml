pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs
import "." as PrimitiveLocal

Item {
    id: root

    required property var chromeBridge
    property var setThemeModeAction: null
    property var setThemeVariantAction: null
    property string currentThemeVariant: "tonal-spot"
    property var themeVariantOptions: []
    property var brightnessMonitor: null
    readonly property var audioState: root.chromeBridge ? root.chromeBridge.audio : null
    readonly property var connectivityState: root.chromeBridge ? root.chromeBridge.connectivity : null
    readonly property var nightModeState: root.chromeBridge ? root.chromeBridge.nightMode : null

    implicitWidth: popupColumn.implicitWidth
    implicitHeight: popupColumn.implicitHeight

    function normalizedVariantId(value): string {
        return String(value === undefined ? "" : value).trim().toLowerCase();
    }

    function variantOptionId(option): string {
        if (option && typeof option === "object" && option.id !== undefined)
            return String(option.id);
        return String(option === undefined ? "" : option);
    }

    function variantOptionLabel(option): string {
        if (option && typeof option === "object" && option.label !== undefined)
            return String(option.label);
        return String(option === undefined ? "" : option);
    }

    Column {
        id: popupColumn

        width: 344
        spacing: 14

        Text {
            text: "Control Center"
            color: Theme.roleOnSurface
            font.family: Theme.fontSans
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }

        PrimitiveLocal.PopupSlider {
            width: parent.width
            label: "Volume"
            valueText: root.audioState && root.audioState.muted ? "muted" : `${root.audioState ? root.audioState.volumePercent : 0}%`
            accent: Theme.primary
            value: root.audioState ? root.audioState.volumeLevel : 0
            onMoved: value => {
                if (root.audioState)
                    root.audioState.setVolume(Math.round(value * 150));
            }
        }

        Rectangle {
            width: parent.width
            radius: Theme.chipRadius
            color: Theme.surfaceContainer
            border.width: 1
            border.color: Theme.outline
            implicitHeight: audioDeviceColumn.implicitHeight + 20

            Column {
                id: audioDeviceColumn

                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Text {
                    text: "Audio Devices"
                    color: Theme.roleOnSurfaceVariant
                    font.family: Theme.fontSans
                    font.pixelSize: 13
                }

                RowLayout {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "Output"
                        color: Theme.roleOnSurfaceVariant
                        font.family: Theme.fontSans
                        font.pixelSize: 12
                        Layout.preferredWidth: 52
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (!root.audioState)
                                return "unavailable";
                            if (root.audioState.devicesAvailable)
                                return root.audioState.currentOutputLabel;
                            return root.audioState.devicesError.length > 0 ? root.audioState.devicesError : "unavailable";
                        }
                        color: root.audioState && root.audioState.devicesAvailable ? Theme.roleOnSurface : Theme.roleOnSurfaceVariant
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    Row {
                        spacing: 6

                        Rectangle {
                            width: 26
                            height: 22
                            radius: 6
                            color: root.audioState && root.audioState.canSelectOutput ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow
                            border.width: 1
                            border.color: Theme.outline
                            opacity: root.audioState && root.audioState.canSelectOutput ? 1 : 0.55

                            Text {
                                anchors.centerIn: parent
                                text: "◀"
                                color: Theme.roleOnSurface
                                font.family: Theme.fontSans
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.audioState && root.audioState.canSelectOutput
                                onClicked: root.audioState.selectPreviousOutput()
                            }
                        }

                        Rectangle {
                            width: 26
                            height: 22
                            radius: 6
                            color: root.audioState && root.audioState.canSelectOutput ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow
                            border.width: 1
                            border.color: Theme.outline
                            opacity: root.audioState && root.audioState.canSelectOutput ? 1 : 0.55

                            Text {
                                anchors.centerIn: parent
                                text: "▶"
                                color: Theme.roleOnSurface
                                font.family: Theme.fontSans
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.audioState && root.audioState.canSelectOutput
                                onClicked: root.audioState.selectNextOutput()
                            }
                        }
                    }
                }

                RowLayout {
                    width: parent.width
                    spacing: 8

                    Text {
                        text: "Input"
                        color: Theme.roleOnSurfaceVariant
                        font.family: Theme.fontSans
                        font.pixelSize: 12
                        Layout.preferredWidth: 52
                    }

                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (!root.audioState)
                                return "unavailable";
                            if (root.audioState.devicesAvailable)
                                return root.audioState.currentInputLabel;
                            return root.audioState.devicesError.length > 0 ? root.audioState.devicesError : "unavailable";
                        }
                        color: root.audioState && root.audioState.devicesAvailable ? Theme.roleOnSurface : Theme.roleOnSurfaceVariant
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }

                    Row {
                        spacing: 6

                        Rectangle {
                            width: 26
                            height: 22
                            radius: 6
                            color: root.audioState && root.audioState.canSelectInput ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow
                            border.width: 1
                            border.color: Theme.outline
                            opacity: root.audioState && root.audioState.canSelectInput ? 1 : 0.55

                            Text {
                                anchors.centerIn: parent
                                text: "◀"
                                color: Theme.roleOnSurface
                                font.family: Theme.fontSans
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.audioState && root.audioState.canSelectInput
                                onClicked: root.audioState.selectPreviousInput()
                            }
                        }

                        Rectangle {
                            width: 26
                            height: 22
                            radius: 6
                            color: root.audioState && root.audioState.canSelectInput ? Theme.surfaceContainerHigh : Theme.surfaceContainerLow
                            border.width: 1
                            border.color: Theme.outline
                            opacity: root.audioState && root.audioState.canSelectInput ? 1 : 0.55

                            Text {
                                anchors.centerIn: parent
                                text: "▶"
                                color: Theme.roleOnSurface
                                font.family: Theme.fontSans
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: root.audioState && root.audioState.canSelectInput
                                onClicked: root.audioState.selectNextInput()
                            }
                        }
                    }
                }
            }
        }

        PrimitiveLocal.PopupSlider {
            width: parent.width
            label: "Brightness"
            valueText: root.brightnessMonitor?.available ? `${root.brightnessMonitor.brightnessPercent}%` : "unavailable"
            accent: Theme.tertiary
            sliderEnabled: root.brightnessMonitor?.available ?? false
            value: root.brightnessMonitor?.brightness ?? 0
            onMoved: value => root.brightnessMonitor?.setBrightness(value)
        }

        GridLayout {
            width: parent.width
            columns: 2
            rowSpacing: 8
            columnSpacing: 8

            PrimitiveLocal.PopupToggle {
                Layout.fillWidth: true
                icon: ""
                text: "Wi-Fi"
                checked: root.connectivityState ? root.connectivityState.wifiEnabled : false
                toggleEnabled: root.connectivityState ? root.connectivityState.wifiAvailable : false
                accent: Theme.secondary
                onClicked: {
                    if (root.connectivityState)
                        root.connectivityState.toggleWifi();
                }
            }

            PrimitiveLocal.PopupToggle {
                Layout.fillWidth: true
                icon: ""
                text: "Ethernet"
                checked: root.connectivityState ? root.connectivityState.ethernetConnected : false
                toggleEnabled: root.connectivityState ? root.connectivityState.ethernetAvailable : false
                accent: Theme.primary
                onClicked: {
                    if (root.connectivityState)
                        root.connectivityState.toggleEthernet();
                }
            }

            PrimitiveLocal.PopupToggle {
                Layout.fillWidth: true
                icon: ""
                text: "Bluetooth"
                checked: root.connectivityState ? root.connectivityState.bluetoothEnabled : false
                toggleEnabled: root.connectivityState ? root.connectivityState.bluetoothAvailable : false
                accent: Theme.secondary
                onClicked: {
                    if (root.connectivityState)
                        root.connectivityState.toggleBluetooth();
                }
            }

            PrimitiveLocal.PopupToggle {
                Layout.fillWidth: true
                icon: Theme.darkMode ? "󰖔" : "󰖨"
                text: Theme.darkMode ? "Dark Mode" : "Light Mode"
                checked: Theme.darkMode
                toggleEnabled: true
                accent: Theme.tertiary
                onClicked: {
                    const nextMode = Theme.darkMode ? "light" : "dark";
                    if (typeof root.setThemeModeAction === "function") {
                        root.setThemeModeAction(nextMode);
                        return;
                    }

                    Theme.toggleDarkMode();
                }
            }

            PrimitiveLocal.PopupToggle {
                Layout.fillWidth: true
                icon: "󰌵"
                text: "Night Light"
                checked: root.nightModeState ? root.nightModeState.active : false
                toggleEnabled: root.nightModeState ? root.nightModeState.available : false
                accent: Theme.tertiary
                onClicked: {
                    if (root.nightModeState)
                        root.nightModeState.toggle();
                }
            }
        }

        Rectangle {
            width: parent.width
            radius: Theme.chipRadius
            color: Theme.surfaceContainer
            border.width: 1
            border.color: Theme.outline
            implicitHeight: themePresetColumn.implicitHeight + 20

            Column {
                id: themePresetColumn

                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                Text {
                    text: "Theme Presets"
                    color: Theme.roleOnSurfaceVariant
                    font.family: Theme.fontSans
                    font.pixelSize: 13
                }

                Flow {
                    width: parent.width
                    spacing: 8

                    Repeater {
                        model: Array.isArray(root.themeVariantOptions) ? root.themeVariantOptions : []

                        Rectangle {
                            id: themePresetChip

                            required property var modelData
                            readonly property string variantId: root.variantOptionId(modelData)
                            readonly property string variantLabel: root.variantOptionLabel(modelData)
                            readonly property bool active: root.normalizedVariantId(root.currentThemeVariant) === root.normalizedVariantId(variantId)
                            readonly property bool selectable: variantId.length > 0 && typeof root.setThemeVariantAction === "function"

                            radius: 13
                            implicitHeight: 28
                            implicitWidth: label.implicitWidth + 18
                            color: active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18) : Theme.surfaceContainerLow
                            border.width: 1
                            border.color: active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45) : Theme.outline
                            opacity: selectable ? 1 : 0.55

                            Text {
                                id: label

                                anchors.centerIn: parent
                                text: themePresetChip.variantLabel
                                color: themePresetChip.active ? Theme.primary : Theme.roleOnSurface
                                font.family: Theme.fontSans
                                font.pixelSize: 12
                                font.weight: themePresetChip.active ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: themePresetChip.selectable
                                onClicked: root.setThemeVariantAction(themePresetChip.variantId)
                            }
                        }
                    }
                }
            }
        }

        PrimitiveLocal.PopupMetricRow {
            width: parent.width
            label: "Network"
            value: root.connectivityState && root.connectivityState.networkConnected ? root.connectivityState.networkLabel : "offline"
            valueColor: root.connectivityState && root.connectivityState.networkConnected ? Theme.secondary : Theme.roleOnSurfaceVariant
        }

        PrimitiveLocal.PopupMetricRow {
            width: parent.width
            label: "Traffic"
            value: `↑ ${root.connectivityState ? root.connectivityState.networkUpRate : "0B"}  ↓ ${root.connectivityState ? root.connectivityState.networkDownRate : "0B"}`
            valueColor: Theme.roleOnSurface
        }

        PrimitiveLocal.PopupMetricRow {
            width: parent.width
            label: "Bluetooth"
            value: root.connectivityState && root.connectivityState.bluetoothEnabled ? root.connectivityState.bluetoothLabel : "off"
            valueColor: root.connectivityState && root.connectivityState.bluetoothEnabled ? Theme.primary : Theme.roleOnSurfaceVariant
        }
    }
}

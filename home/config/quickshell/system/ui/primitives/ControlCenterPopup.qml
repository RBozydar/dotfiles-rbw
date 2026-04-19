import QtQuick
import QtQuick.Layouts
import qs
import "." as PrimitiveLocal

Item {
    id: root

    required property var chromeBridge
    property var setThemeModeAction: null
    property var brightnessMonitor: null
    readonly property var audioState: root.chromeBridge ? root.chromeBridge.audio : null
    readonly property var connectivityState: root.chromeBridge ? root.chromeBridge.connectivity : null
    readonly property var nightModeState: root.chromeBridge ? root.chromeBridge.nightMode : null

    implicitWidth: popupColumn.implicitWidth
    implicitHeight: popupColumn.implicitHeight

    Column {
        id: popupColumn

        width: 344
        spacing: 14

        Text {
            text: "Control Center"
            color: Theme.onSurface
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

        PrimitiveLocal.PopupMetricRow {
            width: parent.width
            label: "Network"
            value: root.connectivityState && root.connectivityState.networkConnected ? root.connectivityState.networkLabel : "offline"
            valueColor: root.connectivityState && root.connectivityState.networkConnected ? Theme.secondary : Theme.onSurfaceVariant
        }

        PrimitiveLocal.PopupMetricRow {
            width: parent.width
            label: "Traffic"
            value: `↑ ${root.connectivityState ? root.connectivityState.networkUpRate : "0B"}  ↓ ${root.connectivityState ? root.connectivityState.networkDownRate : "0B"}`
            valueColor: Theme.onSurface
        }

        PrimitiveLocal.PopupMetricRow {
            width: parent.width
            label: "Bluetooth"
            value: root.connectivityState && root.connectivityState.bluetoothEnabled ? root.connectivityState.bluetoothLabel : "off"
            valueColor: root.connectivityState && root.connectivityState.bluetoothEnabled ? Theme.primary : Theme.onSurfaceVariant
        }
    }
}

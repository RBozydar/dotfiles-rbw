import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

Item {
    id: root

    property var brightnessMonitor: null

    implicitWidth: popupColumn.implicitWidth
    implicitHeight: popupColumn.implicitHeight

    Column {
        id: popupColumn

        width: 344
        spacing: 14

        Text {
            text: "Control Center"
            color: Theme.text
            font.family: Theme.fontSans
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }

        PopupSlider {
            width: parent.width
            label: "Volume"
            valueText: Audio.muted ? "muted" : `${Audio.volumePercent}%`
            accent: Theme.success
            value: Audio.volumeLevel
            onMoved: value => Audio.setVolume(Math.round(value * 150))
        }

        PopupSlider {
            width: parent.width
            label: "Brightness"
            valueText: brightnessMonitor?.available ? `${brightnessMonitor.brightnessPercent}%` : "unavailable"
            accent: Theme.warning
            sliderEnabled: brightnessMonitor?.available ?? false
            value: brightnessMonitor?.brightness ?? 0
            onMoved: value => brightnessMonitor?.setBrightness(value)
        }

        GridLayout {
            width: parent.width
            columns: 2
            rowSpacing: 8
            columnSpacing: 8

            PopupToggle {
                Layout.fillWidth: true
                icon: ""
                text: "Wi-Fi"
                checked: Connectivity.wifiEnabled
                toggleEnabled: Connectivity.wifiAvailable
                accent: Theme.accentStrong
                onClicked: Connectivity.toggleWifi()
            }

            PopupToggle {
                Layout.fillWidth: true
                icon: ""
                text: "Ethernet"
                checked: Connectivity.ethernetConnected
                toggleEnabled: Connectivity.ethernetAvailable
                accent: Theme.accent
                onClicked: Connectivity.toggleEthernet()
            }

            PopupToggle {
                Layout.fillWidth: true
                icon: ""
                text: "Bluetooth"
                checked: Connectivity.bluetoothEnabled
                toggleEnabled: Connectivity.bluetoothAvailable
                accent: Theme.accentStrong
                onClicked: Connectivity.toggleBluetooth()
            }

            PopupToggle {
                Layout.fillWidth: true
                icon: Theme.darkMode ? "󰖔" : "󰖨"
                text: Theme.darkMode ? "Dark Mode" : "Light Mode"
                checked: Theme.darkMode
                toggleEnabled: true
                accent: Theme.warning
                onClicked: Theme.toggleDarkMode()
            }

            PopupToggle {
                Layout.fillWidth: true
                icon: "󰌵"
                text: "Night Light"
                checked: NightMode.active
                toggleEnabled: NightMode.available
                accent: Theme.warning
                onClicked: NightMode.toggle()
            }
        }

        PopupMetricRow {
            width: parent.width
            label: "Network"
            value: Connectivity.networkConnected ? Connectivity.networkLabel : "offline"
            valueColor: Connectivity.networkConnected ? Theme.accentStrong : Theme.textMuted
        }

        PopupMetricRow {
            width: parent.width
            label: "Traffic"
            value: `↑ ${Connectivity.networkUpRate}  ↓ ${Connectivity.networkDownRate}`
            valueColor: Theme.text
        }

        PopupMetricRow {
            width: parent.width
            label: "Bluetooth"
            value: Connectivity.bluetoothEnabled ? Connectivity.bluetoothLabel : "off"
            valueColor: Connectivity.bluetoothEnabled ? Theme.accent : Theme.textMuted
        }
    }
}

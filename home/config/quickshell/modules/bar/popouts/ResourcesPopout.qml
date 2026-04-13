import QtQuick
import qs
import qs.components
import qs.services

Item {
    id: root

    signal openRequested()

    implicitWidth: 360
    implicitHeight: resourcesColumn.implicitHeight

    Column {
        id: resourcesColumn

        width: root.implicitWidth
        spacing: 12

        Text {
            text: "System Monitor"
            color: Theme.text
            font.family: Theme.fontSans
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }

        PopupMetricRow {
            width: parent.width
            label: "CPU"
            value: `${SystemStats.cpuUsage}%  ${SystemStats.formatTemperature(SystemStats.cpuTemp)}`
            valueColor: Theme.warning
        }

        PopupMetricRow {
            width: parent.width
            label: "GPU"
            value: `${SystemStats.formatMetric(SystemStats.gpuUsage)}  ${SystemStats.formatTemperature(SystemStats.gpuTemp)}`
            valueColor: Theme.accentStrong
        }

        PopupMetricRow {
            width: parent.width
            label: "VRAM"
            value: `${SystemStats.formatMetric(SystemStats.gpuMemoryUsage)}  ${SystemStats.formatMiB(SystemStats.gpuMemoryUsedMiB)} / ${SystemStats.formatMiB(SystemStats.gpuMemoryTotalMiB)}`
            valueColor: Theme.accent
        }

        PopupMetricRow {
            width: parent.width
            label: "RAM"
            value: `${SystemStats.ramUsage}%  ${SystemStats.formatGiB(SystemStats.ramUsedGiB)} / ${SystemStats.formatGiB(SystemStats.ramTotalGiB)}`
            valueColor: Theme.success
        }

        PopupButton {
            text: "Open btop"
            accent: Theme.warning
            onClicked: root.openRequested()
        }
    }
}

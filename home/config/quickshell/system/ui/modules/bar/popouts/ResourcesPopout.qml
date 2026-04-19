import QtQuick
import qs
import "../../../primitives" as BarPrimitives

Item {
    id: root

    signal openRequested

    required property var chromeBridge
    readonly property var systemStatsState: root.chromeBridge ? root.chromeBridge.systemStats : null
    implicitWidth: 360
    implicitHeight: resourcesColumn.implicitHeight

    Column {
        id: resourcesColumn

        width: root.implicitWidth
        spacing: 12

        Text {
            text: "System Monitor"
            color: Theme.onSurface
            font.family: Theme.fontSans
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }

        BarPrimitives.PopupMetricRow {
            width: parent.width
            label: "CPU"
            value: root.systemStatsState ? `${root.systemStatsState.cpuUsage}%  ${root.systemStatsState.formatTemperature(root.systemStatsState.cpuTemp)}` : "--"
            valueColor: Theme.tertiary
        }

        BarPrimitives.PopupMetricRow {
            width: parent.width
            label: "GPU"
            value: root.systemStatsState ? `${root.systemStatsState.formatMetric(root.systemStatsState.gpuUsage)}  ${root.systemStatsState.formatTemperature(root.systemStatsState.gpuTemp)}` : "--"
            valueColor: Theme.secondary
        }

        BarPrimitives.PopupMetricRow {
            width: parent.width
            label: "VRAM"
            value: root.systemStatsState ? `${root.systemStatsState.formatMetric(root.systemStatsState.gpuMemoryUsage)}  ${root.systemStatsState.formatMiB(root.systemStatsState.gpuMemoryUsedMiB)} / ${root.systemStatsState.formatMiB(root.systemStatsState.gpuMemoryTotalMiB)}` : "--"
            valueColor: Theme.primary
        }

        BarPrimitives.PopupMetricRow {
            width: parent.width
            label: "RAM"
            value: root.systemStatsState ? `${root.systemStatsState.ramUsage}%  ${root.systemStatsState.formatGiB(root.systemStatsState.ramUsedGiB)} / ${root.systemStatsState.formatGiB(root.systemStatsState.ramTotalGiB)}` : "--"
            valueColor: Theme.primary
        }

        BarPrimitives.PopupButton {
            text: "Open btop"
            accent: Theme.tertiary
            onClicked: root.openRequested()
        }
    }
}

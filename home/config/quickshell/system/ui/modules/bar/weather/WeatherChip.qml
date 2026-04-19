import QtQuick
import qs
import "../../../primitives" as BarPrimitives

BarPrimitives.StatusChip {
    id: root

    required property var chromeBridge
    readonly property var weatherState: root.chromeBridge ? root.chromeBridge.weather : null
    readonly property color weatherAccent: {
        switch (root.weatherState ? root.weatherState.summaryKind : "unknown") {
        case "sunny":
        case "partly-cloudy":
            return Theme.tertiary;
        case "rain":
        case "fog":
            return Theme.secondary;
        case "snow":
            return Theme.onSurface;
        case "storm":
            return Theme.error;
        default:
            return Theme.onSurfaceVariant;
        }
    }

    icon: root.weatherState ? root.weatherState.icon : "☁"
    accent: weatherAccent
    label: root.weatherState ? `${root.weatherState.temperature} • feels ${root.weatherState.feelsLike} • ${root.weatherState.wind}` : "--° • feels --° • --"
    maximumLabelWidth: 220
}

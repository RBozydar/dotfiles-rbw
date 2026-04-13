import QtQuick
import qs
import qs.components
import qs.services

StatusChip {
    id: root

    readonly property color weatherAccent: {
        switch (Weather.summaryKind) {
        case "sunny":
        case "partly-cloudy":
            return Theme.warning;
        case "rain":
        case "fog":
            return Theme.accentStrong;
        case "snow":
            return Theme.text;
        case "storm":
            return Theme.danger;
        default:
            return Theme.textMuted;
        }
    }

    icon: Weather.icon
    accent: weatherAccent
    label: Weather.temperature
    maximumLabelWidth: 56
}

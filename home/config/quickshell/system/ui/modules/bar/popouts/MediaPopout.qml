import QtQuick
import qs
import "../../../primitives" as BarPrimitives

Item {
    id: root

    required property var chromeBridge
    readonly property var mediaState: root.chromeBridge ? root.chromeBridge.media : null
    implicitWidth: 380
    implicitHeight: mediaColumn.implicitHeight

    Column {
        id: mediaColumn

        width: root.implicitWidth
        spacing: 12

        Text {
            text: "Media"
            color: Theme.onSurface
            font.family: Theme.fontSans
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }

        BarPrimitives.PopupMetricRow {
            width: parent.width
            label: "Title"
            value: root.mediaState ? root.mediaState.title : "No media"
            valueColor: Theme.primary
        }

        BarPrimitives.PopupMetricRow {
            width: parent.width
            label: "Artist"
            value: root.mediaState && root.mediaState.artist.length > 0 ? root.mediaState.artist : "--"
        }

        BarPrimitives.PopupMetricRow {
            width: parent.width
            label: "Player"
            value: root.mediaState && root.mediaState.identity.length > 0 ? root.mediaState.identity : "--"
        }

        Rectangle {
            width: parent.width
            height: 10
            radius: 5
            color: Theme.surfaceContainerLow
            border.width: 1
            border.color: Theme.outline
            visible: root.mediaState ? root.mediaState.available : false

            Rectangle {
                width: parent.width * (root.mediaState ? root.mediaState.progress : 0)
                height: parent.height
                radius: parent.radius
                color: Theme.secondary
            }
        }

        Row {
            spacing: 8

            BarPrimitives.PopupButton {
                text: "Prev"
                accent: Theme.onSurface
                onClicked: {
                    if (root.mediaState)
                        root.mediaState.previous();
                }
            }

            BarPrimitives.PopupButton {
                text: root.mediaState && root.mediaState.playing ? "Pause" : "Play"
                accent: Theme.primary
                onClicked: {
                    if (root.mediaState)
                        root.mediaState.toggle();
                }
            }

            BarPrimitives.PopupButton {
                text: "Next"
                accent: Theme.onSurface
                onClicked: {
                    if (root.mediaState)
                        root.mediaState.next();
                }
            }

            BarPrimitives.PopupButton {
                text: "Raise"
                accent: Theme.secondary
                onClicked: {
                    if (root.mediaState)
                        root.mediaState.raise();
                }
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services

Item {
    id: root

    implicitWidth: 380
    implicitHeight: mediaColumn.implicitHeight

    Column {
        id: mediaColumn

        width: root.implicitWidth
        spacing: 12

        Text {
            text: "Media"
            color: Theme.text
            font.family: Theme.fontSans
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }

        PopupMetricRow {
            width: parent.width
            label: "Title"
            value: Media.title
            valueColor: Theme.accent
        }

        PopupMetricRow {
            width: parent.width
            label: "Artist"
            value: Media.artist.length > 0 ? Media.artist : "--"
        }

        PopupMetricRow {
            width: parent.width
            label: "Player"
            value: Media.identity.length > 0 ? Media.identity : "--"
        }

        Rectangle {
            width: parent.width
            height: 10
            radius: 5
            color: Theme.chip
            border.width: 1
            border.color: Theme.border
            visible: Media.available

            Rectangle {
                width: parent.width * Media.progress
                height: parent.height
                radius: parent.radius
                color: Theme.accentStrong
            }
        }

        Row {
            spacing: 8

            PopupButton {
                text: "Prev"
                accent: Theme.text
                onClicked: Media.previous()
            }

            PopupButton {
                text: Media.playing ? "Pause" : "Play"
                accent: Theme.accent
                onClicked: Media.toggle()
            }

            PopupButton {
                text: "Next"
                accent: Theme.text
                onClicked: Media.next()
            }

            PopupButton {
                text: "Raise"
                accent: Theme.accentStrong
                onClicked: Media.raise()
            }
        }
    }
}

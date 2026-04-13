import QtQuick
import QtQuick.Layouts
import qs
import qs.services

Item {
    id: root

    property int maxListHeight: 380
    readonly property real targetListHeight: Notifications.history.length === 0 ? emptyState.implicitHeight : notificationColumn.implicitHeight + Theme.padding

    implicitWidth: 420
    implicitHeight: headerBlock.implicitHeight + Theme.gap + Math.min(maxListHeight, targetListHeight)

    Column {
        id: contentColumn

        width: root.implicitWidth
        spacing: Theme.gap

        RowLayout {
            id: headerBlock

            width: parent.width

            ColumnLayout {
                Layout.fillWidth: true

                Text {
                    text: "Notification Center"
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }

                Text {
                    text: Notifications.history.length > 0 ? `${Notifications.history.length} items in this session` : "All quiet for now"
                    color: Theme.textMuted
                    font.family: Theme.fontSans
                    font.pixelSize: 12
                }
            }

            Rectangle {
                width: clearLabel.implicitWidth + 16
                height: 30
                radius: 15
                color: Theme.chip
                border.width: 1
                border.color: Theme.border

                Text {
                    id: clearLabel

                    anchors.centerIn: parent
                    text: "Clear"
                    color: Theme.text
                    font.family: Theme.fontSans
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: Notifications.history.length > 0
                    onClicked: Notifications.clearHistory()
                }
            }
        }

        Flickable {
            id: scroller

            width: parent.width
            height: Math.min(root.maxListHeight, root.targetListHeight)
            contentWidth: width
            contentHeight: notificationColumn.implicitHeight + Theme.padding
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            bottomMargin: Theme.padding
            interactive: contentHeight > height

            Column {
                id: notificationColumn

                width: scroller.width
                spacing: Theme.gap

                Rectangle {
                    id: emptyState

                    visible: Notifications.history.length === 0
                    width: parent.width
                    height: 120
                    implicitHeight: 120
                    radius: Theme.radius
                    color: Theme.panelSolid
                    border.width: 1
                    border.color: Theme.border

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "All quiet for now"
                            color: Theme.text
                            font.family: Theme.fontSans
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Incoming notifications will land here."
                            color: Theme.textMuted
                            font.family: Theme.fontSans
                            font.pixelSize: 13
                        }
                    }
                }

                Repeater {
                    model: Notifications.history

                    Rectangle {
                        required property var modelData

                        width: notificationColumn.width
                        radius: Theme.radius
                        color: Theme.panelSolid
                        border.width: 1
                        border.color: modelData.urgency === 2 ? Theme.danger : Theme.border
                        height: contentWrapper.implicitHeight + 24

                        Column {
                            id: contentWrapper

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Theme.padding
                            spacing: 8

                            RowLayout {
                                width: parent.width

                                Text {
                                    text: modelData.appName
                                    color: Theme.accent
                                    font.family: Theme.fontSans
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: Theme.chip
                                    border.width: 1
                                    border.color: Theme.border

                                    Text {
                                        anchors.centerIn: parent
                                        text: "×"
                                        color: Theme.textMuted
                                        font.family: Theme.fontSans
                                        font.pixelSize: 14
                                        font.weight: Font.DemiBold
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: Notifications.clearEntry(modelData.key)
                                    }
                                }

                                Text {
                                    text: Qt.formatDateTime(new Date(modelData.timestamp), "hh:mm:ss yyyy-MM-dd")
                                    color: Theme.textMuted
                                    font.family: Theme.fontMono
                                    font.pixelSize: 11
                                }
                            }

                            Text {
                                text: modelData.summary
                                color: Theme.text
                                font.family: Theme.fontSans
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            }

                            Text {
                                visible: modelData.body.length > 0
                                width: parent.width
                                text: modelData.body
                                color: Theme.textMuted
                                font.family: Theme.fontSans
                                font.pixelSize: 13
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                textFormat: Text.PlainText
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Notifications.activateEntry(modelData.key)
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: Theme.padding
                }
            }
        }
    }
}

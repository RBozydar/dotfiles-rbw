pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs

Item {
    id: root

    required property var notificationsBridge

    property int maxListHeight: 380
    readonly property int notificationsRevision: notificationsBridge ? Number(notificationsBridge.storeRevision) : 0
    readonly property var historyEntries: {
        const revision = notificationsRevision;
        return notificationsBridge ? notificationsBridge.history : [];
    }
    readonly property real targetListHeight: historyEntries.length === 0 ? emptyState.implicitHeight : notificationColumn.implicitHeight + Theme.padding

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
                    color: Theme.roleOnSurface
                    font.family: Theme.fontSans
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                }

                Text {
                    text: root.historyEntries.length > 0 ? `${root.historyEntries.length} items in this session` : "All quiet for now"
                    color: Theme.roleOnSurfaceVariant
                    font.family: Theme.fontSans
                    font.pixelSize: 12
                }
            }

            Rectangle {
                Layout.preferredWidth: clearLabel.implicitWidth + 16
                Layout.preferredHeight: 30
                radius: 15
                color: Theme.surfaceContainerLow
                border.width: 1
                border.color: Theme.outline

                Text {
                    id: clearLabel

                    anchors.centerIn: parent
                    text: "Clear"
                    color: Theme.roleOnSurface
                    font.family: Theme.fontSans
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.historyEntries.length > 0
                    onClicked: {
                        if (root.notificationsBridge)
                            root.notificationsBridge.clearHistory();
                    }
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

                    visible: root.historyEntries.length === 0
                    width: parent.width
                    height: 120
                    implicitHeight: 120
                    radius: Theme.radius
                    color: Theme.surfaceContainer
                    border.width: 1
                    border.color: Theme.outline

                    Column {
                        anchors.centerIn: parent
                        spacing: 8

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "All quiet for now"
                            color: Theme.roleOnSurface
                            font.family: Theme.fontSans
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Incoming notifications will land here."
                            color: Theme.roleOnSurfaceVariant
                            font.family: Theme.fontSans
                            font.pixelSize: 13
                        }
                    }
                }

                Repeater {
                    model: root.historyEntries

                    Rectangle {
                        id: entryCard

                        required property var modelData

                        width: notificationColumn.width
                        radius: Theme.radius
                        color: Theme.surfaceContainer
                        border.width: 1
                        border.color: entryCard.modelData.urgency === 2 ? Theme.error : Theme.outline
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
                                    text: entryCard.modelData.appName
                                    color: Theme.primary
                                    font.family: Theme.fontSans
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    Layout.preferredWidth: 24
                                    Layout.preferredHeight: 24
                                    radius: 12
                                    color: Theme.surfaceContainerLow
                                    border.width: 1
                                    border.color: Theme.outline

                                    Text {
                                        anchors.centerIn: parent
                                        text: "×"
                                        color: Theme.roleOnSurfaceVariant
                                        font.family: Theme.fontSans
                                        font.pixelSize: 14
                                        font.weight: Font.DemiBold
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            if (root.notificationsBridge)
                                                root.notificationsBridge.clearEntry(entryCard.modelData.key);
                                        }
                                    }
                                }

                                Text {
                                    text: Qt.formatDateTime(new Date(entryCard.modelData.timestamp), "hh:mm:ss yyyy-MM-dd")
                                    color: Theme.roleOnSurfaceVariant
                                    font.family: Theme.fontMono
                                    font.pixelSize: 11
                                }
                            }

                            Text {
                                text: entryCard.modelData.summary
                                color: Theme.roleOnSurface
                                font.family: Theme.fontSans
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                            }

                            Text {
                                visible: entryCard.modelData.body.length > 0
                                width: parent.width
                                text: entryCard.modelData.body
                                color: Theme.roleOnSurfaceVariant
                                font.family: Theme.fontSans
                                font.pixelSize: 13
                                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                                textFormat: Text.PlainText
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                if (root.notificationsBridge)
                                    root.notificationsBridge.activateEntry(entryCard.modelData.key);
                            }
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

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs
import "." as PrimitiveLocal

Rectangle {
    id: root

    visible: trayRepeater.count > 0
    radius: Theme.chipRadius
    color: Theme.surfaceContainerLow
    border.width: 1
    border.color: Theme.outline
    implicitHeight: Theme.barInnerHeight - 8
    implicitWidth: trayRow.implicitWidth + (Theme.chipPadding * 2)

    RowLayout {
        id: trayRow

        anchors.centerIn: parent
        spacing: 8

        Repeater {
            id: trayRepeater

            model: SystemTray.items.values

            PrimitiveLocal.TrayItem {
                required property var modelData

                item: modelData
            }
        }
    }
}

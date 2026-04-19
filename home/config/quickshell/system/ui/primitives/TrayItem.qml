import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs

MouseArea {
    id: root

    required property SystemTrayItem item

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    implicitWidth: 18
    implicitHeight: 18

    function showMenu(): void {
        if (!root.item?.hasMenu)
            return;

        const anchorX = root.x + Math.round(root.width / 2);
        const anchorY = root.y + root.height + 8;
        root.item.display(root.QsWindow.window, anchorX, anchorY);
    }

    onPressed: event => {
        if (event.button === Qt.LeftButton) {
            if (root.item.onlyMenu && root.item.hasMenu)
                root.showMenu();
            else
                root.item.activate();
        } else if (event.button === Qt.RightButton) {
            if (root.item.hasMenu)
                root.showMenu();
            else
                root.item.secondaryActivate();
        } else if (event.button === Qt.MiddleButton) {
            root.item.secondaryActivate();
        }

        event.accepted = true;
    }

    onWheel: wheel => {
        root.item.scroll(Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y) ? wheel.angleDelta.x : wheel.angleDelta.y, Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y));
        wheel.accepted = true;
    }

    Rectangle {
        anchors.fill: parent
        radius: 9
        color: root.containsMouse ? Theme.surfaceContainerHigh : "transparent"
    }

    IconImage {
        anchors.fill: parent
        anchors.margins: 1
        source: root.item.icon
    }
}

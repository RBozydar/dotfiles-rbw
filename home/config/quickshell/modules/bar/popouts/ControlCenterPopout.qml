import QtQuick
import qs.components

Item {
    id: root

    property var brightnessMonitor: null

    implicitWidth: controlCenter.implicitWidth
    implicitHeight: controlCenter.implicitHeight

    ControlCenterPopup {
        id: controlCenter

        brightnessMonitor: root.brightnessMonitor
    }
}

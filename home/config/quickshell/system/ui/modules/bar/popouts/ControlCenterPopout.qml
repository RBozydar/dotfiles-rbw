import QtQuick
import "../../../primitives" as BarPrimitives

Item {
    id: root

    property var brightnessMonitor: null
    property var setThemeModeAction: null
    required property var chromeBridge

    implicitWidth: controlCenter.implicitWidth
    implicitHeight: controlCenter.implicitHeight

    BarPrimitives.ControlCenterPopup {
        id: controlCenter

        chromeBridge: root.chromeBridge
        brightnessMonitor: root.brightnessMonitor
        setThemeModeAction: root.setThemeModeAction
    }
}

import QtQuick
import "../../../primitives" as BarPrimitives

Item {
    id: root

    property var brightnessMonitor: null
    property var setThemeModeAction: null
    property var setThemeVariantAction: null
    property string currentThemeVariant: "tonal-spot"
    property var themeVariantOptions: [
        {
            id: "tonal-spot",
            label: "Default"
        },
        {
            id: "evangelion",
            label: "Evangelion"
        },
        {
            id: "moon-space",
            label: "Moon Space"
        }
    ]
    required property var chromeBridge

    implicitWidth: controlCenter.implicitWidth
    implicitHeight: controlCenter.implicitHeight

    BarPrimitives.ControlCenterPopup {
        id: controlCenter

        chromeBridge: root.chromeBridge
        brightnessMonitor: root.brightnessMonitor
        setThemeModeAction: root.setThemeModeAction
        setThemeVariantAction: root.setThemeVariantAction
        currentThemeVariant: root.currentThemeVariant
        themeVariantOptions: root.themeVariantOptions
    }
}

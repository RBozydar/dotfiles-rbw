import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

Item {
    id: root

    required property var screen
    required property var popoutState

    property int popupPadding: Theme.padding
    property int overlapHeight: 22
    property int bridgeOverlapIntoBar: 4
    property real slideDistance: 18
    property bool surfaceEnabled: true
    readonly property bool solidPopup: root.popoutState.displayName === "weather"
    readonly property color surfaceColor: root.solidPopup ? Theme.surfaceContainer : Theme.surface

    readonly property bool open: root.surfaceEnabled && root.popoutState.open
    readonly property bool popupVisible: root.surfaceEnabled && root.popoutState.visible
    readonly property bool hovered: popupCardHover.hovered || bridgeHover.hovered

    onHoveredChanged: root.popoutState.popupHovered = hovered
    onPopupVisibleChanged: {
        if (!root.popupVisible)
            root.popoutState.popupHovered = false;
    }

    onOpenChanged: {
        if (root.open) {
            clearTimer.stop();
            popupWindow.retriggerReveal();
        } else if (root.popupVisible) {
            popupWindow.beginHide();
            clearTimer.restart();
        }
    }

    Timer {
        id: clearTimer

        interval: 180
        repeat: false
        onTriggered: root.popoutState.clearDisplay()
    }

    PanelWindow {
        id: popupWindow

        visible: root.popupVisible
        screen: root.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        WlrLayershell.layer: WlrLayer.Overlay

        anchors {
            top: true
            left: true
            right: true
        }

        // qmllint disable unqualified unresolved-type missing-property
        margins.top: Theme.barOuterHeight - Theme.barMargin - root.bridgeOverlapIntoBar
        // qmllint enable unqualified unresolved-type missing-property

        implicitHeight: root.overlapHeight + popupHeight
        mask: Region {
            item: hoverBridge

            Region {
                item: popupClip
            }
        }

        readonly property int contentWidth: root.popupVisible ? Math.max(root.popoutState.displayWidth, popupLoader.implicitWidth > 0 ? popupLoader.implicitWidth : root.popoutState.displayWidth) : 0
        readonly property int popupWidth: root.popupVisible ? contentWidth + (root.popupPadding * 2) : 0
        readonly property int popupHeight: root.popupVisible ? popupLoader.implicitHeight + (root.popupPadding * 2) : 0
        readonly property int popupX: {
            const target = root.popoutState.displayTarget;
            const popupWidth = popupWindow.popupWidth;
            if (!target || !root.QsWindow)
                return Theme.barMargin;

            const mappedX = root.QsWindow.mapFromItem(target, (target.width - popupWidth) / 2, 0).x;
            const maxX = Math.max(Theme.barMargin, popupWindow.width - popupWidth - Theme.barMargin);
            return Math.max(Theme.barMargin, Math.min(maxX, mappedX));
        }

        function retriggerReveal(): void {
            popupCard.revealed = false;
            Qt.callLater(() => {
                popupCard.revealed = root.open;
            });
        }

        function beginHide(): void {
            popupCard.revealed = false;
        }

        Rectangle {
            id: hoverBridge

            visible: root.popupVisible
            x: popupWindow.popupX + ((popupWindow.popupWidth - width) / 2)
            y: 0
            width: root.popupVisible ? Math.min(Math.max((root.popoutState.displayTarget?.width ?? 44) + 24, 60), Math.max(60, popupWindow.popupWidth - 24)) : 0
            height: root.popupVisible ? root.overlapHeight : 0
            radius: Math.min(height / 2, Theme.chipRadius)
            color: root.surfaceColor
            border.width: 0

            HoverHandler {
                id: bridgeHover
            }
        }

        Item {
            id: popupClip

            visible: root.popupVisible
            x: popupWindow.popupX
            y: root.overlapHeight - 1
            width: popupWindow.popupWidth
            height: popupWindow.popupHeight
            clip: true

            Rectangle {
                id: popupCard

                property bool revealed: false

                visible: root.popupVisible
                width: parent.width
                height: parent.height
                y: popupCard.revealed ? 0 : -root.slideDistance
                opacity: popupCard.revealed ? 1 : 0
                radius: Theme.radius
                color: root.surfaceColor
                border.width: 1
                border.color: Theme.outline

                HoverHandler {
                    id: popupCardHover
                }

                Behavior on y {
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }

                Loader {
                    id: popupLoader

                    anchors.fill: parent
                    anchors.margins: root.popupPadding
                    sourceComponent: root.popoutState.displayContent
                }
            }
        }

        Connections {
            target: root.popoutState

            function onDisplayNameChanged(): void {
                if (root.open)
                    popupWindow.retriggerReveal();
            }
        }
    }
}

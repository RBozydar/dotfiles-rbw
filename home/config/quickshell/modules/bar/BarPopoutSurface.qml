import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

Item {
    id: root

    required property var screen
    required property var state

    property int popupPadding: Theme.padding
    property int overlapHeight: 22
    property int bridgeOverlapIntoBar: 4
    property real slideDistance: 18
    property bool surfaceEnabled: true

    readonly property bool open: root.surfaceEnabled && root.state.open
    readonly property bool popupVisible: root.surfaceEnabled && root.state.visible
    readonly property bool hovered: popupCardHover.hovered || bridgeHover.hovered

    onHoveredChanged: root.state.popupHovered = hovered
    onPopupVisibleChanged: {
        if (!root.popupVisible)
            root.state.popupHovered = false;
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
        onTriggered: root.state.clearDisplay()
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

        margins.top: Theme.barOuterHeight - Theme.barMargin - root.bridgeOverlapIntoBar

        implicitHeight: root.overlapHeight + popupHeight
        mask: Region {
            item: hoverBridge

            Region {
                item: popupClip
            }
        }

        readonly property int contentWidth: root.popupVisible ? Math.max(root.state.displayWidth, popupLoader.item?.implicitWidth ?? root.state.displayWidth) : 0
        readonly property int popupWidth: root.popupVisible ? contentWidth + (root.popupPadding * 2) : 0
        readonly property int popupHeight: root.popupVisible ? (popupLoader.item?.implicitHeight ?? 0) + (root.popupPadding * 2) : 0
        readonly property int popupX: {
            const target = root.state.displayTarget;
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
            width: root.popupVisible ? Math.min(Math.max((root.state.displayTarget?.width ?? 44) + 24, 60), Math.max(60, popupWindow.popupWidth - 24)) : 0
            height: root.popupVisible ? root.overlapHeight : 0
            radius: Math.min(height / 2, Theme.chipRadius)
            color: Theme.panel
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
                color: Theme.panel
                border.width: 1
                border.color: Theme.border

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
                    sourceComponent: root.state.displayContent
                }
            }
        }

        Connections {
            target: root.state

            function onDisplayNameChanged(): void {
                if (root.open)
                    popupWindow.retriggerReveal();
            }
        }
    }
}

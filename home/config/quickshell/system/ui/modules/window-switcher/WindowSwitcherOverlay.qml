pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs

Variants {
    id: root

    required property var shell
    model: Quickshell.screens

    PanelWindow {
        id: panel

        required property var modelData
        readonly property var switcherState: root.shell && root.shell.windowSwitcherBridge ? root.shell.windowSwitcherBridge.state : ({
                open: false,
                entries: [],
                selectedIndex: -1,
                selectedAddress: ""
            })
        readonly property var focusedScreen: root.shell && root.shell.shellChromeBridge ? root.shell.shellChromeBridge.focusedScreen : null
        readonly property bool onFocusedScreen: focusedScreen !== null && String(focusedScreen.name || "") === String(modelData.name || "")
        readonly property var entries: Array.isArray(switcherState.entries) ? switcherState.entries : []
        readonly property int selectedIndex: Number(switcherState.selectedIndex)

        screen: modelData
        visible: switcherState.open === true && onFocusedScreen
        color: "transparent"
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        onVisibleChanged: {
            if (visible && root.shell && typeof root.shell.windowSwitcherSyncSnapshot === "function")
                root.shell.windowSwitcherSyncSnapshot("window_switcher.overlay.visible");
        }

        Item {
            anchors.fill: parent
            focus: panel.visible

            Keys.onPressed: event => {
                const hasShift = (event.modifiers & Qt.ShiftModifier) !== 0;

                if (event.key === Qt.Key_Tab) {
                    root.shell.cycleWindowSwitcher(hasShift ? -1 : 1);
                    event.accepted = true;
                    return;
                }

                if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                    root.shell.cycleWindowSwitcher(1);
                    event.accepted = true;
                    return;
                }

                if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                    root.shell.cycleWindowSwitcher(-1);
                    event.accepted = true;
                    return;
                }

                if (event.key === Qt.Key_Escape) {
                    root.shell.cancelWindowSwitcher();
                    event.accepted = true;
                    return;
                }

                if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    root.shell.acceptWindowSwitcher();
                    event.accepted = true;
                }
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(Theme.scrim.r, Theme.scrim.g, Theme.scrim.b, 0.42)
            }

            Rectangle {
                id: card

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(Math.max(parent.width * 0.72, 860), parent.width - Theme.padding * 4)
                height: Math.min(220, parent.height - Theme.padding * 6)
                radius: Theme.radius
                color: Theme.surfaceContainerHigh
                border.width: 1
                border.color: Theme.outline
                opacity: Theme.moduleOpacity("window_switcher.surface", 0.96)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.padding
                    spacing: Theme.gap

                    RowLayout {
                        Layout.fillWidth: true

                        Text {
                            text: "Window Switcher"
                            color: Theme.roleOnSurface
                            font.family: Theme.fontSans
                            font.pixelSize: 22
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }

                        Text {
                            text: `${panel.entries.length} windows`
                            color: Theme.roleOnSurfaceVariant
                            font.family: Theme.fontMono
                            font.pixelSize: 12
                        }
                    }

                    Flickable {
                        id: listFlick

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentWidth: itemsRow.implicitWidth
                        contentHeight: itemsRow.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        RowLayout {
                            id: itemsRow
                            spacing: Theme.gap
                            height: listFlick.height

                            Repeater {
                                model: panel.entries

                                Rectangle {
                                    id: entryCard

                                    required property var modelData
                                    required property int index
                                    readonly property bool selected: index === panel.selectedIndex
                                    readonly property string workspaceLabel: Number(modelData.workspaceId) >= 1 ? `ws ${modelData.workspaceId}` : "special"

                                    Layout.preferredWidth: Math.min(260, Math.max(188, card.width * 0.24))
                                    Layout.fillHeight: true
                                    radius: Theme.chipRadius
                                    color: selected ? Theme.primaryContainer : Theme.surfaceContainer
                                    border.width: selected ? 2 : 1
                                    border.color: selected ? Theme.primary : Theme.outline

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: Theme.padding
                                        spacing: 8

                                        Text {
                                            text: String(entryCard.modelData.title || "(untitled)")
                                            color: entryCard.selected ? Theme.roleOnPrimaryContainer : Theme.roleOnSurface
                                            font.family: Theme.fontSans
                                            font.pixelSize: 15
                                            font.weight: entryCard.selected ? Font.DemiBold : Font.Medium
                                            elide: Text.ElideRight
                                            wrapMode: Text.NoWrap
                                        }

                                        Text {
                                            text: String(entryCard.modelData.className || "unknown")
                                            color: entryCard.selected ? Theme.roleOnPrimaryContainer : Theme.roleOnSurfaceVariant
                                            font.family: Theme.fontMono
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                            wrapMode: Text.NoWrap
                                        }

                                        Rectangle {
                                            width: parent.width
                                            height: 1
                                            color: entryCard.selected ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35) : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.35)
                                        }

                                        Text {
                                            text: entryCard.workspaceLabel
                                            color: entryCard.selected ? Theme.roleOnPrimaryContainer : Theme.roleOnSurface
                                            font.family: Theme.fontSans
                                            font.pixelSize: 12
                                            opacity: 0.9
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Tab / arrows cycle • Enter accept • Esc cancel"
                        color: Theme.roleOnSurfaceVariant
                        font.family: Theme.fontSans
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }
}

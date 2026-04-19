pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "." as BarUi
import qs
import "popouts" as BarPopouts

PanelWindow {
    id: root

    required property var shell
    required property var commandAdapter
    required property var chromeBridge
    required property var workspaceBridge
    required property var notificationsBridge

    readonly property var brightnessMonitor: {
        if (!root.chromeBridge || typeof root.chromeBridge.brightnessMonitorForScreen !== "function")
            return null;

        const _ = root.chromeBridge.brightnessMonitors;
        return root.chromeBridge.brightnessMonitorForScreen(root.screen);
    }

    color: "transparent"
    implicitHeight: Theme.barOuterHeight
    exclusiveZone: Theme.barOuterHeight
    WlrLayershell.layer: WlrLayer.Top
    mask: Region {
        item: barFrame
    }

    anchors {
        top: true
        left: true
        right: true
    }

    function runCommand(command): void {
        if (!commandAdapter)
            return;

        commandAdapter.exec(command);
    }

    function anyPopoutTriggerHovered(): bool {
        return centerCluster.weatherChip.hovered || centerCluster.clockChip.hovered || (rightCluster.mediaChip.visible && rightCluster.mediaChip.hovered) || (rightCluster.homeChip.visible && rightCluster.homeChip.hovered) || rightCluster.controlCenterHovered || rightCluster.resourcesChip.hovered || rightCluster.notificationChip.hovered;
    }

    function syncPopout(): void {
        if (root.shell.sessionOverlayOpen || root.shell.launcherOverlayOpen) {
            closePopoutCheck.stop();
            popoutState.clearAll();
            return;
        }

        if (centerCluster.weatherChip.hovered) {
            closePopoutCheck.stop();
            popoutState.show("weather", centerCluster.weatherChip, weatherPopupContent, 820);
            return;
        }

        if (centerCluster.clockChip.hovered) {
            closePopoutCheck.stop();
            popoutState.show("calendar", centerCluster.clockChip, calendarPopupContent, 330);
            return;
        }

        if (rightCluster.mediaChip.visible && rightCluster.mediaChip.hovered) {
            closePopoutCheck.stop();
            popoutState.show("media", rightCluster.mediaChip, mediaPopupContent, 380);
            return;
        }

        if (rightCluster.homeChip.visible && rightCluster.homeChip.hovered) {
            closePopoutCheck.stop();
            popoutState.show("home-assistant", rightCluster.homeChip, homeAssistantPopupContent, 360);
            return;
        }

        if (rightCluster.controlCenterHovered) {
            closePopoutCheck.stop();
            popoutState.show("control-center", rightCluster.hoveredControlCenterTarget, controlCenterPopupContent, 344);
            return;
        }

        if (rightCluster.resourcesChip.hovered) {
            closePopoutCheck.stop();
            popoutState.show("resources", rightCluster.resourcesChip, resourcesPopupContent, 360);
            return;
        }

        if (rightCluster.notificationChip.hovered) {
            closePopoutCheck.stop();
            popoutState.show("notifications", rightCluster.notificationChip, notificationsPopupContent, 420);
            return;
        }

        if (popoutState.popupHovered)
            closePopoutCheck.stop();
        else
            closePopoutCheck.restart();
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    BarUi.BarPopoutState {
        id: popoutState
    }

    Timer {
        id: closePopoutCheck

        interval: 180
        repeat: false
        onTriggered: {
            if (!root.anyPopoutTriggerHovered() && !popoutState.popupHovered)
                popoutState.hide();
        }
    }

    Rectangle {
        id: barFrame

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Theme.barMargin
        radius: Theme.radius
        color: Theme.surface
        border.width: 0
        height: Theme.barOuterHeight - (Theme.barMargin * 2)

        Item {
            anchors.fill: parent
            anchors.leftMargin: Theme.padding
            anchors.rightMargin: Theme.padding

            BarUi.BarPresentationModel {
                id: presentationModel

                bridge: root.workspaceBridge
                screen: root.screen
            }

            BarUi.BarWorkspaceStrip {
                id: leftCluster

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                presentationModel: presentationModel
            }

            BarUi.BarCenter {
                id: centerCluster

                anchors.centerIn: parent
                clock: clock
                chromeBridge: root.chromeBridge
            }

            BarUi.BarRight {
                id: rightCluster

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                shell: root.shell
                screen: root.screen
                chromeBridge: root.chromeBridge
                brightnessMonitor: root.brightnessMonitor
                runCommand: root.runCommand
                notificationsBridge: root.notificationsBridge
            }

            Component {
                id: weatherPopupContent

                BarPopouts.WeatherPopout {
                    chromeBridge: root.chromeBridge
                }
            }

            Component {
                id: mediaPopupContent

                BarPopouts.MediaPopout {
                    chromeBridge: root.chromeBridge
                }
            }

            Component {
                id: calendarPopupContent

                BarPopouts.CalendarPopout {
                    clock: clock
                }
            }

            Component {
                id: controlCenterPopupContent

                BarPopouts.ControlCenterPopout {
                    brightnessMonitor: root.brightnessMonitor
                    chromeBridge: root.chromeBridge
                    setThemeModeAction: function (mode) {
                        if (!root.shell || typeof root.shell.setThemeMode !== "function")
                            return;
                        root.shell.setThemeMode(mode);
                    }
                }
            }

            Component {
                id: homeAssistantPopupContent

                BarPopouts.HomeAssistantPopout {
                    chromeBridge: root.chromeBridge
                }
            }

            Component {
                id: resourcesPopupContent

                BarPopouts.ResourcesPopout {
                    chromeBridge: root.chromeBridge
                    onOpenRequested: root.runCommand(["ghostty", "-e", "btop"])
                }
            }

            Component {
                id: notificationsPopupContent

                BarPopouts.NotificationsPopout {
                    notificationsBridge: root.notificationsBridge
                }
            }

            Connections {
                target: centerCluster.weatherChip

                function onHoveredChanged(): void {
                    root.syncPopout();
                }
            }

            Connections {
                target: centerCluster.clockChip

                function onHoveredChanged(): void {
                    root.syncPopout();
                }
            }

            Connections {
                target: rightCluster.mediaChip

                function onHoveredChanged(): void {
                    root.syncPopout();
                }

                function onVisibleChanged(): void {
                    root.syncPopout();
                }
            }

            Connections {
                target: rightCluster.homeChip

                function onHoveredChanged(): void {
                    if (rightCluster.homeChip.hovered && root.chromeBridge && root.chromeBridge.homeAssistant)
                        root.chromeBridge.homeAssistant.refresh();
                    root.syncPopout();
                }

                function onVisibleChanged(): void {
                    root.syncPopout();
                }
            }

            Connections {
                target: rightCluster

                function onHoveredControlCenterTargetChanged(): void {
                    root.syncPopout();
                }
            }

            Connections {
                target: rightCluster.resourcesChip

                function onHoveredChanged(): void {
                    root.syncPopout();
                }
            }

            Connections {
                target: rightCluster.notificationChip

                function onHoveredChanged(): void {
                    root.syncPopout();
                }
            }

            Connections {
                target: popoutState

                function onPopupHoveredChanged(): void {
                    root.syncPopout();
                }
            }

            Connections {
                target: root.shell

                function onSessionOverlayOpenChanged(): void {
                    if (root.shell.sessionOverlayOpen || root.shell.launcherOverlayOpen)
                        popoutState.clearAll();
                    else
                        root.syncPopout();
                }

                function onLauncherOverlayOpenChanged(): void {
                    if (root.shell.sessionOverlayOpen || root.shell.launcherOverlayOpen)
                        popoutState.clearAll();
                    else
                        root.syncPopout();
                }
            }
        }
    }

    BarUi.BarPopoutSurface {
        id: popoutSurface

        screen: root.screen
        popoutState: popoutState
        surfaceEnabled: !root.shell.sessionOverlayOpen && !root.shell.launcherOverlayOpen
    }
}

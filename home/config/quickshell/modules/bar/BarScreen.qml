import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import "popouts" as BarPopouts

PanelWindow {
    id: root

    required property var shell

    readonly property var brightnessMonitor: {
        const _ = Brightness.monitors;
        return Brightness.getMonitorForScreen(root.screen);
    }

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.barOuterHeight
    color: "transparent"
    exclusiveZone: Theme.barOuterHeight
    WlrLayershell.layer: WlrLayer.Top
    mask: Region {
        item: barFrame
    }

    function runCommand(command): void {
        Quickshell.execDetached({
            command: command,
            workingDirectory: Quickshell.workingDirectory
        });
    }

    function anyPopoutTriggerHovered(): bool {
        return centerCluster.weatherChip.hovered || (rightCluster.mediaChip.visible && rightCluster.mediaChip.hovered) || rightCluster.controlCenterHovered || rightCluster.resourcesChip.hovered;
    }

    function syncPopout(): void {
        if (root.shell.notificationCenterOpen || root.shell.sessionOverlayOpen) {
            closePopoutCheck.stop();
            popoutState.clearAll();
            return;
        }

        if (centerCluster.weatherChip.hovered) {
            closePopoutCheck.stop();
            popoutState.show("weather", centerCluster.weatherChip, weatherPopupContent, 320);
            return;
        }

        if (rightCluster.mediaChip.visible && rightCluster.mediaChip.hovered) {
            closePopoutCheck.stop();
            popoutState.show("media", rightCluster.mediaChip, mediaPopupContent, 380);
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

        if (popoutState.popupHovered) {
            closePopoutCheck.stop();
        } else {
            closePopoutCheck.restart();
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    BarPopoutState {
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
        color: Theme.panel
        border.width: 0
        height: Theme.barOuterHeight - (Theme.barMargin * 2)

        Item {
            anchors.fill: parent
            anchors.leftMargin: Theme.padding
            anchors.rightMargin: Theme.padding

            BarLeft {
                id: leftCluster

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                screen: root.screen
            }

            BarCenter {
                id: centerCluster

                anchors.centerIn: parent
                clock: clock
            }

            BarRight {
                id: rightCluster

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                shell: root.shell
                screen: root.screen
                brightnessMonitor: root.brightnessMonitor
                runCommand: root.runCommand
            }

            Component {
                id: weatherPopupContent

                BarPopouts.WeatherPopout {
                }
            }

            Component {
                id: mediaPopupContent

                BarPopouts.MediaPopout {
                }
            }

            Component {
                id: controlCenterPopupContent

                BarPopouts.ControlCenterPopout {
                    brightnessMonitor: root.brightnessMonitor
                }
            }

            Component {
                id: resourcesPopupContent

                BarPopouts.ResourcesPopout {
                    onOpenRequested: root.runCommand(["ghostty", "-e", "btop"])
                }
            }

            Connections {
                target: centerCluster.weatherChip

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
                target: popoutState

                function onPopupHoveredChanged(): void {
                    root.syncPopout();
                }
            }

            Connections {
                target: root.shell

                function onNotificationCenterOpenChanged(): void {
                    if (root.shell.notificationCenterOpen)
                        popoutState.clearAll();
                    else
                        root.syncPopout();
                }

                function onSessionOverlayOpenChanged(): void {
                    if (root.shell.sessionOverlayOpen)
                        popoutState.clearAll();
                    else
                        root.syncPopout();
                }
            }
        }
    }

    BarPopoutSurface {
        id: popoutSurface

        screen: root.screen
        state: popoutState
        surfaceEnabled: !root.shell.notificationCenterOpen && !root.shell.sessionOverlayOpen
    }
}

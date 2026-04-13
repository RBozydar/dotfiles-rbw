//@ pragma ShellId rbw-shell
//@ pragma Env QS_NO_RELOAD_POPUP=1

import Quickshell
import qs.modules
import qs.services

ShellRoot {
    id: root

    settings.watchFiles: true

    property bool notificationCenterOpen: false
    property bool sessionOverlayOpen: false
    property var notificationScreen: null

    function toggleNotificationCenter(screen): void {
        sessionOverlayOpen = false;

        if (notificationCenterOpen && notificationScreen === screen) {
            closeNotificationCenter();
            return;
        }

        notificationScreen = screen;
        notificationCenterOpen = true;
        Notifications.markAllRead();
    }

    function closeNotificationCenter(): void {
        notificationCenterOpen = false;
        notificationScreen = null;
    }

    function toggleSessionOverlay(): void {
        closeNotificationCenter();
        sessionOverlayOpen = !sessionOverlayOpen;
    }

    function closeSessionOverlay(): void {
        sessionOverlayOpen = false;
    }

    Bar {
        shell: root
    }

    NotificationCenter {
        shell: root
    }

    NotificationPopups {
        shell: root
    }

    VolumeOsd {
        shell: root
    }

    SessionOverlay {
        shell: root
    }
}

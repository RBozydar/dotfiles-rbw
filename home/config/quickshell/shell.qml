//@ pragma ShellId rbw-shell
//@ pragma Env QS_NO_RELOAD_POPUP=1

import Quickshell
import "modules/bar" as BarModule
import "modules/notifications" as NotificationModule
import "modules/osd" as OsdModule
import "modules/session" as SessionModule
import qs.services

ShellRoot {
    id: root

    settings.watchFiles: true

    property bool sessionOverlayOpen: false

    function toggleSessionOverlay(): void {
        sessionOverlayOpen = !sessionOverlayOpen;
    }

    function closeSessionOverlay(): void {
        sessionOverlayOpen = false;
    }

    BarModule.Bar {
        shell: root
    }

    NotificationModule.NotificationPopups {
        shell: root
    }

    OsdModule.VolumeOsd {
        shell: root
    }

    SessionModule.SessionOverlay {
        shell: root
    }
}

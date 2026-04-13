pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    property var history: []
    property var popupList: []
    property int limit: 120
    property int popupLimit: 5
    readonly property int unreadCount: history.filter(item => !item.read).length

    function popupTimeoutMs(notification): int {
        const timeout = Number(notification.expireTimeout ?? -1);
        if (timeout > 1000)
            return timeout;
        if (timeout > 0)
            return timeout * 1000;
        return 6000;
    }

    function remember(notification): void {
        const entry = {
            key: `${notification.id}-${Date.now()}`,
            id: notification.id,
            appName: notification.appName || "Notification",
            summary: notification.summary || "Untitled notification",
            body: notification.body || "",
            appIcon: notification.appIcon || "",
            image: notification.image || "",
            urgency: notification.urgency,
            timestamp: Date.now(),
            read: false
        };

        root.history = [entry].concat(root.history).slice(0, root.limit);
        root.popupList = [{
            key: entry.key,
            id: entry.id,
            appName: entry.appName,
            summary: entry.summary,
            body: entry.body,
            urgency: entry.urgency,
            timestamp: entry.timestamp,
            expiresAt: Date.now() + popupTimeoutMs(notification)
        }].concat(root.popupList).slice(0, root.popupLimit);
    }

    function markAllRead(): void {
        root.history = root.history.map(entry => {
            entry.read = true;
            return entry;
        });
    }

    function clearHistory(): void {
        root.history = [];
        root.popupList = [];
    }

    function dismissPopup(key): void {
        root.popupList = root.popupList.filter(entry => entry.key !== key);
    }

    function clearEntry(key): void {
        root.history = root.history.filter(entry => entry.key !== key);
        dismissPopup(key);
    }

    function markEntryRead(key): void {
        root.history = root.history.map(entry => {
            if (entry.key === key)
                entry.read = true;
            return entry;
        });
    }

    function activateEntry(key): void {
        const entry = root.history.find(item => item.key === key);
        if (!entry)
            return;

        markEntryRead(key);
        dismissPopup(key);

        if (entry.appName === "Ghostty" || /codex/i.test(entry.summary) || /codex/i.test(entry.body)) {
            Quickshell.execDetached({
                command: ["sh", Quickshell.shellPath("scripts/focus-codex-ghostty.sh")],
                workingDirectory: Quickshell.shellDir
            });
        }
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            const now = Date.now();
            root.popupList = root.popupList.filter(entry => entry.expiresAt > now);
        }
    }

    NotificationServer {
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        imageSupported: true
        actionsSupported: true
        persistenceSupported: true
        onNotification: notification => root.remember(notification)
    }
}

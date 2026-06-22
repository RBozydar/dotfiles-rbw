pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "notifications-store.js" as NotificationsStore

Singleton {
    id: root

    property var history: []
    property var popupList: []
    property int limit: 120
    property int popupLimit: 5
    readonly property int unreadCount: history.filter(item => !item.read).length

    function remember(notification): void {
        const next = NotificationsStore.remember(root.history, root.popupList, notification, Date.now(), root.limit, root.popupLimit);
        root.history = next.history;
        root.popupList = next.popupList;
    }

    function markAllRead(): void {
        root.history = NotificationsStore.markAllRead(root.history);
    }

    function clearHistory(): void {
        root.history = [];
        root.popupList = [];
    }

    function dismissPopup(key): void {
        root.popupList = NotificationsStore.dismissPopup(root.popupList, key);
    }

    function clearEntry(key): void {
        root.history = NotificationsStore.clearEntry(root.history, key);
        dismissPopup(key);
    }

    function markEntryRead(key): void {
        root.history = NotificationsStore.markEntryRead(root.history, key);
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
            root.popupList = NotificationsStore.filterUnexpiredPopups(root.popupList, Date.now());
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

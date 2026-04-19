import "./notification-server-model.js" as NotificationServerModel
import Quickshell
import Quickshell.Services.Notifications
import QtQml

Scope {
    id: root

    signal notificationReceived(var notification)
    property int maxRetainedNotifications: 256
    property var liveNotificationsById: ({})
    property var liveNotificationOrder: []

    function normalizeNotificationId(notificationId): string {
        const parsed = Number(notificationId);
        if (!Number.isFinite(parsed))
            return "";
        return String(parsed);
    }

    function rememberLiveNotification(notification): void {
        const notificationId = normalizeNotificationId(notification && notification.id);
        if (!notificationId)
            return;

        const nextMap = {};
        const currentMap = root.liveNotificationsById || {};
        for (const key in currentMap)
            nextMap[key] = currentMap[key];
        nextMap[notificationId] = notification;
        root.liveNotificationsById = nextMap;

        const nextOrder = [];
        const currentOrder = Array.isArray(root.liveNotificationOrder) ? root.liveNotificationOrder : [];
        nextOrder.push(notificationId);
        for (let index = 0; index < currentOrder.length; index += 1) {
            const value = String(currentOrder[index]);
            if (value === notificationId)
                continue;
            if (nextMap[value] === undefined)
                continue;
            nextOrder.push(value);
            if (nextOrder.length >= root.maxRetainedNotifications)
                break;
        }
        root.liveNotificationOrder = nextOrder;

        if (nextOrder.length < root.maxRetainedNotifications)
            return;

        const trimmedMap = {};
        for (let index = 0; index < nextOrder.length; index += 1) {
            const keepId = nextOrder[index];
            if (nextMap[keepId] !== undefined)
                trimmedMap[keepId] = nextMap[keepId];
        }
        root.liveNotificationsById = trimmedMap;
    }

    function invokeAction(notificationId, actionId): var {
        const normalizedId = normalizeNotificationId(notificationId);
        if (!normalizedId) {
            return {
                status: "invalid",
                reason: "Notification id must be finite"
            };
        }

        const normalizedActionId = String(actionId || "").trim();
        if (!normalizedActionId) {
            return {
                status: "invalid",
                reason: "Notification action id must be non-empty"
            };
        }

        const notification = root.liveNotificationsById ? root.liveNotificationsById[normalizedId] : null;
        if (!notification || typeof notification.invokeAction !== "function") {
            return {
                status: "rejected",
                reason: "Notification action target is unavailable"
            };
        }

        try {
            notification.invokeAction(normalizedActionId);
            return {
                status: "dispatched"
            };
        } catch (error) {
            return {
                status: "failed",
                reason: error && error.message ? String(error.message) : "Notification action dispatch failed"
            };
        }
    }

    function hasNotification(notificationId): bool {
        const normalizedId = normalizeNotificationId(notificationId);
        if (!normalizedId)
            return false;

        const notifications = root.liveNotificationsById || {};
        return notifications[normalizedId] !== undefined;
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

        onNotification: notification => {
            root.rememberLiveNotification(notification);
            root.notificationReceived(NotificationServerModel.normalizeNotification(notification));
        }
    }
}

import "../../adapters/notifications" as NotificationAdapters
import "../../core/application/notifications/activate-notification-entry.js" as NotificationActivationUseCases
import "../../core/application/notifications/clear-notification-entry.js" as NotificationClearEntryUseCases
import "../../core/application/notifications/clear-notification-history.js" as NotificationClearHistoryUseCases
import "../../core/application/notifications/dismiss-notification-popup.js" as NotificationDismissPopupUseCases
import "../../core/application/notifications/expire-notification-popups.js" as NotificationExpiryUseCases
import "../../core/application/notifications/ingest-notification.js" as NotificationIngestUseCases
import "../../core/application/notifications/mark-all-notifications-read.js" as NotificationMarkReadUseCases
import "../../core/contracts/notification-contracts.js" as NotificationContracts
import "../../core/contracts/operation-outcome.js" as OperationOutcomes
import "../../core/domain/notifications/notification-store.js" as NotificationStore
import "../../core/policies/notifications/notification-policy.js" as NotificationPolicy
import Quickshell
import QtQml

Scope {
    id: root

    signal historyMutated(var payload)

    property var commandExecutionPort: null
    property string codexFocusScriptPath: ""
    property int popupSweepIntervalMs: 500
    property var notificationPolicy: ({
            replaceById: true,
            dedupeByContent: true,
            dedupeWindowMs: 5000,
            preserveReadOnReplace: false
        })

    property var store: NotificationStore.createNotificationStore()
    property int storeRevision: 0
    property var history: []
    property var popupList: []
    property int unreadCount: 0
    property int limit: 120
    property int popupLimit: 5
    property string phase: "ready"
    property string error: ""
    property var lastOutcome: null
    readonly property var notificationActionPort: ({
            invokeAction: function (notificationId, actionId) {
                if (!notificationServerAdapter || typeof notificationServerAdapter.invokeAction !== "function") {
                    return {
                        status: "port_unavailable",
                        reason: "Notification server action adapter is unavailable"
                    };
                }
                return notificationServerAdapter.invokeAction(notificationId, actionId);
            },
            hasNotification: function (notificationId) {
                if (!notificationServerAdapter || typeof notificationServerAdapter.hasNotification !== "function")
                    return false;
                return notificationServerAdapter.hasNotification(notificationId);
            }
        })

    function syncProjection() {
        const state = store && store.state ? store.state : null;
        if (!state)
            return;

        storeRevision = Number(state.revision);
        history = NotificationContracts.cloneNotificationEntries(state.history);
        popupList = NotificationContracts.cloneNotificationPopups(state.popupList);
        unreadCount = Number(state.unreadCount);
        limit = Number(state.limit);
        popupLimit = Number(state.popupLimit);
        phase = String(state.phase || "ready");
        error = String(state.error || "");
        lastOutcome = state.lastOutcome || null;
    }

    function emitHistoryMutation(outcome, sourceCode) {
        root.historyMutated({
            kind: "notifications.history_mutated",
            source: String(sourceCode || "notifications.unknown"),
            history: NotificationContracts.cloneNotificationEntries(root.history),
            unreadCount: Number(root.unreadCount),
            revision: Number(root.storeRevision),
            outcome: outcome || null
        });
    }

    function notificationUseCaseDeps() {
        return {
            "validateNotificationKey": NotificationContracts.validateNotificationKey,
            "validateNotificationEvent": NotificationContracts.validateNotificationEvent,
            "validateNotificationEntry": NotificationContracts.validateNotificationEntry,
            "validateNotificationPopup": NotificationContracts.validateNotificationPopup,
            "createNotificationEntry": NotificationContracts.createNotificationEntry,
            "createNotificationPopup": NotificationContracts.createNotificationPopup,
            "cloneNotificationEntries": NotificationContracts.cloneNotificationEntries,
            "cloneNotificationPopups": NotificationContracts.cloneNotificationPopups,
            "prependWithLimit": NotificationContracts.prependWithLimit,
            "popupTimeoutMs": NotificationContracts.popupTimeoutMs,
            "notificationContentSignature": NotificationContracts.notificationContentSignature,
            "resolveNotificationIngestPlan": NotificationPolicy.resolveNotificationIngestPlan,
            "notificationPolicy": root.notificationPolicy,
            "outcomes": OperationOutcomes,
            "commandExecutionPort": root.commandExecutionPort,
            "notificationActionPort": root.notificationActionPort,
            "resolveActivationAction": root.resolveActivationAction
        };
    }

    function resolveDefaultNotificationActionId(entry, requestedActionId) {
        const actions = Array.isArray(entry && entry.actions) ? entry.actions : [];
        const normalizedRequestedActionId = String(requestedActionId || "").trim();

        if (normalizedRequestedActionId.length > 0) {
            for (let index = 0; index < actions.length; index += 1) {
                const action = actions[index];
                if (String(action && action.id) === normalizedRequestedActionId)
                    return normalizedRequestedActionId;
            }
            return "";
        }

        const entryDefaultActionId = String(entry && entry.defaultActionId ? entry.defaultActionId : "").trim();
        if (entryDefaultActionId.length > 0) {
            for (let index = 0; index < actions.length; index += 1) {
                const action = actions[index];
                if (String(action && action.id) === entryDefaultActionId)
                    return entryDefaultActionId;
            }
        }

        if (actions.length === 1)
            return String(actions[0].id || "").trim();

        for (let index = 0; index < actions.length; index += 1) {
            const action = actions[index];
            if (String(action && action.id) === "default")
                return "default";
        }

        return "";
    }

    function resolveActivationAction(entry, requestedActionId) {
        const resolvedNotificationActionId = resolveDefaultNotificationActionId(entry, requestedActionId);
        if (resolvedNotificationActionId.length > 0 && root.notificationActionPort.hasNotification(Number(entry && entry.id))) {
            return {
                type: "notification.action.invoke",
                notificationId: Number(entry && entry.id),
                actionId: resolvedNotificationActionId,
                targetId: "notification.action." + resolvedNotificationActionId
            };
        }

        const summary = String(entry && entry.summary ? entry.summary : "");
        const body = String(entry && entry.body ? entry.body : "");
        const appName = String(entry && entry.appName ? entry.appName : "");
        const hasCodexKeyword = /codex/i.test(summary) || /codex/i.test(body);

        if (!root.codexFocusScriptPath || root.codexFocusScriptPath.length <= 0)
            return null;
        if (appName === "Ghostty" || hasCodexKeyword) {
            return {
                type: "command.execute",
                argv: ["sh", root.codexFocusScriptPath],
                targetId: "codex.terminal"
            };
        }

        return null;
    }

    function restoreHistory(entries, sourceCode) {
        try {
            const normalizedEntries = NotificationContracts.cloneNotificationEntries(entries);
            const staleSafeEntries = [];
            for (let index = 0; index < normalizedEntries.length; index += 1) {
                const entry = normalizedEntries[index];
                staleSafeEntries.push(Object.assign({}, entry, {
                    actions: [],
                    defaultActionId: ""
                }));
            }
            const nextHistory = normalizedEntries.slice(0, root.limit);
            const outcome = OperationOutcomes.applied({
                code: "notifications.history.restored",
                targetId: "notifications",
                meta: {
                    source: String(sourceCode || "notifications.restore"),
                    restoredCount: nextHistory.length
                }
            });
            store.applyMutation(staleSafeEntries.slice(0, root.limit), [], outcome);
            syncProjection();
            return outcome;
        } catch (error) {
            const outcome = OperationOutcomes.failed({
                code: "notifications.history.restore_failed",
                targetId: "notifications",
                reason: error && error.message ? String(error.message) : "Failed to restore notification history"
            });
            store.applyFailure(outcome, "Failed to restore notification history");
            syncProjection();
            return outcome;
        }
    }

    function ingest(notification) {
        const outcome = NotificationIngestUseCases.ingestNotification(notificationUseCaseDeps(), store, notification, Date.now());
        syncProjection();
        if (outcome && outcome.status === "applied")
            emitHistoryMutation(outcome, "notifications.ingest");
        return outcome;
    }

    function markAllRead() {
        const outcome = NotificationMarkReadUseCases.markAllNotificationsRead(notificationUseCaseDeps(), store);
        syncProjection();
        if (outcome && outcome.status === "applied")
            emitHistoryMutation(outcome, "notifications.mark_all_read");
        return outcome;
    }

    function clearHistory() {
        const outcome = NotificationClearHistoryUseCases.clearNotificationHistory(notificationUseCaseDeps(), store);
        syncProjection();
        if (outcome && outcome.status === "applied")
            emitHistoryMutation(outcome, "notifications.clear_history");
        return outcome;
    }

    function clearEntry(key) {
        const outcome = NotificationClearEntryUseCases.clearNotificationEntry(notificationUseCaseDeps(), store, key);
        syncProjection();
        if (outcome && outcome.status === "applied")
            emitHistoryMutation(outcome, "notifications.clear_entry");
        return outcome;
    }

    function dismissPopup(key) {
        const outcome = NotificationDismissPopupUseCases.dismissNotificationPopup(notificationUseCaseDeps(), store, key);
        syncProjection();
        return outcome;
    }

    function activateEntry(key, actionId) {
        const outcome = NotificationActivationUseCases.activateNotificationEntry(notificationUseCaseDeps(), store, key, actionId);
        syncProjection();
        if (outcome && outcome.status === "applied")
            emitHistoryMutation(outcome, "notifications.activate");
        return outcome;
    }

    function expirePopups(nowMs) {
        const outcome = NotificationExpiryUseCases.expireNotificationPopups(notificationUseCaseDeps(), store, nowMs);
        syncProjection();
        return outcome;
    }

    function describe() {
        return {
            kind: "notifications.runtime_snapshot",
            phase: root.phase,
            revision: root.storeRevision,
            unreadCount: root.unreadCount,
            limit: root.limit,
            popupLimit: root.popupLimit,
            history: NotificationContracts.cloneNotificationEntries(root.history),
            popupList: NotificationContracts.cloneNotificationPopups(root.popupList),
            policy: NotificationPolicy.normalizePolicy(root.notificationPolicy),
            error: root.error,
            lastOutcome: root.lastOutcome
        };
    }

    Component.onCompleted: syncProjection()

    Timer {
        interval: root.popupSweepIntervalMs
        running: true
        repeat: true
        onTriggered: root.expirePopups(Date.now())
    }

    NotificationAdapters.NotificationServerAdapter {
        id: notificationServerAdapter

        onNotificationReceived: notification => root.ingest(notification)
    }
}

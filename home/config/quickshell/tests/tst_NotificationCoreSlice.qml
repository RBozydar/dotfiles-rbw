import "../system/core/application/notifications/activate-notification-entry.js" as NotificationActivationUseCases
import "../system/core/application/notifications/clear-notification-entry.js" as NotificationClearEntryUseCases
import "../system/core/application/notifications/dismiss-notification-popup.js" as NotificationDismissPopupUseCases
import "../system/core/application/notifications/expire-notification-popups.js" as NotificationExpiryUseCases
import "../system/core/application/notifications/ingest-notification.js" as NotificationIngestUseCases
import "../system/core/application/notifications/mark-all-notifications-read.js" as NotificationMarkReadUseCases
import "../system/core/contracts/notification-contracts.js" as NotificationContracts
import "../system/core/contracts/operation-outcome.js" as OperationOutcomes
import "../system/core/domain/notifications/notification-store.js" as NotificationStore
import "../system/core/policies/notifications/notification-policy.js" as NotificationPolicy
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function createStore(limit, popupLimit) {
        return NotificationStore.createNotificationStore({
            "limit": limit === undefined ? 120 : limit,
            "popupLimit": popupLimit === undefined ? 5 : popupLimit
        });
    }

    function createEvent(overrides) {
        const base = {
            "id": 7,
            "appName": "Ghostty",
            "summary": "Codex needs your attention",
            "body": "Please check Ghostty for input on the current task.",
            "appIcon": "utilities-terminal",
            "image": "",
            "urgency": 1,
            "expireTimeout": -1
        };

        for (const key in overrides)
            base[key] = overrides[key];

        return NotificationContracts.createNotificationEvent(base);
    }

    function deps(overrides) {
        const defaults = {
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
            "outcomes": OperationOutcomes,
            "commandExecutionPort": null,
            "notificationActionPort": null,
            "notificationPolicy": {
                replaceById: true,
                dedupeByContent: true,
                dedupeWindowMs: 5000,
                preserveReadOnReplace: false
            },
            "resolveActivationAction": function () {
                return null;
            }
        };

        for (const key in overrides)
            defaults[key] = overrides[key];

        return defaults;
    }

    function test_ingestNotification_prepends_and_limits() {
        const store = createStore(2, 1);
        const useCaseDeps = deps({});

        NotificationIngestUseCases.ingestNotification(useCaseDeps, store, createEvent({
            "id": 1
        }), 1000);
        NotificationIngestUseCases.ingestNotification(useCaseDeps, store, createEvent({
            "id": 2
        }), 2000);
        NotificationIngestUseCases.ingestNotification(useCaseDeps, store, createEvent({
            "id": 3
        }), 3000);

        compare(store.state.history.length, 2);
        compare(store.state.history[0].key, "3-3000");
        compare(store.state.history[1].key, "2-2000");
        compare(store.state.popupList.length, 1);
        compare(store.state.popupList[0].key, "3-3000");
        compare(store.state.unreadCount, 2);
    }

    function test_ingestNotification_replaces_existing_entry_by_id_when_policy_enabled() {
        const store = createStore(10, 5);
        const useCaseDeps = deps({
            "resolveNotificationIngestPlan": NotificationPolicy.resolveNotificationIngestPlan,
            "notificationPolicy": {
                replaceById: true,
                dedupeByContent: false
            }
        });

        NotificationIngestUseCases.ingestNotification(useCaseDeps, store, createEvent({
            "id": 41,
            "summary": "First summary"
        }), 1000);
        const outcome = NotificationIngestUseCases.ingestNotification(useCaseDeps, store, createEvent({
            "id": 41,
            "summary": "Updated summary"
        }), 2000);

        compare(outcome.status, "applied");
        compare(outcome.meta.policyDecision, "replaced_by_id");
        compare(store.state.history.length, 1);
        compare(store.state.history[0].key, "41-2000");
        compare(store.state.history[0].summary, "Updated summary");
        compare(store.state.popupList.length, 1);
        compare(store.state.popupList[0].key, "41-2000");
    }

    function test_ingestNotification_deduplicates_recent_content_and_increments_repeat_count() {
        const store = createStore(10, 5);
        const useCaseDeps = deps({
            "resolveNotificationIngestPlan": NotificationPolicy.resolveNotificationIngestPlan,
            "notificationPolicy": {
                replaceById: false,
                dedupeByContent: true,
                dedupeWindowMs: 5000
            }
        });

        NotificationIngestUseCases.ingestNotification(useCaseDeps, store, createEvent({
            "id": 51,
            "summary": "Build complete",
            "body": "All checks passed"
        }), 1000);
        const outcome = NotificationIngestUseCases.ingestNotification(useCaseDeps, store, createEvent({
            "id": 52,
            "summary": "Build complete",
            "body": "All checks passed"
        }), 3000);

        compare(outcome.status, "applied");
        compare(outcome.meta.policyDecision, "deduplicated_recent");
        compare(store.state.history.length, 1);
        compare(store.state.history[0].key, "52-3000");
        compare(store.state.history[0].repeatCount, 2);
        compare(store.state.popupList.length, 1);
        compare(store.state.popupList[0].repeatCount, 2);
    }

    function test_markAllNotificationsRead_marks_entries() {
        const store = createStore(10, 5);
        const useCaseDeps = deps({});

        NotificationIngestUseCases.ingestNotification(useCaseDeps, store, createEvent({
            "id": 9
        }), 1500);
        NotificationIngestUseCases.ingestNotification(useCaseDeps, store, createEvent({
            "id": 10
        }), 1600);

        const outcome = NotificationMarkReadUseCases.markAllNotificationsRead(useCaseDeps, store);
        compare(outcome.status, "applied");
        compare(store.state.unreadCount, 0);
        compare(store.state.history[0].read, true);
        compare(store.state.history[1].read, true);
    }

    function test_dismiss_and_clear_entry_update_store() {
        const store = createStore(10, 5);
        const useCaseDeps = deps({});

        NotificationIngestUseCases.ingestNotification(useCaseDeps, store, createEvent({
            "id": 13
        }), 2100);
        const key = store.state.history[0].key;

        const dismissOutcome = NotificationDismissPopupUseCases.dismissNotificationPopup(useCaseDeps, store, key);
        compare(dismissOutcome.status, "applied");
        compare(store.state.popupList.length, 0);
        compare(store.state.history.length, 1);

        const clearOutcome = NotificationClearEntryUseCases.clearNotificationEntry(useCaseDeps, store, key);
        compare(clearOutcome.status, "applied");
        compare(store.state.history.length, 0);
        compare(store.state.popupList.length, 0);
    }

    function test_activateNotificationEntry_marks_read_and_dispatches_action() {
        const store = createStore(10, 5);
        let capturedArgv = [];
        const useCaseDeps = deps({
            "resolveActivationAction": function () {
                return {
                    "type": "command.execute",
                    "argv": ["sh", "/tmp/focus.sh"],
                    "targetId": "codex.terminal"
                };
            },
            "commandExecutionPort": {
                "execute": function (argv) {
                    capturedArgv = argv;
                    return true;
                }
            }
        });

        NotificationIngestUseCases.ingestNotification(useCaseDeps, store, createEvent({
            "id": 19
        }), 2200);
        const key = store.state.history[0].key;

        const outcome = NotificationActivationUseCases.activateNotificationEntry(useCaseDeps, store, key);
        compare(outcome.status, "applied");
        compare(outcome.meta.action.status, "dispatched");
        compare(capturedArgv.length, 2);
        compare(capturedArgv[1], "/tmp/focus.sh");
        compare(store.state.history[0].read, true);
        compare(store.state.popupList.length, 0);
    }

    function test_activateNotificationEntry_invokes_notification_action_when_available() {
        const store = createStore(10, 5);
        let capturedNotificationId = 0;
        let capturedActionId = "";
        const useCaseDeps = deps({
            "resolveActivationAction": function (entry) {
                return {
                    "type": "notification.action.invoke",
                    "notificationId": entry.id,
                    "actionId": "default-open",
                    "targetId": "notification.action.default-open"
                };
            },
            "notificationActionPort": {
                "invokeAction": function (notificationId, actionId) {
                    capturedNotificationId = Number(notificationId);
                    capturedActionId = String(actionId);
                    return true;
                }
            }
        });

        NotificationIngestUseCases.ingestNotification(useCaseDeps, store, createEvent({
            "id": 29,
            "actions": [
                {
                    "id": "default-open",
                    "label": "Open"
                }
            ],
            "defaultActionId": "default-open"
        }), 2300);
        const key = store.state.history[0].key;

        const outcome = NotificationActivationUseCases.activateNotificationEntry(useCaseDeps, store, key);
        compare(outcome.status, "applied");
        compare(outcome.meta.action.status, "dispatched");
        compare(outcome.meta.action.route, "notification.action.invoke");
        compare(capturedNotificationId, 29);
        compare(capturedActionId, "default-open");
        compare(store.state.history[0].read, true);
    }

    function test_activateNotificationEntry_rejects_unknown_requested_action_id() {
        const store = createStore(10, 5);
        const useCaseDeps = deps({
            "resolveActivationAction": function () {
                return null;
            }
        });

        NotificationIngestUseCases.ingestNotification(useCaseDeps, store, createEvent({
            "id": 31,
            "actions": [
                {
                    "id": "open",
                    "label": "Open"
                }
            ],
            "defaultActionId": "open"
        }), 2400);
        const key = store.state.history[0].key;
        const outcome = NotificationActivationUseCases.activateNotificationEntry(useCaseDeps, store, key, "dismiss");

        compare(outcome.status, "rejected");
        compare(outcome.code, "notifications.activate.action_not_found");
        compare(store.state.history[0].read, false);
    }

    function test_expireNotificationPopups_filters_expired_entries() {
        const store = createStore(10, 5);
        const useCaseDeps = deps({});

        NotificationIngestUseCases.ingestNotification(useCaseDeps, store, createEvent({
            "id": 25,
            "expireTimeout": 2000
        }), 4000);

        compare(store.state.popupList.length, 1);
        compare(store.state.popupList[0].expiresAt, 6000);

        const noneExpired = NotificationExpiryUseCases.expireNotificationPopups(useCaseDeps, store, 5500);
        compare(noneExpired.status, "noop");
        compare(store.state.popupList.length, 1);

        const expired = NotificationExpiryUseCases.expireNotificationPopups(useCaseDeps, store, 6001);
        compare(expired.status, "applied");
        compare(store.state.popupList.length, 0);
    }

    function test_ingestNotification_respects_freedesktop_timeout_milliseconds() {
        const store = createStore(10, 5);
        const useCaseDeps = deps({});

        NotificationIngestUseCases.ingestNotification(useCaseDeps, store, createEvent({
            "id": 71,
            "expireTimeout": 250
        }), 1000);

        compare(store.state.popupList.length, 1);
        compare(store.state.popupList[0].expiresAt, 1250);
    }

    function test_ingestNotification_with_zero_timeout_creates_sticky_popup() {
        const store = createStore(10, 5);
        const useCaseDeps = deps({});

        NotificationIngestUseCases.ingestNotification(useCaseDeps, store, createEvent({
            "id": 72,
            "expireTimeout": 0
        }), 1000);

        compare(store.state.popupList.length, 1);
        verify(store.state.popupList[0].expiresAt > 1000);

        const outcome = NotificationExpiryUseCases.expireNotificationPopups(useCaseDeps, store, 1000 + 60000);
        compare(outcome.status, "noop");
        compare(store.state.popupList.length, 1);
    }

    name: "NotificationCoreSlice"
}

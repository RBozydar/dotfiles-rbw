import "../services/notifications-store.js" as NotificationsStore
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function notification(overrides) {
        const value = {
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
            value[key] = overrides[key];
        return value;
    }

    function test_popupTimeoutMs_uses_existing_behavior() {
        compare(NotificationsStore.popupTimeoutMs(-1), 6000);
        compare(NotificationsStore.popupTimeoutMs(250), 250000);
        compare(NotificationsStore.popupTimeoutMs(5000), 5000);
    }

    function test_remember_prepends_and_limits() {
        const history = [
            {
                "key": "old-1"
            },
            {
                "key": "old-2"
            }
        ];
        const popupList = [
            {
                "key": "popup-old-1"
            },
            {
                "key": "popup-old-2"
            }
        ];
        const result = NotificationsStore.remember(history, popupList, notification({
            "id": 42
        }), 1000, 2, 1);
        compare(result.history.length, 2);
        compare(result.history[0].key, "42-1000");
        compare(result.history[0].appName, "Ghostty");
        compare(result.history[0].summary, "Codex needs your attention");
        compare(result.history[0].read, false);
        compare(result.history[1].key, "old-1");
        compare(result.popupList.length, 1);
        compare(result.popupList[0].key, "42-1000");
        compare(result.popupList[0].expiresAt, 7000);
    }

    function test_remember_fills_defaults() {
        const result = NotificationsStore.remember([], [], notification({
            "id": 5,
            "appName": "",
            "summary": "",
            "body": "",
            "appIcon": "",
            "image": "",
            "expireTimeout": 2000
        }), 500, 5, 5);
        compare(result.history[0].appName, "Notification");
        compare(result.history[0].summary, "Untitled notification");
        compare(result.popupList[0].expiresAt, 2500);
    }

    function test_markAllRead_marks_entries_without_removing_them() {
        const history = [
            {
                "key": "a",
                "read": false
            },
            {
                "key": "b",
                "read": false
            }
        ];
        const result = NotificationsStore.markAllRead(history);
        compare(result.length, 2);
        compare(result[0].read, true);
        compare(result[1].read, true);
    }

    function test_clearEntry_and_dismissPopup_remove_matching_key() {
        const history = [
            {
                "key": "keep"
            },
            {
                "key": "drop"
            }
        ];
        const popupList = [
            {
                "key": "drop"
            },
            {
                "key": "keep"
            }
        ];
        const nextHistory = NotificationsStore.clearEntry(history, "drop");
        const nextPopups = NotificationsStore.dismissPopup(popupList, "drop");
        compare(nextHistory.length, 1);
        compare(nextHistory[0].key, "keep");
        compare(nextPopups.length, 1);
        compare(nextPopups[0].key, "keep");
    }

    function test_markEntryRead_only_marks_matching_key() {
        const history = [
            {
                "key": "a",
                "read": false
            },
            {
                "key": "b",
                "read": false
            }
        ];
        const result = NotificationsStore.markEntryRead(history, "b");
        compare(result[0].read, false);
        compare(result[1].read, true);
    }

    function test_filterUnexpiredPopups_keeps_future_entries_only() {
        const popupList = [
            {
                "key": "expired",
                "expiresAt": 900
            },
            {
                "key": "active",
                "expiresAt": 1100
            }
        ];
        const result = NotificationsStore.filterUnexpiredPopups(popupList, 1000);
        compare(result.length, 1);
        compare(result[0].key, "active");
    }

    name: "NotificationsStore"
}

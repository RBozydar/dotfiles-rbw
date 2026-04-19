function markAllNotificationsRead(deps, store) {
    try {
        const history = deps.cloneNotificationEntries(store.state.history);
        const popups = deps.cloneNotificationPopups(store.state.popupList);

        let unreadCount = 0;
        const nextHistory = [];

        for (let index = 0; index < history.length; index += 1) {
            const entry = history[index];
            if (entry.read !== true) unreadCount += 1;
            entry.read = true;
            nextHistory.push(entry);
        }

        if (unreadCount === 0) {
            return deps.outcomes.noop({
                code: "notifications.mark_all_read.already_read",
                reason: "All notifications are already marked as read",
                targetId: "notifications",
            });
        }

        const outcome = deps.outcomes.applied({
            code: "notifications.mark_all_read.applied",
            targetId: "notifications",
            meta: {
                updatedCount: unreadCount,
            },
        });

        store.applyMutation(nextHistory, popups, outcome);
        return outcome;
    } catch (error) {
        const outcome = deps.outcomes.failed({
            code: "notifications.mark_all_read.failed",
            reason:
                error && error.message
                    ? String(error.message)
                    : "Failed to mark notifications as read",
            targetId: "notifications",
        });
        store.applyFailure(outcome, "Failed to mark notifications as read");
        return outcome;
    }
}

function clearNotificationHistory(deps, store) {
    try {
        const history = deps.cloneNotificationEntries(store.state.history);
        const popups = deps.cloneNotificationPopups(store.state.popupList);

        if (history.length === 0 && popups.length === 0) {
            return deps.outcomes.noop({
                code: "notifications.clear_history.empty",
                reason: "Notification history is already empty",
                targetId: "notifications",
            });
        }

        const outcome = deps.outcomes.applied({
            code: "notifications.clear_history.applied",
            targetId: "notifications",
        });

        store.applyMutation([], [], outcome);
        return outcome;
    } catch (error) {
        const outcome = deps.outcomes.failed({
            code: "notifications.clear_history.failed",
            reason:
                error && error.message
                    ? String(error.message)
                    : "Failed to clear notification history",
            targetId: "notifications",
        });
        store.applyFailure(outcome, "Failed to clear notification history");
        return outcome;
    }
}

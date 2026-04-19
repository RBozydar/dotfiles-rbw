function clearNotificationEntry(deps, store, key) {
    let normalizedKey = "";

    try {
        normalizedKey = deps.validateNotificationKey(String(key || ""));
    } catch (error) {
        return deps.outcomes.rejected({
            code: "notifications.clear_entry.key_required",
            reason: error && error.message ? String(error.message) : "Notification key is required",
            targetId: "notifications",
        });
    }

    try {
        const history = deps.cloneNotificationEntries(store.state.history);
        const popups = deps.cloneNotificationPopups(store.state.popupList);
        const nextHistory = [];
        const nextPopups = [];

        for (let index = 0; index < history.length; index += 1) {
            const entry = history[index];
            if (entry.key !== normalizedKey) nextHistory.push(entry);
        }

        for (let index = 0; index < popups.length; index += 1) {
            const popup = popups[index];
            if (popup.key !== normalizedKey) nextPopups.push(popup);
        }

        if (nextHistory.length === history.length && nextPopups.length === popups.length) {
            return deps.outcomes.noop({
                code: "notifications.clear_entry.not_found",
                reason: "Notification entry was not found",
                targetId: normalizedKey,
            });
        }

        const outcome = deps.outcomes.applied({
            code: "notifications.clear_entry.applied",
            targetId: normalizedKey,
            meta: {
                removedHistory: nextHistory.length < history.length,
                removedPopup: nextPopups.length < popups.length,
            },
        });

        store.applyMutation(nextHistory, nextPopups, outcome);
        return outcome;
    } catch (error) {
        const outcome = deps.outcomes.failed({
            code: "notifications.clear_entry.failed",
            reason:
                error && error.message
                    ? String(error.message)
                    : "Failed to clear notification entry",
            targetId: normalizedKey || "notifications",
        });
        store.applyFailure(outcome, "Failed to clear notification entry");
        return outcome;
    }
}

function dismissNotificationPopup(deps, store, key) {
    let normalizedKey = "";

    try {
        normalizedKey = deps.validateNotificationKey(String(key || ""));
    } catch (error) {
        return deps.outcomes.rejected({
            code: "notifications.dismiss_popup.key_required",
            reason: error && error.message ? String(error.message) : "Notification key is required",
            targetId: "notifications",
        });
    }

    try {
        const history = deps.cloneNotificationEntries(store.state.history);
        const popups = deps.cloneNotificationPopups(store.state.popupList);
        const nextPopups = [];

        for (let index = 0; index < popups.length; index += 1) {
            const popup = popups[index];
            if (popup.key !== normalizedKey) nextPopups.push(popup);
        }

        if (nextPopups.length === popups.length) {
            return deps.outcomes.noop({
                code: "notifications.dismiss_popup.not_found",
                reason: "Popup is already dismissed",
                targetId: normalizedKey,
            });
        }

        const outcome = deps.outcomes.applied({
            code: "notifications.dismiss_popup.applied",
            targetId: normalizedKey,
        });

        store.applyMutation(history, nextPopups, outcome);
        return outcome;
    } catch (error) {
        const outcome = deps.outcomes.failed({
            code: "notifications.dismiss_popup.failed",
            reason: error && error.message ? String(error.message) : "Failed to dismiss popup",
            targetId: normalizedKey || "notifications",
        });
        store.applyFailure(outcome, "Failed to dismiss popup");
        return outcome;
    }
}

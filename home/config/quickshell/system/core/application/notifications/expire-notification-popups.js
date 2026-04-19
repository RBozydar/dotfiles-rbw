function normalizeTimestamp(nowMs) {
    const timestamp = nowMs === undefined ? Date.now() : Number(nowMs);
    if (!Number.isFinite(timestamp))
        throw new Error("Notification expiry timestamp must be finite");
    return timestamp;
}

function expireNotificationPopups(deps, store, nowMs) {
    const timestamp = normalizeTimestamp(nowMs);

    try {
        const history = deps.cloneNotificationEntries(store.state.history);
        const popups = deps.cloneNotificationPopups(store.state.popupList);
        const nextPopups = [];

        for (let index = 0; index < popups.length; index += 1) {
            const popup = popups[index];
            if (popup.expiresAt > timestamp) nextPopups.push(popup);
        }

        if (nextPopups.length === popups.length) {
            return deps.outcomes.noop({
                code: "notifications.expire_popups.none_expired",
                reason: "No notification popups expired",
                targetId: "notifications",
            });
        }

        const outcome = deps.outcomes.applied({
            code: "notifications.expire_popups.applied",
            targetId: "notifications",
            meta: {
                removedCount: popups.length - nextPopups.length,
                now: timestamp,
            },
        });

        store.applyMutation(history, nextPopups, outcome);
        return outcome;
    } catch (error) {
        const outcome = deps.outcomes.failed({
            code: "notifications.expire_popups.failed",
            reason:
                error && error.message
                    ? String(error.message)
                    : "Failed to expire notification popups",
            targetId: "notifications",
        });
        store.applyFailure(outcome, "Failed to expire notification popups");
        return outcome;
    }
}

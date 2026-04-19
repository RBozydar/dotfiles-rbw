function normalizeTimestamp(nowMs) {
    const timestamp = nowMs === undefined ? Date.now() : Number(nowMs);
    if (!Number.isFinite(timestamp))
        throw new Error("Notification ingest timestamp must be finite");
    return timestamp;
}

function resolveIngestPlan(deps, store, event, entry, popup, timestamp) {
    const history = deps.cloneNotificationEntries(store.state.history);
    const popupList = deps.cloneNotificationPopups(store.state.popupList);

    if (typeof deps.resolveNotificationIngestPlan !== "function") {
        return {
            decision: "append",
            entry: entry,
            popup: popup,
            historyBase: history,
            popupBase: popupList,
            meta: {},
        };
    }

    return deps.resolveNotificationIngestPlan({
        event: event,
        entry: entry,
        popup: popup,
        timestamp: timestamp,
        history: history,
        popupList: popupList,
        policy: deps.notificationPolicy,
        notificationContentSignature: deps.notificationContentSignature,
    });
}

function ingestNotification(deps, store, notificationEvent, nowMs) {
    const timestamp = normalizeTimestamp(nowMs);

    try {
        const event = deps.validateNotificationEvent(notificationEvent);
        const baseEntry = deps.createNotificationEntry(event, timestamp);
        const basePopup = deps.createNotificationPopup(
            baseEntry,
            timestamp + deps.popupTimeoutMs(event.expireTimeout),
        );
        const ingestPlan = resolveIngestPlan(deps, store, event, baseEntry, basePopup, timestamp);
        const entry =
            typeof deps.validateNotificationEntry === "function"
                ? deps.validateNotificationEntry(ingestPlan.entry)
                : ingestPlan.entry;
        const popup =
            typeof deps.validateNotificationPopup === "function"
                ? deps.validateNotificationPopup(ingestPlan.popup)
                : ingestPlan.popup;
        const nextHistory = deps.prependWithLimit(
            ingestPlan.historyBase,
            entry,
            store.state.limit,
            store.state.limit,
            500,
        );
        const nextPopups = deps.prependWithLimit(
            ingestPlan.popupBase,
            popup,
            store.state.popupLimit,
            store.state.popupLimit,
            50,
        );
        const outcome = deps.outcomes.applied({
            code: "notifications.ingested",
            targetId: "notifications",
            meta: {
                key: entry.key,
                id: entry.id,
                policyDecision: String(ingestPlan.decision || "append"),
                repeatCount: Number(entry.repeatCount || 1),
                actionCount: Array.isArray(entry.actions) ? entry.actions.length : 0,
                policy:
                    ingestPlan.meta && typeof ingestPlan.meta === "object" ? ingestPlan.meta : {},
            },
        });

        store.applyMutation(nextHistory, nextPopups, outcome);
        return outcome;
    } catch (error) {
        const outcome = deps.outcomes.failed({
            code: "notifications.ingest_failed",
            targetId: "notifications",
            reason: error && error.message ? String(error.message) : "Notification ingest failed",
        });
        store.applyFailure(outcome, "Notification ingest failed");
        return outcome;
    }
}

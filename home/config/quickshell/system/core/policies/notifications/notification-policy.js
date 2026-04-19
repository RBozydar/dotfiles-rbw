function normalizePolicy(policy) {
    const source = policy && typeof policy === "object" ? policy : {};
    const dedupeWindowCandidate = Number(source.dedupeWindowMs);
    const dedupeWindowMs =
        Number.isInteger(dedupeWindowCandidate) && dedupeWindowCandidate >= 0
            ? Math.min(600000, dedupeWindowCandidate)
            : 5000;

    return {
        replaceById: source.replaceById !== false,
        dedupeByContent: source.dedupeByContent !== false,
        dedupeWindowMs: dedupeWindowMs,
        preserveReadOnReplace: source.preserveReadOnReplace === true,
    };
}

function finiteTimestamp(value) {
    const normalized = Number(value);
    if (!Number.isFinite(normalized))
        throw new Error("Notification policy timestamp must be finite");
    return normalized;
}

function cloneArray(values) {
    return Array.isArray(values) ? values.slice() : [];
}

function normalizeRepeatCount(entry) {
    const count = Number(entry && entry.repeatCount);
    if (!Number.isInteger(count) || count < 1) return 1;
    return count;
}

function findFirstHistoryEntryById(history, notificationId) {
    for (let index = 0; index < history.length; index += 1) {
        const entry = history[index];
        if (Number(entry && entry.id) === notificationId) return entry;
    }

    return null;
}

function findRecentDuplicateEntry(
    history,
    signatureFn,
    targetSignature,
    timestamp,
    dedupeWindowMs,
) {
    for (let index = 0; index < history.length; index += 1) {
        const entry = history[index];
        if (!entry || typeof entry !== "object") continue;
        const signature = signatureFn(entry);
        if (signature !== targetSignature) continue;

        const ageMs = timestamp - Number(entry.timestamp);
        if (!Number.isFinite(ageMs) || ageMs < 0) continue;
        if (ageMs > dedupeWindowMs) continue;
        return entry;
    }

    return null;
}

function removeHistoryById(history, notificationId) {
    const next = [];
    let removedCount = 0;
    let allRemovedWereRead = true;
    let maxRepeatCount = 1;

    for (let index = 0; index < history.length; index += 1) {
        const entry = history[index];
        if (Number(entry && entry.id) === notificationId) {
            removedCount += 1;
            if (!entry || entry.read !== true) allRemovedWereRead = false;
            maxRepeatCount = Math.max(maxRepeatCount, normalizeRepeatCount(entry));
            continue;
        }
        next.push(entry);
    }

    return {
        history: next,
        removedCount: removedCount,
        allRemovedWereRead: allRemovedWereRead,
        maxRepeatCount: maxRepeatCount,
    };
}

function removePopupsById(popups, notificationId) {
    const next = [];
    let removedCount = 0;

    for (let index = 0; index < popups.length; index += 1) {
        const popup = popups[index];
        if (Number(popup && popup.id) === notificationId) {
            removedCount += 1;
            continue;
        }
        next.push(popup);
    }

    return {
        popupList: next,
        removedCount: removedCount,
    };
}

function removeByKey(items, key) {
    const next = [];
    let removedCount = 0;

    for (let index = 0; index < items.length; index += 1) {
        const item = items[index];
        if (item && item.key === key) {
            removedCount += 1;
            continue;
        }
        next.push(item);
    }

    return {
        items: next,
        removedCount: removedCount,
    };
}

function resolveNotificationIngestPlan(options) {
    const source = options && typeof options === "object" ? options : {};
    const policy = normalizePolicy(source.policy);
    const event = source.event && typeof source.event === "object" ? source.event : {};
    const timestamp = finiteTimestamp(source.timestamp);
    const notificationContentSignature = source.notificationContentSignature;

    if (typeof notificationContentSignature !== "function") {
        throw new Error("Notification policy requires notificationContentSignature function");
    }

    const history = cloneArray(source.history);
    const popupList = cloneArray(source.popupList);
    const baseEntry = source.entry && typeof source.entry === "object" ? source.entry : null;
    const basePopup = source.popup && typeof source.popup === "object" ? source.popup : null;

    if (!baseEntry || !basePopup) throw new Error("Notification policy requires entry and popup");

    let decision = "append";
    let entry = baseEntry;
    let popup = basePopup;
    let nextHistory = history;
    let nextPopupList = popupList;
    const meta = {
        replaceById: policy.replaceById,
        dedupeByContent: policy.dedupeByContent,
        dedupeWindowMs: policy.dedupeWindowMs,
    };

    const notificationId = Number(event.id);
    if (policy.replaceById && Number.isFinite(notificationId) && notificationId > 0) {
        const existingEntry = findFirstHistoryEntryById(history, notificationId);
        if (existingEntry) {
            const historyRemoval = removeHistoryById(history, notificationId);
            const popupRemoval = removePopupsById(popupList, notificationId);

            nextHistory = historyRemoval.history;
            nextPopupList = popupRemoval.popupList;
            decision = "replaced_by_id";

            entry = Object.assign({}, entry, {
                repeatCount: historyRemoval.maxRepeatCount,
                read: policy.preserveReadOnReplace ? historyRemoval.allRemovedWereRead : false,
            });
            popup = Object.assign({}, popup, {
                repeatCount: historyRemoval.maxRepeatCount,
            });

            meta.replacedHistoryCount = historyRemoval.removedCount;
            meta.replacedPopupCount = popupRemoval.removedCount;
        }
    }

    if (decision === "append" && policy.dedupeByContent && policy.dedupeWindowMs > 0) {
        const signature = notificationContentSignature(entry);
        const duplicateEntry = findRecentDuplicateEntry(
            history,
            notificationContentSignature,
            signature,
            timestamp,
            policy.dedupeWindowMs,
        );

        if (duplicateEntry) {
            const historyRemoval = removeByKey(history, duplicateEntry.key);
            const popupRemoval = removeByKey(popupList, duplicateEntry.key);
            const repeatCount = normalizeRepeatCount(duplicateEntry) + 1;

            nextHistory = historyRemoval.items;
            nextPopupList = popupRemoval.items;
            decision = "deduplicated_recent";
            entry = Object.assign({}, entry, {
                repeatCount: repeatCount,
            });
            popup = Object.assign({}, popup, {
                repeatCount: repeatCount,
            });

            meta.deduplicatedFromKey = duplicateEntry.key;
            meta.deduplicatedHistoryCount = historyRemoval.removedCount;
            meta.deduplicatedPopupCount = popupRemoval.removedCount;
            meta.repeatCount = repeatCount;
        }
    }

    return {
        decision: decision,
        entry: entry,
        popup: popup,
        historyBase: nextHistory,
        popupBase: nextPopupList,
        meta: meta,
    };
}

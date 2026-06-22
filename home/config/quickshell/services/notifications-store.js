function cloneObject(source) {
    const copy = {};

    if (!source) return copy;

    for (const key in source) copy[key] = source[key];

    return copy;
}

function popupTimeoutMs(expireTimeout) {
    const timeout = Number(expireTimeout ?? -1);

    if (timeout > 1000) return timeout;
    if (timeout > 0) return timeout * 1000;
    return 6000;
}

function createEntry(notification, nowMs) {
    return {
        key: String(notification.id) + "-" + String(nowMs),
        id: notification.id,
        appName: notification.appName || "Notification",
        summary: notification.summary || "Untitled notification",
        body: notification.body || "",
        appIcon: notification.appIcon || "",
        image: notification.image || "",
        urgency: notification.urgency,
        timestamp: nowMs,
        read: false,
    };
}

function createPopupEntry(entry, expiresAt) {
    return {
        key: entry.key,
        id: entry.id,
        appName: entry.appName,
        summary: entry.summary,
        body: entry.body,
        urgency: entry.urgency,
        timestamp: entry.timestamp,
        expiresAt: expiresAt,
    };
}

function prependWithLimit(items, nextItem, limit) {
    return [nextItem].concat(items).slice(0, limit);
}

function remember(history, popupList, notification, nowMs, limit, popupLimit) {
    const entry = createEntry(notification, nowMs);
    const popup = createPopupEntry(entry, nowMs + popupTimeoutMs(notification.expireTimeout));

    return {
        entry: entry,
        history: prependWithLimit(history, entry, limit),
        popupList: prependWithLimit(popupList, popup, popupLimit),
    };
}

function markAllRead(history) {
    const next = [];

    for (let index = 0; index < history.length; index += 1) {
        const entry = cloneObject(history[index]);
        entry.read = true;
        next.push(entry);
    }

    return next;
}

function dismissPopup(popupList, key) {
    const next = [];

    for (let index = 0; index < popupList.length; index += 1) {
        const entry = popupList[index];
        if (entry.key !== key) next.push(entry);
    }

    return next;
}

function clearEntry(history, key) {
    const next = [];

    for (let index = 0; index < history.length; index += 1) {
        const entry = history[index];
        if (entry.key !== key) next.push(entry);
    }

    return next;
}

function markEntryRead(history, key) {
    const next = [];

    for (let index = 0; index < history.length; index += 1) {
        const entry = cloneObject(history[index]);
        if (entry.key === key) entry.read = true;
        next.push(entry);
    }

    return next;
}

function filterUnexpiredPopups(popupList, nowMs) {
    const next = [];

    for (let index = 0; index < popupList.length; index += 1) {
        const entry = popupList[index];
        if (entry.expiresAt > nowMs) next.push(entry);
    }

    return next;
}

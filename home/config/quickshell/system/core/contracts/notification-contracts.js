function clampPositiveInteger(value, fallbackValue, maxValue) {
    const parsed = Number(value);
    if (!Number.isInteger(parsed) || parsed < 1) return fallbackValue;
    if (parsed > maxValue) return maxValue;
    return parsed;
}

function finiteNumber(value, fieldName) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed))
        throw new Error("Notification " + String(fieldName) + " must be a finite number");
    return parsed;
}

function optionalString(value) {
    if (value === undefined || value === null) return "";
    return String(value);
}

function cloneObject(source) {
    const copy = {};
    if (!source || typeof source !== "object") return copy;

    for (const key in source) copy[key] = source[key];

    return copy;
}

function validateNotificationAction(action) {
    if (!action || typeof action !== "object")
        throw new Error("Notification action must be an object");

    const id = optionalString(action.id).trim();
    const label = optionalString(action.label).trim();

    if (id.length === 0) throw new Error("Notification action id must be a non-empty string");
    if (label.length === 0) throw new Error("Notification action label must be a non-empty string");

    return {
        id: id,
        label: label,
    };
}

function cloneNotificationAction(action) {
    return validateNotificationAction(cloneObject(action));
}

function cloneNotificationActions(actions) {
    const next = [];
    if (!Array.isArray(actions)) return next;

    for (let index = 0; index < actions.length; index += 1)
        next.push(cloneNotificationAction(actions[index]));

    return next;
}

function hasNotificationAction(actions, actionId) {
    const normalizedActionId = optionalString(actionId);
    if (!normalizedActionId) return false;

    for (let index = 0; index < actions.length; index += 1) {
        if (actions[index].id === normalizedActionId) return true;
    }

    return false;
}

function popupTimeoutMs(expireTimeout) {
    const timeout = Number(expireTimeout ?? -1);

    // Freedesktop semantics: timeout is milliseconds, 0 means persistent.
    if (timeout === 0) return Number.MAX_SAFE_INTEGER;
    if (timeout > 0) return timeout;
    return 6000;
}

function validateNotificationKey(key) {
    if (typeof key !== "string" || key.length === 0)
        throw new Error("Notification key must be a non-empty string");
    return key;
}

function validateNotificationEvent(event) {
    if (!event || typeof event !== "object")
        throw new Error("Notification event must be an object");
    if (event.kind !== "notifications.event")
        throw new Error("Notification event kind must be notifications.event");

    finiteNumber(event.id, "event.id");
    finiteNumber(event.urgency, "event.urgency");
    finiteNumber(event.expireTimeout, "event.expireTimeout");

    if (typeof event.appName !== "string")
        throw new Error("Notification event appName must be a string");
    if (typeof event.summary !== "string")
        throw new Error("Notification event summary must be a string");
    if (typeof event.body !== "string") throw new Error("Notification event body must be a string");
    if (typeof event.appIcon !== "string")
        throw new Error("Notification event appIcon must be a string");
    if (typeof event.image !== "string")
        throw new Error("Notification event image must be a string");
    if (!Array.isArray(event.actions))
        throw new Error("Notification event actions must be an array");
    if (typeof event.defaultActionId !== "string")
        throw new Error("Notification event defaultActionId must be a string");

    const actions = cloneNotificationActions(event.actions);
    if (event.defaultActionId.length > 0 && !hasNotificationAction(actions, event.defaultActionId))
        throw new Error("Notification event defaultActionId must reference an existing action");

    event.actions = actions;

    return event;
}

function createNotificationEvent(fields) {
    const event = {
        kind: "notifications.event",
        id: finiteNumber(fields.id, "event.id"),
        appName: optionalString(fields.appName),
        summary: optionalString(fields.summary),
        body: optionalString(fields.body),
        appIcon: optionalString(fields.appIcon),
        image: optionalString(fields.image),
        urgency: fields.urgency === undefined ? 1 : finiteNumber(fields.urgency, "event.urgency"),
        expireTimeout:
            fields.expireTimeout === undefined
                ? -1
                : finiteNumber(fields.expireTimeout, "event.expireTimeout"),
        actions: cloneNotificationActions(fields.actions),
        defaultActionId: optionalString(fields.defaultActionId),
    };

    return validateNotificationEvent(event);
}

function validateNotificationEntry(entry) {
    if (!entry || typeof entry !== "object")
        throw new Error("Notification entry must be an object");

    validateNotificationKey(entry.key);
    finiteNumber(entry.id, "entry.id");
    finiteNumber(entry.urgency, "entry.urgency");
    finiteNumber(entry.timestamp, "entry.timestamp");

    if (typeof entry.appName !== "string")
        throw new Error("Notification entry appName must be a string");
    if (typeof entry.summary !== "string")
        throw new Error("Notification entry summary must be a string");
    if (typeof entry.body !== "string") throw new Error("Notification entry body must be a string");
    if (typeof entry.appIcon !== "string")
        throw new Error("Notification entry appIcon must be a string");
    if (typeof entry.image !== "string")
        throw new Error("Notification entry image must be a string");
    if (typeof entry.read !== "boolean")
        throw new Error("Notification entry read must be a boolean");
    if (!Number.isInteger(Number(entry.repeatCount)) || Number(entry.repeatCount) < 1)
        throw new Error("Notification entry repeatCount must be an integer >= 1");
    if (!Array.isArray(entry.actions))
        throw new Error("Notification entry actions must be an array");
    if (typeof entry.defaultActionId !== "string")
        throw new Error("Notification entry defaultActionId must be a string");

    const actions = cloneNotificationActions(entry.actions);
    if (entry.defaultActionId.length > 0 && !hasNotificationAction(actions, entry.defaultActionId))
        throw new Error("Notification entry defaultActionId must reference an existing action");

    entry.actions = actions;

    return entry;
}

function createNotificationEntry(notificationEvent, nowMs) {
    const event = validateNotificationEvent(notificationEvent);
    const timestamp = finiteNumber(nowMs, "entry.timestamp");
    const id = finiteNumber(event.id, "entry.id");

    const entry = {
        key: String(id) + "-" + String(timestamp),
        id: id,
        appName: event.appName.length > 0 ? event.appName : "Notification",
        summary: event.summary.length > 0 ? event.summary : "Untitled notification",
        body: event.body,
        appIcon: event.appIcon,
        image: event.image,
        urgency: finiteNumber(event.urgency, "entry.urgency"),
        timestamp: timestamp,
        read: false,
        repeatCount: 1,
        actions: cloneNotificationActions(event.actions),
        defaultActionId: event.defaultActionId,
    };

    return validateNotificationEntry(entry);
}

function validateNotificationPopup(popup) {
    if (!popup || typeof popup !== "object")
        throw new Error("Notification popup must be an object");

    validateNotificationKey(popup.key);
    finiteNumber(popup.id, "popup.id");
    finiteNumber(popup.urgency, "popup.urgency");
    finiteNumber(popup.timestamp, "popup.timestamp");
    finiteNumber(popup.expiresAt, "popup.expiresAt");

    if (typeof popup.appName !== "string")
        throw new Error("Notification popup appName must be a string");
    if (typeof popup.summary !== "string")
        throw new Error("Notification popup summary must be a string");
    if (typeof popup.body !== "string") throw new Error("Notification popup body must be a string");
    if (!Number.isInteger(Number(popup.repeatCount)) || Number(popup.repeatCount) < 1)
        throw new Error("Notification popup repeatCount must be an integer >= 1");

    return popup;
}

function createNotificationPopup(entry, expiresAt) {
    const normalizedEntry = validateNotificationEntry(entry);
    const popup = {
        key: normalizedEntry.key,
        id: normalizedEntry.id,
        appName: normalizedEntry.appName,
        summary: normalizedEntry.summary,
        body: normalizedEntry.body,
        urgency: normalizedEntry.urgency,
        timestamp: normalizedEntry.timestamp,
        expiresAt: finiteNumber(expiresAt, "popup.expiresAt"),
        repeatCount: Number(normalizedEntry.repeatCount),
    };

    return validateNotificationPopup(popup);
}

function cloneNotificationEntry(entry) {
    return validateNotificationEntry(cloneObject(entry));
}

function cloneNotificationPopup(popup) {
    return validateNotificationPopup(cloneObject(popup));
}

function cloneNotificationEntries(entries) {
    const next = [];
    if (!Array.isArray(entries)) return next;

    for (let index = 0; index < entries.length; index += 1)
        next.push(cloneNotificationEntry(entries[index]));

    return next;
}

function cloneNotificationPopups(popups) {
    const next = [];
    if (!Array.isArray(popups)) return next;

    for (let index = 0; index < popups.length; index += 1)
        next.push(cloneNotificationPopup(popups[index]));

    return next;
}

function prependWithLimit(items, nextItem, limit, fallbackLimit, maxLimit) {
    const normalizedLimit = clampPositiveInteger(
        limit,
        fallbackLimit === undefined ? 120 : Number(fallbackLimit),
        maxLimit === undefined ? 500 : Number(maxLimit),
    );
    const source = Array.isArray(items) ? items : [];
    const prepended = [nextItem];

    for (let index = 0; index < source.length && prepended.length < normalizedLimit; index += 1)
        prepended.push(source[index]);

    return prepended;
}

function notificationContentSignature(value) {
    const source = value && typeof value === "object" ? value : {};
    return (
        optionalString(source.appName).trim().toLowerCase() +
        "\u0000" +
        optionalString(source.summary).trim().toLowerCase() +
        "\u0000" +
        optionalString(source.body).trim().toLowerCase()
    );
}

function countUnreadEntries(historyEntries) {
    let unread = 0;
    const entries = Array.isArray(historyEntries) ? historyEntries : [];

    for (let index = 0; index < entries.length; index += 1) {
        const entry = entries[index];
        if (!entry || entry.read !== true) unread += 1;
    }

    return unread;
}

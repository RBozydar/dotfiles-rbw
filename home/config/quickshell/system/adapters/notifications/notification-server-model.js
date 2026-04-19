function finiteNumberOrFallback(value, fallbackValue) {
    const parsed = Number(value);
    if (!Number.isFinite(parsed)) return fallbackValue;
    return parsed;
}

function asString(value) {
    if (value === undefined || value === null) return "";
    return String(value);
}

function toArray(values) {
    if (Array.isArray(values)) return values;
    if (!values || typeof values !== "object") return [];

    const next = [];
    const length = Number(values.length);
    if (!Number.isInteger(length) || length < 0) return [];

    for (let index = 0; index < length; index += 1) next.push(values[index]);

    return next;
}

function normalizeNotificationAction(action) {
    const source = action && typeof action === "object" ? action : {};
    const id = asString(
        source.id !== undefined
            ? source.id
            : source.identifier !== undefined
              ? source.identifier
              : source.key !== undefined
                ? source.key
                : source.name,
    ).trim();
    if (!id) return null;

    const label = asString(
        source.label !== undefined
            ? source.label
            : source.text !== undefined
              ? source.text
              : source.title !== undefined
                ? source.title
                : id,
    ).trim();

    return {
        id: id,
        label: label || id,
    };
}

function normalizeNotificationActions(actions) {
    const source = toArray(actions);
    const next = [];

    for (let index = 0; index < source.length; index += 1) {
        const action = normalizeNotificationAction(source[index]);
        if (!action) continue;
        next.push(action);
    }

    return next;
}

function actionExists(actions, actionId) {
    const normalizedActionId = asString(actionId).trim();
    if (!normalizedActionId) return false;

    for (let index = 0; index < actions.length; index += 1) {
        const action = actions[index];
        if (action.id === normalizedActionId) return true;
    }

    return false;
}

function resolveDefaultActionId(notification, actions) {
    const source = notification && typeof notification === "object" ? notification : {};
    const candidates = [
        source.defaultActionId,
        source.defaultAction,
        source.defaultActionKey,
        source.defaultActionName,
    ];

    for (let index = 0; index < candidates.length; index += 1) {
        const candidate = asString(candidates[index]).trim();
        if (!candidate) continue;
        if (actionExists(actions, candidate)) return candidate;
    }

    if (actionExists(actions, "default")) return "default";
    if (actions.length === 1) return actions[0].id;
    return "";
}

function normalizeNotification(notification) {
    const source = notification && typeof notification === "object" ? notification : {};
    const actions = normalizeNotificationActions(source.actions);

    return {
        kind: "notifications.event",
        id: finiteNumberOrFallback(source.id, 0),
        appName: asString(source.appName),
        summary: asString(source.summary),
        body: asString(source.body),
        appIcon: asString(source.appIcon),
        image: asString(source.image),
        urgency: finiteNumberOrFallback(source.urgency, 1),
        expireTimeout: finiteNumberOrFallback(source.expireTimeout, -1),
        actions: actions,
        defaultActionId: resolveDefaultActionId(source, actions),
    };
}

function cloneObject(source) {
    const copy = {};
    if (!source || typeof source !== "object") return copy;

    for (const key in source) copy[key] = source[key];

    return copy;
}

function cloneItems(items) {
    const source = Array.isArray(items) ? items : [];
    const next = [];

    for (let index = 0; index < source.length; index += 1) next.push(cloneObject(source[index]));

    return next;
}

function clampPositiveInteger(value, fallbackValue, maxValue) {
    const parsed = Number(value);
    if (!Number.isInteger(parsed) || parsed < 1) return fallbackValue;
    if (parsed > maxValue) return maxValue;
    return parsed;
}

function countUnread(history) {
    let unread = 0;
    const source = Array.isArray(history) ? history : [];

    for (let index = 0; index < source.length; index += 1) {
        const entry = source[index];
        if (!entry || entry.read !== true) unread += 1;
    }

    return unread;
}

function normalizeHistory(history, limit) {
    const cloned = cloneItems(history);
    return cloned.slice(0, limit);
}

function normalizePopupList(popupList, popupLimit) {
    const cloned = cloneItems(popupList);
    return cloned.slice(0, popupLimit);
}

function createInitialNotificationState(limit, popupLimit) {
    const normalizedLimit = clampPositiveInteger(limit, 120, 500);
    const normalizedPopupLimit = clampPositiveInteger(popupLimit, 5, 50);

    return {
        phase: "ready",
        revision: 0,
        history: [],
        popupList: [],
        unreadCount: 0,
        limit: normalizedLimit,
        popupLimit: normalizedPopupLimit,
        lastOutcome: null,
        error: "",
    };
}

function createNotificationStore(options) {
    const settings = options && typeof options === "object" ? options : {};
    const initialState = createInitialNotificationState(settings.limit, settings.popupLimit);

    return {
        state: initialState,

        reset: function () {
            this.state = createInitialNotificationState(this.state.limit, this.state.popupLimit);
        },

        setLimits: function (limit, popupLimit) {
            const nextLimit = clampPositiveInteger(limit, this.state.limit, 500);
            const nextPopupLimit = clampPositiveInteger(popupLimit, this.state.popupLimit, 50);
            const nextHistory = normalizeHistory(this.state.history, nextLimit);
            const nextPopupList = normalizePopupList(this.state.popupList, nextPopupLimit);

            this.state = {
                phase: this.state.phase,
                revision: this.state.revision + 1,
                history: nextHistory,
                popupList: nextPopupList,
                unreadCount: countUnread(nextHistory),
                limit: nextLimit,
                popupLimit: nextPopupLimit,
                lastOutcome: this.state.lastOutcome,
                error: this.state.error,
            };
        },

        applyMutation: function (nextHistory, nextPopupList, outcome) {
            const normalizedHistory = normalizeHistory(nextHistory, this.state.limit);
            const normalizedPopupList = normalizePopupList(nextPopupList, this.state.popupLimit);

            this.state = {
                phase: "ready",
                revision: this.state.revision + 1,
                history: normalizedHistory,
                popupList: normalizedPopupList,
                unreadCount: countUnread(normalizedHistory),
                limit: this.state.limit,
                popupLimit: this.state.popupLimit,
                lastOutcome: outcome,
                error: "",
            };
        },

        applyFailure: function (outcome, fallbackError) {
            const normalizedHistory = normalizeHistory(this.state.history, this.state.limit);
            const normalizedPopupList = normalizePopupList(
                this.state.popupList,
                this.state.popupLimit,
            );

            this.state = {
                phase: "error",
                revision: this.state.revision + 1,
                history: normalizedHistory,
                popupList: normalizedPopupList,
                unreadCount: countUnread(normalizedHistory),
                limit: this.state.limit,
                popupLimit: this.state.popupLimit,
                lastOutcome: outcome,
                error:
                    outcome && outcome.reason
                        ? String(outcome.reason)
                        : String(fallbackError || "Notification operation failed"),
            };
        },
    };
}

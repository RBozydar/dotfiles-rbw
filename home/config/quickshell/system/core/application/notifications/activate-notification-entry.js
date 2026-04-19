function findEntryByKey(history, key) {
    for (let index = 0; index < history.length; index += 1) {
        const entry = history[index];
        if (entry.key === key) return entry;
    }

    return null;
}

function findNotificationAction(actions, actionId) {
    const normalizedActionId = String(actionId || "").trim();
    if (!normalizedActionId || !Array.isArray(actions)) return null;

    for (let index = 0; index < actions.length; index += 1) {
        const action = actions[index];
        if (!action || typeof action !== "object") continue;
        if (String(action.id || "") === normalizedActionId) return action;
    }

    return null;
}

function markEntryRead(history, key) {
    const next = [];

    for (let index = 0; index < history.length; index += 1) {
        const entry = history[index];
        if (entry.key === key) entry.read = true;
        next.push(entry);
    }

    return next;
}

function dismissPopup(popups, key) {
    const next = [];

    for (let index = 0; index < popups.length; index += 1) {
        const popup = popups[index];
        if (popup.key !== key) next.push(popup);
    }

    return next;
}

function normalizeActivationAction(action) {
    if (!action || typeof action !== "object") return null;

    if (String(action.type) === "command.execute") {
        const argv = [];
        if (Array.isArray(action.argv)) {
            for (let index = 0; index < action.argv.length; index += 1)
                argv.push(String(action.argv[index]));
        }

        return {
            type: "command.execute",
            argv: argv,
            targetId: action.targetId === undefined ? undefined : String(action.targetId),
        };
    }

    if (String(action.type) === "notification.action.invoke") {
        const notificationId = Number(action.notificationId);
        const actionId = String(action.actionId || "").trim();

        return {
            type: "notification.action.invoke",
            notificationId: notificationId,
            actionId: actionId,
            targetId: action.targetId === undefined ? undefined : String(action.targetId),
        };
    }

    return {
        type: String(action.type || "unsupported"),
    };
}

function dispatchCommandAction(deps, action) {
    if (!Array.isArray(action.argv) || action.argv.length <= 0) {
        return {
            status: "invalid",
            reason: "Activation command is missing argv",
        };
    }

    if (!deps.commandExecutionPort || typeof deps.commandExecutionPort.execute !== "function") {
        return {
            status: "port_unavailable",
            reason: "Command execution port is unavailable",
        };
    }

    try {
        const accepted = deps.commandExecutionPort.execute(action.argv);
        if (accepted) {
            return {
                status: "dispatched",
                command: action.argv[0],
                argv: action.argv,
                route: "command.execute",
            };
        }

        return {
            status: "rejected",
            reason: "Command execution adapter rejected activation command",
            route: "command.execute",
        };
    } catch (error) {
        return {
            status: "failed",
            reason: error && error.message ? String(error.message) : "Activation dispatch failed",
            route: "command.execute",
        };
    }
}

function dispatchNotificationAction(deps, action) {
    if (!Number.isFinite(action.notificationId)) {
        return {
            status: "invalid",
            reason: "Notification action notificationId must be finite",
            route: "notification.action.invoke",
        };
    }

    if (!action.actionId) {
        return {
            status: "invalid",
            reason: "Notification action id must be non-empty",
            route: "notification.action.invoke",
        };
    }

    if (
        !deps.notificationActionPort ||
        typeof deps.notificationActionPort.invokeAction !== "function"
    ) {
        return {
            status: "port_unavailable",
            reason: "Notification action port is unavailable",
            route: "notification.action.invoke",
        };
    }

    try {
        const dispatchResult = deps.notificationActionPort.invokeAction(
            action.notificationId,
            action.actionId,
        );
        if (dispatchResult === true) {
            return {
                status: "dispatched",
                notificationId: action.notificationId,
                actionId: action.actionId,
                route: "notification.action.invoke",
            };
        }

        if (dispatchResult && typeof dispatchResult === "object") {
            const status = String(dispatchResult.status || "rejected");
            return {
                status: status,
                reason: dispatchResult.reason === undefined ? "" : String(dispatchResult.reason),
                notificationId: action.notificationId,
                actionId: action.actionId,
                route: "notification.action.invoke",
            };
        }

        return {
            status: "rejected",
            reason: "Notification action adapter rejected activation action",
            notificationId: action.notificationId,
            actionId: action.actionId,
            route: "notification.action.invoke",
        };
    } catch (error) {
        return {
            status: "failed",
            reason: error && error.message ? String(error.message) : "Notification action failed",
            notificationId: action.notificationId,
            actionId: action.actionId,
            route: "notification.action.invoke",
        };
    }
}

function dispatchActivationAction(deps, action) {
    if (!action) return { status: "none" };

    if (action.type === "command.execute") return dispatchCommandAction(deps, action);
    if (action.type === "notification.action.invoke")
        return dispatchNotificationAction(deps, action);

    return {
        status: "unsupported",
        reason: "Unsupported activation action type",
    };
}

function activateNotificationEntry(deps, store, key, actionIdOverride) {
    let normalizedKey = "";
    const normalizedActionIdOverride = String(actionIdOverride || "").trim();

    try {
        normalizedKey = deps.validateNotificationKey(String(key || ""));
    } catch (error) {
        return deps.outcomes.rejected({
            code: "notifications.activate.key_required",
            reason: error && error.message ? String(error.message) : "Notification key is required",
            targetId: "notifications",
        });
    }

    try {
        const history = deps.cloneNotificationEntries(store.state.history);
        const popups = deps.cloneNotificationPopups(store.state.popupList);
        const entry = findEntryByKey(history, normalizedKey);

        if (!entry) {
            return deps.outcomes.rejected({
                code: "notifications.activate.not_found",
                reason: "Notification entry was not found",
                targetId: normalizedKey,
            });
        }

        if (
            normalizedActionIdOverride.length > 0 &&
            !findNotificationAction(entry.actions, normalizedActionIdOverride)
        ) {
            return deps.outcomes.rejected({
                code: "notifications.activate.action_not_found",
                reason: "Notification action was not found for this entry",
                targetId: normalizedKey,
                meta: {
                    actionId: normalizedActionIdOverride,
                },
            });
        }

        const nextHistory = markEntryRead(history, normalizedKey);
        const nextPopups = dismissPopup(popups, normalizedKey);

        let action = null;
        if (typeof deps.resolveActivationAction === "function")
            action = normalizeActivationAction(
                deps.resolveActivationAction(entry, normalizedActionIdOverride),
            );
        const activation = dispatchActivationAction(deps, action);

        const outcome = deps.outcomes.applied({
            code: "notifications.activate.applied",
            targetId: normalizedKey,
            meta: {
                action: activation,
                requestedActionId:
                    normalizedActionIdOverride.length > 0 ? normalizedActionIdOverride : undefined,
            },
        });

        store.applyMutation(nextHistory, nextPopups, outcome);
        return outcome;
    } catch (error) {
        const outcome = deps.outcomes.failed({
            code: "notifications.activate.failed",
            reason:
                error && error.message ? String(error.message) : "Failed to activate notification",
            targetId: normalizedKey || "notifications",
        });
        store.applyFailure(outcome, "Failed to activate notification");
        return outcome;
    }
}

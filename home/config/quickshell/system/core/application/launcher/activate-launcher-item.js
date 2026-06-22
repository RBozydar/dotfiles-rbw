function copyStringArray(value) {
    if (!Array.isArray(value)) return [];

    const next = [];
    for (let index = 0; index < value.length; index += 1) next.push(String(value[index]));
    return next;
}

function parseCommandArgv(commandText) {
    const normalized = String(commandText || "").trim();
    if (!normalized) return [];

    const argv = [];
    let current = "";
    let quote = "";

    for (let index = 0; index < normalized.length; index += 1) {
        const character = normalized[index];

        if (quote) {
            if (character === quote) {
                quote = "";
            } else if (
                character === "\\" &&
                index + 1 < normalized.length &&
                normalized[index + 1] === quote
            ) {
                current += quote;
                index += 1;
            } else {
                current += character;
            }
            continue;
        }

        if (character === '"' || character === "'") {
            quote = character;
            continue;
        }

        if (/\s/.test(character)) {
            if (current) {
                argv.push(current);
                current = "";
            }
            continue;
        }

        current += character;
    }

    if (current) argv.push(current);

    return argv;
}

function normalizeDesktopId(value) {
    const desktopId = String(value || "").trim();
    if (!desktopId) return "";
    return desktopId.endsWith(".desktop") ? desktopId.slice(0, -8) : desktopId;
}

function findResultById(store, itemId) {
    if (!store || !store.state || !Array.isArray(store.state.results)) return null;

    const normalizedId = String(itemId || "");
    for (let index = 0; index < store.state.results.length; index += 1) {
        const item = store.state.results[index];
        if (item && item.id === normalizedId) return item;
    }

    return null;
}

function dispatchExternalCommand(deps, argv, targetId, code, meta) {
    const normalizedArgv = copyStringArray(argv);
    if (normalizedArgv.length === 0) {
        return deps.outcomes.rejected({
            code: "launcher.activate.invalid_command",
            reason: "Launcher action does not contain a runnable command",
            targetId: targetId,
            meta: meta || {},
        });
    }

    if (!deps.commandExecutionPort || typeof deps.commandExecutionPort.execute !== "function") {
        return deps.outcomes.rejected({
            code: "launcher.activate.command_port_unavailable",
            reason: "Command execution port is unavailable",
            targetId: targetId,
            meta: meta || {},
        });
    }

    const dispatched = deps.commandExecutionPort.execute(normalizedArgv);
    if (!dispatched) {
        return deps.outcomes.failed({
            code: "launcher.activate.command_dispatch_failed",
            reason: "Command execution adapter did not accept the command",
            targetId: targetId,
            meta: meta || {},
        });
    }

    return deps.outcomes.applied({
        code: code,
        targetId: targetId,
        meta: {
            argv: normalizedArgv,
        },
    });
}

function activateShellIpcAction(deps, action, item) {
    if (!deps.dispatchShellIpcCommand || typeof deps.dispatchShellIpcCommand !== "function") {
        return deps.outcomes.rejected({
            code: "launcher.activate.ipc_dispatch_unavailable",
            reason: "Shell IPC dispatch function is unavailable",
            targetId: item.id,
        });
    }

    const commandName =
        action.command === undefined ? String(action.targetId || "") : String(action.command);
    const args = copyStringArray(action.args);

    if (!commandName) {
        return deps.outcomes.rejected({
            code: "launcher.activate.ipc_command_missing",
            reason: "Launcher IPC action requires a command name",
            targetId: item.id,
        });
    }

    return deps.dispatchShellIpcCommand(commandName, args, {
        source: "launcher.activate",
        launcherItemId: item.id,
    });
}

function activateAppLaunchAction(deps, action, item) {
    const desktopId = normalizeDesktopId(action.targetId);

    if (!desktopId) {
        return deps.outcomes.rejected({
            code: "launcher.activate.app_target_missing",
            reason: "Launcher app action requires a desktop entry id",
            targetId: item.id,
        });
    }

    return dispatchExternalCommand(
        deps,
        ["gtk-launch", desktopId],
        item.id,
        "launcher.activate.app_dispatched",
        {
            desktopId: desktopId,
        },
    );
}

function activateShellCommandAction(deps, action, item) {
    const argv = parseCommandArgv(action.command);
    return dispatchExternalCommand(deps, argv, item.id, "launcher.activate.command_dispatched", {
        command: String(action.command || ""),
    });
}

function activateFileOpenAction(deps, action, item) {
    const path = String(action.targetId || "").trim();
    if (!path) {
        return deps.outcomes.rejected({
            code: "launcher.activate.file_target_missing",
            reason: "File-open action requires a path",
            targetId: item.id,
        });
    }

    return dispatchExternalCommand(
        deps,
        ["xdg-open", path],
        item.id,
        "launcher.activate.file_open_dispatched",
        {
            path: path,
        },
    );
}

function activateClipboardCopyTextAction(deps, action, item, options) {
    const value = action.targetId === undefined ? "" : String(action.targetId);
    if (!value) {
        return deps.outcomes.rejected({
            code:
                options && options.emptyCode
                    ? String(options.emptyCode)
                    : "launcher.activate.clipboard_value_missing",
            reason:
                options && options.emptyReason
                    ? String(options.emptyReason)
                    : "Clipboard copy action does not include a value",
            targetId: item.id,
        });
    }

    return dispatchExternalCommand(
        deps,
        ["wl-copy", value],
        item.id,
        options && options.successCode
            ? String(options.successCode)
            : "launcher.activate.clipboard_copied",
        {
            value: value,
        },
    );
}

function activateCalculatorCopyAction(deps, action, item) {
    return activateClipboardCopyTextAction(deps, action, item, {
        emptyCode: "launcher.activate.calculator_value_missing",
        emptyReason: "Calculator action does not include a value",
        successCode: "launcher.activate.calculator_copied",
    });
}

function normalizeClipboardHistoryEntryId(value) {
    const entryId = String(value || "").trim();
    if (!/^[0-9]+$/.test(entryId)) return "";
    return entryId;
}

function activateClipboardHistoryCopyAction(deps, action, item) {
    const entryId = normalizeClipboardHistoryEntryId(action.targetId);
    if (!entryId) {
        return deps.outcomes.rejected({
            code: "launcher.activate.clipboard_history_target_missing",
            reason: "Clipboard history action requires a numeric cliphist entry id",
            targetId: item.id,
        });
    }

    return dispatchExternalCommand(
        deps,
        ["sh", "-lc", "cliphist decode " + entryId + " | wl-copy"],
        item.id,
        "launcher.activate.clipboard_history_copied",
        {
            entryId: entryId,
        },
    );
}

function previewFileAction(deps, action, item) {
    const path = String(action.targetId || "").trim();
    if (!path) {
        return deps.outcomes.rejected({
            code: "launcher.preview.file_target_missing",
            reason: "File preview action requires a path",
            targetId: item.id,
        });
    }

    return dispatchExternalCommand(
        deps,
        ["sushi", path],
        item.id,
        "launcher.preview.file_dispatched",
        {
            path: path,
        },
    );
}

function activateLauncherItem(deps, store, itemId) {
    const item = findResultById(store, itemId);
    if (!item) {
        return deps.outcomes.stale({
            code: "launcher.activate.item_missing",
            reason: "Launcher item is no longer present in current results",
            targetId: String(itemId || ""),
        });
    }

    const validatedItem = deps.validateLauncherItem(item);
    const action = validatedItem.action;

    if (action.type === "shell.ipc.dispatch")
        return activateShellIpcAction(deps, action, validatedItem);
    if (action.type === "app.launch") return activateAppLaunchAction(deps, action, validatedItem);
    if (action.type === "shell.command.run")
        return activateShellCommandAction(deps, action, validatedItem);
    if (action.type === "file.open") return activateFileOpenAction(deps, action, validatedItem);
    if (action.type === "calculator.copy_result")
        return activateCalculatorCopyAction(deps, action, validatedItem);
    if (action.type === "clipboard.copy_text")
        return activateClipboardCopyTextAction(deps, action, validatedItem);
    if (action.type === "clipboard.copy_history_entry")
        return activateClipboardHistoryCopyAction(deps, action, validatedItem);

    return deps.outcomes.rejected({
        code: "launcher.activate.unsupported_action",
        reason: "Unsupported launcher action type: " + String(action.type),
        targetId: validatedItem.id,
    });
}

function previewLauncherItem(deps, store, itemId) {
    const item = findResultById(store, itemId);
    if (!item) {
        return deps.outcomes.stale({
            code: "launcher.preview.item_missing",
            reason: "Launcher item is no longer present in current results",
            targetId: String(itemId || ""),
        });
    }

    const validatedItem = deps.validateLauncherItem(item);
    const action = validatedItem.action;

    if (action.type === "file.open") return previewFileAction(deps, action, validatedItem);

    return deps.outcomes.rejected({
        code: "launcher.preview.unsupported_action",
        reason: "Unsupported launcher preview action type: " + String(action.type),
        targetId: validatedItem.id,
    });
}

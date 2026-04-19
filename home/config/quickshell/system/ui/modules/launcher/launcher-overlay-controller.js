function clamp(value, min, max) {
    if (!Number.isFinite(value)) return min;
    if (value < min) return min;
    if (value > max) return max;
    return value;
}

function normalizeTotalItemCount(totalItemCount) {
    const parsed = Number(totalItemCount);
    if (!Number.isInteger(parsed) || parsed < 0) return 0;
    return parsed;
}

function resolveCommandPrefix(launcherSettings, fallbackPrefix) {
    const fallback = fallbackPrefix === undefined ? ">" : String(fallbackPrefix);
    const settings =
        launcherSettings && typeof launcherSettings === "object" ? launcherSettings : {};
    const prefix = settings.commandPrefix === undefined ? fallback : String(settings.commandPrefix);
    return prefix.trim();
}

function isCommandModeQuery(query, commandPrefix) {
    const normalizedQuery = String(query || "").trim();
    const normalizedPrefix = String(commandPrefix || "").trim();
    if (!normalizedPrefix) return false;
    return normalizedQuery.indexOf(normalizedPrefix) === 0;
}

function commandAutocompleteCandidate(queryText, commandPrefix, highlightedItem) {
    if (!isCommandModeQuery(queryText, commandPrefix)) return "";

    const item = highlightedItem && typeof highlightedItem === "object" ? highlightedItem : null;
    if (!item || !item.action || item.action.type !== "shell.ipc.dispatch") return "";

    const commandName = String(item.action.command || "").trim();
    if (!commandName) return "";
    return commandName;
}

function autocompleteQuery(queryText, commandPrefix, highlightedItem) {
    const normalizedPrefix = String(commandPrefix || "").trim();
    if (!normalizedPrefix) {
        return {
            applied: false,
            query: String(queryText || ""),
        };
    }

    const commandName = commandAutocompleteCandidate(queryText, normalizedPrefix, highlightedItem);
    if (!commandName) {
        return {
            applied: false,
            query: String(queryText || ""),
        };
    }

    return {
        applied: true,
        query: normalizedPrefix + commandName,
    };
}

function decideNavigationAction(input) {
    const context = input && typeof input === "object" ? input : {};
    const key = context.key;
    const keyCodes =
        context.keyCodes && typeof context.keyCodes === "object" ? context.keyCodes : {};
    const keyEscape = Number(keyCodes.escape);
    const keyTab = Number(keyCodes.tab);
    const keyN = Number(keyCodes.n);
    const keyP = Number(keyCodes.p);
    const keyDown = Number(keyCodes.down);
    const keyUp = Number(keyCodes.up);
    const keyPageDown = Number(keyCodes.pageDown);
    const keyPageUp = Number(keyCodes.pageUp);
    const keyHome = Number(keyCodes.home);
    const keyEnd = Number(keyCodes.end);
    const keyReturn = Number(keyCodes.returnKey);
    const keyEnter = Number(keyCodes.enter);
    const controlPressed = context.controlPressed === true;
    const hasAutocompleteCandidate = context.hasAutocompleteCandidate === true;
    const totalItemCount = normalizeTotalItemCount(context.totalItemCount);

    if (key === keyEscape)
        return {
            kind: "close",
        };

    if (key === keyTab && hasAutocompleteCandidate)
        return {
            kind: "autocomplete",
        };

    if (controlPressed && key === keyN)
        return {
            kind: "move",
            delta: 1,
        };
    if (controlPressed && key === keyP)
        return {
            kind: "move",
            delta: -1,
        };

    if (key === keyDown)
        return {
            kind: "move",
            delta: 1,
        };
    if (key === keyUp)
        return {
            kind: "move",
            delta: -1,
        };
    if (key === keyPageDown)
        return {
            kind: "move",
            delta: 6,
        };
    if (key === keyPageUp)
        return {
            kind: "move",
            delta: -6,
        };

    if (key === keyHome && totalItemCount > 0)
        return {
            kind: "set_index",
            index: 0,
        };
    if (key === keyEnd && totalItemCount > 0)
        return {
            kind: "set_index",
            index: totalItemCount - 1,
        };

    if ((key === keyReturn || key === keyEnter) && totalItemCount > 0)
        return {
            kind: "activate",
        };

    return {
        kind: "noop",
    };
}

function computeVisibleContentY(
    currentContentY,
    viewportHeight,
    contentHeight,
    entryY,
    entryHeight,
    gap,
) {
    const current = Number(currentContentY);
    const viewHeight = Number(viewportHeight);
    const totalContentHeight = Number(contentHeight);
    const itemY = Number(entryY);
    const itemHeight = Number(entryHeight);
    const offset = Number(gap);

    if (
        !Number.isFinite(current) ||
        !Number.isFinite(viewHeight) ||
        !Number.isFinite(totalContentHeight)
    )
        return 0;
    if (!Number.isFinite(itemY) || !Number.isFinite(itemHeight)) return current;

    const normalizedGap = Number.isFinite(offset) ? Math.max(0, offset) : 0;
    const maxContentY = Math.max(0, totalContentHeight - viewHeight);
    const viewTop = current;
    const viewBottom = viewTop + viewHeight;
    const itemBottom = itemY + itemHeight;

    let nextContentY = current;
    if (itemY < viewTop) nextContentY = itemY - normalizedGap;
    else if (itemBottom > viewBottom) nextContentY = itemBottom - viewHeight + normalizedGap;

    return clamp(nextContentY, 0, maxContentY);
}

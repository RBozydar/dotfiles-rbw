function normalizeString(value, fallback) {
    const normalized = String(value === undefined || value === null ? "" : value).trim();
    if (normalized.length > 0) return normalized;
    return fallback === undefined ? "" : String(fallback);
}

function normalizeInteger(value, fallback) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return Math.round(parsed);
    return fallback === undefined ? -1 : Number(fallback);
}

function createWindowSwitcherEntry(fields) {
    const source = fields && typeof fields === "object" ? fields : {};
    const address = normalizeString(source.address, "");
    if (!address) throw new Error("Window switcher entry address must be a non-empty string");

    return {
        id: normalizeString(source.id, "hypr:" + address),
        address: address,
        title: normalizeString(source.title, "(untitled)"),
        className: normalizeString(source.className, "unknown"),
        workspaceId: normalizeInteger(source.workspaceId, -1),
        workspaceName: normalizeString(source.workspaceName, ""),
        monitorId: normalizeInteger(source.monitorId, -1),
        pid: normalizeInteger(source.pid, -1),
        focusHistoryId: normalizeInteger(source.focusHistoryId, 999999),
    };
}

function validateWindowSwitcherEntry(entry) {
    return createWindowSwitcherEntry(entry);
}

function createWindowSwitcherSnapshot(fields) {
    const source = fields && typeof fields === "object" ? fields : {};
    const rawEntries = Array.isArray(source.entries) ? source.entries : [];
    const entries = [];

    for (let index = 0; index < rawEntries.length; index += 1)
        entries.push(validateWindowSwitcherEntry(rawEntries[index]));

    return {
        kind: "compositor.window_switcher_snapshot",
        focusedAddress: normalizeString(source.focusedAddress, ""),
        entries: entries,
        capturedAt: normalizeString(source.capturedAt, new Date().toISOString()),
    };
}

function validateWindowSwitcherSnapshot(snapshot) {
    return createWindowSwitcherSnapshot(snapshot);
}

function createFocusWindowCommand(address) {
    const normalizedAddress = normalizeString(address, "");
    if (!normalizedAddress) throw new Error("Window focus command requires a non-empty address");

    return {
        type: "compositor.focus_window",
        payload: {
            address: normalizedAddress,
        },
    };
}

function validateFocusWindowCommand(command) {
    if (!command || typeof command !== "object")
        throw new Error("Window focus command must be an object");
    if (command.type !== "compositor.focus_window")
        throw new Error("Window focus command type must be compositor.focus_window");
    if (!command.payload || typeof command.payload !== "object")
        throw new Error("Window focus command payload must be an object");

    return createFocusWindowCommand(command.payload.address);
}

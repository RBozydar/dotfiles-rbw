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

function parseJsonArray(rawText) {
    if (typeof rawText !== "string") return [];

    try {
        const parsed = JSON.parse(rawText);
        return Array.isArray(parsed) ? parsed : [];
    } catch (_error) {
        return [];
    }
}

function parseJsonObject(rawText) {
    if (typeof rawText !== "string") return {};

    try {
        const parsed = JSON.parse(rawText);
        if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return {};
        return parsed;
    } catch (_error) {
        return {};
    }
}

function normalizeClient(client) {
    const raw = client && typeof client === "object" ? client : {};
    if (raw.mapped === false || raw.hidden === true) return null;

    const address = normalizeString(raw.address, "");
    if (!address) return null;

    const workspace = raw.workspace && typeof raw.workspace === "object" ? raw.workspace : {};

    return {
        id: "hypr:" + address,
        address: address,
        title: normalizeString(raw.title, normalizeString(raw.initialTitle, "(untitled)")),
        className: normalizeString(raw.class, normalizeString(raw.initialClass, "unknown")),
        workspaceId: normalizeInteger(workspace.id, -1),
        workspaceName: normalizeString(workspace.name, ""),
        monitorId: normalizeInteger(raw.monitor, -1),
        pid: normalizeInteger(raw.pid, -1),
        focusHistoryId: normalizeInteger(raw.focusHistoryID, 999999),
    };
}

function compareEntriesByFocus(left, right) {
    if (left.focusHistoryId !== right.focusHistoryId)
        return left.focusHistoryId - right.focusHistoryId;
    if (left.monitorId !== right.monitorId) return left.monitorId - right.monitorId;

    const leftTitle = normalizeString(left.title, "");
    const rightTitle = normalizeString(right.title, "");
    const titleCmp = leftTitle.localeCompare(rightTitle);
    if (titleCmp !== 0) return titleCmp;

    return normalizeString(left.address, "").localeCompare(normalizeString(right.address, ""));
}

function sortEntriesByFocus(entries) {
    const copy = [];
    for (let index = 0; index < entries.length; index += 1) copy.push(entries[index]);
    copy.sort(compareEntriesByFocus);
    return copy;
}

function normalizeFocusedAddress(activeWindow) {
    const raw = activeWindow && typeof activeWindow === "object" ? activeWindow : {};
    return normalizeString(raw.address, "");
}

function createSnapshotFromObjects(clients, activeWindow) {
    const normalized = [];
    const source = Array.isArray(clients) ? clients : [];

    for (let index = 0; index < source.length; index += 1) {
        const entry = normalizeClient(source[index]);
        if (entry) normalized.push(entry);
    }

    return {
        kind: "compositor.window_switcher_snapshot",
        focusedAddress: normalizeFocusedAddress(activeWindow),
        entries: sortEntriesByFocus(normalized),
        capturedAt: new Date().toISOString(),
    };
}

function createSnapshotFromRaw(clientsRawText, activeWindowRawText) {
    return createSnapshotFromObjects(
        parseJsonArray(clientsRawText),
        parseJsonObject(activeWindowRawText),
    );
}

function findEntryIndexByAddress(entries, address) {
    const normalizedAddress = normalizeString(address, "");
    if (!normalizedAddress) return -1;

    for (let index = 0; index < entries.length; index += 1) {
        if (normalizeString(entries[index].address, "") === normalizedAddress) return index;
    }

    return -1;
}

function normalizedDirection(direction) {
    return Number(direction) < 0 ? -1 : 1;
}

function pickInitialSelectionIndex(entries, focusedAddress, direction) {
    const list = Array.isArray(entries) ? entries : [];
    if (list.length === 0) return -1;

    const step = normalizedDirection(direction);
    const focusedIndex = findEntryIndexByAddress(list, focusedAddress);
    if (focusedIndex < 0) return 0;

    const total = list.length;
    return (focusedIndex + step + total) % total;
}

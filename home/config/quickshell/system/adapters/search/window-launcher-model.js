function normalizeText(value) {
    return String(value === undefined || value === null ? "" : value).trim();
}

function lowercase(value) {
    return normalizeText(value).toLowerCase();
}

function normalizeInteger(value, fallback) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return Math.round(parsed);
    return Number(fallback);
}

function normalizeLimit(value, fallback) {
    const parsed = Number(value);
    if (!Number.isInteger(parsed) || parsed <= 0) return Number(fallback);
    if (parsed > 200) return 200;
    return parsed;
}

function normalizeEntry(entry) {
    const source = entry && typeof entry === "object" ? entry : {};
    const address = normalizeText(source.address);
    if (!address) return null;

    const title = normalizeText(source.title) || "(untitled)";
    const className = normalizeText(source.className) || "unknown";
    const workspaceId = normalizeInteger(source.workspaceId, -1);
    const workspaceName = normalizeText(source.workspaceName);
    const focusHistoryId = normalizeInteger(source.focusHistoryId, 999999);

    return {
        address: address,
        title: title,
        className: className,
        workspaceId: workspaceId,
        workspaceName: workspaceName,
        focusHistoryId: focusHistoryId,
    };
}

function normalizeEntries(rawEntries) {
    const source = Array.isArray(rawEntries) ? rawEntries : [];
    const entries = [];
    const seenAddresses = {};

    for (let index = 0; index < source.length; index += 1) {
        const entry = normalizeEntry(source[index]);
        if (!entry) continue;
        if (seenAddresses[entry.address]) continue;
        seenAddresses[entry.address] = true;
        entries.push(entry);
    }

    return entries;
}

function queryMatches(text, normalizedQuery) {
    if (!normalizedQuery) return true;

    const haystack = lowercase(text);
    if (haystack.indexOf(normalizedQuery) >= 0) return true;

    const terms = normalizedQuery.split(/\s+/).filter(Boolean);
    if (terms.length <= 1) return false;

    for (let index = 0; index < terms.length; index += 1) {
        if (haystack.indexOf(terms[index]) < 0) return false;
    }

    return true;
}

function focusHistoryBoost(focusHistoryId) {
    const normalized = normalizeInteger(focusHistoryId, 999999);
    if (normalized < 0) return 0;
    if (normalized === 0) return 220;
    if (normalized === 1) return 170;
    if (normalized === 2) return 130;
    if (normalized <= 5) return 80;
    if (normalized <= 12) return 40;
    return 0;
}

function queryBoost(entry, normalizedQuery) {
    if (!normalizedQuery) return 0;

    const title = lowercase(entry.title);
    const className = lowercase(entry.className);
    const workspaceName = lowercase(entry.workspaceName);
    const address = lowercase(entry.address);
    let score = 0;

    if (title === normalizedQuery) score += 280;
    else if (title.indexOf(normalizedQuery) === 0) score += 200;
    else if (title.indexOf(normalizedQuery) >= 0) score += 130;

    if (className === normalizedQuery) score += 150;
    else if (className.indexOf(normalizedQuery) >= 0) score += 80;

    if (workspaceName && workspaceName.indexOf(normalizedQuery) >= 0) score += 50;
    if (address.indexOf(normalizedQuery) >= 0) score += 30;
    return score;
}

function subtitleForEntry(entry) {
    const workspaceLabel =
        entry.workspaceName.length > 0
            ? entry.workspaceName
            : entry.workspaceId >= 0
              ? String(entry.workspaceId)
              : "";
    if (workspaceLabel.length > 0) return entry.className + " • ws " + workspaceLabel;
    return entry.className;
}

function createWindowLauncherItem(entry, focusedAddress, normalizedQuery, focusCommand) {
    const focused = normalizeText(focusedAddress) === entry.address;
    const base = 300;
    const focusBoost = focused ? 140 : focusHistoryBoost(entry.focusHistoryId);
    const score = base + focusBoost + queryBoost(entry, normalizedQuery);

    return {
        id: "win:" + entry.address,
        title: entry.title,
        subtitle: subtitleForEntry(entry),
        detail: entry.address,
        iconName: entry.className,
        provider: "windows",
        score: score,
        action: {
            type: "shell.ipc.dispatch",
            command: focusCommand,
            args: [entry.address],
        },
    };
}

function sortItems(items) {
    items.sort(function (left, right) {
        if (right.score !== left.score) return right.score - left.score;
        if (left.title < right.title) return -1;
        if (left.title > right.title) return 1;
        if (left.id < right.id) return -1;
        if (left.id > right.id) return 1;
        return 0;
    });
}

function searchWindowSnapshot(rawSnapshot, rawQuery, limit, commandConfig) {
    const snapshot =
        rawSnapshot && typeof rawSnapshot === "object" && !Array.isArray(rawSnapshot)
            ? rawSnapshot
            : {};
    const entries = normalizeEntries(snapshot.entries);
    if (entries.length <= 0) return [];

    const focusedAddress = normalizeText(snapshot.focusedAddress);
    const normalizedQuery = lowercase(rawQuery).trim();
    const maxResults = normalizeLimit(limit, 24);
    const focusCommand =
        normalizeText(commandConfig && commandConfig.focusCommand) || "window_switcher.focus";

    const items = [];

    for (let index = 0; index < entries.length; index += 1) {
        const entry = entries[index];
        const searchable =
            entry.title +
            " " +
            entry.className +
            " " +
            entry.workspaceName +
            " ws" +
            String(entry.workspaceId) +
            " " +
            entry.address;
        if (!queryMatches(searchable, normalizedQuery)) continue;
        items.push(createWindowLauncherItem(entry, focusedAddress, normalizedQuery, focusCommand));
    }

    sortItems(items);
    if (items.length <= maxResults) return items;
    return items.slice(0, maxResults);
}

function lowercase(value) {
    return String(value || "").toLowerCase();
}

function trimString(value) {
    return String(value || "").trim();
}

function normalizeEntry(rawEntry) {
    if (!rawEntry || typeof rawEntry !== "object") return null;

    const id = trimString(rawEntry.id);
    const preview = trimString(rawEntry.preview);
    if (!/^[0-9]+$/.test(id)) return null;
    if (!preview) return null;

    return {
        id: id,
        preview: preview,
    };
}

function normalizeEntries(rawEntries) {
    if (!Array.isArray(rawEntries)) return [];

    const normalized = [];
    const byId = {};

    for (let index = 0; index < rawEntries.length; index += 1) {
        const entry = normalizeEntry(rawEntries[index]);
        if (!entry) continue;
        if (byId[entry.id]) continue;

        byId[entry.id] = true;
        normalized.push(entry);
    }

    return normalized;
}

function parseListLine(line) {
    const source = String(line || "");
    if (!source.trim()) return null;

    const tabIndex = source.indexOf("\t");
    if (tabIndex <= 0) return null;

    return normalizeEntry({
        id: source.slice(0, tabIndex),
        preview: source.slice(tabIndex + 1),
    });
}

function parseListOutput(text) {
    const lines = String(text || "").split(/\r?\n/);
    const entries = [];

    for (let index = 0; index < lines.length; index += 1) {
        const entry = parseListLine(lines[index]);
        if (!entry) continue;
        entries.push(entry);
    }

    return normalizeEntries(entries);
}

function entryMatchesQuery(entry, query) {
    const normalizedQuery = lowercase(query).trim();
    if (!normalizedQuery) return false;

    const preview = lowercase(entry.preview);
    if (preview.indexOf(normalizedQuery) >= 0) return true;
    return entry.id.indexOf(normalizedQuery) >= 0;
}

function scoreEntry(entry, query) {
    const normalizedQuery = lowercase(query).trim();
    if (!normalizedQuery) return 0;

    const preview = lowercase(entry.preview);
    let score = 90;

    if (preview === normalizedQuery) score += 920;
    else if (preview.indexOf(normalizedQuery) === 0) score += 520;
    else if (preview.indexOf(normalizedQuery) >= 0) score += 200;

    if (entry.id === normalizedQuery) score += 240;
    else if (entry.id.indexOf(normalizedQuery) === 0) score += 120;

    return score;
}

function truncatePreview(text, maxLength) {
    const source = trimString(text);
    const normalizedLimit = Number.isInteger(Number(maxLength)) ? Number(maxLength) : 84;
    if (source.length <= normalizedLimit) return source;
    return source.slice(0, Math.max(1, normalizedLimit - 1)) + "…";
}

function toLauncherItem(entry, query) {
    const preview = truncatePreview(entry.preview, 84);

    return {
        id: "clipboard:" + entry.id,
        title: preview || "Clipboard item #" + entry.id,
        subtitle: "Clipboard history",
        detail: "cliphist #" + entry.id,
        iconName: "edit-paste",
        provider: "clipboard",
        score: scoreEntry(entry, query),
        action: {
            type: "clipboard.copy_history_entry",
            targetId: entry.id,
        },
    };
}

function searchEntries(entries, query, limit) {
    const normalized = normalizeEntries(entries);
    const normalizedLimit =
        Number.isInteger(Number(limit)) && Number(limit) > 0 ? Number(limit) : 120;
    const results = [];

    for (let index = 0; index < normalized.length; index += 1) {
        const entry = normalized[index];
        if (!entryMatchesQuery(entry, query)) continue;

        results.push(toLauncherItem(entry, query));
    }

    results.sort(function (left, right) {
        if (right.score !== left.score) return right.score - left.score;
        if (left.title < right.title) return -1;
        if (left.title > right.title) return 1;
        return 0;
    });

    if (results.length <= normalizedLimit) return results;
    return results.slice(0, normalizedLimit);
}

function lowercase(value) {
    return String(value || "").toLowerCase();
}

function trimString(value) {
    return String(value || "").trim();
}

function copyStringArray(values) {
    if (!Array.isArray(values)) return [];

    const copied = [];
    for (let index = 0; index < values.length; index += 1) {
        const value = trimString(values[index]);
        if (!value) continue;
        copied.push(value);
    }

    return copied;
}

function normalizeCatalogEntry(rawEntry) {
    if (!rawEntry || typeof rawEntry !== "object") return null;

    const desktopId = trimString(rawEntry.desktopId);
    const name = trimString(rawEntry.name);
    const exec = trimString(rawEntry.exec);
    if (!desktopId || !name || !exec) return null;

    return {
        desktopId: desktopId,
        name: name,
        iconName: trimString(rawEntry.iconName),
        genericName: trimString(rawEntry.genericName),
        comment: trimString(rawEntry.comment),
        exec: exec,
        keywords: copyStringArray(rawEntry.keywords),
        categories: copyStringArray(rawEntry.categories),
        terminal: Boolean(rawEntry.terminal),
        sourcePriority: Number.isFinite(Number(rawEntry.sourcePriority))
            ? Number(rawEntry.sourcePriority)
            : 999,
    };
}

function normalizeCatalogEntries(rawEntries) {
    if (!Array.isArray(rawEntries)) return [];

    const normalized = [];
    const byId = {};

    for (let index = 0; index < rawEntries.length; index += 1) {
        const entry = normalizeCatalogEntry(rawEntries[index]);
        if (!entry) continue;
        if (byId[entry.desktopId]) continue;

        byId[entry.desktopId] = true;
        normalized.push(entry);
    }

    normalized.sort(function (left, right) {
        if (left.sourcePriority !== right.sourcePriority)
            return left.sourcePriority - right.sourcePriority;

        const leftName = lowercase(left.name);
        const rightName = lowercase(right.name);
        if (leftName < rightName) return -1;
        if (leftName > rightName) return 1;
        return 0;
    });

    return normalized;
}

function parseCatalogJson(text) {
    const source = String(text || "").trim();
    if (!source) return [];

    try {
        const parsed = JSON.parse(source);
        return normalizeCatalogEntries(parsed);
    } catch (error) {
        return [];
    }
}

function entryMatchesQuery(entry, query) {
    const normalizedQuery = lowercase(query).trim();
    if (!normalizedQuery) return true;

    const name = lowercase(entry.name);
    const genericName = lowercase(entry.genericName);
    const comment = lowercase(entry.comment);
    const exec = lowercase(entry.exec);

    if (name.indexOf(normalizedQuery) >= 0) return true;
    if (genericName.indexOf(normalizedQuery) >= 0) return true;
    if (comment.indexOf(normalizedQuery) >= 0) return true;
    if (exec.indexOf(normalizedQuery) >= 0) return true;

    for (let index = 0; index < entry.keywords.length; index += 1) {
        if (lowercase(entry.keywords[index]).indexOf(normalizedQuery) >= 0) return true;
    }

    return false;
}

function scoreEntry(entry, query) {
    const normalizedQuery = lowercase(query).trim();
    const name = lowercase(entry.name);
    const genericName = lowercase(entry.genericName);
    const comment = lowercase(entry.comment);
    const exec = lowercase(entry.exec);
    let score = 120;

    if (!normalizedQuery) return score;

    if (name === normalizedQuery) score += 900;
    else if (name.indexOf(normalizedQuery) === 0) score += 520;
    else if (name.indexOf(normalizedQuery) >= 0) score += 260;

    if (genericName === normalizedQuery) score += 420;
    else if (genericName.indexOf(normalizedQuery) === 0) score += 220;
    else if (genericName.indexOf(normalizedQuery) >= 0) score += 120;

    if (comment.indexOf(normalizedQuery) >= 0) score += 80;
    if (exec.indexOf(normalizedQuery) >= 0) score += 40;

    for (let index = 0; index < entry.keywords.length; index += 1) {
        const keyword = lowercase(entry.keywords[index]);
        if (keyword === normalizedQuery) score += 180;
        else if (keyword.indexOf(normalizedQuery) >= 0) score += 60;
    }

    return score;
}

function subtitleForEntry(entry) {
    if (entry.genericName) return entry.genericName;
    if (entry.comment) return entry.comment;
    return entry.exec;
}

function detailForEntry(entry) {
    if (entry.comment) return entry.comment;
    if (entry.categories.length > 0) return entry.categories.slice(0, 3).join(", ");
    return entry.exec;
}

function toLauncherItem(entry, query) {
    return {
        id: "app:" + entry.desktopId,
        title: entry.name,
        subtitle: subtitleForEntry(entry),
        detail: detailForEntry(entry),
        iconName: entry.iconName,
        provider: "apps",
        score: scoreEntry(entry, query),
        action: {
            type: "app.launch",
            targetId: entry.desktopId,
        },
    };
}

function searchCatalogEntries(entries, query, limit) {
    const normalizedEntries = normalizeCatalogEntries(entries);
    const normalizedLimit =
        Number.isInteger(Number(limit)) && Number(limit) > 0 ? Number(limit) : 200;
    const results = [];

    for (let index = 0; index < normalizedEntries.length; index += 1) {
        const entry = normalizedEntries[index];
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

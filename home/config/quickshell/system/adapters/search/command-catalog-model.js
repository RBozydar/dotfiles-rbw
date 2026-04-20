function lowercase(value) {
    return String(value || "").toLowerCase();
}

function trimString(value) {
    return String(value || "").trim();
}

function normalizeEntry(rawEntry) {
    if (!rawEntry || typeof rawEntry !== "object") return null;

    const name = trimString(rawEntry.name);
    const path = trimString(rawEntry.path);
    if (!name || !path) return null;

    return {
        name: name,
        path: path,
        sourcePriority:
            Number.isInteger(Number(rawEntry.sourcePriority)) &&
            Number(rawEntry.sourcePriority) >= 0
                ? Number(rawEntry.sourcePriority)
                : 999,
    };
}

function normalizeEntries(rawEntries) {
    if (!Array.isArray(rawEntries)) return [];

    const normalized = [];
    const byName = {};

    for (let index = 0; index < rawEntries.length; index += 1) {
        const entry = normalizeEntry(rawEntries[index]);
        if (!entry) continue;
        if (byName[entry.name]) continue;
        byName[entry.name] = true;
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
        return normalizeEntries(parsed);
    } catch (error) {
        return [];
    }
}

function scoreEntry(entry, query) {
    const normalizedQuery = lowercase(query).trim();
    if (!normalizedQuery) return 200;

    const name = lowercase(entry.name);
    const path = lowercase(entry.path);

    let score = 300;

    if (name === normalizedQuery) score += 1000;
    else if (name.indexOf(normalizedQuery) === 0) score += 620;
    else if (name.indexOf(normalizedQuery) >= 0) score += 280;

    if (path.indexOf("/" + normalizedQuery) >= 0) score += 120;
    else if (path.indexOf(normalizedQuery) >= 0) score += 60;

    return score;
}

function toLauncherItem(entry, query) {
    return {
        id: "cmd:" + entry.name,
        title: entry.name,
        subtitle: entry.path,
        detail: "Executable command",
        iconName: "utilities-terminal",
        provider: "commands",
        score: scoreEntry(entry, query),
        action: {
            type: "shell.command.run",
            command: entry.name,
        },
    };
}

function searchEntries(entries, query, limit) {
    const normalizedQuery = trimString(query);
    const normalizedEntries = normalizeEntries(entries);
    const normalizedLimit =
        Number.isInteger(Number(limit)) && Number(limit) > 0 ? Number(limit) : 80;
    const queryLower = lowercase(normalizedQuery);
    const results = [];

    for (let index = 0; index < normalizedEntries.length; index += 1) {
        const entry = normalizedEntries[index];
        const name = lowercase(entry.name);
        const path = lowercase(entry.path);

        if (queryLower.length > 0 && name.indexOf(queryLower) < 0 && path.indexOf(queryLower) < 0)
            continue;
        results.push(toLauncherItem(entry, normalizedQuery));
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

function lowercase(value) {
    return String(value || "").toLowerCase();
}

function trimString(value) {
    return String(value || "").trim();
}

function copyStringArray(values) {
    if (!Array.isArray(values)) return [];

    const copied = [];
    const dedupe = {};

    for (let index = 0; index < values.length; index += 1) {
        const value = trimString(values[index]);
        if (!value) continue;
        if (dedupe[value]) continue;
        dedupe[value] = true;
        copied.push(value);
    }

    return copied;
}

function normalizeIdentifierPart(value, fallbackValue) {
    const source = trimString(value || fallbackValue || "")
        .toLowerCase()
        .replace(/[^a-z0-9._-]+/g, "-")
        .replace(/^-+/, "")
        .replace(/-+$/, "");

    if (source) return source;
    return trimString(fallbackValue || "emoji");
}

function normalizeEntry(rawEntry, fallbackIndex) {
    if (!rawEntry || typeof rawEntry !== "object") return null;

    const emoji = trimString(rawEntry.emoji);
    const description = trimString(rawEntry.description);
    const category = trimString(rawEntry.category);
    const aliases = copyStringArray(rawEntry.aliases);
    const tags = copyStringArray(rawEntry.tags);
    const primaryAlias = aliases.length > 0 ? aliases[0] : "";
    const id =
        "emoji:" + normalizeIdentifierPart(primaryAlias || description, String(fallbackIndex));

    if (!emoji) return null;

    return {
        id: id,
        emoji: emoji,
        description: description,
        category: category,
        aliases: aliases,
        tags: tags,
    };
}

function normalizeEmojiEntries(rawEntries) {
    if (!Array.isArray(rawEntries)) return [];

    const normalized = [];
    const byId = {};

    for (let index = 0; index < rawEntries.length; index += 1) {
        const entry = normalizeEntry(rawEntries[index], index);
        if (!entry) continue;
        if (byId[entry.id]) continue;
        byId[entry.id] = true;
        normalized.push(entry);
    }

    normalized.sort(function (left, right) {
        const leftDescription = lowercase(left.description);
        const rightDescription = lowercase(right.description);
        if (leftDescription < rightDescription) return -1;
        if (leftDescription > rightDescription) return 1;
        if (left.id < right.id) return -1;
        if (left.id > right.id) return 1;
        return 0;
    });

    return normalized;
}

function parseEmojiCatalogJson(text) {
    const source = String(text || "").trim();
    if (!source) return [];

    try {
        const parsed = JSON.parse(source);
        return normalizeEmojiEntries(parsed);
    } catch (error) {
        return [];
    }
}

function normalizeQuery(query) {
    const source = trimString(query).toLowerCase();
    if (!source) return "";
    return source[0] === ":" ? source.slice(1).trim() : source;
}

function entryMatchesQuery(entry, query) {
    const normalizedQuery = normalizeQuery(query);
    if (!normalizedQuery) return false;

    if (entry.emoji === normalizedQuery) return true;
    if (lowercase(entry.description).indexOf(normalizedQuery) >= 0) return true;
    if (lowercase(entry.category).indexOf(normalizedQuery) >= 0) return true;

    for (let index = 0; index < entry.aliases.length; index += 1) {
        if (lowercase(entry.aliases[index]).indexOf(normalizedQuery) >= 0) return true;
    }

    for (let index = 0; index < entry.tags.length; index += 1) {
        if (lowercase(entry.tags[index]).indexOf(normalizedQuery) >= 0) return true;
    }

    return false;
}

function scoreEntry(entry, query) {
    const normalizedQuery = normalizeQuery(query);
    if (!normalizedQuery) return 0;

    const description = lowercase(entry.description);
    const category = lowercase(entry.category);
    let score = 80;

    if (entry.emoji === normalizedQuery) score += 960;

    if (description === normalizedQuery) score += 520;
    else if (description.indexOf(normalizedQuery) === 0) score += 300;
    else if (description.indexOf(normalizedQuery) >= 0) score += 140;

    if (category.indexOf(normalizedQuery) >= 0) score += 60;

    for (let index = 0; index < entry.aliases.length; index += 1) {
        const alias = lowercase(entry.aliases[index]);
        if (alias === normalizedQuery) score += 680;
        else if (alias.indexOf(normalizedQuery) === 0) score += 360;
        else if (alias.indexOf(normalizedQuery) >= 0) score += 190;
    }

    for (let index = 0; index < entry.tags.length; index += 1) {
        const tag = lowercase(entry.tags[index]);
        if (tag === normalizedQuery) score += 210;
        else if (tag.indexOf(normalizedQuery) >= 0) score += 90;
    }

    return score;
}

function subtitleForEntry(entry) {
    if (entry.aliases.length > 0) return ":" + entry.aliases[0] + ":";
    if (entry.description) return entry.description;
    return "Emoji";
}

function detailForEntry(entry) {
    const parts = [];
    if (entry.category) parts.push(entry.category);
    if (entry.tags.length > 0) parts.push(entry.tags.slice(0, 4).join(", "));
    return parts.join(" • ");
}

function titleForEntry(entry) {
    if (entry.description) return entry.emoji + "  " + entry.description;
    return entry.emoji;
}

function toLauncherItem(entry, query) {
    return {
        id: entry.id,
        title: titleForEntry(entry),
        subtitle: subtitleForEntry(entry),
        detail: detailForEntry(entry),
        iconName: "face-smile",
        provider: "emoji",
        score: scoreEntry(entry, query),
        action: {
            type: "clipboard.copy_text",
            targetId: entry.emoji,
        },
    };
}

function searchEmojiEntries(entries, query, limit) {
    const normalized = normalizeEmojiEntries(entries);
    const normalizedLimit =
        Number.isInteger(Number(limit)) && Number(limit) > 0 ? Number(limit) : 60;
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

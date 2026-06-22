function lowercase(value) {
    return String(value === undefined ? "" : value).toLowerCase();
}

function trimString(value) {
    return String(value === undefined ? "" : value).trim();
}

function normalizeImagePath(value) {
    const path = trimString(value);
    if (!path) return "";

    const normalized = path.replace(/\\/g, "/");
    if (!normalized) return "";

    return normalized;
}

function hasSupportedImageExtension(path) {
    const normalized = lowercase(path);
    return (
        normalized.endsWith(".png") ||
        normalized.endsWith(".jpg") ||
        normalized.endsWith(".jpeg") ||
        normalized.endsWith(".webp") ||
        normalized.endsWith(".bmp") ||
        normalized.endsWith(".gif")
    );
}

function fileNameFromPath(path) {
    const normalized = normalizeImagePath(path);
    if (!normalized) return "";

    const parts = normalized.split("/");
    return parts.length > 0 ? parts[parts.length - 1] : "";
}

function parentDirectoryFromPath(path) {
    const normalized = normalizeImagePath(path);
    if (!normalized) return "";

    const parts = normalized.split("/");
    if (parts.length <= 1) return "";
    return parts[parts.length - 2];
}

function withoutExtension(name) {
    const normalized = trimString(name);
    if (!normalized) return "";

    return normalized.replace(/\.[^.]+$/, "");
}

function humanizeLabel(value) {
    const normalized = trimString(value);
    if (!normalized) return "";

    return normalized.replace(/[_-]+/g, " ").replace(/\s+/g, " ").trim();
}

function createEntry(path) {
    const normalizedPath = normalizeImagePath(path);
    if (!normalizedPath) return null;
    if (!hasSupportedImageExtension(normalizedPath)) return null;

    const fileName = fileNameFromPath(normalizedPath);
    const parentDirectory = humanizeLabel(parentDirectoryFromPath(normalizedPath));
    const title = humanizeLabel(withoutExtension(fileName));

    return {
        path: normalizedPath,
        fileName: fileName,
        title: title || fileName || normalizedPath,
        subtitle: parentDirectory,
    };
}

function compareEntries(left, right) {
    const leftTitle = lowercase(left && left.title);
    const rightTitle = lowercase(right && right.title);
    if (leftTitle < rightTitle) return -1;
    if (leftTitle > rightTitle) return 1;

    const leftPath = lowercase(left && left.path);
    const rightPath = lowercase(right && right.path);
    if (leftPath < rightPath) return -1;
    if (leftPath > rightPath) return 1;
    return 0;
}

function normalizeEntries(paths, maxEntries) {
    const source = Array.isArray(paths) ? paths : [];
    const dedupe = {};
    const entries = [];
    const parsedMaxEntries = Number(maxEntries);
    const limit =
        Number.isInteger(parsedMaxEntries) && parsedMaxEntries > 0
            ? parsedMaxEntries
            : Number.MAX_SAFE_INTEGER;

    for (let index = 0; index < source.length; index += 1) {
        const entry = createEntry(source[index]);
        if (!entry) continue;
        if (dedupe[entry.path]) continue;
        dedupe[entry.path] = true;
        entries.push(entry);
    }

    entries.sort(compareEntries);

    if (entries.length > limit) return entries.slice(0, limit);
    return entries;
}

function parseFindOutput(text) {
    const lines = String(text === undefined ? "" : text).split(/\r?\n/);
    const paths = [];

    for (let index = 0; index < lines.length; index += 1) {
        const path = trimString(lines[index]);
        if (!path) continue;
        paths.push(path);
    }

    return paths;
}

function scoreEntry(entry, query, terms) {
    const normalizedQuery = lowercase(query);
    const title = lowercase(entry.title);
    const subtitle = lowercase(entry.subtitle);
    const path = lowercase(entry.path);
    const fileName = lowercase(entry.fileName);

    let score = 0;

    if (title === normalizedQuery) score += 520;
    else if (title.indexOf(normalizedQuery) === 0) score += 360;
    else if (title.indexOf(normalizedQuery) >= 0) score += 220;
    else if (fileName.indexOf(normalizedQuery) >= 0) score += 170;
    else if (subtitle.indexOf(normalizedQuery) >= 0) score += 140;
    else if (path.indexOf(normalizedQuery) >= 0) score += 100;
    else return -1;

    for (let index = 0; index < terms.length; index += 1) {
        const term = terms[index];
        if (!term) continue;
        if (title.indexOf(term) >= 0) score += 45;
        if (subtitle.indexOf(term) >= 0) score += 20;
        if (path.indexOf(term) >= 0) score += 15;
    }

    return score;
}

function searchEntries(entries, query, resultLimit) {
    const normalizedQuery = trimString(query);
    if (!normalizedQuery) return [];

    const source = Array.isArray(entries) ? entries : [];
    const terms = lowercase(normalizedQuery)
        .split(/\s+/)
        .filter((term) => term.length > 0);
    const parsedResultLimit = Number(resultLimit);
    const limit =
        Number.isInteger(parsedResultLimit) && parsedResultLimit > 0 ? parsedResultLimit : 1;
    const ranked = [];

    for (let index = 0; index < source.length; index += 1) {
        const entry = source[index];
        if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue;

        const score = scoreEntry(entry, normalizedQuery, terms);
        if (score < 0) continue;

        ranked.push({
            id: "wallpaper:" + entry.path,
            title: entry.title,
            subtitle: entry.subtitle,
            detail: entry.path,
            iconName: "image-x-generic",
            provider: "wallpaper",
            score: score,
            action: {
                type: "shell.ipc.dispatch",
                command: "wallpaper.set",
                args: [entry.path],
            },
        });
    }

    ranked.sort((left, right) => {
        const scoreDelta = Number(right.score) - Number(left.score);
        if (scoreDelta !== 0) return scoreDelta;
        const leftTitle = lowercase(left.title);
        const rightTitle = lowercase(right.title);
        if (leftTitle < rightTitle) return -1;
        if (leftTitle > rightTitle) return 1;
        return 0;
    });

    if (ranked.length > limit) return ranked.slice(0, limit);
    return ranked;
}

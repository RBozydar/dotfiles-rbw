function lowercase(value) {
    return String(value || "").toLowerCase();
}

function trimString(value) {
    return String(value || "").trim();
}

function normalizePath(value) {
    const source = trimString(value);
    if (!source) return "";
    if (source === "/") return "/";
    return source.replace(/\/+$/, "");
}

function basename(path) {
    const normalized = normalizePath(path);
    if (!normalized || normalized === "/") return normalized;

    const slashIndex = normalized.lastIndexOf("/");
    if (slashIndex < 0) return normalized;
    return normalized.slice(slashIndex + 1);
}

function dirname(path) {
    const normalized = normalizePath(path);
    if (!normalized || normalized === "/") return "";

    const slashIndex = normalized.lastIndexOf("/");
    if (slashIndex < 0) return "";
    if (slashIndex === 0) return "/";
    return normalized.slice(0, slashIndex);
}

function extension(name) {
    const source = trimString(name);
    const dotIndex = source.lastIndexOf(".");
    if (dotIndex <= 0 || dotIndex === source.length - 1) return "";
    return lowercase(source.slice(dotIndex + 1));
}

function iconForEntry(entry) {
    const ext = extension(entry.name);

    if (ext === "png" || ext === "jpg" || ext === "jpeg" || ext === "webp" || ext === "svg")
        return "image-x-generic";
    if (ext === "mp3" || ext === "flac" || ext === "wav" || ext === "ogg") return "audio-x-generic";
    if (ext === "mp4" || ext === "mkv" || ext === "mov" || ext === "webm") return "video-x-generic";
    if (ext === "zip" || ext === "gz" || ext === "tar" || ext === "xz" || ext === "7z")
        return "package-x-generic";

    return "text-x-generic";
}

function normalizeEntry(rawPath) {
    const path = normalizePath(rawPath);
    if (!path) return null;

    return {
        path: path,
        name: basename(path),
        directory: dirname(path),
    };
}

function normalizeEntries(rawEntries) {
    if (!Array.isArray(rawEntries)) return [];

    const normalized = [];
    const byPath = {};

    for (let index = 0; index < rawEntries.length; index += 1) {
        const source = rawEntries[index];
        const entry = normalizeEntry(typeof source === "string" ? source : source && source.path);
        if (!entry) continue;
        if (byPath[entry.path]) continue;
        byPath[entry.path] = true;
        normalized.push(entry);
    }

    return normalized;
}

function parseFdOutput(text) {
    const lines = String(text || "").split(/\r?\n/);
    const entries = [];

    for (let index = 0; index < lines.length; index += 1) {
        const entry = normalizeEntry(lines[index]);
        if (!entry) continue;
        entries.push(entry);
    }

    return normalizeEntries(entries);
}

function normalizeQuery(query) {
    return lowercase(trimString(query));
}

function entryMatchesQuery(entry, query) {
    const normalizedQuery = normalizeQuery(query);
    if (!normalizedQuery) return false;

    const name = lowercase(entry.name);
    const path = lowercase(entry.path);
    return name.indexOf(normalizedQuery) >= 0 || path.indexOf(normalizedQuery) >= 0;
}

function scoreEntry(entry, query) {
    const normalizedQuery = normalizeQuery(query);
    if (!normalizedQuery) return 0;

    const name = lowercase(entry.name);
    const path = lowercase(entry.path);
    let score = 80;

    if (name === normalizedQuery) score += 920;
    else if (name.indexOf(normalizedQuery) === 0) score += 520;
    else if (name.indexOf(normalizedQuery) >= 0) score += 220;

    if (path === normalizedQuery) score += 360;
    else if (path.indexOf("/" + normalizedQuery) >= 0) score += 180;
    else if (path.indexOf(normalizedQuery) >= 0) score += 100;

    if (extension(entry.name) === normalizedQuery) score += 160;

    return score;
}

function toLauncherItem(entry, query) {
    return {
        id: "file:" + entry.path,
        title: entry.name || entry.path,
        subtitle: entry.directory || "File search",
        detail: entry.path,
        iconName: iconForEntry(entry),
        provider: "files",
        score: scoreEntry(entry, query),
        action: {
            type: "file.open",
            targetId: entry.path,
        },
    };
}

function searchEntries(entries, query, limit) {
    const normalizedEntries = normalizeEntries(entries);
    const normalizedLimit =
        Number.isInteger(Number(limit)) && Number(limit) > 0 ? Number(limit) : 80;
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
        if (left.id < right.id) return -1;
        if (left.id > right.id) return 1;
        return 0;
    });

    if (results.length <= normalizedLimit) return results;
    return results.slice(0, normalizedLimit);
}

function normalizeString(value) {
    return String(value === undefined || value === null ? "" : value).trim();
}

function normalizeAbsolutePath(path) {
    const normalized = normalizeString(path);
    if (!normalized.startsWith("/")) return "";
    return normalized;
}

function normalizeLimit(limit) {
    const parsed = Number(limit);
    if (!Number.isInteger(parsed) || parsed < 1) return 64;
    if (parsed > 512) return 512;
    return parsed;
}

function cloneEntries(entries) {
    if (!Array.isArray(entries)) return [];
    const next = [];
    for (let index = 0; index < entries.length; index += 1) {
        const entry = entries[index];
        if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue;
        const path = normalizeAbsolutePath(entry.path);
        if (!path) continue;
        next.push({
            path: path,
            at: normalizeString(entry.at),
            source: normalizeString(entry.source),
        });
    }
    return next;
}

function clampCursor(cursor, entriesLength) {
    if (!Number.isInteger(cursor)) return entriesLength > 0 ? entriesLength - 1 : -1;
    if (entriesLength <= 0) return -1;
    if (cursor < 0) return 0;
    if (cursor >= entriesLength) return entriesLength - 1;
    return cursor;
}

function createWallpaperHistoryState(options) {
    const source = options && typeof options === "object" ? options : {};
    const entries = cloneEntries(source.entries);
    const limit = normalizeLimit(source.limit);
    let nextEntries = entries;

    if (nextEntries.length > limit) nextEntries = nextEntries.slice(nextEntries.length - limit);

    const cursor = clampCursor(source.cursor, nextEntries.length);
    return {
        kind: "wallpaper.workflow.history_state",
        limit: limit,
        cursor: cursor,
        entries: nextEntries,
    };
}

function currentWallpaperPath(state) {
    const normalizedState = createWallpaperHistoryState(state);
    if (normalizedState.cursor < 0 || normalizedState.cursor >= normalizedState.entries.length)
        return "";
    return normalizedState.entries[normalizedState.cursor].path;
}

function appendWallpaperHistoryEntry(state, path, source, atIso) {
    const normalizedPath = normalizeAbsolutePath(path);
    if (!normalizedPath) return createWallpaperHistoryState(state);

    const normalizedState = createWallpaperHistoryState(state);
    const limit = normalizeLimit(normalizedState.limit);
    let entries = cloneEntries(normalizedState.entries);
    let cursor = clampCursor(normalizedState.cursor, entries.length);

    if (cursor >= 0 && cursor < entries.length - 1) entries = entries.slice(0, cursor + 1);

    const nowIso = normalizeString(atIso) || new Date().toISOString();
    const normalizedSource = normalizeString(source);

    if (entries.length > 0 && entries[entries.length - 1].path === normalizedPath) {
        entries[entries.length - 1] = {
            path: normalizedPath,
            at: nowIso,
            source: normalizedSource,
        };
    } else {
        entries.push({
            path: normalizedPath,
            at: nowIso,
            source: normalizedSource,
        });
    }

    if (entries.length > limit) entries = entries.slice(entries.length - limit);

    cursor = entries.length > 0 ? entries.length - 1 : -1;
    return {
        kind: "wallpaper.workflow.history_state",
        limit: limit,
        cursor: cursor,
        entries: entries,
    };
}

function setWallpaperHistoryCursor(state, nextCursor) {
    const normalizedState = createWallpaperHistoryState(state);
    return {
        kind: "wallpaper.workflow.history_state",
        limit: normalizedState.limit,
        cursor: clampCursor(nextCursor, normalizedState.entries.length),
        entries: cloneEntries(normalizedState.entries),
    };
}

function peekWallpaperHistoryPrevious(state) {
    const normalizedState = createWallpaperHistoryState(state);
    if (normalizedState.cursor <= 0 || normalizedState.entries.length === 0) {
        return {
            movable: false,
            cursor: normalizedState.cursor,
            path: "",
        };
    }

    const nextCursor = normalizedState.cursor - 1;
    return {
        movable: true,
        cursor: nextCursor,
        path: normalizedState.entries[nextCursor].path,
    };
}

function peekWallpaperHistoryNext(state) {
    const normalizedState = createWallpaperHistoryState(state);
    if (
        normalizedState.entries.length === 0 ||
        normalizedState.cursor >= normalizedState.entries.length - 1
    ) {
        return {
            movable: false,
            cursor: normalizedState.cursor,
            path: "",
        };
    }

    const nextCursor = normalizedState.cursor + 1;
    return {
        movable: true,
        cursor: nextCursor,
        path: normalizedState.entries[nextCursor].path,
    };
}

function normalizeCatalogPaths(catalogEntries) {
    if (!Array.isArray(catalogEntries)) return [];
    const dedupe = {};
    const paths = [];

    for (let index = 0; index < catalogEntries.length; index += 1) {
        const entry = catalogEntries[index];
        if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue;
        const path = normalizeAbsolutePath(entry.path);
        if (!path || dedupe[path]) continue;
        dedupe[path] = true;
        paths.push(path);
    }

    return paths;
}

function normalizeRandomValue(randomValue) {
    const parsed = Number(randomValue);
    if (!Number.isFinite(parsed)) return Math.random();
    if (parsed < 0) return 0;
    if (parsed >= 1) return 0.999999999;
    return parsed;
}

function chooseRandomWallpaperPath(catalogEntries, currentPath, randomValue) {
    const paths = normalizeCatalogPaths(catalogEntries);
    if (paths.length === 0) return "";

    const normalizedCurrentPath = normalizeAbsolutePath(currentPath);
    const candidates = [];
    for (let index = 0; index < paths.length; index += 1) {
        const path = paths[index];
        if (paths.length > 1 && path === normalizedCurrentPath) continue;
        candidates.push(path);
    }

    const effectiveCandidates = candidates.length > 0 ? candidates : paths;
    const random = normalizeRandomValue(randomValue);
    const selectedIndex = Math.floor(random * effectiveCandidates.length);
    return effectiveCandidates[selectedIndex];
}

function describeWallpaperHistory(state, maxEntries) {
    const normalizedState = createWallpaperHistoryState(state);
    const parsedMaxEntries = Number(maxEntries);
    const limit =
        Number.isInteger(parsedMaxEntries) && parsedMaxEntries > 0
            ? parsedMaxEntries
            : normalizedState.entries.length;
    const entries = [];
    const sourceEntries = normalizedState.entries;
    const startIndex = sourceEntries.length > limit ? sourceEntries.length - limit : 0;

    for (let index = startIndex; index < sourceEntries.length; index += 1) {
        const entry = sourceEntries[index];
        entries.push({
            index: index,
            path: entry.path,
            at: entry.at,
            source: entry.source,
            current: index === normalizedState.cursor,
        });
    }

    return {
        kind: "wallpaper.workflow.history_snapshot",
        limit: normalizedState.limit,
        totalEntries: normalizedState.entries.length,
        cursor: normalizedState.cursor,
        hasPrevious: normalizedState.cursor > 0,
        hasNext:
            normalizedState.cursor >= 0 &&
            normalizedState.cursor < normalizedState.entries.length - 1,
        currentPath: currentWallpaperPath(normalizedState),
        entries: entries,
    };
}

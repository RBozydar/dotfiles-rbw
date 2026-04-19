function createRegistry() {
    return {};
}

function cloneRegistry(registry) {
    const next = {};
    const source = registry && typeof registry === "object" ? registry : {};

    for (const token in source) next[token] = source[token];

    return next;
}

function normalizePendingProviderEvent(event, fallbackQuery) {
    const generation = Number(event && event.generation);
    if (!Number.isInteger(generation))
        throw new Error("Launcher async provider event generation must be an integer");

    const providerId = String(event && event.providerId ? event.providerId : "").trim();
    if (!providerId) throw new Error("Launcher async provider event providerId is required");

    return {
        generation: generation,
        providerId: providerId,
        query:
            event && event.query !== undefined ? String(event.query) : String(fallbackQuery || ""),
    };
}

function eventToken(event) {
    return String(event.generation) + ":" + String(event.providerId);
}

function normalizeTimeoutMs(timeoutMs) {
    const parsed = Number(timeoutMs);
    if (!Number.isFinite(parsed) || parsed < 100) return 2500;
    if (parsed > 120000) return 120000;
    return Math.round(parsed);
}

function createPendingEntry(event, startedAtMs, timeoutMs) {
    const normalizedEvent = normalizePendingProviderEvent(event);
    const nowMs = Number(startedAtMs);
    if (!Number.isFinite(nowMs))
        throw new Error("Launcher async provider pending startedAtMs must be finite");

    const normalizedTimeoutMs = normalizeTimeoutMs(timeoutMs);

    return {
        token: eventToken(normalizedEvent),
        generation: normalizedEvent.generation,
        providerId: normalizedEvent.providerId,
        query: normalizedEvent.query,
        startedAtMs: Math.round(nowMs),
        startedAt: new Date(Math.round(nowMs)).toISOString(),
        timeoutMs: normalizedTimeoutMs,
        deadlineMs: Math.round(nowMs) + normalizedTimeoutMs,
    };
}

function upsertPendingEntry(registry, entry) {
    const next = cloneRegistry(registry);
    const normalizedEntry = entry && typeof entry === "object" ? entry : null;
    if (!normalizedEntry || typeof normalizedEntry.token !== "string")
        throw new Error("Launcher async provider pending entry token is required");
    next[normalizedEntry.token] = normalizedEntry;
    return next;
}

function removePendingEntry(registry, generation, providerId) {
    const normalizedEvent = normalizePendingProviderEvent({
        generation: generation,
        providerId: providerId,
    });
    const token = eventToken(normalizedEvent);
    const source = registry && typeof registry === "object" ? registry : {};
    const removed = source[token] === undefined ? null : source[token];
    const next = cloneRegistry(source);
    delete next[token];

    return {
        registry: next,
        removedEntry: removed,
    };
}

function pendingEntry(registry, generation, providerId) {
    const normalizedEvent = normalizePendingProviderEvent({
        generation: generation,
        providerId: providerId,
    });
    const token = eventToken(normalizedEvent);
    const source = registry && typeof registry === "object" ? registry : {};
    return source[token] === undefined ? null : source[token];
}

function listPendingEntries(registry, nowMs) {
    const source = registry && typeof registry === "object" ? registry : {};
    const entries = [];
    const now = Number(nowMs);

    for (const token in source) {
        const entry = source[token];
        if (!entry || typeof entry !== "object") continue;
        entries.push({
            token: token,
            generation: Number(entry.generation),
            providerId: String(entry.providerId),
            query: String(entry.query || ""),
            startedAtMs: Number(entry.startedAtMs),
            startedAt: String(entry.startedAt || ""),
            timeoutMs: Number(entry.timeoutMs),
            deadlineMs: Number(entry.deadlineMs),
            ageMs: Number.isFinite(now) ? Math.max(0, now - Number(entry.startedAtMs)) : -1,
        });
    }

    entries.sort(function (left, right) {
        if (left.startedAtMs !== right.startedAtMs) return left.startedAtMs - right.startedAtMs;
        if (left.token < right.token) return -1;
        if (left.token > right.token) return 1;
        return 0;
    });

    return entries;
}

function collectExpiredEntries(registry, nowMs) {
    const now = Number(nowMs);
    if (!Number.isFinite(now)) return [];

    const entries = listPendingEntries(registry, now);
    const expired = [];

    for (let index = 0; index < entries.length; index += 1) {
        const entry = entries[index];
        if (!Number.isFinite(entry.deadlineMs)) continue;
        if (now >= entry.deadlineMs) expired.push(entry);
    }

    return expired;
}

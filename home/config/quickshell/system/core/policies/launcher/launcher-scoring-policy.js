function lowercase(value) {
    return String(value || "").toLowerCase();
}

function clamp(value, min, max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
}

function parseTimestampMs(value) {
    const source = String(value || "").trim();
    if (!source) return null;

    const parsed = Date.parse(source);
    if (!Number.isFinite(parsed)) return null;
    return parsed;
}

function normalizeUsageByItemId(usageByItemId) {
    if (!usageByItemId || typeof usageByItemId !== "object" || Array.isArray(usageByItemId))
        return {};

    const next = {};

    for (const rawItemId in usageByItemId) {
        const itemId = String(rawItemId || "").trim();
        if (!itemId) continue;

        const entry = usageByItemId[rawItemId];
        if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue;

        const count = Number(entry.count);
        const lastUsedAt = entry.lastUsedAt === undefined ? "" : String(entry.lastUsedAt);
        if (!Number.isInteger(count) || count < 0) continue;

        next[itemId] = {
            count: count,
            lastUsedAt: lastUsedAt,
        };
    }

    return next;
}

function usageCountBoost(count) {
    const normalizedCount = clamp(Number(count), 0, 20);
    return normalizedCount * 16;
}

function usageRecencyBoost(lastUsedAt, nowMs) {
    const usedAtMs = parseTimestampMs(lastUsedAt);
    if (usedAtMs === null) return 0;
    if (nowMs === null || usedAtMs > nowMs) return 0;

    const ageHours = (nowMs - usedAtMs) / 3600000;

    if (ageHours <= 1) return 220;
    if (ageHours <= 24) return 160;
    if (ageHours <= 24 * 7) return 95;
    if (ageHours <= 24 * 30) return 55;
    if (ageHours <= 24 * 90) return 20;
    return 0;
}

function scoreQueryMatch(title, subtitle, normalizedQuery) {
    const titleText = lowercase(title);
    const subtitleText = lowercase(subtitle);
    let titleBoost = 0;
    let subtitleBoost = 0;

    if (!normalizedQuery) {
        return {
            titleBoost: 0,
            subtitleBoost: 0,
            score: 0,
        };
    }

    if (titleText === normalizedQuery) titleBoost = 1000;
    else if (titleText.indexOf(normalizedQuery) === 0) titleBoost = 500;
    else if (titleText.indexOf(normalizedQuery) >= 0) titleBoost = 200;

    if (subtitleText.indexOf(normalizedQuery) >= 0) subtitleBoost = 50;

    return {
        titleBoost: titleBoost,
        subtitleBoost: subtitleBoost,
        score: titleBoost + subtitleBoost,
    };
}

function isPathLikeQuery(normalizedQuery) {
    if (!normalizedQuery) return false;
    return (
        normalizedQuery.indexOf("/") >= 0 ||
        normalizedQuery.indexOf("~") >= 0 ||
        normalizedQuery.indexOf("\\") >= 0
    );
}

function providerIntentBoost(item, normalizedQuery) {
    const provider = lowercase(item && item.provider);
    if (!normalizedQuery) return 0;

    const titleText = lowercase(item && item.title);
    const pathLike = isPathLikeQuery(normalizedQuery);

    if (provider === "apps") {
        if (titleText === normalizedQuery) return 480;
        if (titleText.indexOf(normalizedQuery) === 0) return 220;
        return pathLike ? -120 : 120;
    }

    if (provider === "files") {
        if (pathLike) return 220;
        return -220;
    }

    return 0;
}

function copyOptionalMetadata(source, target) {
    const item = source && typeof source === "object" ? source : {};
    const next = target && typeof target === "object" ? target : {};
    const parsedPinOrder = Number(item.pinOrder);

    if (item.pinned !== undefined) next.pinned = item.pinned === true;
    if (Number.isInteger(parsedPinOrder)) next.pinOrder = parsedPinOrder;
}

function scoreLauncherItem(item, query, options) {
    const config = options && typeof options === "object" ? options : {};
    const usageByItemId = normalizeUsageByItemId(config.usageByItemId);
    const personalizationEnabled = config.personalizationEnabled !== false;
    const nowMs = parseTimestampMs(config.nowIso);
    const normalizedQuery = lowercase(query).trim();
    const baseScore = Number(item.score || 0);
    const queryScore = scoreQueryMatch(item.title, item.subtitle, normalizedQuery);
    const providerIntentScore = providerIntentBoost(item, normalizedQuery);
    let usageFrequencyScore = 0;
    let usageRecencyScore = 0;

    if (personalizationEnabled) {
        const usageEntry = usageByItemId[item.id];
        if (usageEntry) {
            usageFrequencyScore = usageCountBoost(usageEntry.count);
            usageRecencyScore = usageRecencyBoost(usageEntry.lastUsedAt, nowMs);
        }
    }

    const score =
        baseScore +
        queryScore.score +
        providerIntentScore +
        usageFrequencyScore +
        usageRecencyScore;

    return {
        score: score,
        breakdown: {
            base: baseScore,
            queryTitleBoost: queryScore.titleBoost,
            querySubtitleBoost: queryScore.subtitleBoost,
            providerIntentBoost: providerIntentScore,
            usageFrequencyBoost: usageFrequencyScore,
            usageRecencyBoost: usageRecencyScore,
            personalizationEnabled: personalizationEnabled,
            total: score,
        },
    };
}

function scoreLauncherItems(items, query, options) {
    const config = options && typeof options === "object" ? options : {};
    const includeScoreMeta = config.includeScoreMeta !== false;
    const next = [];

    for (let index = 0; index < items.length; index += 1) {
        const item = items[index];
        const scoredItem = scoreLauncherItem(item, query, config);
        const normalizedItem = {
            id: item.id,
            title: item.title,
            subtitle: item.subtitle,
            provider: item.provider,
            score: scoredItem.score,
            action: item.action,
        };

        if (item.detail !== undefined) normalizedItem.detail = String(item.detail);
        if (item.iconName !== undefined) normalizedItem.iconName = String(item.iconName);
        copyOptionalMetadata(item, normalizedItem);
        if (includeScoreMeta) normalizedItem.scoreMeta = scoredItem.breakdown;
        next.push(normalizedItem);
    }

    next.sort(function (left, right) {
        if (right.score !== left.score) return right.score - left.score;

        if (left.title < right.title) return -1;
        if (left.title > right.title) return 1;
        return 0;
    });

    return next;
}

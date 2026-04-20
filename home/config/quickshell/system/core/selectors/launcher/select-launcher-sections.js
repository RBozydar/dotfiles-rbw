function normalizePerSectionLimit(perSectionLimit) {
    const parsed = Number(perSectionLimit);
    if (!Number.isInteger(parsed) || parsed <= 0) return 6;
    if (parsed > 50) return 50;
    return parsed;
}

function normalizeProviderId(item) {
    const provider = item && item.provider !== undefined ? String(item.provider).trim() : "default";
    return provider || "default";
}

function isStableIpcAction(action) {
    if (!action || typeof action !== "object") return false;
    if (String(action.type || "") !== "shell.ipc.dispatch") return false;

    const commandName = String(action.command || "").trim();
    if (!commandName) return false;
    if (action.args === undefined) return true;
    if (!Array.isArray(action.args)) return false;
    return action.args.length === 0;
}

function pinOrderFor(item, fallbackOrder) {
    const parsed = Number(item && item.pinOrder);
    if (Number.isInteger(parsed) && parsed >= 0) return parsed;
    return 100000 + Number(fallbackOrder || 0);
}

function isPinnedCommandItem(item) {
    if (!item || typeof item !== "object") return false;
    if (!isStableIpcAction(item.action)) return false;

    if (item.pinned === true) return true;
    const parsedOrder = Number(item.pinOrder);
    return Number.isInteger(parsedOrder) && parsedOrder >= 0;
}

function collectPinnedSectionItems(items, limit) {
    const source = Array.isArray(items) ? items : [];
    const pinned = [];

    for (let index = 0; index < source.length; index += 1) {
        const item = source[index];
        if (!isPinnedCommandItem(item)) continue;
        pinned.push(item);
    }

    pinned.sort(function (left, right) {
        const leftOrder = pinOrderFor(left, 0);
        const rightOrder = pinOrderFor(right, 0);
        if (leftOrder !== rightOrder) return leftOrder - rightOrder;

        const leftScore = Number(left && left.score ? left.score : 0);
        const rightScore = Number(right && right.score ? right.score : 0);
        if (rightScore !== leftScore) return rightScore - leftScore;

        const leftTitle = String(left && left.title ? left.title : "");
        const rightTitle = String(right && right.title ? right.title : "");
        if (leftTitle < rightTitle) return -1;
        if (leftTitle > rightTitle) return 1;
        return 0;
    });

    if (pinned.length <= limit) return pinned;
    return pinned.slice(0, limit);
}

function selectLauncherSections(items, perSectionLimit) {
    const source = Array.isArray(items) ? items : [];
    const limit = normalizePerSectionLimit(perSectionLimit);
    const sectionsByProvider = {};
    const providerOrder = [];
    const sections = [];
    const pinnedItems = collectPinnedSectionItems(source, limit);
    const pinnedById = {};

    for (let index = 0; index < pinnedItems.length; index += 1)
        pinnedById[String(pinnedItems[index].id)] = true;

    if (pinnedItems.length > 0) {
        sections.push({
            id: "pinned",
            title: "Pinned",
            items: pinnedItems,
        });
    }

    for (let index = 0; index < source.length; index += 1) {
        const item = source[index];
        if (!item || typeof item !== "object") continue;

        const itemId = String(item.id || "");
        if (itemId && pinnedById[itemId]) continue;

        const provider = normalizeProviderId(item);
        if (!sectionsByProvider[provider]) {
            sectionsByProvider[provider] = {
                id: provider,
                title: provider,
                items: [],
            };
            providerOrder.push(provider);
        }

        if (sectionsByProvider[provider].items.length < limit)
            sectionsByProvider[provider].items.push(item);
    }

    for (let index = 0; index < providerOrder.length; index += 1)
        sections.push(sectionsByProvider[providerOrder[index]]);

    return sections;
}

function countLauncherItems(sections) {
    let count = 0;

    for (let index = 0; index < sections.length; index += 1) {
        const section = sections[index];
        if (!section || !Array.isArray(section.items)) continue;
        count += section.items.length;
    }

    return count;
}

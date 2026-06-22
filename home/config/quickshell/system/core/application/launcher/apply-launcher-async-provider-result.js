function normalizeProviderEvent(event, fallbackQuery) {
    const generation = Number(event && event.generation);
    if (!Number.isInteger(generation))
        throw new Error("Launcher async provider event generation must be an integer");

    const providerId = String(event && event.providerId ? event.providerId : "").trim();
    if (!providerId) throw new Error("Launcher async provider event providerId is required");

    const query =
        event && event.query !== undefined ? String(event.query) : String(fallbackQuery || "");

    return {
        generation: generation,
        providerId: providerId,
        query: query,
    };
}

function copyItems(items) {
    const source = Array.isArray(items) ? items : [];
    const next = [];

    for (let index = 0; index < source.length; index += 1) next.push(source[index]);

    return next;
}

function mergeSourceItems(currentItems, incomingItems) {
    const merged = copyItems(currentItems);
    const byId = {};

    for (let index = 0; index < merged.length; index += 1) {
        const item = merged[index];
        byId[item.id] = index;
    }

    let addedCount = 0;
    let updatedCount = 0;

    for (let index = 0; index < incomingItems.length; index += 1) {
        const item = incomingItems[index];
        const existingIndex = byId[item.id];

        if (existingIndex === undefined) {
            byId[item.id] = merged.length;
            merged.push(item);
            addedCount += 1;
            continue;
        }

        merged[existingIndex] = item;
        updatedCount += 1;
    }

    return {
        items: merged,
        addedCount: addedCount,
        updatedCount: updatedCount,
    };
}

function validateIncomingItems(deps, items, generation) {
    const source = Array.isArray(items) ? items : [];
    return deps.createLauncherResultList(source, generation).items;
}

function applyLauncherAsyncProviderResult(deps, store, event, rawItems) {
    let normalizedEvent = null;

    try {
        normalizedEvent = normalizeProviderEvent(event, store.state.query);

        if (store.state.generation !== normalizedEvent.generation) {
            return deps.outcomes.stale({
                code: "launcher.async_provider.stale_generation",
                reason: "Async provider result generation is no longer active",
                targetId: "launcher",
                generation: normalizedEvent.generation,
                meta: {
                    providerId: normalizedEvent.providerId,
                },
            });
        }

        const currentSourceItems = Array.isArray(store.state.sourceItems)
            ? store.state.sourceItems
            : store.state.results;
        const incomingItems = validateIncomingItems(deps, rawItems, normalizedEvent.generation);
        const merged = mergeSourceItems(currentSourceItems, incomingItems);
        const scoredItems = deps.scoreLauncherItems(merged.items, normalizedEvent.query);
        const limitedItems =
            typeof deps.limitLauncherItems === "function"
                ? deps.limitLauncherItems(scoredItems, normalizedEvent)
                : scoredItems;
        const resultList = deps.createLauncherResultList(limitedItems, normalizedEvent.generation);
        const outcome = deps.outcomes.applied({
            code: "launcher.async_provider.applied",
            targetId: "launcher",
            generation: normalizedEvent.generation,
            meta: {
                providerId: normalizedEvent.providerId,
                query: normalizedEvent.query,
                addedCount: merged.addedCount,
                updatedCount: merged.updatedCount,
                resultList: resultList,
            },
        });

        if (typeof store.applyAsyncProviderMerged === "function")
            store.applyAsyncProviderMerged(normalizedEvent, merged.items, resultList, outcome);
        else store.applySearchCompleted(resultList, outcome, merged.items);

        return outcome;
    } catch (error) {
        const outcome = deps.outcomes.failed({
            code: "launcher.async_provider.apply_failed",
            reason: error && error.message ? String(error.message) : "Async provider apply failed",
            targetId: "launcher",
            generation:
                normalizedEvent !== null
                    ? normalizedEvent.generation
                    : Number(event && event.generation),
            meta: {
                providerId:
                    normalizedEvent !== null
                        ? normalizedEvent.providerId
                        : String(event && event.providerId ? event.providerId : ""),
            },
        });

        if (normalizedEvent !== null && typeof store.applyAsyncProviderFailed === "function")
            store.applyAsyncProviderFailed(normalizedEvent, outcome);

        return outcome;
    }
}

function failLauncherAsyncProviderResult(deps, store, event, error) {
    let normalizedEvent = null;

    try {
        normalizedEvent = normalizeProviderEvent(event, store.state.query);
    } catch (normalizationError) {
        return deps.outcomes.failed({
            code: "launcher.async_provider.failed",
            reason:
                normalizationError && normalizationError.message
                    ? String(normalizationError.message)
                    : "Async provider event is invalid",
            targetId: "launcher",
            generation: Number(event && event.generation),
            meta: {
                providerId: String(event && event.providerId ? event.providerId : ""),
            },
        });
    }

    if (store.state.generation !== normalizedEvent.generation) {
        return deps.outcomes.stale({
            code: "launcher.async_provider.stale_generation",
            reason: "Async provider result generation is no longer active",
            targetId: "launcher",
            generation: normalizedEvent.generation,
            meta: {
                providerId: normalizedEvent.providerId,
            },
        });
    }

    const outcome = deps.outcomes.failed({
        code: "launcher.async_provider.failed",
        reason: error && error.message ? String(error.message) : "Async provider failed",
        targetId: "launcher",
        generation: normalizedEvent.generation,
        meta: {
            providerId: normalizedEvent.providerId,
            query: normalizedEvent.query,
        },
    });

    if (typeof store.applyAsyncProviderFailed === "function")
        store.applyAsyncProviderFailed(normalizedEvent, outcome);

    return outcome;
}

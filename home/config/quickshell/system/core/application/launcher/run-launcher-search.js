function runLauncherSearch(deps, store, command) {
    deps.validateLauncherSearchCommand(command);
    store.applySearchStarted(command);

    try {
        const rawItems = deps.searchAdapter.search(command);
        if (rawItems && typeof rawItems.then === "function")
            throw new Error("Launcher search adapter must return synchronously for IPC v1");

        if (store.state.generation !== command.meta.generation) {
            return deps.outcomes.stale({
                code: "launcher.generation_changed",
                reason: "A newer launcher query replaced this request",
                targetId: "launcher",
                generation: command.meta.generation,
            });
        }

        const scoredItems = deps.scoreLauncherItems(rawItems, command.payload.query);
        const limitedItems =
            typeof deps.limitLauncherItems === "function"
                ? deps.limitLauncherItems(scoredItems, command)
                : scoredItems;
        const resultList = deps.createLauncherResultList(limitedItems, command.meta.generation);
        const outcome = deps.outcomes.applied({
            code: "launcher.search_applied",
            targetId: "launcher",
            generation: command.meta.generation,
            meta: {
                query: command.payload.query,
                resultList: resultList,
            },
        });

        store.applySearchCompleted(resultList, outcome, rawItems);
        return outcome;
    } catch (error) {
        const outcome = deps.outcomes.failed({
            code: "launcher.search_failed",
            reason: error && error.message ? error.message : "Search failed",
            targetId: "launcher",
            generation: command.meta.generation,
        });

        if (store.state.generation === command.meta.generation)
            store.applySearchFailed(command, outcome);

        return outcome;
    }
}

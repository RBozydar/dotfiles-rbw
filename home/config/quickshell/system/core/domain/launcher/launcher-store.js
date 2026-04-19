function cloneItems(items) {
    const next = [];

    const source = Array.isArray(items) ? items : [];
    for (let index = 0; index < source.length; index += 1) next.push(source[index]);

    return next;
}

function cloneStringArray(values) {
    const next = [];
    const source = Array.isArray(values) ? values : [];

    for (let index = 0; index < source.length; index += 1) {
        const value = String(source[index] || "").trim();
        if (!value) continue;
        next.push(value);
    }

    return next;
}

function removeString(values, needle) {
    const normalizedNeedle = String(needle || "").trim();
    const source = cloneStringArray(values);
    const next = [];

    for (let index = 0; index < source.length; index += 1) {
        if (source[index] === normalizedNeedle) continue;
        next.push(source[index]);
    }

    return next;
}

function appendUniqueString(values, needle) {
    const normalizedNeedle = String(needle || "").trim();
    if (!normalizedNeedle) return cloneStringArray(values);

    const source = cloneStringArray(values);
    for (let index = 0; index < source.length; index += 1) {
        if (source[index] === normalizedNeedle) return source;
    }

    source.push(normalizedNeedle);
    return source;
}

function createInitialLauncherState() {
    return {
        query: "",
        generation: 0,
        phase: "idle",
        results: [],
        sourceItems: [],
        pendingProviders: [],
        lastOutcome: null,
        error: "",
    };
}

function createLauncherStore() {
    return {
        state: createInitialLauncherState(),

        reset: function () {
            this.state = createInitialLauncherState();
        },

        applySearchStarted: function (command) {
            this.state = {
                query: command.payload.query,
                generation: command.meta.generation,
                phase: "searching",
                results: cloneItems(this.state.results),
                sourceItems: cloneItems(this.state.sourceItems),
                pendingProviders: [],
                lastOutcome: this.state.lastOutcome,
                error: "",
            };
        },

        applySearchCompleted: function (resultList, outcome, sourceItems, pendingProviders) {
            const nextPendingProviders =
                pendingProviders === undefined
                    ? cloneStringArray(this.state.pendingProviders)
                    : cloneStringArray(pendingProviders);
            this.state = {
                query: this.state.query,
                generation: resultList.generation,
                phase: nextPendingProviders.length > 0 ? "searching" : "ready",
                results: cloneItems(resultList.items),
                sourceItems:
                    sourceItems === undefined
                        ? cloneItems(resultList.items)
                        : cloneItems(sourceItems),
                pendingProviders: nextPendingProviders,
                lastOutcome: outcome,
                error: "",
            };
        },

        applySearchFailed: function (command, outcome) {
            this.state = {
                query: command.payload.query,
                generation: command.meta.generation,
                phase: "error",
                results: cloneItems(this.state.results),
                sourceItems: cloneItems(this.state.sourceItems),
                pendingProviders: [],
                lastOutcome: outcome,
                error: outcome.reason || "Search failed",
            };
        },

        markAsyncProviderPending: function (event) {
            const generation = Number(event && event.generation);
            if (!Number.isInteger(generation) || generation !== this.state.generation) return false;

            const providerId = String(event && event.providerId ? event.providerId : "").trim();
            if (!providerId) return false;

            this.state = {
                query: this.state.query,
                generation: this.state.generation,
                phase: "searching",
                results: cloneItems(this.state.results),
                sourceItems: cloneItems(this.state.sourceItems),
                pendingProviders: appendUniqueString(this.state.pendingProviders, providerId),
                lastOutcome: this.state.lastOutcome,
                error: "",
            };
            return true;
        },

        applyAsyncProviderMerged: function (event, sourceItems, resultList, outcome) {
            const generation = Number(event && event.generation);
            if (!Number.isInteger(generation) || generation !== this.state.generation) return false;

            const providerId = String(event && event.providerId ? event.providerId : "").trim();
            const nextPendingProviders = removeString(this.state.pendingProviders, providerId);

            this.state = {
                query: this.state.query,
                generation: this.state.generation,
                phase: nextPendingProviders.length > 0 ? "searching" : "ready",
                results: cloneItems(resultList.items),
                sourceItems: cloneItems(sourceItems),
                pendingProviders: nextPendingProviders,
                lastOutcome: outcome,
                error: "",
            };
            return true;
        },

        applyAsyncProviderFailed: function (event, outcome) {
            const generation = Number(event && event.generation);
            if (!Number.isInteger(generation) || generation !== this.state.generation) return false;

            const providerId = String(event && event.providerId ? event.providerId : "").trim();
            const nextPendingProviders = removeString(this.state.pendingProviders, providerId);

            this.state = {
                query: this.state.query,
                generation: this.state.generation,
                phase: nextPendingProviders.length > 0 ? "searching" : "ready",
                results: cloneItems(this.state.results),
                sourceItems: cloneItems(this.state.sourceItems),
                pendingProviders: nextPendingProviders,
                lastOutcome: outcome,
                error: "",
            };
            return true;
        },
    };
}

function cloneJsonValue(value) {
    if (Array.isArray(value)) {
        const nextArray = [];
        for (let index = 0; index < value.length; index += 1)
            nextArray.push(cloneJsonValue(value[index]));
        return nextArray;
    }

    if (value && typeof value === "object") {
        const nextObject = {};
        for (const key in value) nextObject[key] = cloneJsonValue(value[key]);
        return nextObject;
    }

    return value;
}

function cloneDomainMap(source) {
    const next = {};
    if (!source || typeof source !== "object") return next;

    for (const domainKey in source) next[String(domainKey)] = cloneJsonValue(source[domainKey]);

    return next;
}

function cloneGenerationMap(source) {
    const next = {};
    if (!source || typeof source !== "object") return next;

    for (const domainKey in source) {
        const generation = Number(source[domainKey]);
        if (!Number.isInteger(generation) || generation < 0) continue;
        next[String(domainKey)] = generation;
    }

    return next;
}

function computeNextGeneration(currentGeneration, requestedGeneration) {
    const normalizedCurrent =
        Number.isInteger(Number(currentGeneration)) && Number(currentGeneration) >= 0
            ? Number(currentGeneration)
            : 0;
    const normalizedRequested =
        Number.isInteger(Number(requestedGeneration)) && Number(requestedGeneration) >= 0
            ? Number(requestedGeneration)
            : normalizedCurrent;
    return Math.max(normalizedCurrent, normalizedRequested) + 1;
}

function createInMemoryPersistenceAdapter(seed) {
    const configByDomain = cloneDomainMap(seed ? seed.config : null);
    const stateByDomain = cloneDomainMap(seed ? seed.state : null);
    const generationByDomain = cloneGenerationMap(seed ? seed.generations : null);

    function readGeneration(domainKey) {
        return Number(generationByDomain[domainKey]) || 0;
    }

    function bumpGeneration(domainKey, requestedGeneration) {
        const nextGeneration = computeNextGeneration(
            generationByDomain[domainKey],
            requestedGeneration,
        );
        generationByDomain[domainKey] = nextGeneration;
        return nextGeneration;
    }

    return {
        readConfig: function (domainKey) {
            const value = configByDomain[domainKey];
            return value === undefined ? null : cloneJsonValue(value);
        },

        readState: function (domainKey) {
            const value = stateByDomain[domainKey];
            return value === undefined ? null : cloneJsonValue(value);
        },

        writeConfig: function (domainKey, document) {
            configByDomain[domainKey] = cloneJsonValue(document);
            bumpGeneration(domainKey, undefined);
            return true;
        },

        writeState: function (domainKey, document) {
            stateByDomain[domainKey] = cloneJsonValue(document);
            bumpGeneration(domainKey, undefined);
            return true;
        },

        readSnapshot: function (domainKey) {
            const configDocument = configByDomain[domainKey];
            const stateDocument = stateByDomain[domainKey];

            if (configDocument === undefined && stateDocument === undefined) return null;

            return {
                config: configDocument === undefined ? null : cloneJsonValue(configDocument),
                state: stateDocument === undefined ? null : cloneJsonValue(stateDocument),
                generation: readGeneration(domainKey),
                meta: {
                    kind: "adapter.persistence.snapshot.in_memory",
                },
            };
        },

        writeSnapshot: function (domainKey, snapshot) {
            const normalizedSnapshot = snapshot && typeof snapshot === "object" ? snapshot : {};
            const nextConfig =
                normalizedSnapshot.config === undefined
                    ? configByDomain[domainKey]
                    : normalizedSnapshot.config;
            const nextState =
                normalizedSnapshot.state === undefined
                    ? stateByDomain[domainKey]
                    : normalizedSnapshot.state;

            if (nextConfig === undefined || nextState === undefined) {
                return {
                    saved: false,
                    configSaved: false,
                    stateSaved: false,
                    generation: readGeneration(domainKey),
                    reason: "In-memory snapshot writes require both config and state",
                    meta: {
                        kind: "adapter.persistence.snapshot.in_memory",
                    },
                };
            }

            configByDomain[domainKey] = cloneJsonValue(nextConfig);
            stateByDomain[domainKey] = cloneJsonValue(nextState);
            const nextGeneration = bumpGeneration(domainKey, normalizedSnapshot.generation);

            return {
                saved: true,
                configSaved: true,
                stateSaved: true,
                generation: nextGeneration,
                meta: {
                    kind: "adapter.persistence.snapshot.in_memory",
                },
            };
        },
    };
}

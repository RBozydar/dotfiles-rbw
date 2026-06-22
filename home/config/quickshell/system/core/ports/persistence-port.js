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

function normalizeDomainKey(domainKey) {
    return String(domainKey === undefined ? "" : domainKey);
}

function cloneSnapshotEnvelope(snapshot) {
    if (snapshot === undefined || snapshot === null) return null;
    if (typeof snapshot !== "object") return null;
    return cloneJsonValue(snapshot);
}

function createPersistencePort(handlers) {
    const adapter = handlers && typeof handlers === "object" ? handlers : {};

    function read(methodName, domainKey) {
        const method = adapter[methodName];
        if (typeof method !== "function") return null;
        return cloneJsonValue(method(normalizeDomainKey(domainKey)));
    }

    function write(methodName, domainKey, document) {
        const method = adapter[methodName];
        if (typeof method !== "function") return false;
        return method(normalizeDomainKey(domainKey), cloneJsonValue(document)) === true;
    }

    function readSnapshotDirect(domainKey) {
        const method = adapter.readSnapshot;
        if (typeof method !== "function") return null;

        const snapshot = method(normalizeDomainKey(domainKey));
        return cloneSnapshotEnvelope(snapshot);
    }

    function writeSnapshotDirect(domainKey, snapshot) {
        const method = adapter.writeSnapshot;
        if (typeof method !== "function") return null;

        const rawResult = method(normalizeDomainKey(domainKey), cloneJsonValue(snapshot));
        if (rawResult === true) {
            return {
                saved: true,
                configSaved: true,
                stateSaved: true,
                generation: null,
            };
        }

        if (!rawResult || typeof rawResult !== "object") return null;
        return cloneJsonValue(rawResult);
    }

    return {
        readConfig: function (domainKey) {
            return read("readConfig", domainKey);
        },

        readState: function (domainKey) {
            return read("readState", domainKey);
        },

        writeConfig: function (domainKey, document) {
            return write("writeConfig", domainKey, document);
        },

        writeState: function (domainKey, document) {
            return write("writeState", domainKey, document);
        },

        readSnapshot: function (domainKey) {
            const directSnapshot = readSnapshotDirect(domainKey);
            if (directSnapshot) return directSnapshot;

            const configDocument = read("readConfig", domainKey);
            const stateDocument = read("readState", domainKey);
            if (configDocument === null && stateDocument === null) return null;

            return {
                config: configDocument,
                state: stateDocument,
                generation: null,
                meta: {
                    mode: "port.legacy_split_read",
                },
            };
        },

        writeSnapshot: function (domainKey, snapshot) {
            const normalizedSnapshot =
                snapshot && typeof snapshot === "object" ? cloneJsonValue(snapshot) : {};

            const directResult = writeSnapshotDirect(domainKey, normalizedSnapshot);
            if (directResult) return directResult;

            const configDocument =
                normalizedSnapshot.config === undefined
                    ? read("readConfig", domainKey)
                    : normalizedSnapshot.config;
            const stateDocument =
                normalizedSnapshot.state === undefined
                    ? read("readState", domainKey)
                    : normalizedSnapshot.state;

            if (configDocument === null || stateDocument === null) {
                return {
                    saved: false,
                    configSaved: false,
                    stateSaved: false,
                    generation: null,
                    reason: "Legacy persistence port requires both config and state documents",
                    meta: {
                        mode: "port.legacy_split_write",
                    },
                };
            }

            const configSaved = write("writeConfig", domainKey, configDocument);
            const stateSaved = write("writeState", domainKey, stateDocument);

            return {
                saved: configSaved && stateSaved,
                configSaved: configSaved,
                stateSaved: stateSaved,
                generation:
                    normalizedSnapshot.generation !== undefined &&
                    Number.isInteger(Number(normalizedSnapshot.generation))
                        ? Number(normalizedSnapshot.generation)
                        : null,
                meta: {
                    mode: "port.legacy_split_write",
                },
            };
        },
    };
}

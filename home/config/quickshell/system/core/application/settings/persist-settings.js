function parseErrorReason(error, fallbackReason) {
    if (error && error.message) return String(error.message);
    return fallbackReason;
}

function normalizeSnapshotWriteResult(rawResult, requestedGeneration) {
    const fallbackGeneration =
        Number.isInteger(Number(requestedGeneration)) && Number(requestedGeneration) >= 0
            ? Number(requestedGeneration)
            : null;
    if (rawResult === true) {
        return {
            saved: true,
            configSaved: true,
            stateSaved: true,
            generation: fallbackGeneration,
            reason: "",
            meta: {},
        };
    }

    if (!rawResult || typeof rawResult !== "object") {
        return {
            saved: false,
            configSaved: false,
            stateSaved: false,
            generation: fallbackGeneration,
            reason: "Persistence adapter returned invalid snapshot write result",
            meta: {},
        };
    }

    const saved =
        rawResult.saved === undefined
            ? rawResult.configSaved === true && rawResult.stateSaved === true
            : rawResult.saved === true;
    const normalizedGeneration = Number(rawResult.generation);

    return {
        saved: saved,
        configSaved: rawResult.configSaved === undefined ? saved : rawResult.configSaved === true,
        stateSaved: rawResult.stateSaved === undefined ? saved : rawResult.stateSaved === true,
        generation:
            Number.isInteger(normalizedGeneration) && normalizedGeneration >= 0
                ? normalizedGeneration
                : fallbackGeneration,
        reason: rawResult.reason ? String(rawResult.reason) : "",
        meta: rawResult.meta && typeof rawResult.meta === "object" ? rawResult.meta : {},
    };
}

function writeLegacySplitDocuments(
    persistencePort,
    domainKey,
    configDocument,
    stateDocument,
    requestedGeneration,
) {
    const configSaved =
        persistencePort && typeof persistencePort.writeConfig === "function"
            ? persistencePort.writeConfig(domainKey, configDocument) === true
            : false;
    const stateSaved =
        persistencePort && typeof persistencePort.writeState === "function"
            ? persistencePort.writeState(domainKey, stateDocument) === true
            : false;

    return {
        saved: configSaved && stateSaved,
        configSaved: configSaved,
        stateSaved: stateSaved,
        generation:
            Number.isInteger(Number(requestedGeneration)) && Number(requestedGeneration) >= 0
                ? Number(requestedGeneration)
                : null,
        reason: "",
        meta: {
            mode: "settings.persist.legacy_split_write",
        },
    };
}

function persistSettings(deps, store, domainKey, source) {
    const normalizedDomainKey = domainKey === undefined ? "shell" : String(domainKey);
    const normalizedSource = source === undefined ? "settings.manual" : String(source);

    try {
        const configDocument = deps.validateSettingsConfigDocument(store.state.config);
        const stateDocument = deps.validateSettingsStateDocument(store.state.durableState);
        const requestedGeneration = Number(store.state.persistedRevision);

        const snapshotResult =
            deps.persistencePort && typeof deps.persistencePort.writeSnapshot === "function"
                ? normalizeSnapshotWriteResult(
                      deps.persistencePort.writeSnapshot(normalizedDomainKey, {
                          config: configDocument,
                          state: stateDocument,
                          generation: requestedGeneration,
                          meta: {
                              source: normalizedSource,
                              revision: Number(store.state.revision),
                          },
                      }),
                      requestedGeneration,
                  )
                : writeLegacySplitDocuments(
                      deps.persistencePort,
                      normalizedDomainKey,
                      configDocument,
                      stateDocument,
                      requestedGeneration,
                  );
        const configSaved = snapshotResult.configSaved;
        const stateSaved = snapshotResult.stateSaved;

        if (!snapshotResult.saved || !configSaved || !stateSaved) {
            const failedOutcome = deps.outcomes.failed({
                code: "settings.persist_failed",
                targetId: normalizedDomainKey,
                reason:
                    snapshotResult.reason && snapshotResult.reason.length > 0
                        ? snapshotResult.reason
                        : "Persistence adapter did not confirm all writes",
                meta: {
                    configSaved: configSaved,
                    stateSaved: stateSaved,
                    source: normalizedSource,
                    generation: snapshotResult.generation,
                    persistence: snapshotResult.meta,
                },
            });

            if (typeof store.applyPersistFailed === "function")
                store.applyPersistFailed(failedOutcome);

            return failedOutcome;
        }

        const appliedOutcomeDetails = {
            code: "settings.persisted",
            targetId: normalizedDomainKey,
            meta: {
                source: normalizedSource,
                revision: Number(store.state.revision),
                persistence: snapshotResult.meta,
            },
        };
        if (
            Number.isInteger(Number(snapshotResult.generation)) &&
            Number(snapshotResult.generation) >= 0
        ) {
            appliedOutcomeDetails.generation = Number(snapshotResult.generation);
        }
        const appliedOutcome = deps.outcomes.applied(appliedOutcomeDetails);

        if (typeof store.applyPersisted === "function") store.applyPersisted(appliedOutcome);

        return appliedOutcome;
    } catch (error) {
        const failedOutcome = deps.outcomes.failed({
            code: "settings.persist_failed",
            targetId: normalizedDomainKey,
            reason: parseErrorReason(error, "Settings persistence failed"),
            meta: {
                source: normalizedSource,
            },
        });

        if (typeof store.applyPersistFailed === "function") store.applyPersistFailed(failedOutcome);

        return failedOutcome;
    }
}

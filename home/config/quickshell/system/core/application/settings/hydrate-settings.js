function copyWarnings(warnings) {
    const next = [];

    for (let index = 0; index < warnings.length; index += 1) {
        const warning = warnings[index];
        next.push({
            code: String(warning.code),
            reason: String(warning.reason),
        });
    }

    return next;
}

function parseErrorReason(error, fallbackReason) {
    if (error && error.message) return String(error.message);
    return fallbackReason;
}

function appendWarning(warnings, code, reason) {
    warnings.push({
        code: String(code),
        reason: String(reason),
    });
}

function appendSnapshotWarnings(warnings, snapshot) {
    if (!snapshot || typeof snapshot !== "object") return;
    const meta = snapshot.meta;
    if (!meta || typeof meta !== "object") return;
    if (!Array.isArray(meta.warnings)) return;

    for (let index = 0; index < meta.warnings.length; index += 1) {
        const warning = meta.warnings[index];
        if (!warning || typeof warning !== "object") continue;

        if (warning.code === undefined || warning.reason === undefined) continue;
        appendWarning(warnings, warning.code, warning.reason);
    }
}

function readSnapshotOrNull(persistencePort, domainKey, warnings) {
    if (!persistencePort || typeof persistencePort.readSnapshot !== "function") return null;

    let snapshot = null;
    try {
        snapshot = persistencePort.readSnapshot(domainKey);
    } catch (error) {
        appendWarning(
            warnings,
            "settings.snapshot.read_failed",
            parseErrorReason(error, "Snapshot read failed"),
        );
        return null;
    }

    if (snapshot === null || snapshot === undefined) return null;
    if (typeof snapshot !== "object") {
        appendWarning(
            warnings,
            "settings.snapshot.invalid",
            "Persistence snapshot must be an object",
        );
        return null;
    }

    appendSnapshotWarnings(warnings, snapshot);
    return snapshot;
}

function readDocumentOrDefault(
    readFn,
    domainKey,
    defaultDocument,
    validateDocument,
    warnings,
    prefix,
) {
    if (typeof readFn !== "function") {
        warnings.push({
            code: prefix + ".port_missing",
            reason: "Persistence port does not implement " + prefix,
        });
        return defaultDocument;
    }

    let rawDocument = null;
    try {
        rawDocument = readFn(domainKey);
    } catch (error) {
        warnings.push({
            code: prefix + ".read_failed",
            reason: parseErrorReason(error, "Read failed"),
        });
        return defaultDocument;
    }

    if (rawDocument === undefined || rawDocument === null) return defaultDocument;

    try {
        return validateDocument(rawDocument);
    } catch (error) {
        appendWarning(warnings, prefix + ".invalid", parseErrorReason(error, "Invalid document"));
        return defaultDocument;
    }
}

function readSnapshotDocumentOrDefault(
    snapshot,
    fieldName,
    defaultDocument,
    validateDocument,
    warnings,
    prefix,
) {
    if (!snapshot || typeof snapshot !== "object") return defaultDocument;

    const rawDocument = snapshot[fieldName];
    if (rawDocument === undefined || rawDocument === null) return defaultDocument;

    try {
        return validateDocument(rawDocument);
    } catch (error) {
        appendWarning(warnings, prefix + ".invalid", parseErrorReason(error, "Invalid document"));
        return defaultDocument;
    }
}

function extractSnapshotGeneration(snapshot) {
    if (!snapshot || typeof snapshot !== "object") return null;
    const normalizedGeneration = Number(snapshot.generation);
    if (!Number.isInteger(normalizedGeneration) || normalizedGeneration < 0) return null;
    return normalizedGeneration;
}

function hydrateSettings(deps, store, domainKey) {
    const normalizedDomainKey = domainKey === undefined ? "shell" : String(domainKey);
    const warnings = [];

    const defaultConfigDocument = deps.createDefaultSettingsConfigDocument();
    const defaultStateDocument = deps.createDefaultSettingsStateDocument();

    try {
        const snapshot = readSnapshotOrNull(deps.persistencePort, normalizedDomainKey, warnings);
        const configDocument = snapshot
            ? readSnapshotDocumentOrDefault(
                  snapshot,
                  "config",
                  defaultConfigDocument,
                  deps.validateSettingsConfigDocument,
                  warnings,
                  "settings.config",
              )
            : readDocumentOrDefault(
                  deps.persistencePort ? deps.persistencePort.readConfig : null,
                  normalizedDomainKey,
                  defaultConfigDocument,
                  deps.validateSettingsConfigDocument,
                  warnings,
                  "settings.config",
              );
        const stateDocument = snapshot
            ? readSnapshotDocumentOrDefault(
                  snapshot,
                  "state",
                  defaultStateDocument,
                  deps.validateSettingsStateDocument,
                  warnings,
                  "settings.state",
              )
            : readDocumentOrDefault(
                  deps.persistencePort ? deps.persistencePort.readState : null,
                  normalizedDomainKey,
                  defaultStateDocument,
                  deps.validateSettingsStateDocument,
                  warnings,
                  "settings.state",
              );
        const runtimeSettings = deps.createRuntimeSettings(configDocument, stateDocument);
        const snapshotGeneration = extractSnapshotGeneration(snapshot);
        const baseMeta =
            snapshotGeneration === null
                ? null
                : {
                      snapshotGeneration: snapshotGeneration,
                  };
        const outcome =
            warnings.length === 0
                ? deps.outcomes.applied({
                      code: "settings.hydrated",
                      targetId: normalizedDomainKey,
                      meta: baseMeta === null ? undefined : baseMeta,
                  })
                : deps.outcomes.applied({
                      code: "settings.hydrated_with_fallback",
                      targetId: normalizedDomainKey,
                      reason: "Some persisted settings were invalid or unavailable",
                      meta: Object.assign({}, baseMeta === null ? {} : baseMeta, {
                          warnings: copyWarnings(warnings),
                      }),
                  });

        store.applyHydrated(configDocument, stateDocument, runtimeSettings, outcome);
        return outcome;
    } catch (error) {
        const outcome = deps.outcomes.failed({
            code: "settings.hydration_failed",
            targetId: normalizedDomainKey,
            reason: parseErrorReason(error, "Settings hydration failed"),
        });
        store.applyHydrationFailed(outcome);
        return outcome;
    }
}

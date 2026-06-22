function parseErrorReason(error, fallbackReason) {
    if (error && error.message) return String(error.message);
    return fallbackReason;
}

const DEFAULT_QUERY_HISTORY_RETENTION_DAYS = 90;
const DEFAULT_QUERY_HISTORY_MAX_ENTRIES = 20000;
const MAX_USAGE_COUNT = 2147483647;
const MILLISECONDS_PER_DAY = 24 * 60 * 60 * 1000;

function cloneSettingsConfigDocument(document) {
    return {
        kind: "shell.settings.config",
        schemaVersion: Number(document.schemaVersion),
        session: {
            overlayEnabled: Boolean(document.session && document.session.overlayEnabled),
        },
        launcher: {
            commandPrefix: String(document.launcher && document.launcher.commandPrefix),
            maxResults: Number(document.launcher && document.launcher.maxResults),
        },
        theme: {
            providerId: String(document.theme && document.theme.providerId),
            fallbackProviderId: String(document.theme && document.theme.fallbackProviderId),
            mode: String(document.theme && document.theme.mode),
            variant: String(document.theme && document.theme.variant),
            sourceKind: String(document.theme && document.theme.sourceKind),
            sourceValue: String(document.theme && document.theme.sourceValue),
            matugenSchemePath: String(document.theme && document.theme.matugenSchemePath),
        },
        integrations: {
            homeAssistantEnabled: Boolean(
                document.integrations && document.integrations.homeAssistantEnabled,
            ),
            launcherHomeAssistantEnabled: Boolean(
                document.integrations && document.integrations.launcherHomeAssistantEnabled,
            ),
            launcherEmojiEnabled: Boolean(
                document.integrations && document.integrations.launcherEmojiEnabled,
            ),
            launcherClipboardEnabled: Boolean(
                document.integrations && document.integrations.launcherClipboardEnabled,
            ),
            launcherFileSearchEnabled: Boolean(
                document.integrations && document.integrations.launcherFileSearchEnabled,
            ),
            launcherWallpaperEnabled: Boolean(
                document.integrations && document.integrations.launcherWallpaperEnabled,
            ),
        },
    };
}

function cloneNotificationActions(actions) {
    const next = [];
    if (!Array.isArray(actions)) return next;

    for (let index = 0; index < actions.length; index += 1) {
        const action = actions[index];
        if (!action || typeof action !== "object" || Array.isArray(action)) continue;
        const id = action.id === undefined ? "" : String(action.id).trim();
        const label = action.label === undefined ? "" : String(action.label).trim();
        if (!id || !label) continue;
        next.push({
            id: id,
            label: label,
        });
    }

    return next;
}

function cloneNotificationHistory(historyEntries) {
    const next = [];
    if (!Array.isArray(historyEntries)) return next;

    for (let index = 0; index < historyEntries.length; index += 1) {
        const entry = historyEntries[index];
        if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue;
        const key = entry.key === undefined ? "" : String(entry.key);
        const id = Number(entry.id);
        const urgency = Number(entry.urgency);
        const timestamp = Number(entry.timestamp);
        const repeatCount = Number(entry.repeatCount === undefined ? 1 : entry.repeatCount);
        if (
            !key ||
            !Number.isFinite(id) ||
            !Number.isFinite(urgency) ||
            !Number.isFinite(timestamp)
        )
            continue;
        if (!Number.isInteger(repeatCount) || repeatCount < 1) continue;

        next.push({
            key: key,
            id: id,
            appName: entry.appName === undefined ? "" : String(entry.appName),
            summary: entry.summary === undefined ? "" : String(entry.summary),
            body: entry.body === undefined ? "" : String(entry.body),
            appIcon: entry.appIcon === undefined ? "" : String(entry.appIcon),
            image: entry.image === undefined ? "" : String(entry.image),
            urgency: urgency,
            timestamp: timestamp,
            read: entry.read === true,
            repeatCount: repeatCount,
            actions: cloneNotificationActions(entry.actions),
            defaultActionId:
                entry.defaultActionId === undefined ? "" : String(entry.defaultActionId),
        });
    }

    return next;
}

function cloneWallpaperHistoryEntries(historyEntries) {
    const next = [];
    if (!Array.isArray(historyEntries)) return next;

    for (let index = 0; index < historyEntries.length; index += 1) {
        const entry = historyEntries[index];
        if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue;
        const path = entry.path === undefined ? "" : String(entry.path).trim();
        if (!path || !path.startsWith("/")) continue;

        next.push({
            path: path,
            source: entry.source === undefined ? "" : String(entry.source),
            at: entry.at === undefined ? "" : String(entry.at),
        });
    }

    return next;
}

function normalizeWallpaperHistoryCursor(cursor, historyLength) {
    const entryCount = Number(historyLength);
    if (!Number.isInteger(entryCount) || entryCount <= 0) return -1;

    const normalized = Number(cursor);
    if (!Number.isInteger(normalized)) return entryCount - 1;
    if (normalized < 0) return 0;
    if (normalized >= entryCount) return entryCount - 1;
    return normalized;
}

function cloneSettingsStateDocument(document) {
    const pinnedCommandIds = [];
    const usageByItemId = {};
    const queryHistory = [];
    const notificationHistory = cloneNotificationHistory(
        document.notifications ? document.notifications.history : [],
    );
    const wallpaperHistory = cloneWallpaperHistoryEntries(
        document.wallpaper ? document.wallpaper.history : [],
    );

    if (document.launcher && Array.isArray(document.launcher.pinnedCommandIds)) {
        for (let index = 0; index < document.launcher.pinnedCommandIds.length; index += 1)
            pinnedCommandIds.push(String(document.launcher.pinnedCommandIds[index]));
    }

    if (
        document.launcher &&
        document.launcher.usageByItemId &&
        typeof document.launcher.usageByItemId === "object" &&
        !Array.isArray(document.launcher.usageByItemId)
    ) {
        for (const rawItemId in document.launcher.usageByItemId) {
            const itemId = String(rawItemId);
            const entry = document.launcher.usageByItemId[rawItemId];
            if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue;
            const count = Number(entry.count);
            if (!Number.isInteger(count) || count < 0) continue;
            usageByItemId[itemId] = {
                count: count,
                lastUsedAt: entry.lastUsedAt === undefined ? "" : String(entry.lastUsedAt),
            };
        }
    }

    if (document.launcher && Array.isArray(document.launcher.queryHistory)) {
        for (let index = 0; index < document.launcher.queryHistory.length; index += 1) {
            const entry = document.launcher.queryHistory[index];
            if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue;
            const query = entry.query === undefined ? "" : String(entry.query);
            if (!query) continue;
            queryHistory.push({
                query: query,
                at: entry.at === undefined ? "" : String(entry.at),
                source: entry.source === undefined ? "" : String(entry.source),
            });
        }
    }

    return {
        kind: "shell.settings.state",
        schemaVersion: Number(document.schemaVersion),
        launcher: {
            lastQuery: String(document.launcher && document.launcher.lastQuery),
            pinnedCommandIds: pinnedCommandIds,
            usageByItemId: usageByItemId,
            queryHistory: queryHistory,
        },
        notifications: {
            history: notificationHistory,
        },
        wallpaper: {
            history: wallpaperHistory,
            cursor: normalizeWallpaperHistoryCursor(
                document.wallpaper ? document.wallpaper.cursor : -1,
                wallpaperHistory.length,
            ),
        },
    };
}

function normalizePositiveInteger(value, fallbackValue, minValue, maxValue) {
    const normalized = Number(value);
    if (!Number.isInteger(normalized)) return fallbackValue;
    if (normalized < minValue) return minValue;
    if (normalized > maxValue) return maxValue;
    return normalized;
}

function normalizeIsoTimestamp(value, fallbackIso) {
    if (typeof value === "string") {
        const parsed = Date.parse(value);
        if (Number.isFinite(parsed)) return new Date(parsed).toISOString();
    }

    const fallbackParsed = Date.parse(String(fallbackIso || ""));
    if (Number.isFinite(fallbackParsed)) return new Date(fallbackParsed).toISOString();
    return new Date().toISOString();
}

function normalizeLauncherTelemetryPolicy(policy) {
    const candidate = policy && typeof policy === "object" ? policy : {};
    return {
        queryHistoryRetentionDays: normalizePositiveInteger(
            candidate.queryHistoryRetentionDays,
            DEFAULT_QUERY_HISTORY_RETENTION_DAYS,
            1,
            3650,
        ),
        maxQueryHistoryEntries: normalizePositiveInteger(
            candidate.maxQueryHistoryEntries,
            DEFAULT_QUERY_HISTORY_MAX_ENTRIES,
            1,
            200000,
        ),
    };
}

function normalizeLauncherTelemetryEvents(events) {
    if (!Array.isArray(events)) return [];

    const normalized = [];

    for (let index = 0; index < events.length; index += 1) {
        const event = events[index];
        if (!event || typeof event !== "object" || Array.isArray(event)) continue;
        const kind = String(event.kind || "");
        const at = normalizeIsoTimestamp(event.at, new Date().toISOString());
        const source = event.source === undefined ? "" : String(event.source);

        if (kind === "query") {
            const query = String(event.query === undefined ? "" : event.query);
            if (!query.trim()) continue;
            normalized.push({
                kind: "query",
                query: query,
                at: at,
                source: source,
            });
            continue;
        }

        if (kind === "usage") {
            const itemId = String(event.itemId === undefined ? "" : event.itemId).trim();
            if (!itemId) continue;
            normalized.push({
                kind: "usage",
                itemId: itemId,
                at: at,
                source: source,
            });
        }
    }

    return normalized;
}

function compactLauncherQueryHistory(queryHistory, policy, nowMilliseconds) {
    const normalizedHistory = [];

    if (Array.isArray(queryHistory)) {
        for (let index = 0; index < queryHistory.length; index += 1) {
            const entry = queryHistory[index];
            if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue;
            const query = String(entry.query === undefined ? "" : entry.query);
            if (!query.trim()) continue;
            const at = normalizeIsoTimestamp(entry.at, new Date(nowMilliseconds).toISOString());
            const source = entry.source === undefined ? "" : String(entry.source);
            normalizedHistory.push({
                query: query,
                at: at,
                source: source,
            });
        }
    }

    const cutoff = nowMilliseconds - policy.queryHistoryRetentionDays * MILLISECONDS_PER_DAY;
    const retained = [];

    for (let index = 0; index < normalizedHistory.length; index += 1) {
        const entry = normalizedHistory[index];
        const parsed = Date.parse(entry.at);
        if (!Number.isFinite(parsed)) continue;
        if (parsed < cutoff) continue;
        retained.push(entry);
    }

    if (retained.length > policy.maxQueryHistoryEntries) {
        return retained.slice(retained.length - policy.maxQueryHistoryEntries);
    }

    return retained;
}

function applyLauncherTelemetryEvents(stateDocument, telemetryEvents, policy) {
    const launcherState =
        stateDocument.launcher && typeof stateDocument.launcher === "object"
            ? stateDocument.launcher
            : {};
    if (!stateDocument.launcher || typeof stateDocument.launcher !== "object")
        stateDocument.launcher = launcherState;

    const currentUsage =
        launcherState.usageByItemId &&
        typeof launcherState.usageByItemId === "object" &&
        !Array.isArray(launcherState.usageByItemId)
            ? launcherState.usageByItemId
            : {};
    const currentHistory = Array.isArray(launcherState.queryHistory)
        ? launcherState.queryHistory
        : [];

    let changed = false;
    let latestQuery = null;
    const nowMilliseconds = Date.now();

    for (let index = 0; index < telemetryEvents.length; index += 1) {
        const event = telemetryEvents[index];

        if (event.kind === "query") {
            currentHistory.push({
                query: event.query,
                at: event.at,
                source: event.source,
            });
            latestQuery = event.query;
            changed = true;
            continue;
        }

        if (event.kind === "usage") {
            const existing = currentUsage[event.itemId];
            const previousCount =
                existing && Number.isInteger(Number(existing.count)) && Number(existing.count) >= 0
                    ? Number(existing.count)
                    : 0;
            const nextCount = Math.min(MAX_USAGE_COUNT, previousCount + 1);
            const previousLastUsedAt =
                existing && typeof existing.lastUsedAt === "string" ? existing.lastUsedAt : "";

            if (nextCount !== previousCount || previousLastUsedAt !== event.at) changed = true;

            currentUsage[event.itemId] = {
                count: nextCount,
                lastUsedAt: event.at,
            };
        }
    }

    const compactedHistory = compactLauncherQueryHistory(currentHistory, policy, nowMilliseconds);
    if (compactedHistory.length !== currentHistory.length) changed = true;
    launcherState.queryHistory = compactedHistory;
    launcherState.usageByItemId = currentUsage;

    if (latestQuery !== null) {
        if (String(launcherState.lastQuery || "") !== latestQuery) changed = true;
        launcherState.lastQuery = latestQuery;
    }

    return changed;
}

function normalizeNotificationHistoryForPersistence(historyEntries, maxEntries) {
    const normalizedLimit = normalizePositiveInteger(maxEntries, 240, 1, 5000);
    const normalizedHistory = cloneNotificationHistory(historyEntries);

    if (normalizedHistory.length <= normalizedLimit) return normalizedHistory;
    return normalizedHistory.slice(0, normalizedLimit);
}

function sanitizePersistedNotificationHistory(historyEntries) {
    const source = Array.isArray(historyEntries) ? historyEntries : [];
    const next = [];

    for (let index = 0; index < source.length; index += 1) {
        const entry = source[index];
        if (!entry || typeof entry !== "object") continue;

        next.push(
            Object.assign({}, entry, {
                actions: [],
                defaultActionId: "",
            }),
        );
    }

    return next;
}

function normalizeWallpaperHistoryForPersistence(historyEntries, cursor, maxEntries) {
    const normalizedLimit = normalizePositiveInteger(maxEntries, 240, 1, 5000);
    const normalizedHistory = cloneWallpaperHistoryEntries(historyEntries);

    if (normalizedHistory.length === 0) {
        return {
            history: [],
            cursor: -1,
        };
    }

    let trimmedHistory = normalizedHistory;
    let normalizedCursor = normalizeWallpaperHistoryCursor(cursor, normalizedHistory.length);

    if (normalizedHistory.length > normalizedLimit) {
        const overflow = normalizedHistory.length - normalizedLimit;
        trimmedHistory = normalizedHistory.slice(overflow);
        normalizedCursor = normalizeWallpaperHistoryCursor(
            normalizedCursor - overflow,
            trimmedHistory.length,
        );
    }

    return {
        history: trimmedHistory,
        cursor: normalizedCursor,
    };
}

function loadCurrentDocuments(deps, store) {
    const configDocument = deps.validateSettingsConfigDocument(store.state.config);
    const stateDocument = deps.validateSettingsStateDocument(store.state.durableState);

    return {
        config: cloneSettingsConfigDocument(configDocument),
        state: cloneSettingsStateDocument(stateDocument),
    };
}

function applySettingsUpdate(deps, store, operationCode, reason, applyMutation, options) {
    const normalizedOptions = options && typeof options === "object" ? options : {};
    const skipSnapshotDiff = normalizedOptions.skipSnapshotDiff === true;

    try {
        const current = loadCurrentDocuments(deps, store);
        const currentConfigSnapshot = skipSnapshotDiff ? "" : JSON.stringify(current.config);
        const currentStateSnapshot = skipSnapshotDiff ? "" : JSON.stringify(current.state);

        const mutationApplied = applyMutation(current.config, current.state);
        if (mutationApplied === false) {
            return deps.outcomes.noop({
                code: operationCode + ".noop",
                reason: reason,
                targetId: "shell",
            });
        }

        const nextConfig = deps.validateSettingsConfigDocument(current.config);
        const nextState = deps.validateSettingsStateDocument(current.state);
        if (!skipSnapshotDiff) {
            const nextConfigSnapshot = JSON.stringify(nextConfig);
            const nextStateSnapshot = JSON.stringify(nextState);

            if (
                currentConfigSnapshot === nextConfigSnapshot &&
                currentStateSnapshot === nextStateSnapshot
            ) {
                return deps.outcomes.noop({
                    code: operationCode + ".noop",
                    reason: reason,
                    targetId: "shell",
                });
            }
        }

        const runtimeSettings = deps.createRuntimeSettings(nextConfig, nextState);
        const outcome = deps.outcomes.applied({
            code: operationCode,
            targetId: "shell",
        });

        store.applyUpdated(nextConfig, nextState, runtimeSettings, outcome);
        return outcome;
    } catch (error) {
        return deps.outcomes.rejected({
            code: operationCode + ".invalid",
            reason: parseErrorReason(error, "Settings update is invalid"),
            targetId: "shell",
        });
    }
}

function setSessionOverlayEnabled(deps, store, enabled) {
    const nextEnabled = Boolean(enabled);
    return applySettingsUpdate(
        deps,
        store,
        "settings.session_overlay.updated",
        nextEnabled
            ? "Session overlay setting is already enabled"
            : "Session overlay setting is already disabled",
        function (configDocument) {
            configDocument.session.overlayEnabled = nextEnabled;
        },
    );
}

function setIntegrationEnabled(
    deps,
    store,
    integrationKey,
    enabled,
    operationCode,
    noopReasonEnabled,
    noopReasonDisabled,
) {
    const nextEnabled = Boolean(enabled);
    const normalizedIntegrationKey = String(integrationKey || "").trim();
    if (!normalizedIntegrationKey) {
        return deps.outcomes.rejected({
            code: operationCode + ".invalid",
            reason: "Integration key must be non-empty",
            targetId: "shell",
        });
    }

    return applySettingsUpdate(
        deps,
        store,
        operationCode,
        nextEnabled ? noopReasonEnabled : noopReasonDisabled,
        function (configDocument) {
            const integrations =
                configDocument.integrations && typeof configDocument.integrations === "object"
                    ? configDocument.integrations
                    : {};
            if (!configDocument.integrations || typeof configDocument.integrations !== "object")
                configDocument.integrations = integrations;

            integrations[normalizedIntegrationKey] = nextEnabled;
        },
    );
}

function setHomeAssistantIntegrationEnabled(deps, store, enabled) {
    return setIntegrationEnabled(
        deps,
        store,
        "homeAssistantEnabled",
        enabled,
        "settings.integrations.homeassistant.updated",
        "Home Assistant integration is already enabled",
        "Home Assistant integration is already disabled",
    );
}

function setLauncherHomeAssistantIntegrationEnabled(deps, store, enabled) {
    return setIntegrationEnabled(
        deps,
        store,
        "launcherHomeAssistantEnabled",
        enabled,
        "settings.integrations.launcher_homeassistant.updated",
        "Launcher Home Assistant integration is already enabled",
        "Launcher Home Assistant integration is already disabled",
    );
}

function setLauncherEmojiIntegrationEnabled(deps, store, enabled) {
    return setIntegrationEnabled(
        deps,
        store,
        "launcherEmojiEnabled",
        enabled,
        "settings.integrations.launcher_emoji.updated",
        "Launcher emoji integration is already enabled",
        "Launcher emoji integration is already disabled",
    );
}

function setLauncherClipboardIntegrationEnabled(deps, store, enabled) {
    return setIntegrationEnabled(
        deps,
        store,
        "launcherClipboardEnabled",
        enabled,
        "settings.integrations.launcher_clipboard.updated",
        "Launcher clipboard integration is already enabled",
        "Launcher clipboard integration is already disabled",
    );
}

function setLauncherFileSearchIntegrationEnabled(deps, store, enabled) {
    return setIntegrationEnabled(
        deps,
        store,
        "launcherFileSearchEnabled",
        enabled,
        "settings.integrations.launcher_file_search.updated",
        "Launcher file-search integration is already enabled",
        "Launcher file-search integration is already disabled",
    );
}

function setLauncherWallpaperIntegrationEnabled(deps, store, enabled) {
    return setIntegrationEnabled(
        deps,
        store,
        "launcherWallpaperEnabled",
        enabled,
        "settings.integrations.launcher_wallpaper.updated",
        "Launcher wallpaper integration is already enabled",
        "Launcher wallpaper integration is already disabled",
    );
}

function setLauncherCommandPrefix(deps, store, commandPrefix) {
    const nextPrefix = String(commandPrefix);
    return applySettingsUpdate(
        deps,
        store,
        "settings.launcher.command_prefix.updated",
        "Launcher command prefix is already set",
        function (configDocument) {
            configDocument.launcher.commandPrefix = nextPrefix;
        },
    );
}

function setLauncherMaxResults(deps, store, maxResults) {
    const parsed = Number(maxResults);
    if (!Number.isInteger(parsed))
        return deps.outcomes.rejected({
            code: "settings.launcher.max_results.invalid",
            reason: "Launcher max results must be an integer",
            targetId: "shell",
        });

    return applySettingsUpdate(
        deps,
        store,
        "settings.launcher.max_results.updated",
        "Launcher max results is already set",
        function (configDocument) {
            configDocument.launcher.maxResults = parsed;
        },
    );
}

function setThemeProviderId(deps, store, providerId) {
    const normalizedProviderId = String(providerId === undefined ? "" : providerId).trim();
    if (!normalizedProviderId) {
        return deps.outcomes.rejected({
            code: "settings.theme.provider.invalid",
            reason: "Theme provider id must be a non-empty string",
            targetId: "shell",
        });
    }

    return applySettingsUpdate(
        deps,
        store,
        "settings.theme.provider.updated",
        "Theme provider is already selected",
        function (configDocument) {
            configDocument.theme.providerId = normalizedProviderId;
        },
    );
}

function setThemeMode(deps, store, mode) {
    const normalizedMode = String(mode === undefined ? "" : mode)
        .trim()
        .toLowerCase();
    if (normalizedMode !== "dark" && normalizedMode !== "light") {
        return deps.outcomes.rejected({
            code: "settings.theme.mode.invalid",
            reason: "Theme mode must be dark or light",
            targetId: "shell",
        });
    }

    return applySettingsUpdate(
        deps,
        store,
        "settings.theme.mode.updated",
        "Theme mode is already selected",
        function (configDocument) {
            configDocument.theme.mode = normalizedMode;
        },
    );
}

function setThemeVariant(deps, store, variant) {
    const normalizedVariant = String(variant === undefined ? "" : variant).trim();
    if (!normalizedVariant) {
        return deps.outcomes.rejected({
            code: "settings.theme.variant.invalid",
            reason: "Theme variant must be a non-empty string",
            targetId: "shell",
        });
    }

    return applySettingsUpdate(
        deps,
        store,
        "settings.theme.variant.updated",
        "Theme variant is already selected",
        function (configDocument) {
            configDocument.theme.variant = normalizedVariant;
        },
    );
}

function setLauncherLastQuery(deps, store, query) {
    const nextQuery = String(query);
    return applySettingsUpdate(
        deps,
        store,
        "settings.launcher.last_query.updated",
        "Launcher last query is already set",
        function (_configDocument, stateDocument) {
            stateDocument.launcher.lastQuery = nextQuery;
        },
    );
}

function pinLauncherCommand(deps, store, commandId) {
    const normalizedCommandId = String(commandId || "").trim();
    if (!normalizedCommandId) {
        return deps.outcomes.rejected({
            code: "settings.launcher.pin_command.invalid",
            reason: "Pinned command id must be non-empty",
            targetId: "shell",
        });
    }

    return applySettingsUpdate(
        deps,
        store,
        "settings.launcher.pin_command.updated",
        "Launcher command is already pinned",
        function (_configDocument, stateDocument) {
            const currentPinned = Array.isArray(stateDocument.launcher.pinnedCommandIds)
                ? stateDocument.launcher.pinnedCommandIds
                : [];
            for (let index = 0; index < currentPinned.length; index += 1) {
                if (String(currentPinned[index]) === normalizedCommandId) return;
            }

            currentPinned.push(normalizedCommandId);
            stateDocument.launcher.pinnedCommandIds = currentPinned;
        },
    );
}

function unpinLauncherCommand(deps, store, commandId) {
    const normalizedCommandId = String(commandId || "").trim();
    if (!normalizedCommandId) {
        return deps.outcomes.rejected({
            code: "settings.launcher.unpin_command.invalid",
            reason: "Pinned command id must be non-empty",
            targetId: "shell",
        });
    }

    return applySettingsUpdate(
        deps,
        store,
        "settings.launcher.unpin_command.updated",
        "Launcher command is already unpinned",
        function (_configDocument, stateDocument) {
            const currentPinned = Array.isArray(stateDocument.launcher.pinnedCommandIds)
                ? stateDocument.launcher.pinnedCommandIds
                : [];
            const nextPinned = [];

            for (let index = 0; index < currentPinned.length; index += 1) {
                const value = String(currentPinned[index]);
                if (value !== normalizedCommandId) nextPinned.push(value);
            }

            stateDocument.launcher.pinnedCommandIds = nextPinned;
        },
    );
}

function movePinnedLauncherCommandUp(deps, store, commandId) {
    const normalizedCommandId = String(commandId || "").trim();
    if (!normalizedCommandId) {
        return deps.outcomes.rejected({
            code: "settings.launcher.pin_command.move_up.invalid",
            reason: "Pinned command id must be non-empty",
            targetId: "shell",
        });
    }

    return applySettingsUpdate(
        deps,
        store,
        "settings.launcher.pin_command.move_up.updated",
        "Pinned launcher command cannot move higher",
        function (_configDocument, stateDocument) {
            const currentPinned = Array.isArray(stateDocument.launcher.pinnedCommandIds)
                ? stateDocument.launcher.pinnedCommandIds
                : [];
            let currentIndex = -1;

            for (let index = 0; index < currentPinned.length; index += 1) {
                if (String(currentPinned[index]) === normalizedCommandId) {
                    currentIndex = index;
                    break;
                }
            }

            if (currentIndex <= 0) return false;

            const nextPinned = [];
            for (let index = 0; index < currentPinned.length; index += 1)
                nextPinned.push(String(currentPinned[index]));

            const previous = nextPinned[currentIndex - 1];
            nextPinned[currentIndex - 1] = nextPinned[currentIndex];
            nextPinned[currentIndex] = previous;
            stateDocument.launcher.pinnedCommandIds = nextPinned;
            return true;
        },
    );
}

function movePinnedLauncherCommandDown(deps, store, commandId) {
    const normalizedCommandId = String(commandId || "").trim();
    if (!normalizedCommandId) {
        return deps.outcomes.rejected({
            code: "settings.launcher.pin_command.move_down.invalid",
            reason: "Pinned command id must be non-empty",
            targetId: "shell",
        });
    }

    return applySettingsUpdate(
        deps,
        store,
        "settings.launcher.pin_command.move_down.updated",
        "Pinned launcher command cannot move lower",
        function (_configDocument, stateDocument) {
            const currentPinned = Array.isArray(stateDocument.launcher.pinnedCommandIds)
                ? stateDocument.launcher.pinnedCommandIds
                : [];
            let currentIndex = -1;

            for (let index = 0; index < currentPinned.length; index += 1) {
                if (String(currentPinned[index]) === normalizedCommandId) {
                    currentIndex = index;
                    break;
                }
            }

            if (currentIndex < 0 || currentIndex >= currentPinned.length - 1) return false;

            const nextPinned = [];
            for (let index = 0; index < currentPinned.length; index += 1)
                nextPinned.push(String(currentPinned[index]));

            const next = nextPinned[currentIndex + 1];
            nextPinned[currentIndex + 1] = nextPinned[currentIndex];
            nextPinned[currentIndex] = next;
            stateDocument.launcher.pinnedCommandIds = nextPinned;
            return true;
        },
    );
}

function applyLauncherTelemetryBatch(deps, store, events, policy) {
    const telemetryEvents = normalizeLauncherTelemetryEvents(events);
    if (telemetryEvents.length === 0) {
        return deps.outcomes.noop({
            code: "settings.launcher.telemetry.updated.noop",
            reason: "No valid launcher telemetry events to apply",
            targetId: "shell",
        });
    }

    const normalizedPolicy = normalizeLauncherTelemetryPolicy(policy);
    return applySettingsUpdate(
        deps,
        store,
        "settings.launcher.telemetry.updated",
        "No launcher telemetry changes were applied",
        function (_configDocument, stateDocument) {
            return applyLauncherTelemetryEvents(stateDocument, telemetryEvents, normalizedPolicy);
        },
        {
            skipSnapshotDiff: true,
        },
    );
}

function resetLauncherPersonalization(deps, store) {
    return applySettingsUpdate(
        deps,
        store,
        "settings.launcher.personalization.reset",
        "Launcher personalization is already reset",
        function (_configDocument, stateDocument) {
            let changed = false;
            const launcherState =
                stateDocument.launcher && typeof stateDocument.launcher === "object"
                    ? stateDocument.launcher
                    : {};
            if (!stateDocument.launcher || typeof stateDocument.launcher !== "object")
                stateDocument.launcher = launcherState;

            if (String(launcherState.lastQuery || "") !== "") {
                launcherState.lastQuery = "";
                changed = true;
            }

            const currentPinned = Array.isArray(launcherState.pinnedCommandIds)
                ? launcherState.pinnedCommandIds
                : [];
            if (currentPinned.length > 0) {
                launcherState.pinnedCommandIds = [];
                changed = true;
            } else if (!Array.isArray(launcherState.pinnedCommandIds)) {
                launcherState.pinnedCommandIds = [];
                changed = true;
            }

            const currentQueryHistory = Array.isArray(launcherState.queryHistory)
                ? launcherState.queryHistory
                : [];
            if (currentQueryHistory.length > 0) {
                launcherState.queryHistory = [];
                changed = true;
            } else if (!Array.isArray(launcherState.queryHistory)) {
                launcherState.queryHistory = [];
                changed = true;
            }

            const currentUsageByItemId =
                launcherState.usageByItemId &&
                typeof launcherState.usageByItemId === "object" &&
                !Array.isArray(launcherState.usageByItemId)
                    ? launcherState.usageByItemId
                    : null;
            if (currentUsageByItemId && Object.keys(currentUsageByItemId).length > 0) {
                launcherState.usageByItemId = {};
                changed = true;
            } else if (!currentUsageByItemId) {
                launcherState.usageByItemId = {};
                changed = true;
            }

            return changed;
        },
    );
}

function setNotificationHistory(deps, store, historyEntries, options) {
    const normalizedOptions = options && typeof options === "object" ? options : {};
    const normalizedHistory = normalizeNotificationHistoryForPersistence(
        historyEntries,
        normalizedOptions.maxEntries,
    );
    const persistedHistory = sanitizePersistedNotificationHistory(normalizedHistory);

    return applySettingsUpdate(
        deps,
        store,
        "settings.notifications.history.updated",
        "Notifications history is already up to date",
        function (_configDocument, stateDocument) {
            const notificationsState =
                stateDocument.notifications && typeof stateDocument.notifications === "object"
                    ? stateDocument.notifications
                    : {};
            if (!stateDocument.notifications || typeof stateDocument.notifications !== "object")
                stateDocument.notifications = notificationsState;

            notificationsState.history = persistedHistory;
        },
    );
}

function setWallpaperHistory(deps, store, historyEntries, cursor, options) {
    const normalizedOptions = options && typeof options === "object" ? options : {};
    const normalizedHistory = normalizeWallpaperHistoryForPersistence(
        historyEntries,
        cursor,
        normalizedOptions.maxEntries,
    );

    return applySettingsUpdate(
        deps,
        store,
        "settings.wallpaper.history.updated",
        "Wallpaper history is already up to date",
        function (_configDocument, stateDocument) {
            const wallpaperState =
                stateDocument.wallpaper && typeof stateDocument.wallpaper === "object"
                    ? stateDocument.wallpaper
                    : {};
            if (!stateDocument.wallpaper || typeof stateDocument.wallpaper !== "object")
                stateDocument.wallpaper = wallpaperState;

            wallpaperState.history = normalizedHistory.history;
            wallpaperState.cursor = normalizedHistory.cursor;
        },
    );
}

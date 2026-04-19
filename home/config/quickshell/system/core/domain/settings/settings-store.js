function copyStringArray(values) {
    const next = [];

    if (!Array.isArray(values)) return next;

    for (let index = 0; index < values.length; index += 1) next.push(String(values[index]));

    return next;
}

function copyLauncherUsageByItemId(value) {
    const next = {};
    if (!value || typeof value !== "object" || Array.isArray(value)) return next;

    for (const rawItemId in value) {
        const itemId = String(rawItemId);
        const entry = value[rawItemId];
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

function copyLauncherQueryHistory(queryHistory) {
    const next = [];
    if (!Array.isArray(queryHistory)) return next;

    for (let index = 0; index < queryHistory.length; index += 1) {
        const entry = queryHistory[index];
        if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue;
        const query = entry.query === undefined ? "" : String(entry.query);
        const at = entry.at === undefined ? "" : String(entry.at);
        const source = entry.source === undefined ? "" : String(entry.source);
        if (!query) continue;
        next.push({
            query: query,
            at: at,
            source: source,
        });
    }

    return next;
}

function copyNotificationActions(actions) {
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

function copyNotificationHistory(history) {
    const next = [];
    if (!Array.isArray(history)) return next;

    for (let index = 0; index < history.length; index += 1) {
        const entry = history[index];
        if (!entry || typeof entry !== "object" || Array.isArray(entry)) continue;
        const key = entry.key === undefined ? "" : String(entry.key);
        const id = Number(entry.id);
        const urgency = Number(entry.urgency);
        const timestamp = Number(entry.timestamp);
        const read = entry.read === true;
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
            read: read,
            repeatCount: repeatCount,
            actions: copyNotificationActions(entry.actions),
            defaultActionId:
                entry.defaultActionId === undefined ? "" : String(entry.defaultActionId),
        });
    }

    return next;
}

function copyWallpaperHistoryEntries(history) {
    const next = [];
    if (!Array.isArray(history)) return next;

    for (let index = 0; index < history.length; index += 1) {
        const entry = history[index];
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

function normalizeNonNegativeInteger(value, fallback) {
    const normalized = Number(value);
    if (Number.isInteger(normalized) && normalized >= 0) return normalized;
    return Number(fallback) >= 0 ? Number(fallback) : 0;
}

function normalizeInteger(value, fallback) {
    const normalized = Number(value);
    if (Number.isInteger(normalized)) return normalized;
    if (Number.isInteger(Number(fallback))) return Number(fallback);
    return 0;
}

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

function cloneSettingsStateDocument(document) {
    const wallpaperHistory = copyWallpaperHistoryEntries(
        document.wallpaper ? document.wallpaper.history : [],
    );
    return {
        kind: "shell.settings.state",
        schemaVersion: Number(document.schemaVersion),
        launcher: {
            lastQuery: String(document.launcher && document.launcher.lastQuery),
            pinnedCommandIds: copyStringArray(
                document.launcher ? document.launcher.pinnedCommandIds : [],
            ),
            usageByItemId: copyLauncherUsageByItemId(
                document.launcher ? document.launcher.usageByItemId : {},
            ),
            queryHistory: copyLauncherQueryHistory(
                document.launcher ? document.launcher.queryHistory : [],
            ),
        },
        notifications: {
            history: copyNotificationHistory(
                document.notifications ? document.notifications.history : [],
            ),
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

function cloneRuntimeSettings(runtimeSettings) {
    return {
        kind: "shell.runtime_settings",
        schemaVersion: Number(runtimeSettings.schemaVersion),
        sourceSchema: {
            config: Number(runtimeSettings.sourceSchema && runtimeSettings.sourceSchema.config),
            state: Number(runtimeSettings.sourceSchema && runtimeSettings.sourceSchema.state),
        },
        session: {
            overlayEnabled: Boolean(
                runtimeSettings.session && runtimeSettings.session.overlayEnabled,
            ),
        },
        launcher: {
            commandPrefix: String(
                runtimeSettings.launcher && runtimeSettings.launcher.commandPrefix,
            ),
            maxResults: Number(runtimeSettings.launcher && runtimeSettings.launcher.maxResults),
            lastQuery: String(runtimeSettings.launcher && runtimeSettings.launcher.lastQuery),
            pinnedCommandIds: copyStringArray(
                runtimeSettings.launcher ? runtimeSettings.launcher.pinnedCommandIds : [],
            ),
            telemetry: {
                usageItemCount: normalizeNonNegativeInteger(
                    runtimeSettings.launcher &&
                        runtimeSettings.launcher.telemetry &&
                        runtimeSettings.launcher.telemetry.usageItemCount,
                    0,
                ),
                queryHistoryEntryCount: normalizeNonNegativeInteger(
                    runtimeSettings.launcher &&
                        runtimeSettings.launcher.telemetry &&
                        runtimeSettings.launcher.telemetry.queryHistoryEntryCount,
                    0,
                ),
            },
        },
        theme: {
            providerId:
                runtimeSettings.theme && runtimeSettings.theme.providerId !== undefined
                    ? String(runtimeSettings.theme.providerId)
                    : "static",
            fallbackProviderId:
                runtimeSettings.theme && runtimeSettings.theme.fallbackProviderId !== undefined
                    ? String(runtimeSettings.theme.fallbackProviderId)
                    : "static",
            mode:
                runtimeSettings.theme && runtimeSettings.theme.mode !== undefined
                    ? String(runtimeSettings.theme.mode)
                    : "dark",
            variant:
                runtimeSettings.theme && runtimeSettings.theme.variant !== undefined
                    ? String(runtimeSettings.theme.variant)
                    : "tonal-spot",
            sourceKind:
                runtimeSettings.theme && runtimeSettings.theme.sourceKind !== undefined
                    ? String(runtimeSettings.theme.sourceKind)
                    : "static",
            sourceValue:
                runtimeSettings.theme && runtimeSettings.theme.sourceValue !== undefined
                    ? String(runtimeSettings.theme.sourceValue)
                    : "",
            matugenSchemePath:
                runtimeSettings.theme && runtimeSettings.theme.matugenSchemePath !== undefined
                    ? String(runtimeSettings.theme.matugenSchemePath)
                    : "",
        },
        integrations: {
            homeAssistantEnabled: Boolean(
                runtimeSettings.integrations && runtimeSettings.integrations.homeAssistantEnabled,
            ),
            launcherHomeAssistantEnabled: Boolean(
                runtimeSettings.integrations &&
                runtimeSettings.integrations.launcherHomeAssistantEnabled,
            ),
            launcherEmojiEnabled: Boolean(
                runtimeSettings.integrations && runtimeSettings.integrations.launcherEmojiEnabled,
            ),
            launcherClipboardEnabled: Boolean(
                runtimeSettings.integrations &&
                runtimeSettings.integrations.launcherClipboardEnabled,
            ),
            launcherFileSearchEnabled: Boolean(
                runtimeSettings.integrations &&
                runtimeSettings.integrations.launcherFileSearchEnabled,
            ),
            launcherWallpaperEnabled: Boolean(
                runtimeSettings.integrations &&
                runtimeSettings.integrations.launcherWallpaperEnabled,
            ),
        },
        notifications: {
            historyCount: normalizeNonNegativeInteger(
                runtimeSettings.notifications && runtimeSettings.notifications.historyCount,
                0,
            ),
            unreadCount: normalizeNonNegativeInteger(
                runtimeSettings.notifications && runtimeSettings.notifications.unreadCount,
                0,
            ),
        },
        wallpaper: {
            historyEntryCount: normalizeNonNegativeInteger(
                runtimeSettings.wallpaper && runtimeSettings.wallpaper.historyEntryCount,
                0,
            ),
            currentHistoryIndex: normalizeInteger(
                runtimeSettings.wallpaper && runtimeSettings.wallpaper.currentHistoryIndex,
                -1,
            ),
            currentPath:
                runtimeSettings.wallpaper && runtimeSettings.wallpaper.currentPath !== undefined
                    ? String(runtimeSettings.wallpaper.currentPath)
                    : "",
        },
    };
}

function createInitialSettingsState() {
    const config = {
        kind: "shell.settings.config",
        schemaVersion: 1,
        session: {
            overlayEnabled: true,
        },
        launcher: {
            commandPrefix: ">",
            maxResults: 8,
        },
        theme: {
            providerId: "static",
            fallbackProviderId: "static",
            mode: "dark",
            variant: "tonal-spot",
            sourceKind: "static",
            sourceValue: "",
            matugenSchemePath: "",
        },
        integrations: {
            homeAssistantEnabled: true,
            launcherHomeAssistantEnabled: true,
            launcherEmojiEnabled: true,
            launcherClipboardEnabled: true,
            launcherFileSearchEnabled: true,
            launcherWallpaperEnabled: true,
        },
    };
    const durableState = {
        kind: "shell.settings.state",
        schemaVersion: 1,
        launcher: {
            lastQuery: "",
            pinnedCommandIds: [],
            usageByItemId: {},
            queryHistory: [],
        },
        notifications: {
            history: [],
        },
        wallpaper: {
            history: [],
            cursor: -1,
        },
    };
    const runtime = {
        kind: "shell.runtime_settings",
        schemaVersion: 1,
        sourceSchema: {
            config: 1,
            state: 1,
        },
        session: {
            overlayEnabled: true,
        },
        launcher: {
            commandPrefix: ">",
            maxResults: 8,
            lastQuery: "",
            pinnedCommandIds: [],
            telemetry: {
                usageItemCount: 0,
                queryHistoryEntryCount: 0,
            },
        },
        theme: {
            providerId: "static",
            fallbackProviderId: "static",
            mode: "dark",
            variant: "tonal-spot",
            sourceKind: "static",
            sourceValue: "",
            matugenSchemePath: "",
        },
        integrations: {
            homeAssistantEnabled: true,
            launcherHomeAssistantEnabled: true,
            launcherEmojiEnabled: true,
            launcherClipboardEnabled: true,
            launcherFileSearchEnabled: true,
            launcherWallpaperEnabled: true,
        },
        notifications: {
            historyCount: 0,
            unreadCount: 0,
        },
        wallpaper: {
            historyEntryCount: 0,
            currentHistoryIndex: -1,
            currentPath: "",
        },
    };

    return {
        phase: "idle",
        revision: 0,
        persistedRevision: 0,
        config: config,
        durableState: durableState,
        runtime: runtime,
        lastOutcome: null,
        error: "",
    };
}

function createSettingsStore() {
    return {
        state: createInitialSettingsState(),

        reset: function () {
            this.state = createInitialSettingsState();
        },

        applyHydrated: function (configDocument, stateDocument, runtimeSettings, outcome) {
            const nextRevision = this.state.revision + 1;
            this.state = {
                phase: "ready",
                revision: nextRevision,
                persistedRevision: nextRevision,
                config: cloneSettingsConfigDocument(configDocument),
                durableState: cloneSettingsStateDocument(stateDocument),
                runtime: cloneRuntimeSettings(runtimeSettings),
                lastOutcome: outcome,
                error: "",
            };
        },

        applyUpdated: function (configDocument, stateDocument, runtimeSettings, outcome) {
            this.state = {
                phase: "ready",
                revision: this.state.revision + 1,
                persistedRevision: this.state.persistedRevision,
                config: cloneSettingsConfigDocument(configDocument),
                durableState: cloneSettingsStateDocument(stateDocument),
                runtime: cloneRuntimeSettings(runtimeSettings),
                lastOutcome: outcome,
                error: "",
            };
        },

        applyPersisted: function (outcome) {
            this.state = {
                phase: this.state.phase,
                revision: this.state.revision,
                persistedRevision: this.state.revision,
                config: cloneSettingsConfigDocument(this.state.config),
                durableState: cloneSettingsStateDocument(this.state.durableState),
                runtime: cloneRuntimeSettings(this.state.runtime),
                lastOutcome: outcome,
                error: "",
            };
        },

        applyPersistFailed: function (outcome) {
            this.state = {
                phase: this.state.phase,
                revision: this.state.revision,
                persistedRevision: this.state.persistedRevision,
                config: cloneSettingsConfigDocument(this.state.config),
                durableState: cloneSettingsStateDocument(this.state.durableState),
                runtime: cloneRuntimeSettings(this.state.runtime),
                lastOutcome: outcome,
                error:
                    outcome && outcome.reason
                        ? String(outcome.reason)
                        : "Settings persistence failed",
            };
        },

        applyHydrationFailed: function (outcome) {
            this.state = {
                phase: "error",
                revision: this.state.revision + 1,
                persistedRevision: this.state.persistedRevision,
                config: cloneSettingsConfigDocument(this.state.config),
                durableState: cloneSettingsStateDocument(this.state.durableState),
                runtime: cloneRuntimeSettings(this.state.runtime),
                lastOutcome: outcome,
                error:
                    outcome && outcome.reason
                        ? String(outcome.reason)
                        : "Settings hydration failed",
            };
        },
    };
}

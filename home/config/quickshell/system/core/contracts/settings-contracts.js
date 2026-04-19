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

function copyNotificationHistoryEntries(history) {
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
        const defaultActionId =
            entry.defaultActionId === undefined ? "" : String(entry.defaultActionId);
        const actions = copyNotificationActions(entry.actions);

        if (
            !key ||
            !Number.isFinite(id) ||
            !Number.isFinite(urgency) ||
            !Number.isFinite(timestamp)
        )
            continue;
        if (!Number.isInteger(repeatCount) || repeatCount < 1) continue;
        if (defaultActionId && actions.length > 0) {
            let hasDefaultAction = false;
            for (let actionIndex = 0; actionIndex < actions.length; actionIndex += 1) {
                if (actions[actionIndex].id === defaultActionId) {
                    hasDefaultAction = true;
                    break;
                }
            }
            if (!hasDefaultAction) continue;
        }

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
            actions: actions,
            defaultActionId: defaultActionId,
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

function countUnreadNotificationHistoryEntries(history) {
    const source = Array.isArray(history) ? history : [];
    let unread = 0;

    for (let index = 0; index < source.length; index += 1) {
        const entry = source[index];
        if (!entry || entry.read !== true) unread += 1;
    }

    return unread;
}

function validateSettingsConfigSession(session) {
    if (session === undefined) {
        return {
            overlayEnabled: true,
        };
    }

    if (!session || typeof session !== "object")
        throw new Error("Settings config session must be an object");
    if (session.overlayEnabled !== undefined && typeof session.overlayEnabled !== "boolean")
        throw new Error("Settings config session.overlayEnabled must be a boolean");

    return {
        overlayEnabled: session.overlayEnabled === undefined ? true : session.overlayEnabled,
    };
}

function validateSettingsConfigLauncher(launcher) {
    if (launcher === undefined) {
        return {
            commandPrefix: ">",
            maxResults: 8,
        };
    }

    if (!launcher || typeof launcher !== "object")
        throw new Error("Settings config launcher must be an object");

    const commandPrefix =
        launcher.commandPrefix === undefined ? ">" : String(launcher.commandPrefix);
    if (commandPrefix.length === 0)
        throw new Error("Settings config launcher.commandPrefix must be non-empty");

    const maxResults = launcher.maxResults === undefined ? 8 : Number(launcher.maxResults);
    if (!Number.isInteger(maxResults) || maxResults < 1 || maxResults > 50)
        throw new Error("Settings config launcher.maxResults must be an integer in range 1-50");

    return {
        commandPrefix: commandPrefix,
        maxResults: maxResults,
    };
}

function normalizeThemeMode(mode) {
    const normalized = String(mode === undefined ? "dark" : mode)
        .trim()
        .toLowerCase();
    if (normalized !== "dark" && normalized !== "light")
        throw new Error("Settings config theme.mode must be dark or light");
    return normalized;
}

function normalizeThemeSourceKind(sourceKind) {
    const normalized = String(sourceKind === undefined ? "static" : sourceKind)
        .trim()
        .toLowerCase();
    if (
        normalized !== "static" &&
        normalized !== "wallpaper" &&
        normalized !== "color" &&
        normalized !== "file" &&
        normalized !== "generated"
    )
        throw new Error(
            "Settings config theme.sourceKind must be static, wallpaper, color, file, or generated",
        );
    return normalized;
}

function validateSettingsConfigTheme(theme) {
    if (theme === undefined) {
        return {
            providerId: "static",
            fallbackProviderId: "static",
            mode: "dark",
            variant: "tonal-spot",
            sourceKind: "static",
            sourceValue: "",
            matugenSchemePath: "",
        };
    }

    if (!theme || typeof theme !== "object")
        throw new Error("Settings config theme must be an object");

    const providerId = String(theme.providerId === undefined ? "static" : theme.providerId).trim();
    if (!providerId) throw new Error("Settings config theme.providerId must be a non-empty string");

    const fallbackProviderId = String(
        theme.fallbackProviderId === undefined ? "static" : theme.fallbackProviderId,
    ).trim();
    if (!fallbackProviderId)
        throw new Error("Settings config theme.fallbackProviderId must be a non-empty string");

    const variant = String(theme.variant === undefined ? "tonal-spot" : theme.variant).trim();
    if (!variant) throw new Error("Settings config theme.variant must be a non-empty string");

    return {
        providerId: providerId,
        fallbackProviderId: fallbackProviderId,
        mode: normalizeThemeMode(theme.mode),
        variant: variant,
        sourceKind: normalizeThemeSourceKind(theme.sourceKind),
        sourceValue: String(theme.sourceValue === undefined ? "" : theme.sourceValue),
        matugenSchemePath: String(
            theme.matugenSchemePath === undefined ? "" : theme.matugenSchemePath,
        ),
    };
}

function validateSettingsConfigIntegrations(integrations) {
    if (integrations === undefined) {
        return {
            homeAssistantEnabled: true,
            launcherHomeAssistantEnabled: true,
            launcherEmojiEnabled: true,
            launcherClipboardEnabled: true,
            launcherFileSearchEnabled: true,
            launcherWallpaperEnabled: true,
        };
    }

    if (!integrations || typeof integrations !== "object")
        throw new Error("Settings config integrations must be an object");

    const fields = [
        "homeAssistantEnabled",
        "launcherHomeAssistantEnabled",
        "launcherEmojiEnabled",
        "launcherClipboardEnabled",
        "launcherFileSearchEnabled",
        "launcherWallpaperEnabled",
    ];

    for (let index = 0; index < fields.length; index += 1) {
        const field = fields[index];
        if (integrations[field] !== undefined && typeof integrations[field] !== "boolean") {
            throw new Error("Settings config integrations." + field + " must be a boolean");
        }
    }

    return {
        homeAssistantEnabled:
            integrations.homeAssistantEnabled === undefined
                ? true
                : integrations.homeAssistantEnabled,
        launcherHomeAssistantEnabled:
            integrations.launcherHomeAssistantEnabled === undefined
                ? true
                : integrations.launcherHomeAssistantEnabled,
        launcherEmojiEnabled:
            integrations.launcherEmojiEnabled === undefined
                ? true
                : integrations.launcherEmojiEnabled,
        launcherClipboardEnabled:
            integrations.launcherClipboardEnabled === undefined
                ? true
                : integrations.launcherClipboardEnabled,
        launcherFileSearchEnabled:
            integrations.launcherFileSearchEnabled === undefined
                ? true
                : integrations.launcherFileSearchEnabled,
        launcherWallpaperEnabled:
            integrations.launcherWallpaperEnabled === undefined
                ? true
                : integrations.launcherWallpaperEnabled,
    };
}

function validateSettingsConfigDocument(document) {
    if (!document || typeof document !== "object")
        throw new Error("Settings config document must be an object");
    if (document.kind !== "shell.settings.config")
        throw new Error("Settings config kind must be shell.settings.config");

    const schemaVersion = Number(document.schemaVersion);
    if (!Number.isInteger(schemaVersion) || schemaVersion < 1)
        throw new Error("Settings config schemaVersion must be an integer >= 1");

    return {
        kind: "shell.settings.config",
        schemaVersion: schemaVersion,
        session: validateSettingsConfigSession(document.session),
        launcher: validateSettingsConfigLauncher(document.launcher),
        theme: validateSettingsConfigTheme(document.theme),
        integrations: validateSettingsConfigIntegrations(document.integrations),
    };
}

function createDefaultSettingsConfigDocument() {
    return validateSettingsConfigDocument({
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
    });
}

function validateSettingsStateLauncher(launcher) {
    if (launcher === undefined) {
        return {
            lastQuery: "",
            pinnedCommandIds: [],
            usageByItemId: {},
            queryHistory: [],
        };
    }

    if (!launcher || typeof launcher !== "object")
        throw new Error("Settings state launcher must be an object");

    if (launcher.lastQuery !== undefined && typeof launcher.lastQuery !== "string")
        throw new Error("Settings state launcher.lastQuery must be a string");

    if (launcher.pinnedCommandIds !== undefined && !Array.isArray(launcher.pinnedCommandIds))
        throw new Error("Settings state launcher.pinnedCommandIds must be an array");

    if (
        launcher.usageByItemId !== undefined &&
        (!launcher.usageByItemId ||
            typeof launcher.usageByItemId !== "object" ||
            Array.isArray(launcher.usageByItemId))
    )
        throw new Error("Settings state launcher.usageByItemId must be an object");

    if (launcher.queryHistory !== undefined && !Array.isArray(launcher.queryHistory))
        throw new Error("Settings state launcher.queryHistory must be an array");

    const usageByItemId = copyLauncherUsageByItemId(launcher.usageByItemId);
    if (launcher.usageByItemId !== undefined) {
        for (const rawItemId in launcher.usageByItemId) {
            const itemId = String(rawItemId);
            const entry = launcher.usageByItemId[rawItemId];
            if (!entry || typeof entry !== "object" || Array.isArray(entry))
                throw new Error("Settings state launcher.usageByItemId entries must be objects");
            if (!Number.isInteger(Number(entry.count)) || Number(entry.count) < 0)
                throw new Error("Settings state launcher.usageByItemId entry count must be >= 0");
            if (entry.lastUsedAt !== undefined && typeof entry.lastUsedAt !== "string")
                throw new Error(
                    "Settings state launcher.usageByItemId entry lastUsedAt must be a string",
                );
            if (!Object.prototype.hasOwnProperty.call(usageByItemId, itemId))
                throw new Error("Settings state launcher.usageByItemId contains invalid entries");
        }
    }

    const queryHistory = copyLauncherQueryHistory(launcher.queryHistory);
    if (launcher.queryHistory !== undefined) {
        for (let index = 0; index < launcher.queryHistory.length; index += 1) {
            const entry = launcher.queryHistory[index];
            if (!entry || typeof entry !== "object" || Array.isArray(entry))
                throw new Error("Settings state launcher.queryHistory entries must be objects");
            if (typeof entry.query !== "string")
                throw new Error(
                    "Settings state launcher.queryHistory entry query must be a string",
                );
            if (entry.at !== undefined && typeof entry.at !== "string")
                throw new Error("Settings state launcher.queryHistory entry at must be a string");
            if (entry.source !== undefined && typeof entry.source !== "string")
                throw new Error(
                    "Settings state launcher.queryHistory entry source must be a string",
                );
        }
    }

    return {
        lastQuery: launcher.lastQuery === undefined ? "" : launcher.lastQuery,
        pinnedCommandIds: copyStringArray(launcher.pinnedCommandIds),
        usageByItemId: usageByItemId,
        queryHistory: queryHistory,
    };
}

function validateSettingsStateNotifications(notifications) {
    if (notifications === undefined) {
        return {
            history: [],
        };
    }

    if (!notifications || typeof notifications !== "object")
        throw new Error("Settings state notifications must be an object");
    if (notifications.history !== undefined && !Array.isArray(notifications.history))
        throw new Error("Settings state notifications.history must be an array");

    const history = copyNotificationHistoryEntries(notifications.history);
    if (notifications.history !== undefined) {
        for (let index = 0; index < notifications.history.length; index += 1) {
            const entry = notifications.history[index];
            if (!entry || typeof entry !== "object" || Array.isArray(entry))
                throw new Error("Settings state notifications.history entries must be objects");
            if (typeof entry.key !== "string" || entry.key.length === 0)
                throw new Error(
                    "Settings state notifications.history entry key must be a non-empty string",
                );
            if (!Number.isFinite(Number(entry.id)))
                throw new Error("Settings state notifications.history entry id must be finite");
            if (!Number.isFinite(Number(entry.urgency)))
                throw new Error(
                    "Settings state notifications.history entry urgency must be finite",
                );
            if (!Number.isFinite(Number(entry.timestamp)))
                throw new Error(
                    "Settings state notifications.history entry timestamp must be finite",
                );
            if (typeof entry.read !== "boolean")
                throw new Error("Settings state notifications.history entry read must be boolean");
            if (entry.repeatCount !== undefined) {
                const repeatCount = Number(entry.repeatCount);
                if (!Number.isInteger(repeatCount) || repeatCount < 1)
                    throw new Error(
                        "Settings state notifications.history entry repeatCount must be an integer >= 1",
                    );
            }
            if (entry.defaultActionId !== undefined && typeof entry.defaultActionId !== "string")
                throw new Error(
                    "Settings state notifications.history entry defaultActionId must be a string",
                );
            if (entry.actions !== undefined && !Array.isArray(entry.actions))
                throw new Error(
                    "Settings state notifications.history entry actions must be an array",
                );
        }
    }

    return {
        history: history,
    };
}

function validateSettingsStateWallpaper(wallpaper) {
    if (wallpaper === undefined) {
        return {
            history: [],
            cursor: -1,
        };
    }

    if (!wallpaper || typeof wallpaper !== "object")
        throw new Error("Settings state wallpaper must be an object");
    if (wallpaper.history !== undefined && !Array.isArray(wallpaper.history))
        throw new Error("Settings state wallpaper.history must be an array");
    if (wallpaper.cursor !== undefined && !Number.isInteger(Number(wallpaper.cursor)))
        throw new Error("Settings state wallpaper.cursor must be an integer");

    if (wallpaper.history !== undefined) {
        for (let index = 0; index < wallpaper.history.length; index += 1) {
            const entry = wallpaper.history[index];
            if (!entry || typeof entry !== "object" || Array.isArray(entry))
                throw new Error("Settings state wallpaper.history entries must be objects");
            if (typeof entry.path !== "string" || entry.path.trim().length === 0)
                throw new Error(
                    "Settings state wallpaper.history entry path must be a non-empty string",
                );
            if (!String(entry.path).startsWith("/"))
                throw new Error(
                    "Settings state wallpaper.history entry path must be an absolute path",
                );
            if (entry.source !== undefined && typeof entry.source !== "string")
                throw new Error("Settings state wallpaper.history entry source must be a string");
            if (entry.at !== undefined && typeof entry.at !== "string")
                throw new Error("Settings state wallpaper.history entry at must be a string");
        }
    }

    const history = copyWallpaperHistoryEntries(wallpaper.history);
    return {
        history: history,
        cursor: normalizeWallpaperHistoryCursor(wallpaper.cursor, history.length),
    };
}

function validateSettingsStateDocument(document) {
    if (!document || typeof document !== "object")
        throw new Error("Settings state document must be an object");
    if (document.kind !== "shell.settings.state")
        throw new Error("Settings state kind must be shell.settings.state");

    const schemaVersion = Number(document.schemaVersion);
    if (!Number.isInteger(schemaVersion) || schemaVersion < 1)
        throw new Error("Settings state schemaVersion must be an integer >= 1");

    return {
        kind: "shell.settings.state",
        schemaVersion: schemaVersion,
        launcher: validateSettingsStateLauncher(document.launcher),
        notifications: validateSettingsStateNotifications(document.notifications),
        wallpaper: validateSettingsStateWallpaper(document.wallpaper),
    };
}

function createDefaultSettingsStateDocument() {
    return validateSettingsStateDocument({
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
    });
}

function createRuntimeSettings(configDocument, stateDocument) {
    const config = validateSettingsConfigDocument(configDocument);
    const state = validateSettingsStateDocument(stateDocument);

    return {
        kind: "shell.runtime_settings",
        schemaVersion: 1,
        sourceSchema: {
            config: config.schemaVersion,
            state: state.schemaVersion,
        },
        session: {
            overlayEnabled: config.session.overlayEnabled,
        },
        launcher: {
            commandPrefix: config.launcher.commandPrefix,
            maxResults: config.launcher.maxResults,
            lastQuery: state.launcher.lastQuery,
            pinnedCommandIds: copyStringArray(state.launcher.pinnedCommandIds),
            telemetry: {
                usageItemCount: Object.keys(state.launcher.usageByItemId).length,
                queryHistoryEntryCount: state.launcher.queryHistory.length,
            },
        },
        theme: {
            providerId: config.theme.providerId,
            fallbackProviderId: config.theme.fallbackProviderId,
            mode: config.theme.mode,
            variant: config.theme.variant,
            sourceKind: config.theme.sourceKind,
            sourceValue: config.theme.sourceValue,
            matugenSchemePath: config.theme.matugenSchemePath,
        },
        integrations: {
            homeAssistantEnabled: config.integrations.homeAssistantEnabled,
            launcherHomeAssistantEnabled: config.integrations.launcherHomeAssistantEnabled,
            launcherEmojiEnabled: config.integrations.launcherEmojiEnabled,
            launcherClipboardEnabled: config.integrations.launcherClipboardEnabled,
            launcherFileSearchEnabled: config.integrations.launcherFileSearchEnabled,
            launcherWallpaperEnabled: config.integrations.launcherWallpaperEnabled,
        },
        notifications: {
            historyCount: state.notifications.history.length,
            unreadCount: countUnreadNotificationHistoryEntries(state.notifications.history),
        },
        wallpaper: {
            historyEntryCount: state.wallpaper.history.length,
            currentHistoryIndex: state.wallpaper.cursor,
            currentPath:
                state.wallpaper.cursor >= 0 &&
                state.wallpaper.cursor < state.wallpaper.history.length
                    ? String(state.wallpaper.history[state.wallpaper.cursor].path)
                    : "",
        },
    };
}

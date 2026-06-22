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

function migrateSettingsConfigDocument(rawDocument) {
    if (!rawDocument || typeof rawDocument !== "object")
        throw new Error("Settings config document must be an object");

    const migrated = cloneJsonValue(rawDocument);
    if (migrated.kind === undefined) migrated.kind = "shell.settings.config";
    if (migrated.schemaVersion === undefined) migrated.schemaVersion = 1;

    if (!migrated.session || typeof migrated.session !== "object") migrated.session = {};
    if (
        migrated.sessionOverlayEnabled !== undefined &&
        migrated.session.overlayEnabled === undefined
    )
        migrated.session.overlayEnabled = Boolean(migrated.sessionOverlayEnabled);

    if (!migrated.launcher || typeof migrated.launcher !== "object") migrated.launcher = {};
    if (
        migrated.launcherCommandPrefix !== undefined &&
        migrated.launcher.commandPrefix === undefined
    )
        migrated.launcher.commandPrefix = String(migrated.launcherCommandPrefix);
    if (migrated.maxResults !== undefined && migrated.launcher.maxResults === undefined)
        migrated.launcher.maxResults = Number(migrated.maxResults);

    if (!migrated.theme || typeof migrated.theme !== "object") migrated.theme = {};
    if (migrated.themeProviderId !== undefined && migrated.theme.providerId === undefined)
        migrated.theme.providerId = String(migrated.themeProviderId);
    if (
        migrated.themeFallbackProviderId !== undefined &&
        migrated.theme.fallbackProviderId === undefined
    )
        migrated.theme.fallbackProviderId = String(migrated.themeFallbackProviderId);
    if (migrated.themeMode !== undefined && migrated.theme.mode === undefined)
        migrated.theme.mode = String(migrated.themeMode);
    if (migrated.themeVariant !== undefined && migrated.theme.variant === undefined)
        migrated.theme.variant = String(migrated.themeVariant);
    if (migrated.themeSourceKind !== undefined && migrated.theme.sourceKind === undefined)
        migrated.theme.sourceKind = String(migrated.themeSourceKind);
    if (migrated.themeSourceValue !== undefined && migrated.theme.sourceValue === undefined)
        migrated.theme.sourceValue = String(migrated.themeSourceValue);
    if (
        migrated.themeMatugenSchemePath !== undefined &&
        migrated.theme.matugenSchemePath === undefined
    )
        migrated.theme.matugenSchemePath = String(migrated.themeMatugenSchemePath);

    if (!migrated.integrations || typeof migrated.integrations !== "object")
        migrated.integrations = {};
    if (
        migrated.homeAssistantIntegrationEnabled !== undefined &&
        migrated.integrations.homeAssistantEnabled === undefined
    )
        migrated.integrations.homeAssistantEnabled = Boolean(
            migrated.homeAssistantIntegrationEnabled,
        );
    if (
        migrated.launcherHomeAssistantIntegrationEnabled !== undefined &&
        migrated.integrations.launcherHomeAssistantEnabled === undefined
    )
        migrated.integrations.launcherHomeAssistantEnabled = Boolean(
            migrated.launcherHomeAssistantIntegrationEnabled,
        );
    if (
        migrated.launcherEmojiIntegrationEnabled !== undefined &&
        migrated.integrations.launcherEmojiEnabled === undefined
    )
        migrated.integrations.launcherEmojiEnabled = Boolean(
            migrated.launcherEmojiIntegrationEnabled,
        );
    if (
        migrated.launcherClipboardIntegrationEnabled !== undefined &&
        migrated.integrations.launcherClipboardEnabled === undefined
    )
        migrated.integrations.launcherClipboardEnabled = Boolean(
            migrated.launcherClipboardIntegrationEnabled,
        );
    if (
        migrated.launcherFileSearchIntegrationEnabled !== undefined &&
        migrated.integrations.launcherFileSearchEnabled === undefined
    )
        migrated.integrations.launcherFileSearchEnabled = Boolean(
            migrated.launcherFileSearchIntegrationEnabled,
        );
    if (
        migrated.launcherWallpaperIntegrationEnabled !== undefined &&
        migrated.integrations.launcherWallpaperEnabled === undefined
    )
        migrated.integrations.launcherWallpaperEnabled = Boolean(
            migrated.launcherWallpaperIntegrationEnabled,
        );

    return migrated;
}

function migrateSettingsStateDocument(rawDocument) {
    if (!rawDocument || typeof rawDocument !== "object")
        throw new Error("Settings state document must be an object");

    const migrated = cloneJsonValue(rawDocument);
    if (migrated.kind === undefined) migrated.kind = "shell.settings.state";
    if (migrated.schemaVersion === undefined) migrated.schemaVersion = 1;

    if (!migrated.launcher || typeof migrated.launcher !== "object") migrated.launcher = {};
    if (migrated.lastLauncherQuery !== undefined && migrated.launcher.lastQuery === undefined)
        migrated.launcher.lastQuery = String(migrated.lastLauncherQuery);
    if (
        migrated.pinnedLauncherCommands !== undefined &&
        migrated.launcher.pinnedCommandIds === undefined
    )
        migrated.launcher.pinnedCommandIds = cloneJsonValue(migrated.pinnedLauncherCommands);
    if (
        migrated.launcherUsageByItemId !== undefined &&
        migrated.launcher.usageByItemId === undefined
    )
        migrated.launcher.usageByItemId = cloneJsonValue(migrated.launcherUsageByItemId);
    if (migrated.launcherQueryHistory !== undefined && migrated.launcher.queryHistory === undefined)
        migrated.launcher.queryHistory = cloneJsonValue(migrated.launcherQueryHistory);

    if (!migrated.notifications || typeof migrated.notifications !== "object")
        migrated.notifications = {};
    if (migrated.notificationHistory !== undefined && migrated.notifications.history === undefined)
        migrated.notifications.history = cloneJsonValue(migrated.notificationHistory);
    if (migrated.notificationsHistory !== undefined && migrated.notifications.history === undefined)
        migrated.notifications.history = cloneJsonValue(migrated.notificationsHistory);

    if (!migrated.wallpaper || typeof migrated.wallpaper !== "object") migrated.wallpaper = {};
    if (migrated.wallpaperHistory !== undefined && migrated.wallpaper.history === undefined)
        migrated.wallpaper.history = cloneJsonValue(migrated.wallpaperHistory);
    if (migrated.wallpaperHistoryCursor !== undefined && migrated.wallpaper.cursor === undefined)
        migrated.wallpaper.cursor = Number(migrated.wallpaperHistoryCursor);

    return migrated;
}

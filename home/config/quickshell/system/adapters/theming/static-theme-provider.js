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

function normalizeThemeMode(mode) {
    const normalized = String(mode === undefined ? "dark" : mode)
        .trim()
        .toLowerCase();
    return normalized === "light" ? "light" : "dark";
}

function defaultRoleMapForMode(mode) {
    const normalizedMode = normalizeThemeMode(mode);
    if (normalizedMode === "light") {
        return {
            primary: "#0f9684",
            onPrimary: "#ffffff",
            primaryContainer: "#cbe7e1",
            onPrimaryContainer: "#132235",
            secondary: "#0077cc",
            onSecondary: "#ffffff",
            secondaryContainer: "#cedceb",
            onSecondaryContainer: "#132235",
            tertiary: "#cf6b5d",
            onTertiary: "#ffffff",
            tertiaryContainer: "#f9d4ce",
            onTertiaryContainer: "#132235",
            error: "#d64f44",
            onError: "#ffffff",
            errorContainer: "#f9d4ce",
            onErrorContainer: "#132235",
            background: "#edf4fb",
            onBackground: "#132235",
            surface: "#eef7fbff",
            onSurface: "#132235",
            surfaceVariant: "#ffffff",
            onSurfaceVariant: "#5d7389",
            outline: "#9bb1c6",
            outlineVariant: "#b8c8d8",
            shadow: "#000000",
            scrim: "#000000",
            inverseSurface: "#132235",
            inverseOnSurface: "#edf4fb",
            inversePrimary: "#82dccc",
            surfaceTint: "#0f9684",
            surfaceContainerLowest: "#ffffff",
            surfaceContainerLow: "#dfe9f4",
            surfaceContainer: "#ffffff",
            surfaceContainerHigh: "#cedceb",
            surfaceContainerHighest: "#cbe7e1",
            surfaceBright: "#ffffff",
            surfaceDim: "#dfe9f4",
        };
    }

    return {
        primary: "#82dccc",
        onPrimary: "#003731",
        primaryContainer: "#1b3b36",
        onPrimaryContainer: "#c8d2e0",
        secondary: "#01ccff",
        onSecondary: "#003547",
        secondaryContainer: "#1a2b44",
        onSecondaryContainer: "#c8d2e0",
        tertiary: "#fb958b",
        onTertiary: "#4f1d17",
        tertiaryContainer: "#5e2a22",
        onTertiaryContainer: "#ffd7d1",
        error: "#ff857d",
        onError: "#601410",
        errorContainer: "#7f221a",
        onErrorContainer: "#ffdad6",
        background: "#09111f",
        onBackground: "#c8d2e0",
        surface: "#d9111827",
        onSurface: "#c8d2e0",
        surfaceVariant: "#111827",
        onSurfaceVariant: "#8ea4bf",
        outline: "#33526e",
        outlineVariant: "#274058",
        shadow: "#000000",
        scrim: "#000000",
        inverseSurface: "#c8d2e0",
        inverseOnSurface: "#132235",
        inversePrimary: "#0077cc",
        surfaceTint: "#82dccc",
        surfaceContainerLowest: "#09111f",
        surfaceContainerLow: "#132033",
        surfaceContainer: "#111827",
        surfaceContainerHigh: "#1a2b44",
        surfaceContainerHighest: "#1b3b36",
        surfaceBright: "#1a2b44",
        surfaceDim: "#09111f",
    };
}

function createStaticThemeProvider(options) {
    const config = options && typeof options === "object" ? options : {};
    const providerId = String(config.providerId === undefined ? "static" : config.providerId);
    const darkRoleMap = cloneJsonValue(
        config.darkRoleMap === undefined ? defaultRoleMapForMode("dark") : config.darkRoleMap,
    );
    const lightRoleMap = cloneJsonValue(
        config.lightRoleMap === undefined ? defaultRoleMapForMode("light") : config.lightRoleMap,
    );

    return {
        describe: function () {
            return {
                kind: "adapter.theme.provider",
                id: providerId,
                ready: true,
                mode: "static",
                capabilities: {
                    supportsWallpaper: false,
                    supportsColorSource: true,
                    supportsVariants: false,
                },
            };
        },

        generate: function (request) {
            const normalizedRequest = request && typeof request === "object" ? request : {};
            const mode = normalizeThemeMode(normalizedRequest.mode);
            const roles = mode === "light" ? lightRoleMap : darkRoleMap;

            return {
                kind: "shell.theme.scheme",
                schemaVersion: 1,
                themeId:
                    normalizedRequest.themeId === undefined
                        ? providerId + "." + mode
                        : String(normalizedRequest.themeId),
                provider: providerId,
                mode: mode,
                variant:
                    normalizedRequest.variant === undefined
                        ? "tonal-spot"
                        : String(normalizedRequest.variant),
                sourceKind: "static",
                sourceValue: "",
                generatedAt: new Date().toISOString(),
                roles: cloneJsonValue(roles),
                meta: {
                    kind: "adapter.theme.provider.static",
                },
            };
        },
    };
}

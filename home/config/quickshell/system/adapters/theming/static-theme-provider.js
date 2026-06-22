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

function normalizeStaticVariant(variant) {
    const normalized = String(variant === undefined ? "" : variant)
        .trim()
        .toLowerCase();
    if (normalized === "evangelion") return "evangelion";
    if (normalized === "moon-space" || normalized === "moon" || normalized === "space")
        return "moon-space";
    return "";
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

function variantRoleOverrides(mode, variantId) {
    const normalizedMode = normalizeThemeMode(mode);
    if (variantId === "evangelion") {
        if (normalizedMode === "light") {
            return {
                primary: "#2f6200",
                onPrimary: "#ffffff",
                primaryContainer: "#b8f27b",
                onPrimaryContainer: "#183300",
                secondary: "#b35200",
                onSecondary: "#ffffff",
                secondaryContainer: "#ffd8bf",
                onSecondaryContainer: "#3a1a00",
                tertiary: "#5b4ac9",
                onTertiary: "#ffffff",
                tertiaryContainer: "#e2dcff",
                onTertiaryContainer: "#21145f",
                background: "#f5f3ee",
                onBackground: "#1a1d24",
                surface: "#fbf9f4",
                onSurface: "#1a1d24",
                surfaceVariant: "#e3e0d9",
                onSurfaceVariant: "#444a58",
                outline: "#747c8e",
                surfaceContainerLow: "#f3efe6",
                surfaceContainer: "#ece8e0",
                surfaceContainerHigh: "#e5e1da",
                surfaceContainerHighest: "#dcd8d2",
            };
        }

        return {
            primary: "#95ff00",
            onPrimary: "#102300",
            primaryContainer: "#244900",
            onPrimaryContainer: "#d8ffb0",
            secondary: "#ff6a00",
            onSecondary: "#3a1a00",
            secondaryContainer: "#5a2b00",
            onSecondaryContainer: "#ffd7b3",
            tertiary: "#8f7cff",
            onTertiary: "#22144b",
            tertiaryContainer: "#3b2a68",
            onTertiaryContainer: "#e4dcff",
            background: "#0f1014",
            onBackground: "#e6e2d8",
            surface: "#12141a",
            onSurface: "#e6e2d8",
            surfaceVariant: "#1d212b",
            onSurfaceVariant: "#b9bfce",
            outline: "#5a6276",
            surfaceContainerLow: "#1a1f29",
            surfaceContainer: "#202634",
            surfaceContainerHigh: "#283144",
            surfaceContainerHighest: "#313d56",
            inverseSurface: "#e6e2d8",
            inverseOnSurface: "#1a1f29",
            inversePrimary: "#3f7000",
        };
    }

    if (variantId === "moon-space") {
        if (normalizedMode === "light") {
            return {
                primary: "#365ba8",
                onPrimary: "#ffffff",
                primaryContainer: "#d9e2ff",
                onPrimaryContainer: "#0f2b61",
                secondary: "#006b8f",
                onSecondary: "#ffffff",
                secondaryContainer: "#c7ecff",
                onSecondaryContainer: "#001f2c",
                tertiary: "#5d54a9",
                onTertiary: "#ffffff",
                tertiaryContainer: "#e6ddff",
                onTertiaryContainer: "#1e1a52",
                background: "#eef3ff",
                onBackground: "#151c2c",
                surface: "#f3f6ff",
                onSurface: "#151c2c",
                surfaceVariant: "#dde4f2",
                onSurfaceVariant: "#424c63",
                outline: "#727c94",
                surfaceContainerLow: "#ecf1ff",
                surfaceContainer: "#e5ebfc",
                surfaceContainerHigh: "#dde4f6",
                surfaceContainerHighest: "#d5ddf0",
            };
        }

        return {
            primary: "#9ab6ff",
            onPrimary: "#0f1f49",
            primaryContainer: "#253564",
            onPrimaryContainer: "#d9e2ff",
            secondary: "#8ad8ff",
            onSecondary: "#00344a",
            secondaryContainer: "#194a63",
            onSecondaryContainer: "#d5f0ff",
            tertiary: "#c4b5ff",
            onTertiary: "#34246a",
            tertiaryContainer: "#4c3a84",
            onTertiaryContainer: "#e7deff",
            background: "#070b14",
            onBackground: "#dbe6ff",
            surface: "#0c1220",
            onSurface: "#dbe6ff",
            surfaceVariant: "#182132",
            onSurfaceVariant: "#a8b5d1",
            outline: "#5b6a88",
            surfaceContainerLow: "#111a2d",
            surfaceContainer: "#182336",
            surfaceContainerHigh: "#223047",
            surfaceContainerHighest: "#2b3c58",
            inverseSurface: "#dbe6ff",
            inverseOnSurface: "#162033",
            inversePrimary: "#365ba8",
        };
    }

    return {};
}

function roleMapForRequest(mode, variant, darkRoleMap, lightRoleMap) {
    const normalizedMode = normalizeThemeMode(mode);
    const baseRoleMap =
        normalizedMode === "light" ? cloneJsonValue(lightRoleMap) : cloneJsonValue(darkRoleMap);
    const variantId = normalizeStaticVariant(variant);
    const overrides = variantRoleOverrides(normalizedMode, variantId);

    for (const roleName in overrides) baseRoleMap[roleName] = overrides[roleName];

    return baseRoleMap;
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
                    supportsVariants: true,
                },
            };
        },

        generate: function (request) {
            const normalizedRequest = request && typeof request === "object" ? request : {};
            const mode = normalizeThemeMode(normalizedRequest.mode);
            const roles = roleMapForRequest(
                mode,
                normalizedRequest.variant,
                darkRoleMap,
                lightRoleMap,
            );

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

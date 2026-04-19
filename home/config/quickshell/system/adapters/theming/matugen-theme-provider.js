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

function parseJsonValue(value) {
    if (typeof value !== "string") return cloneJsonValue(value);

    const text = String(value).trim();
    if (!text) return null;

    try {
        return JSON.parse(text);
    } catch (error) {
        return null;
    }
}

function normalizeRoleMap(raw) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null;

    const normalized = {};
    for (const rawRoleName in raw) {
        const roleName = String(rawRoleName).trim();
        const roleValue = String(raw[rawRoleName] === undefined ? "" : raw[rawRoleName]).trim();
        if (!roleName || !roleValue) continue;
        normalized[roleName] = roleValue;
    }

    return Object.keys(normalized).length > 0 ? normalized : null;
}

function extractRoleMap(rawScheme, mode) {
    if (!rawScheme || typeof rawScheme !== "object" || Array.isArray(rawScheme)) return null;

    if (rawScheme.kind === "shell.theme.scheme" && rawScheme.roles) {
        const directRoleMap = normalizeRoleMap(rawScheme.roles);
        if (directRoleMap) return directRoleMap;
    }

    const directRoles = normalizeRoleMap(rawScheme.roles);
    if (directRoles) return directRoles;

    const directColors = normalizeRoleMap(rawScheme.colors);
    if (directColors) return directColors;

    if (rawScheme.schemes && typeof rawScheme.schemes === "object") {
        const schemeByMode = rawScheme.schemes[mode];
        const schemeRoleMap = extractRoleMap(schemeByMode, mode);
        if (schemeRoleMap) return schemeRoleMap;
    }

    if (rawScheme[mode] && typeof rawScheme[mode] === "object") {
        const modeRoleMap = extractRoleMap(rawScheme[mode], mode);
        if (modeRoleMap) return modeRoleMap;
    }

    return null;
}

function createMatugenThemeProvider(options) {
    const config = options && typeof options === "object" ? options : {};
    const providerId = String(config.providerId === undefined ? "matugen" : config.providerId);
    const schemePath = String(config.schemePath === undefined ? "" : config.schemePath);
    const readScheme = typeof config.readScheme === "function" ? config.readScheme : null;
    const generateScheme =
        typeof config.generateScheme === "function" ? config.generateScheme : null;

    return {
        describe: function () {
            return {
                kind: "adapter.theme.provider",
                id: providerId,
                ready: readScheme !== null || generateScheme !== null,
                mode: "scaffold",
                schemePath: schemePath,
                capabilities: {
                    supportsWallpaper: true,
                    supportsColorSource: true,
                    supportsVariants: true,
                },
            };
        },

        generate: function (request) {
            const normalizedRequest = request && typeof request === "object" ? request : {};
            const mode = normalizeThemeMode(normalizedRequest.mode);

            let generatedValue = null;
            if (generateScheme)
                generatedValue = parseJsonValue(generateScheme(cloneJsonValue(normalizedRequest)));

            let rawScheme = generatedValue;
            if (readScheme)
                rawScheme = parseJsonValue(readScheme(cloneJsonValue(normalizedRequest)));
            if (!rawScheme) return null;

            if (rawScheme.kind === "shell.theme.scheme") return cloneJsonValue(rawScheme);

            const roleMap = extractRoleMap(rawScheme, mode);
            if (!roleMap) return null;

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
                sourceKind:
                    normalizedRequest.sourceKind === undefined
                        ? "generated"
                        : String(normalizedRequest.sourceKind),
                sourceValue:
                    normalizedRequest.sourceValue === undefined
                        ? ""
                        : String(normalizedRequest.sourceValue),
                generatedAt: new Date().toISOString(),
                roles: roleMap,
                meta: {
                    kind: "adapter.theme.provider.matugen",
                    schemePath: schemePath,
                },
            };
        },
    };
}

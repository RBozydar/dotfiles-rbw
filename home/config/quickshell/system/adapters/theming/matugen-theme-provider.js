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

function normalizeRoleName(roleName) {
    const normalized = String(roleName === undefined ? "" : roleName).trim();
    if (!normalized) return "";

    const tokenized = normalized.replace(/[\s-]+/g, "_");
    if (tokenized.indexOf("_") < 0) return tokenized;

    const parts = tokenized.split("_");
    if (parts.length <= 0) return tokenized;

    let nextName = String(parts[0]).toLowerCase();
    for (let index = 1; index < parts.length; index += 1) {
        const part = String(parts[index]).toLowerCase();
        if (!part) continue;
        nextName += part[0].toUpperCase() + part.slice(1);
    }

    return nextName;
}

function normalizeColorString(value) {
    if (value === undefined || value === null) return "";
    if (typeof value !== "string" && typeof value !== "number") return "";
    return String(value).trim();
}

function extractColorValue(rawRoleValue, mode) {
    const directValue = normalizeColorString(rawRoleValue);
    if (directValue) return directValue;

    if (!rawRoleValue || typeof rawRoleValue !== "object" || Array.isArray(rawRoleValue)) return "";

    if (
        rawRoleValue[mode] &&
        typeof rawRoleValue[mode] === "object" &&
        !Array.isArray(rawRoleValue[mode])
    ) {
        const nestedModeColor = normalizeColorString(rawRoleValue[mode].color);
        if (nestedModeColor) return nestedModeColor;
    }

    const modeValue = normalizeColorString(rawRoleValue[mode]);
    if (modeValue) return modeValue;

    if (
        rawRoleValue.default &&
        typeof rawRoleValue.default === "object" &&
        !Array.isArray(rawRoleValue.default)
    ) {
        const nestedDefaultColor = normalizeColorString(rawRoleValue.default.color);
        if (nestedDefaultColor) return nestedDefaultColor;
    }

    const defaultValue = normalizeColorString(rawRoleValue.default);
    if (defaultValue) return defaultValue;

    const nestedColor = normalizeColorString(rawRoleValue.color);
    if (nestedColor) return nestedColor;

    return "";
}

function normalizeRoleMap(raw, mode) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null;

    const normalized = {};
    for (const rawRoleName in raw) {
        const roleName = normalizeRoleName(rawRoleName);
        const roleValue = extractColorValue(raw[rawRoleName], mode);
        if (!roleName || !roleValue) continue;
        normalized[roleName] = roleValue;
    }

    return Object.keys(normalized).length > 0 ? normalized : null;
}

function extractRoleMap(rawScheme, mode) {
    if (!rawScheme || typeof rawScheme !== "object" || Array.isArray(rawScheme)) return null;

    if (rawScheme.kind === "shell.theme.scheme" && rawScheme.roles) {
        const directRoleMap = normalizeRoleMap(rawScheme.roles, mode);
        if (directRoleMap) return directRoleMap;
    }

    const directRoles = normalizeRoleMap(rawScheme.roles, mode);
    if (directRoles) return directRoles;

    const directColors = normalizeRoleMap(rawScheme.colors, mode);
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
    const describeRuntime =
        typeof config.describeRuntime === "function" ? config.describeRuntime : null;

    return {
        describe: function () {
            const runtimeDetails = describeRuntime ? cloneJsonValue(describeRuntime()) : null;
            const hasRuntimeCallbacks = readScheme !== null || generateScheme !== null;

            return {
                kind: "adapter.theme.provider",
                id: providerId,
                ready:
                    runtimeDetails && runtimeDetails.ready !== undefined
                        ? Boolean(runtimeDetails.ready)
                        : hasRuntimeCallbacks,
                mode: hasRuntimeCallbacks ? "runtime" : "scaffold",
                schemePath: schemePath,
                capabilities: {
                    supportsWallpaper: true,
                    supportsColorSource: true,
                    supportsVariants: true,
                },
                runtime: runtimeDetails,
            };
        },

        generate: function (request) {
            const normalizedRequest = request && typeof request === "object" ? request : {};
            const mode = normalizeThemeMode(normalizedRequest.mode);

            let rawScheme = null;
            if (readScheme)
                rawScheme = parseJsonValue(readScheme(cloneJsonValue(normalizedRequest)));
            if (!rawScheme && generateScheme)
                rawScheme = parseJsonValue(generateScheme(cloneJsonValue(normalizedRequest)));
            if (!rawScheme && readScheme)
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

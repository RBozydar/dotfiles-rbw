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

function normalizeNonEmptyString(value, fieldName) {
    const normalized = String(value === undefined ? "" : value).trim();
    if (!normalized) throw new Error(fieldName + " must be a non-empty string");
    return normalized;
}

function isHexColorString(value) {
    return /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(String(value || ""));
}

function normalizeThemeMode(mode) {
    const normalized = String(mode === undefined ? "dark" : mode)
        .trim()
        .toLowerCase();
    if (normalized !== "dark" && normalized !== "light")
        throw new Error("Theme mode must be dark or light");
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
        throw new Error("Theme sourceKind must be static, wallpaper, color, file, or generated");

    return normalized;
}

function requiredThemeRoleNames() {
    return [
        "primary",
        "onPrimary",
        "primaryContainer",
        "onPrimaryContainer",
        "secondary",
        "onSecondary",
        "secondaryContainer",
        "onSecondaryContainer",
        "tertiary",
        "onTertiary",
        "tertiaryContainer",
        "onTertiaryContainer",
        "error",
        "onError",
        "errorContainer",
        "onErrorContainer",
        "background",
        "onBackground",
        "surface",
        "onSurface",
        "surfaceVariant",
        "onSurfaceVariant",
        "outline",
        "outlineVariant",
        "shadow",
        "scrim",
        "inverseSurface",
        "inverseOnSurface",
        "inversePrimary",
        "surfaceTint",
        "surfaceContainerLowest",
        "surfaceContainerLow",
        "surfaceContainer",
        "surfaceContainerHigh",
        "surfaceContainerHighest",
        "surfaceBright",
        "surfaceDim",
    ];
}

function createDefaultThemeRoleMap(mode) {
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

function validateThemeRoleMap(roleMap) {
    if (!roleMap || typeof roleMap !== "object" || Array.isArray(roleMap))
        throw new Error("Theme roles must be an object");

    const normalized = {};

    for (const rawRoleName in roleMap) {
        const roleName = String(rawRoleName).trim();
        const roleValue = String(roleMap[rawRoleName] === undefined ? "" : roleMap[rawRoleName])
            .trim()
            .toLowerCase();
        if (!roleName) throw new Error("Theme role names must be non-empty");
        if (!isHexColorString(roleValue))
            throw new Error("Theme role " + roleName + " must be a hex color string");
        normalized[roleName] = roleValue;
    }

    const requiredRoles = requiredThemeRoleNames();
    for (let index = 0; index < requiredRoles.length; index += 1) {
        const requiredRoleName = requiredRoles[index];
        if (!Object.prototype.hasOwnProperty.call(normalized, requiredRoleName))
            throw new Error("Theme roles are missing required role " + requiredRoleName);
    }

    return normalized;
}

function validateThemeGenerationRequest(request) {
    if (!request || typeof request !== "object" || Array.isArray(request))
        throw new Error("Theme generation request must be an object");
    if (request.kind !== "shell.theme.generate")
        throw new Error("Theme generation request kind must be shell.theme.generate");

    const schemaVersion = Number(request.schemaVersion);
    if (!Number.isInteger(schemaVersion) || schemaVersion < 1)
        throw new Error("Theme generation request schemaVersion must be an integer >= 1");

    const provider = normalizeNonEmptyString(request.provider, "Theme request provider");
    const mode = normalizeThemeMode(request.mode);
    const variant = normalizeNonEmptyString(
        request.variant === undefined ? "tonal-spot" : request.variant,
        "Theme request variant",
    );
    const sourceKind = normalizeThemeSourceKind(request.sourceKind);
    const sourceValue = String(request.sourceValue === undefined ? "" : request.sourceValue);
    const meta = request.meta === undefined ? {} : request.meta;
    if (!meta || typeof meta !== "object" || Array.isArray(meta))
        throw new Error("Theme request meta must be an object");

    return {
        kind: "shell.theme.generate",
        schemaVersion: schemaVersion,
        provider: provider,
        mode: mode,
        variant: variant,
        sourceKind: sourceKind,
        sourceValue: sourceValue,
        meta: cloneJsonValue(meta),
    };
}

function createThemeGenerationRequest(fields) {
    const base = fields && typeof fields === "object" ? fields : {};
    return validateThemeGenerationRequest({
        kind: "shell.theme.generate",
        schemaVersion: 1,
        provider: base.provider === undefined ? "static" : base.provider,
        mode: base.mode === undefined ? "dark" : base.mode,
        variant: base.variant === undefined ? "tonal-spot" : base.variant,
        sourceKind: base.sourceKind === undefined ? "static" : base.sourceKind,
        sourceValue: base.sourceValue === undefined ? "" : base.sourceValue,
        meta: base.meta === undefined ? {} : base.meta,
    });
}

function validateThemeSchemeDocument(document) {
    if (!document || typeof document !== "object" || Array.isArray(document))
        throw new Error("Theme scheme document must be an object");
    if (document.kind !== "shell.theme.scheme")
        throw new Error("Theme scheme kind must be shell.theme.scheme");

    const schemaVersion = Number(document.schemaVersion);
    if (!Number.isInteger(schemaVersion) || schemaVersion < 1)
        throw new Error("Theme scheme schemaVersion must be an integer >= 1");

    const themeId = normalizeNonEmptyString(document.themeId, "Theme id");
    const provider = normalizeNonEmptyString(document.provider, "Theme provider");
    const mode = normalizeThemeMode(document.mode);
    const variant = normalizeNonEmptyString(
        document.variant === undefined ? "tonal-spot" : document.variant,
        "Theme variant",
    );
    const sourceKind = normalizeThemeSourceKind(document.sourceKind);
    const sourceValue = String(document.sourceValue === undefined ? "" : document.sourceValue);
    const generatedAt = normalizeNonEmptyString(
        document.generatedAt === undefined ? new Date().toISOString() : document.generatedAt,
        "Theme generatedAt",
    );
    const roles = validateThemeRoleMap(document.roles);
    const meta = document.meta === undefined ? {} : document.meta;
    if (!meta || typeof meta !== "object" || Array.isArray(meta))
        throw new Error("Theme scheme meta must be an object");

    return {
        kind: "shell.theme.scheme",
        schemaVersion: schemaVersion,
        themeId: themeId,
        provider: provider,
        mode: mode,
        variant: variant,
        sourceKind: sourceKind,
        sourceValue: sourceValue,
        generatedAt: generatedAt,
        roles: roles,
        meta: cloneJsonValue(meta),
    };
}

function createThemeSchemeDocument(fields) {
    const base = fields && typeof fields === "object" ? fields : {};
    const mode = normalizeThemeMode(base.mode === undefined ? "dark" : base.mode);
    const provider = base.provider === undefined ? "static" : String(base.provider);

    return validateThemeSchemeDocument({
        kind: "shell.theme.scheme",
        schemaVersion: 1,
        themeId:
            base.themeId === undefined
                ? provider + "." + mode
                : String(base.themeId === undefined ? "" : base.themeId),
        provider: provider,
        mode: mode,
        variant: base.variant === undefined ? "tonal-spot" : base.variant,
        sourceKind: base.sourceKind === undefined ? "static" : base.sourceKind,
        sourceValue: base.sourceValue === undefined ? "" : base.sourceValue,
        generatedAt: base.generatedAt === undefined ? new Date().toISOString() : base.generatedAt,
        roles: base.roles === undefined ? createDefaultThemeRoleMap(mode) : base.roles,
        meta: base.meta === undefined ? {} : base.meta,
    });
}

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

function createThemeProviderPort(adapter) {
    const provider = adapter && typeof adapter === "object" ? adapter : {};

    return {
        generate: function (request) {
            if (typeof provider.generate !== "function") return null;
            return cloneJsonValue(provider.generate(cloneJsonValue(request)));
        },

        describe: function () {
            if (typeof provider.describe !== "function") return null;
            return cloneJsonValue(provider.describe());
        },
    };
}

function normalizeThemeProviderCatalog(catalog) {
    if (!catalog || typeof catalog !== "object" || Array.isArray(catalog)) return {};

    const normalized = {};
    for (const rawProviderId in catalog) {
        const providerId = String(rawProviderId).trim();
        const adapter = catalog[rawProviderId];
        if (!providerId) continue;
        if (!adapter || typeof adapter !== "object") continue;
        normalized[providerId] = adapter;
    }

    return normalized;
}

function resolveThemeProvider(catalog, preferredProviderId, fallbackProviderId) {
    const normalizedCatalog = normalizeThemeProviderCatalog(catalog);
    const preferred = String(preferredProviderId === undefined ? "" : preferredProviderId).trim();
    const fallback = String(fallbackProviderId === undefined ? "" : fallbackProviderId).trim();

    if (preferred && normalizedCatalog[preferred]) {
        return {
            providerId: preferred,
            adapter: normalizedCatalog[preferred],
            fallbackUsed: false,
        };
    }

    if (fallback && normalizedCatalog[fallback]) {
        return {
            providerId: fallback,
            adapter: normalizedCatalog[fallback],
            fallbackUsed: preferred !== fallback,
        };
    }

    const providerIds = Object.keys(normalizedCatalog);
    if (providerIds.length <= 0) {
        return {
            providerId: "",
            adapter: null,
            fallbackUsed: false,
        };
    }

    return {
        providerId: providerIds[0],
        adapter: normalizedCatalog[providerIds[0]],
        fallbackUsed: preferred !== providerIds[0],
    };
}

function describeThemeProviderCatalog(catalog) {
    const normalizedCatalog = normalizeThemeProviderCatalog(catalog);
    const providers = [];
    const providerIds = Object.keys(normalizedCatalog).sort();

    for (let index = 0; index < providerIds.length; index += 1) {
        const providerId = providerIds[index];
        const port = createThemeProviderPort(normalizedCatalog[providerId]);
        const details = port.describe() || {};
        providers.push({
            providerId: providerId,
            ready: Boolean(details.ready === true),
            details: details,
        });
    }

    return {
        kind: "theme.provider_catalog",
        providers: providers,
    };
}

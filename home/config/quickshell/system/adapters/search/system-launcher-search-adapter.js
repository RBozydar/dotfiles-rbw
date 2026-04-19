function lowercase(value) {
    return String(value || "").toLowerCase();
}

function clamp(value, min, max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
}

function isThenable(value) {
    if (!value) return false;
    const kind = typeof value;
    if (kind !== "object" && kind !== "function") return false;
    return typeof value.then === "function";
}

var fallbackAppCatalog = [
    {
        desktopId: "foot.desktop",
        title: "Foot",
        subtitle: "Terminal emulator",
        detail: "Terminal emulator",
        iconName: "foot",
        provider: "apps",
        score: 120,
    },
    {
        desktopId: "firefox.desktop",
        title: "Firefox",
        subtitle: "Web browser",
        detail: "Web browser",
        iconName: "firefox",
        provider: "apps",
        score: 110,
    },
    {
        desktopId: "org.gnome.Nautilus.desktop",
        title: "Files",
        subtitle: "File manager",
        detail: "File manager",
        iconName: "org.gnome.Nautilus",
        provider: "apps",
        score: 90,
    },
];

function searchFallbackApps(command) {
    const payload = command && command.payload ? command.payload : {};
    const query = lowercase(payload.query).trim();
    const results = [];

    for (let index = 0; index < fallbackAppCatalog.length; index += 1) {
        const entry = fallbackAppCatalog[index];
        const title = lowercase(entry.title);
        const subtitle = lowercase(entry.subtitle);

        if (query && title.indexOf(query) < 0 && subtitle.indexOf(query) < 0) continue;

        results.push({
            id: "app:" + entry.desktopId,
            title: entry.title,
            subtitle: entry.subtitle,
            detail: entry.detail,
            iconName: entry.iconName,
            provider: entry.provider,
            score: entry.score,
            action: {
                type: "app.launch",
                targetId: entry.desktopId,
            },
        });
    }

    return results;
}

function normalizeCommandSpecs(commandSpecs) {
    if (!Array.isArray(commandSpecs)) return [];

    const normalized = [];

    for (let index = 0; index < commandSpecs.length; index += 1) {
        const spec = commandSpecs[index];
        if (!spec || typeof spec.name !== "string") continue;
        normalized.push({
            name: spec.name,
            summary: spec.summary === undefined ? "" : String(spec.summary),
            usage: spec.usage === undefined ? spec.name : String(spec.usage),
            minArgs: spec.minArgs === undefined ? 0 : Number(spec.minArgs),
            maxArgs: spec.maxArgs === undefined ? 0 : Number(spec.maxArgs),
        });
    }

    return normalized;
}

function normalizePinnedCommandIds(pinnedCommandIds) {
    const source = [];

    if (Array.isArray(pinnedCommandIds)) {
        for (let index = 0; index < pinnedCommandIds.length; index += 1)
            source.push(pinnedCommandIds[index]);
    } else if (
        pinnedCommandIds &&
        typeof pinnedCommandIds === "object" &&
        typeof pinnedCommandIds.length === "number"
    ) {
        for (let index = 0; index < pinnedCommandIds.length; index += 1)
            source.push(pinnedCommandIds[index]);
    } else {
        return {};
    }

    const byId = {};

    for (let index = 0; index < source.length; index += 1) {
        const id = String(source[index] || "").trim();
        if (!id) continue;
        byId[id] = true;
    }

    return byId;
}

function normalizeMaxResults(maxResults) {
    const parsed = Number(maxResults);
    if (!Number.isInteger(parsed)) return 8;
    return clamp(parsed, 1, 50);
}

function isCommandModeQuery(query, commandPrefix) {
    const normalizedPrefix = String(commandPrefix || "").trim();
    if (!normalizedPrefix) return false;
    return (
        String(query || "")
            .trim()
            .indexOf(normalizedPrefix) === 0
    );
}

function stripCommandPrefix(query, commandPrefix) {
    const normalizedQuery = String(query || "").trim();
    const normalizedPrefix = String(commandPrefix || "").trim();
    if (!normalizedPrefix) return normalizedQuery;
    if (normalizedQuery.indexOf(normalizedPrefix) !== 0) return normalizedQuery;
    return normalizedQuery.slice(normalizedPrefix.length).trim();
}

function searchIpcCommandSpecs(commandSpecs, commandTerm, pinnedCommandIds) {
    const normalizedTerm = lowercase(commandTerm).trim();
    const pinnedById = normalizePinnedCommandIds(pinnedCommandIds);
    const items = [];

    for (let index = 0; index < commandSpecs.length; index += 1) {
        const spec = commandSpecs[index];
        const name = lowercase(spec.name);
        const summary = lowercase(spec.summary);
        const pinned = pinnedById[spec.name] === true;

        if (normalizedTerm) {
            if (name.indexOf(normalizedTerm) < 0 && summary.indexOf(normalizedTerm) < 0) continue;
        }

        let score = 750;
        if (pinned) score += 260;
        if (!normalizedTerm) score += 25;
        else if (name === normalizedTerm) score += 500;
        else if (name.indexOf(normalizedTerm) === 0) score += 250;
        else score += 100;

        items.push({
            id: "ipc:" + spec.name,
            title: spec.name,
            subtitle: spec.summary,
            provider: "commands",
            score: score,
            action: {
                type: "shell.ipc.dispatch",
                command: spec.name,
                args: [],
            },
        });
    }

    return items;
}

function createExternalCommandCandidate(commandTerm) {
    const normalizedTerm = String(commandTerm || "").trim();
    if (!normalizedTerm) return null;

    return {
        id: "exec:" + normalizedTerm,
        title: normalizedTerm,
        subtitle: "Run external command",
        provider: "commands",
        score: 920,
        action: {
            type: "shell.command.run",
            command: normalizedTerm,
        },
    };
}

function tokenizeExpression(expression) {
    const source = String(expression || "").trim();
    const tokens = [];
    let cursor = 0;

    while (cursor < source.length) {
        const character = source[cursor];

        if (/\s/.test(character)) {
            cursor += 1;
            continue;
        }

        if ("+-*/()".indexOf(character) >= 0) {
            tokens.push({
                kind: "operator",
                value: character,
            });
            cursor += 1;
            continue;
        }

        if (/[0-9.]/.test(character)) {
            let numberText = "";
            let dotCount = 0;

            while (cursor < source.length && /[0-9.]/.test(source[cursor])) {
                if (source[cursor] === ".") dotCount += 1;
                numberText += source[cursor];
                cursor += 1;
            }

            if (dotCount > 1) throw new Error("Invalid numeric literal");
            if (numberText === "." || numberText.length === 0) throw new Error("Invalid number");

            tokens.push({
                kind: "number",
                value: Number(numberText),
            });
            continue;
        }

        throw new Error("Unsupported expression token");
    }

    return tokens;
}

function evaluateExpressionTokens(tokens) {
    let position = 0;

    function current() {
        return position < tokens.length ? tokens[position] : null;
    }

    function consume(value) {
        const token = current();
        if (!token || token.value !== value) return false;
        position += 1;
        return true;
    }

    function parsePrimary() {
        const token = current();
        if (!token) throw new Error("Unexpected end of expression");

        if (token.kind === "operator" && token.value === "(") {
            position += 1;
            const nested = parseAddSub();
            if (!consume(")")) throw new Error("Expected closing parenthesis");
            return nested;
        }

        if (token.kind === "number") {
            position += 1;
            return Number(token.value);
        }

        throw new Error("Unexpected token in expression");
    }

    function parseUnary() {
        const token = current();
        if (token && token.kind === "operator" && (token.value === "+" || token.value === "-")) {
            position += 1;
            const value = parseUnary();
            return token.value === "-" ? -value : value;
        }
        return parsePrimary();
    }

    function parseMulDiv() {
        let value = parseUnary();

        while (true) {
            const token = current();
            if (!token || token.kind !== "operator" || (token.value !== "*" && token.value !== "/"))
                break;

            position += 1;
            const right = parseUnary();

            if (token.value === "*") value *= right;
            else value /= right;
        }

        return value;
    }

    function parseAddSub() {
        let value = parseMulDiv();

        while (true) {
            const token = current();
            if (!token || token.kind !== "operator" || (token.value !== "+" && token.value !== "-"))
                break;

            position += 1;
            const right = parseMulDiv();

            if (token.value === "+") value += right;
            else value -= right;
        }

        return value;
    }

    const value = parseAddSub();

    if (position < tokens.length) throw new Error("Unexpected trailing tokens");
    if (!Number.isFinite(value)) throw new Error("Expression result is not finite");

    return value;
}

function tryEvaluateExpression(query) {
    const normalized = String(query || "").trim();
    if (!normalized) return null;
    if (!/[0-9]/.test(normalized)) return null;
    if (!/^[0-9+\-*/().\s]+$/.test(normalized)) return null;

    try {
        const tokens = tokenizeExpression(normalized);
        if (tokens.length === 0) return null;

        const value = evaluateExpressionTokens(tokens);
        return {
            expression: normalized,
            value: String(value),
        };
    } catch (error) {
        return null;
    }
}

function createCalculatorResult(query) {
    const evaluation = tryEvaluateExpression(query);
    if (!evaluation) return null;

    return {
        id: "calc:" + evaluation.expression,
        title: evaluation.value,
        subtitle: evaluation.expression,
        provider: "calculator",
        score: 840,
        action: {
            type: "calculator.copy_result",
            targetId: evaluation.value,
        },
    };
}

function limitItems(items, maxResults) {
    const normalizedLimit = normalizeMaxResults(maxResults);
    const limited = [];

    for (let index = 0; index < items.length && limited.length < normalizedLimit; index += 1)
        limited.push(items[index]);

    return limited;
}

function normalizeProviderModes(rawModes) {
    const source = [];
    if (Array.isArray(rawModes)) {
        for (let index = 0; index < rawModes.length; index += 1) source.push(rawModes[index]);
    } else if (typeof rawModes === "string") {
        source.push(rawModes);
    } else {
        source.push("query");
    }

    const modes = {};

    for (let index = 0; index < source.length; index += 1) {
        const mode = String(source[index] || "").trim();
        if (!mode) continue;
        modes[mode] = true;
    }

    if (Object.keys(modes).length === 0) modes.query = true;
    return modes;
}

function normalizeProviderSpec(provider, fallbackId, fallbackOrder) {
    if (!provider || typeof provider !== "object") return null;
    if (typeof provider.search !== "function") return null;

    const id = String(provider.id || fallbackId || "").trim();
    if (!id) return null;

    const parsedOrder = Number(provider.order);
    const order = Number.isFinite(parsedOrder) ? parsedOrder : Number(fallbackOrder);
    const kind = provider.kind === "async" ? "async" : "sync";

    return {
        id: id,
        order: order,
        kind: kind,
        modes: normalizeProviderModes(provider.modes),
        search: provider.search,
    };
}

function normalizeProviderSpecs(providers, orderOffset) {
    if (!Array.isArray(providers)) return [];
    const normalized = [];
    const offset = Number(orderOffset || 0);

    for (let index = 0; index < providers.length; index += 1) {
        const spec = normalizeProviderSpec(
            providers[index],
            "provider.custom." + String(index),
            offset + index,
        );
        if (!spec) continue;
        normalized.push(spec);
    }

    return normalized;
}

function providerSupportsMode(provider, mode) {
    if (!provider || !provider.modes || typeof provider.modes !== "object") return false;
    return provider.modes[mode] === true;
}

function normalizeProviderItems(rawItems, fallbackProviderId) {
    if (!Array.isArray(rawItems)) return [];
    const normalized = [];

    for (let index = 0; index < rawItems.length; index += 1) {
        const item = rawItems[index];
        if (!item || typeof item !== "object") continue;
        if (typeof item.id !== "string") continue;
        if (typeof item.title !== "string") continue;
        if (!item.action || typeof item.action.type !== "string") continue;

        const normalizedItem = {
            id: item.id,
            title: item.title,
            subtitle: item.subtitle === undefined ? "" : String(item.subtitle),
            detail: item.detail === undefined ? "" : String(item.detail),
            iconName: item.iconName === undefined ? "" : String(item.iconName),
            provider:
                typeof item.provider === "string" && item.provider
                    ? item.provider
                    : String(fallbackProviderId),
            score: Number(item.score || 0),
            action: item.action,
        };

        normalized.push(normalizedItem);
    }

    return normalized;
}

function createDefaultProviderSpecs() {
    return [
        {
            id: "commands.external",
            order: 10,
            kind: "sync",
            modes: {
                command: true,
            },
            search: function (context) {
                const candidate = createExternalCommandCandidate(context.commandTerm);
                return candidate ? [candidate] : [];
            },
        },
        {
            id: "commands.catalog",
            order: 20,
            kind: "sync",
            modes: {
                command: true,
            },
            search: function (context) {
                return searchIpcCommandSpecs(
                    context.commandSpecs,
                    context.commandTerm,
                    context.pinnedCommandIds,
                );
            },
        },
        {
            id: "calculator.expression",
            order: 10,
            kind: "sync",
            modes: {
                query: true,
            },
            search: function (context) {
                const item = createCalculatorResult(context.query);
                return item ? [item] : [];
            },
        },
        {
            id: "apps.catalog",
            order: 20,
            kind: "sync",
            modes: {
                query: true,
            },
            search: function (context) {
                if (
                    context.appSearchAdapter &&
                    typeof context.appSearchAdapter.search === "function"
                ) {
                    const appItems = context.appSearchAdapter.search(context.command);
                    return Array.isArray(appItems) ? appItems : [];
                }

                return searchFallbackApps(context.command);
            },
        },
    ];
}

function sortProviderSpecs(providerSpecs) {
    providerSpecs.sort(function (left, right) {
        if (left.order !== right.order) return left.order - right.order;
        if (left.id < right.id) return -1;
        if (left.id > right.id) return 1;
        return 0;
    });
}

function sortLauncherItems(items) {
    items.sort(function (left, right) {
        if (right.score !== left.score) return right.score - left.score;
        if (left.title < right.title) return -1;
        if (left.title > right.title) return 1;
        return 0;
    });
}

function collectProviderItems(providerSpecs, searchContext, onAsyncProviderResult) {
    const merged = [];

    for (let index = 0; index < providerSpecs.length; index += 1) {
        const provider = providerSpecs[index];
        if (!providerSupportsMode(provider, searchContext.mode)) continue;

        const rawItems = provider.search(searchContext);
        if (provider.kind === "async" || isThenable(rawItems)) {
            if (typeof onAsyncProviderResult === "function") {
                onAsyncProviderResult({
                    kind: "launcher.provider.async_pending",
                    providerId: provider.id,
                    mode: searchContext.mode,
                    generation: searchContext.generation,
                    query: searchContext.query,
                    promise: rawItems,
                });
            }
            continue;
        }

        const normalized = normalizeProviderItems(rawItems, provider.id);
        for (let itemIndex = 0; itemIndex < normalized.length; itemIndex += 1)
            merged.push(normalized[itemIndex]);
    }

    return merged;
}

function commandGeneration(command) {
    const parsed =
        command && command.meta && command.meta.generation !== undefined
            ? Number(command.meta.generation)
            : NaN;
    if (!Number.isInteger(parsed)) return -1;
    return parsed;
}

function createSystemLauncherSearchAdapter(options) {
    const config = options && typeof options === "object" ? options : {};

    const adapter = {
        search: function (command) {
            const payload = command && command.payload ? command.payload : {};
            const query = String(payload.query || "");
            const commandPrefix =
                config.commandPrefix === undefined ? ">" : String(config.commandPrefix);
            const commandSpecs = normalizeCommandSpecs(config.commandSpecs);
            const maxResults = normalizeMaxResults(config.maxResults);
            const pinnedCommandIds = config.pinnedCommandIds;
            const appSearchAdapter = config.appSearchAdapter;
            const includeDefaultProviders = config.includeDefaultProviders !== false;
            const customProviderSpecs = normalizeProviderSpecs(config.providers, 100);
            const onAsyncProviderResult =
                typeof config.onAsyncProviderResult === "function"
                    ? config.onAsyncProviderResult
                    : null;

            const mode = isCommandModeQuery(query, commandPrefix) ? "command" : "query";
            const commandTerm = mode === "command" ? stripCommandPrefix(query, commandPrefix) : "";

            const providerSpecs = [];
            if (includeDefaultProviders) {
                const defaultSpecs = createDefaultProviderSpecs();
                for (let index = 0; index < defaultSpecs.length; index += 1)
                    providerSpecs.push(defaultSpecs[index]);
            }
            for (let index = 0; index < customProviderSpecs.length; index += 1)
                providerSpecs.push(customProviderSpecs[index]);

            sortProviderSpecs(providerSpecs);

            const searchContext = {
                mode: mode,
                query: query,
                commandTerm: commandTerm,
                generation: commandGeneration(command),
                command: command,
                commandPrefix: commandPrefix,
                commandSpecs: commandSpecs,
                pinnedCommandIds: pinnedCommandIds,
                appSearchAdapter: appSearchAdapter,
            };

            const merged = collectProviderItems(
                providerSpecs,
                searchContext,
                onAsyncProviderResult,
            );
            sortLauncherItems(merged);
            return limitItems(merged, maxResults);
        },
    };

    return adapter;
}

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
    } else if (pinnedCommandIds && typeof pinnedCommandIds === "object") {
        if (typeof pinnedCommandIds.length === "number") {
            for (let index = 0; index < pinnedCommandIds.length; index += 1)
                source.push(pinnedCommandIds[index]);
        } else {
            for (const key in pinnedCommandIds) source.push(pinnedCommandIds[key]);
        }
    } else {
        return {
            byId: {},
            orderById: {},
        };
    }

    const byId = {};
    const orderById = {};
    let order = 0;

    for (let index = 0; index < source.length; index += 1) {
        const id = String(source[index] || "").trim();
        if (!id) continue;
        if (byId[id]) continue;
        byId[id] = true;
        orderById[id] = order;
        order += 1;
    }

    return {
        byId: byId,
        orderById: orderById,
    };
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

function splitFirstToken(value) {
    const source = String(value || "").trim();
    if (!source)
        return {
            token: "",
            remainder: "",
        };

    const splitIndex = source.search(/\s/);
    if (splitIndex < 0) {
        return {
            token: source,
            remainder: "",
        };
    }

    return {
        token: source.slice(0, splitIndex),
        remainder: source.slice(splitIndex + 1).trim(),
    };
}

function normalizeRouteKey(value) {
    const normalized = lowercase(value).trim();
    return normalized || "default";
}

function resolveCommandRoute(commandTerm) {
    const normalizedTerm = String(commandTerm || "").trim();
    if (!normalizedTerm) {
        return {
            mode: "command",
            routeKey: "default",
            term: "",
        };
    }

    const head = splitFirstToken(normalizedTerm);
    const token = lowercase(head.token);

    if (token === "cmd" || token === "command" || token === "exec")
        return {
            mode: "command",
            routeKey: "cmd",
            term: head.remainder,
        };
    if (token === "web" || token === "w")
        return {
            mode: "query",
            routeKey: "web",
            term: head.remainder,
        };
    if (token === "app" || token === "apps")
        return {
            mode: "query",
            routeKey: "apps",
            term: head.remainder,
        };
    if (token === "clip" || token === "clipboard")
        return {
            mode: "query",
            routeKey: "clipboard",
            term: head.remainder,
        };
    if (token === "emoji" || token === "em")
        return {
            mode: "query",
            routeKey: "emoji",
            term: head.remainder,
        };
    if (token === "file" || token === "files")
        return {
            mode: "query",
            routeKey: "files",
            term: head.remainder,
        };
    if (token === "win" || token === "window" || token === "windows")
        return {
            mode: "query",
            routeKey: "windows",
            term: head.remainder,
        };
    if (token === "home" || token === "ha" || token === "hass")
        return {
            mode: "query",
            routeKey: "homeassistant",
            term: head.remainder,
        };
    if (token === "wall" || token === "wallpaper")
        return {
            mode: "query",
            routeKey: "wallpaper",
            term: head.remainder,
        };
    if (token === "calc" || token === "math")
        return {
            mode: "query",
            routeKey: "calculator",
            term: head.remainder,
        };

    return {
        mode: "command",
        routeKey: "default",
        term: normalizedTerm,
    };
}

function resolveSearchProjection(query, commandPrefix) {
    const normalizedQuery = String(query || "");
    const trimmedQuery = normalizedQuery.trim();
    const prefix = String(commandPrefix || "").trim();

    if (!isCommandModeQuery(trimmedQuery, prefix)) {
        return {
            mode: "query",
            routeKey: "default",
            queryTerm: trimmedQuery,
            commandTerm: "",
        };
    }

    const stripped = stripCommandPrefix(trimmedQuery, prefix);
    const route = resolveCommandRoute(stripped);

    if (route.mode === "query") {
        return {
            mode: "query",
            routeKey: normalizeRouteKey(route.routeKey),
            queryTerm: String(route.term || "").trim(),
            commandTerm: "",
        };
    }

    return {
        mode: "command",
        routeKey: normalizeRouteKey(route.routeKey),
        queryTerm: "",
        commandTerm: String(route.term || "").trim(),
    };
}

function createQueryCommand(command, query) {
    const source = command && typeof command === "object" ? command : {};
    const payload = source.payload && typeof source.payload === "object" ? source.payload : {};
    const meta = source.meta && typeof source.meta === "object" ? source.meta : {};
    return {
        type: source.type === undefined ? "launcher.run_search" : String(source.type),
        payload: {
            query: query === undefined ? String(payload.query || "") : String(query),
        },
        meta: meta,
    };
}

function searchIpcCommandSpecs(commandSpecs, commandTerm, pinnedCommandIds) {
    const normalizedTerm = lowercase(commandTerm).trim();
    const pinnedState = normalizePinnedCommandIds(pinnedCommandIds);
    const pinnedById = pinnedState.byId;
    const pinnedOrderById = pinnedState.orderById;
    const items = [];

    for (let index = 0; index < commandSpecs.length; index += 1) {
        const spec = commandSpecs[index];
        const name = lowercase(spec.name);
        const summary = lowercase(spec.summary);
        const pinned = pinnedById[spec.name] === true;
        const pinnedOrder = pinned ? Number(pinnedOrderById[spec.name]) : -1;

        if (normalizedTerm) {
            if (name.indexOf(normalizedTerm) < 0 && summary.indexOf(normalizedTerm) < 0) continue;
        }

        let score = 750;
        if (pinned) score += 260;
        if (pinnedOrder >= 0) score += Math.max(0, 220 - pinnedOrder * 12);
        if (!normalizedTerm) score += 25;
        else if (name === normalizedTerm) score += 500;
        else if (name.indexOf(normalizedTerm) === 0) score += 250;
        else score += 100;

        items.push({
            id: "ipc:" + spec.name,
            title: spec.name,
            subtitle: spec.summary,
            provider: "commands",
            pinned: pinned,
            pinOrder: pinnedOrder,
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

function createExternalCommandCandidate(commandTerm, options) {
    const normalizedTerm = String(commandTerm || "").trim();
    if (!normalizedTerm) return null;
    const config = options && typeof options === "object" ? options : {};
    const subtitle =
        config.subtitle === undefined ? "Run external command" : String(config.subtitle);
    const score = Number(config.score);

    return {
        id: "exec:" + normalizedTerm,
        title: normalizedTerm,
        subtitle: subtitle,
        detail: "External command",
        iconName: "utilities-terminal",
        provider: config.provider === undefined ? "commands" : String(config.provider),
        score: Number.isFinite(score) ? score : 920,
        action: {
            type: "shell.command.run",
            command: normalizedTerm,
        },
    };
}

function normalizeRecentExternalCommands(recentExternalCommands) {
    const source = [];

    if (Array.isArray(recentExternalCommands)) {
        for (let index = 0; index < recentExternalCommands.length; index += 1)
            source.push(recentExternalCommands[index]);
    } else if (
        recentExternalCommands &&
        typeof recentExternalCommands === "object" &&
        typeof recentExternalCommands.length === "number"
    ) {
        for (let index = 0; index < recentExternalCommands.length; index += 1)
            source.push(recentExternalCommands[index]);
    } else {
        return [];
    }

    const normalized = [];
    const byCommand = {};

    for (let index = 0; index < source.length; index += 1) {
        const commandText = String(source[index] || "").trim();
        if (!commandText) continue;
        const key = lowercase(commandText);
        if (byCommand[key]) continue;
        byCommand[key] = true;
        normalized.push(commandText);
    }

    return normalized;
}

function searchRecentExternalCommands(recentExternalCommands, query, limit) {
    const commands = normalizeRecentExternalCommands(recentExternalCommands);
    if (commands.length === 0) return [];

    const normalizedQuery = lowercase(query).trim();
    const normalizedLimit = normalizeMaxResults(limit);
    const items = [];

    for (let index = 0; index < commands.length && items.length < normalizedLimit; index += 1) {
        const commandText = commands[index];
        const normalizedCommand = lowercase(commandText);

        if (normalizedQuery && normalizedCommand.indexOf(normalizedQuery) < 0) continue;

        let score = 1080 - index * 4;
        if (!normalizedQuery) score += 60;
        else if (normalizedCommand === normalizedQuery) score += 240;
        else if (normalizedCommand.indexOf(normalizedQuery) === 0) score += 150;

        items.push(
            createExternalCommandCandidate(commandText, {
                subtitle: "Recent command",
                score: score,
            }),
        );
    }

    return items;
}

function normalizeCatalogTerm(commandTerm) {
    const split = splitFirstToken(commandTerm);
    return String(split.token || "").trim();
}

function searchExternalCommandCatalog(commandCatalogAdapter, commandTerm) {
    const term = normalizeCatalogTerm(commandTerm);
    if (!commandCatalogAdapter || typeof commandCatalogAdapter !== "object") return [];

    let rawItems = [];

    if (typeof commandCatalogAdapter.searchTerm === "function")
        rawItems = commandCatalogAdapter.searchTerm(term);
    else if (typeof commandCatalogAdapter.search === "function")
        rawItems = commandCatalogAdapter.search({
            payload: {
                query: term,
            },
        });

    return Array.isArray(rawItems) ? rawItems : [];
}

function createWebSearchCandidate(query) {
    const normalizedQuery = String(query || "").trim();
    if (!normalizedQuery) return null;

    const encodedQuery = encodeURIComponent(normalizedQuery);
    const url = "https://duckduckgo.com/?q=" + encodedQuery;

    return {
        id: "web:" + encodedQuery,
        title: 'Search web for "' + normalizedQuery + '"',
        subtitle: url,
        detail: "Open in default browser",
        iconName: "internet-web-browser",
        provider: "web",
        score: 780,
        action: {
            type: "shell.command.run",
            command: 'xdg-open "' + url + '"',
        },
    };
}

function dedupeByIdAndCommand(items) {
    if (!Array.isArray(items)) return [];

    const normalized = [];
    const byId = {};
    const byCommand = {};

    for (let index = 0; index < items.length; index += 1) {
        const item = items[index];
        if (!item || typeof item !== "object") continue;
        if (typeof item.id !== "string" || !item.id) continue;

        const command =
            item.action && typeof item.action.command === "string"
                ? lowercase(item.action.command)
                : "";

        if (byId[item.id]) continue;
        if (command && byCommand[command]) continue;

        byId[item.id] = true;
        if (command) byCommand[command] = true;
        normalized.push(item);
    }

    return normalized;
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

function normalizeProviderRouteKeys(rawRouteKeys) {
    const source = [];
    if (Array.isArray(rawRouteKeys)) {
        for (let index = 0; index < rawRouteKeys.length; index += 1)
            source.push(rawRouteKeys[index]);
    } else if (typeof rawRouteKeys === "string") {
        source.push(rawRouteKeys);
    }

    const routeKeys = [];
    const byKey = {};

    for (let index = 0; index < source.length; index += 1) {
        const routeKey = normalizeRouteKey(source[index]);
        if (!routeKey) continue;
        if (byKey[routeKey]) continue;
        byKey[routeKey] = true;
        routeKeys.push(routeKey);
    }

    return routeKeys;
}

function normalizeProviderSpec(provider, fallbackId, fallbackOrder) {
    if (!provider || typeof provider !== "object") return null;
    if (typeof provider.search !== "function") return null;

    const id = String(provider.id || fallbackId || "").trim();
    if (!id) return null;

    const parsedOrder = Number(provider.order);
    const order = Number.isFinite(parsedOrder) ? parsedOrder : Number(fallbackOrder);
    const kind = provider.kind === "async" ? "async" : "sync";
    const routeKeys = normalizeProviderRouteKeys(provider.routeKeys);

    return {
        id: id,
        order: order,
        kind: kind,
        routeKeys: routeKeys,
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

function providerMatchesRoute(provider, routeKey) {
    const normalizedRouteKey = normalizeRouteKey(routeKey);
    const providerRouteKeys =
        provider && Array.isArray(provider.routeKeys) ? provider.routeKeys : [];
    if (providerRouteKeys.length === 0) return normalizedRouteKey === "default";

    for (let index = 0; index < providerRouteKeys.length; index += 1) {
        if (normalizeRouteKey(providerRouteKeys[index]) === normalizedRouteKey) return true;
    }

    return false;
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
        const parsedPinOrder = Number(item.pinOrder);
        if (item.pinned !== undefined) normalizedItem.pinned = item.pinned === true;
        if (Number.isInteger(parsedPinOrder)) normalizedItem.pinOrder = parsedPinOrder;

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
            routeKeys: ["default", "cmd"],
            modes: {
                command: true,
            },
            search: function (context) {
                const candidate = createExternalCommandCandidate(context.commandTerm);
                return candidate ? [candidate] : [];
            },
        },
        {
            id: "commands.recent",
            order: 15,
            kind: "sync",
            routeKeys: ["cmd"],
            modes: {
                command: true,
            },
            search: function (context) {
                return searchRecentExternalCommands(
                    context.recentExternalCommands,
                    context.commandTerm,
                    20,
                );
            },
        },
        {
            id: "commands.command_catalog",
            order: 18,
            kind: "sync",
            routeKeys: ["cmd"],
            modes: {
                command: true,
            },
            search: function (context) {
                return searchExternalCommandCatalog(
                    context.commandCatalogAdapter,
                    context.commandTerm,
                );
            },
        },
        {
            id: "commands.catalog",
            order: 20,
            kind: "sync",
            routeKeys: ["default"],
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
            routeKeys: ["default", "calculator"],
            modes: {
                query: true,
            },
            search: function (context) {
                const item = createCalculatorResult(context.queryTerm);
                return item ? [item] : [];
            },
        },
        {
            id: "apps.catalog",
            order: 20,
            kind: "sync",
            routeKeys: ["default", "apps"],
            modes: {
                query: true,
            },
            search: function (context) {
                if (
                    context.appSearchAdapter &&
                    typeof context.appSearchAdapter.search === "function"
                ) {
                    const appItems = context.appSearchAdapter.search(context.queryCommand);
                    return Array.isArray(appItems) ? appItems : [];
                }

                return searchFallbackApps(context.queryCommand);
            },
        },
        {
            id: "web.search",
            order: 30,
            kind: "sync",
            routeKeys: ["web"],
            modes: {
                query: true,
            },
            search: function (context) {
                const item = createWebSearchCandidate(context.queryTerm);
                return item ? [item] : [];
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
        if (!providerMatchesRoute(provider, searchContext.routeKey)) continue;

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
            const commandCatalogAdapter = config.commandCatalogAdapter;
            const recentExternalCommands = config.recentExternalCommands;
            const includeDefaultProviders = config.includeDefaultProviders !== false;
            const customProviderSpecs = normalizeProviderSpecs(config.providers, 100);
            const onAsyncProviderResult =
                typeof config.onAsyncProviderResult === "function"
                    ? config.onAsyncProviderResult
                    : null;

            const projection = resolveSearchProjection(query, commandPrefix);
            const mode = projection.mode;
            const routeKey = projection.routeKey;
            const commandTerm = projection.commandTerm;
            const queryTerm = projection.queryTerm;

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
                routeKey: routeKey,
                query: query,
                queryTerm: queryTerm,
                commandTerm: commandTerm,
                generation: commandGeneration(command),
                command: command,
                queryCommand: createQueryCommand(command, queryTerm),
                commandPrefix: commandPrefix,
                commandSpecs: commandSpecs,
                pinnedCommandIds: pinnedCommandIds,
                appSearchAdapter: appSearchAdapter,
                commandCatalogAdapter: commandCatalogAdapter,
                recentExternalCommands: recentExternalCommands,
            };

            const merged = collectProviderItems(
                providerSpecs,
                searchContext,
                onAsyncProviderResult,
            );
            const deduped = dedupeByIdAndCommand(merged);
            sortLauncherItems(deduped);
            return limitItems(deduped, maxResults);
        },
    };

    return adapter;
}

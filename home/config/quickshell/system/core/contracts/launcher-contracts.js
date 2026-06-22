function copyItemArray(items) {
    const next = [];

    for (let index = 0; index < items.length; index += 1) next.push(items[index]);

    return next;
}

function copyStringArray(items) {
    if (!Array.isArray(items)) return [];

    const next = [];

    for (let index = 0; index < items.length; index += 1) next.push(String(items[index]));

    return next;
}

function validateLauncherSearchCommand(command) {
    if (!command || typeof command !== "object")
        throw new Error("Launcher command must be an object");
    if (command.type !== "launcher.run_search")
        throw new Error("Launcher command type must be launcher.run_search");
    if (!command.payload || typeof command.payload.query !== "string")
        throw new Error("Launcher command payload.query must be a string");
    if (!command.meta || typeof command.meta.generation !== "number")
        throw new Error("Launcher command meta.generation must be a number");
    if (command.meta.requestId !== undefined && typeof command.meta.requestId !== "string")
        throw new Error("Launcher command meta.requestId must be a string");

    return command;
}

function createLauncherSearchCommand(query, generation, requestId) {
    return validateLauncherSearchCommand({
        type: "launcher.run_search",
        payload: {
            query: String(query),
        },
        meta: {
            generation: Number(generation),
            requestId: requestId === undefined ? undefined : String(requestId),
        },
    });
}

function validateLauncherItem(item) {
    if (!item || typeof item !== "object") throw new Error("Launcher item must be an object");
    if (typeof item.id !== "string") throw new Error("Launcher item id must be a string");
    if (typeof item.title !== "string") throw new Error("Launcher item title must be a string");
    if (typeof item.provider !== "string")
        throw new Error("Launcher item provider must be a string");
    if (!item.action || typeof item.action.type !== "string")
        throw new Error("Launcher item action.type must be a string");
    if (item.action.targetId !== undefined && typeof item.action.targetId !== "string")
        throw new Error("Launcher item action.targetId must be a string");
    if (item.action.command !== undefined && typeof item.action.command !== "string")
        throw new Error("Launcher item action.command must be a string");
    if (item.action.args !== undefined && !Array.isArray(item.action.args))
        throw new Error("Launcher item action.args must be an array");

    return item;
}

function createLauncherItem(fields) {
    const item = {
        id: String(fields.id),
        title: String(fields.title),
        subtitle: fields.subtitle === undefined ? "" : String(fields.subtitle),
        provider: String(fields.provider),
        score: fields.score === undefined ? 0 : Number(fields.score),
        action: {
            type: String(fields.action.type),
            targetId:
                fields.action.targetId === undefined ? undefined : String(fields.action.targetId),
            command:
                fields.action.command === undefined ? undefined : String(fields.action.command),
            args: copyStringArray(fields.action.args),
        },
    };

    return validateLauncherItem(item);
}

function createLauncherResultList(items, generation) {
    const validatedItems = [];

    for (let index = 0; index < items.length; index += 1)
        validatedItems.push(validateLauncherItem(items[index]));

    return {
        kind: "launcher.result_list",
        items: copyItemArray(validatedItems),
        generation: Number(generation),
    };
}

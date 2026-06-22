function cloneStringArray(values) {
    const next = [];

    if (!Array.isArray(values)) return next;

    for (let index = 0; index < values.length; index += 1) next.push(String(values[index]));

    return next;
}

function validateShellIpcMeta(meta) {
    if (meta === undefined) return {};
    if (!meta || typeof meta !== "object")
        throw new Error("Shell IPC command meta must be an object");

    const nextMeta = {};

    if (meta.requestId !== undefined) nextMeta.requestId = String(meta.requestId);
    if (meta.source !== undefined) nextMeta.source = String(meta.source);

    return nextMeta;
}

function validateShellIpcCommand(command) {
    if (!command || typeof command !== "object")
        throw new Error("Shell IPC command must be an object");
    if (command.type !== "shell.ipc_command")
        throw new Error("Shell IPC command type must be shell.ipc_command");
    if (!command.payload || typeof command.payload !== "object")
        throw new Error("Shell IPC command payload must be an object");
    if (typeof command.payload.name !== "string" || command.payload.name.length === 0)
        throw new Error("Shell IPC command payload.name must be a non-empty string");
    if (!Array.isArray(command.payload.args))
        throw new Error("Shell IPC command payload.args must be an array");

    const normalizedArgs = cloneStringArray(command.payload.args);
    const normalizedMeta = validateShellIpcMeta(command.meta);

    return {
        type: "shell.ipc_command",
        payload: {
            name: command.payload.name,
            args: normalizedArgs,
        },
        meta: normalizedMeta,
    };
}

function createShellIpcCommand(commandName, args, meta) {
    return validateShellIpcCommand({
        type: "shell.ipc_command",
        payload: {
            name: String(commandName),
            args: cloneStringArray(args),
        },
        meta: meta === undefined ? {} : meta,
    });
}

function validateShellIpcCommandSpec(spec) {
    if (!spec || typeof spec !== "object")
        throw new Error("Shell IPC command spec must be an object");
    if (typeof spec.name !== "string" || spec.name.length === 0)
        throw new Error("Shell IPC command spec.name must be a non-empty string");

    const minArgs = spec.minArgs === undefined ? 0 : Number(spec.minArgs);
    const maxArgs = spec.maxArgs === undefined ? minArgs : Number(spec.maxArgs);

    if (!Number.isInteger(minArgs) || minArgs < 0)
        throw new Error("Shell IPC command spec.minArgs must be a non-negative integer");
    if (!Number.isInteger(maxArgs) || maxArgs < minArgs)
        throw new Error("Shell IPC command spec.maxArgs must be an integer >= minArgs");

    return {
        name: spec.name,
        summary: spec.summary === undefined ? "" : String(spec.summary),
        usage: spec.usage === undefined ? spec.name : String(spec.usage),
        minArgs: minArgs,
        maxArgs: maxArgs,
    };
}

function createShellIpcCommandSpec(fields) {
    return validateShellIpcCommandSpec(fields || {});
}

function normalizeShellIpcCommandSpecs(specs) {
    if (!Array.isArray(specs)) throw new Error("Shell IPC command specs must be an array");

    const normalized = [];
    const seen = {};

    for (let index = 0; index < specs.length; index += 1) {
        const spec = validateShellIpcCommandSpec(specs[index]);
        if (seen[spec.name]) throw new Error("Duplicate shell IPC command spec: " + spec.name);
        seen[spec.name] = true;
        normalized.push(spec);
    }

    return normalized;
}

function createShellIpcCommandCatalog(specs) {
    const normalized = normalizeShellIpcCommandSpecs(specs || []);
    const commands = [];

    for (let index = 0; index < normalized.length; index += 1) commands.push(normalized[index]);

    commands.sort((left, right) => left.name.localeCompare(right.name));

    return {
        kind: "shell.ipc_command_catalog",
        protocolVersion: 1,
        commands: commands,
    };
}

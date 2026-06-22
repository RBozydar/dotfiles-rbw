function ensureArray(value) {
    return Array.isArray(value) ? value : [];
}

function copyArgs(args) {
    const source = ensureArray(args);
    const next = [];

    for (let index = 0; index < source.length; index += 1) next.push(String(source[index]));

    return next;
}

function findCommandSpec(specs, commandName) {
    for (let index = 0; index < specs.length; index += 1) {
        if (specs[index].name === commandName) return specs[index];
    }

    return null;
}

function listShellIpcCommands(deps, commandSpecs) {
    const normalizedSpecs = deps.normalizeShellIpcCommandSpecs(commandSpecs || []);
    return deps.createShellIpcCommandCatalog(normalizedSpecs);
}

function dispatchShellIpcCommand(deps, commandSpecs, commandName, rawArgs, meta) {
    const normalizedSpecs = deps.normalizeShellIpcCommandSpecs(commandSpecs || []);
    const command = deps.createShellIpcCommand(commandName, copyArgs(rawArgs), meta || {});
    const spec = findCommandSpec(normalizedSpecs, command.payload.name);

    if (!spec) {
        return deps.outcomes.rejected({
            code: "shell.ipc.unknown_command",
            reason: "Unknown shell IPC command: " + command.payload.name,
            targetId: command.payload.name,
        });
    }

    const argumentCount = command.payload.args.length;
    if (argumentCount < spec.minArgs || argumentCount > spec.maxArgs) {
        return deps.outcomes.rejected({
            code: "shell.ipc.invalid_args",
            reason:
                "Expected " +
                String(spec.minArgs) +
                "-" +
                String(spec.maxArgs) +
                " args, received " +
                String(argumentCount),
            targetId: command.payload.name,
            meta: {
                usage: spec.usage,
            },
        });
    }

    let outcome = null;
    try {
        outcome = deps.shellCommandPort.execute(
            command.payload.name,
            command.payload.args,
            command.meta,
            spec,
        );
    } catch (error) {
        return deps.outcomes.failed({
            code: "shell.ipc.command_threw",
            reason: error && error.message ? error.message : "Shell IPC handler threw",
            targetId: command.payload.name,
        });
    }

    if (!outcome) {
        return deps.outcomes.rejected({
            code: "shell.ipc.handler_missing",
            reason: "No shell command handler for " + command.payload.name,
            targetId: command.payload.name,
        });
    }

    return deps.validateOperationOutcome(outcome);
}

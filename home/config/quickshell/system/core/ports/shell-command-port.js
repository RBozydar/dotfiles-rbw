function createShellCommandPort(handlersByCommand) {
    const handlers =
        handlersByCommand && typeof handlersByCommand === "object" ? handlersByCommand : {};

    return {
        has: function (commandName) {
            return typeof handlers[commandName] === "function";
        },

        execute: function (commandName, args, meta, spec) {
            const handler = handlers[commandName];
            if (typeof handler !== "function") return null;
            return handler(args, meta, spec);
        },
    };
}

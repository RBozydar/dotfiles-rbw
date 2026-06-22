function normalizeArgv(argv) {
    if (!Array.isArray(argv)) return [];

    const normalized = [];

    for (let index = 0; index < argv.length; index += 1) {
        const value = String(argv[index]);
        if (!value) continue;
        normalized.push(value);
    }

    return normalized;
}

function createCommandExecutionPort(adapter) {
    const handler = adapter && typeof adapter.exec === "function" ? adapter : null;

    return {
        execute: function (argv) {
            if (!handler) return false;

            const normalizedArgv = normalizeArgv(argv);
            if (normalizedArgv.length === 0) return false;

            handler.exec(normalizedArgv);
            return true;
        },
    };
}

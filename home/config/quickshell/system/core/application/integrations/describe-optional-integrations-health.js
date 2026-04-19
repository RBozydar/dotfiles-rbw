function normalizeString(value, fallback) {
    if (value === undefined || value === null)
        return fallback === undefined ? "" : String(fallback);
    return String(value);
}

function normalizeBoolean(value) {
    return value === true;
}

function pushUnique(values, value) {
    const normalized = normalizeString(value, "").trim();
    if (!normalized) return;
    for (let index = 0; index < values.length; index += 1) {
        if (values[index] === normalized) return;
    }
    values.push(normalized);
}

function integrationDefaults() {
    return {
        kind: "adapter.integration.unknown",
        integrationId: "unknown.integration",
        displayName: "Unknown integration",
        enableEnvVar: "",
        searchRootsEnvVar: "",
        catalogEnvVar: "",
        diagnosticsCommand: "",
        refreshCommand: "",
    };
}

function integrationConfig(integrationId) {
    switch (normalizeString(integrationId, "").trim()) {
        case "launcher.emoji":
            return {
                kind: "adapter.search.emoji_catalog",
                integrationId: "launcher.emoji",
                displayName: "Emoji catalog",
                enableEnvVar: "RBW_LAUNCHER_EMOJI_ENABLED",
                searchRootsEnvVar: "",
                catalogEnvVar: "RBW_LAUNCHER_EMOJI_CATALOG_PATH",
                diagnosticsCommand: "launcher.integrations.describe",
                refreshCommand: "",
            };
        case "launcher.clipboard_history":
            return {
                kind: "adapter.search.clipboard_history",
                integrationId: "launcher.clipboard_history",
                displayName: "Clipboard history",
                enableEnvVar: "RBW_LAUNCHER_CLIPBOARD_ENABLED",
                searchRootsEnvVar: "",
                catalogEnvVar: "",
                diagnosticsCommand: "launcher.integrations.describe",
                refreshCommand: "",
            };
        case "launcher.file_search":
            return {
                kind: "adapter.search.file_search",
                integrationId: "launcher.file_search",
                displayName: "File search",
                enableEnvVar: "RBW_LAUNCHER_FILE_SEARCH_ENABLED",
                searchRootsEnvVar: "RBW_LAUNCHER_FILE_SEARCH_ROOTS",
                catalogEnvVar: "",
                diagnosticsCommand: "launcher.integrations.describe",
                refreshCommand: "",
            };
        case "launcher.wallpaper":
            return {
                kind: "adapter.search.wallpaper_catalog",
                integrationId: "launcher.wallpaper",
                displayName: "Wallpaper catalog",
                enableEnvVar: "RBW_LAUNCHER_WALLPAPER_ENABLED",
                searchRootsEnvVar: "RBW_LAUNCHER_WALLPAPER_DIRS",
                catalogEnvVar: "",
                diagnosticsCommand: "wallpaper.describe",
                refreshCommand: "wallpaper.refresh_catalog",
            };
        case "shell.home_assistant":
            return {
                kind: "adapter.integration.home_assistant",
                integrationId: "shell.home_assistant",
                displayName: "Home Assistant",
                enableEnvVar: "RBW_HOME_ASSISTANT_ENABLED",
                searchRootsEnvVar: "",
                catalogEnvVar: "",
                diagnosticsCommand: "homeassistant.describe",
                refreshCommand: "homeassistant.refresh",
            };
        default:
            return integrationDefaults();
    }
}

function normalizeReasonCode(reasonCode, enabled) {
    const normalized = normalizeString(reasonCode, "").trim();
    if (normalized) return normalized;
    if (!enabled) return "integration_disabled";
    return "unknown";
}

function statusFromState(enabled, ready, degraded) {
    if (!enabled) return "disabled";
    if (ready && !degraded) return "ready";
    if (degraded) return "degraded";
    return "initializing";
}

function severityFromStatus(status) {
    if (status === "ready") return "ok";
    if (status === "disabled") return "info";
    if (status === "initializing") return "warn";
    return "error";
}

function createHint(code, message, action, command, severity) {
    return {
        code: normalizeString(code, "").trim(),
        message: normalizeString(message, "").trim(),
        action: normalizeString(action, "").trim(),
        command: normalizeString(command, "").trim(),
        severity: normalizeString(severity, "warn").trim(),
    };
}

function appendHint(hints, nextHint) {
    if (!nextHint || !nextHint.code) return;
    for (let index = 0; index < hints.length; index += 1) {
        if (hints[index].code === nextHint.code) return;
    }
    hints.push(nextHint);
}

function collectDependencyCommands(diagnostic) {
    const commands = [];

    const lastError = normalizeString(diagnostic.lastError, "");
    const missingMatch = /missing required commands:\s*(.+)$/i.exec(lastError);
    if (missingMatch && missingMatch[1]) {
        const parsed = missingMatch[1].split(",");
        for (let index = 0; index < parsed.length; index += 1) pushUnique(commands, parsed[index]);
        if (commands.length > 0) return commands;
    }

    pushUnique(commands, diagnostic.commandPath);
    pushUnique(commands, diagnostic.applyCommandPath);
    return commands;
}

function createHintsForDiagnostic(diagnostic, config) {
    const hints = [];
    const status = diagnostic.status;
    const reasonCode = diagnostic.reasonCode;

    if (!diagnostic.enabled && config.enableEnvVar) {
        appendHint(
            hints,
            createHint(
                "enable_integration",
                config.displayName + " is disabled",
                "Set " + config.enableEnvVar + "=1 and restart Quickshell.",
                "",
                "info",
            ),
        );
    }

    if (reasonCode === "dependency_missing") {
        const commands = collectDependencyCommands(diagnostic);
        const commandText =
            commands.length > 0 ? commands.join(", ") : "required integration dependencies";
        appendHint(
            hints,
            createHint(
                "install_dependencies",
                "Missing dependencies for " + config.displayName + ": " + commandText,
                "Install the missing dependencies and ensure they are on PATH.",
                "",
                "error",
            ),
        );
    }

    if (reasonCode === "search_root_missing" && config.searchRootsEnvVar) {
        appendHint(
            hints,
            createHint(
                "set_search_roots",
                config.displayName + " has no configured search roots",
                "Set " +
                    config.searchRootsEnvVar +
                    " to one or more existing directories and restart Quickshell.",
                "",
                "warn",
            ),
        );
    }

    if (reasonCode === "catalog_missing" && config.catalogEnvVar) {
        appendHint(
            hints,
            createHint(
                "set_catalog_path",
                config.displayName + " catalog file is missing",
                "Set " + config.catalogEnvVar + " to a valid catalog file path.",
                "",
                "warn",
            ),
        );
    }

    if (reasonCode === "adapter_unavailable" || reasonCode === "bridge_unavailable") {
        appendHint(
            hints,
            createHint(
                "investigate_wiring",
                config.displayName + " adapter wiring is unavailable",
                "Verify adapter and bridge composition in SystemShell and restart Quickshell.",
                "",
                "error",
            ),
        );
    }

    if (status === "initializing") {
        appendHint(
            hints,
            createHint(
                "wait_for_initialization",
                config.displayName + " is still initializing",
                "Wait a few seconds and re-run diagnostics.",
                "",
                "warn",
            ),
        );
    }

    if (!diagnostic.ready && config.refreshCommand) {
        appendHint(
            hints,
            createHint(
                "run_refresh",
                "Queue a refresh for " + config.displayName,
                "Run the refresh command and then re-check diagnostics.",
                config.refreshCommand,
                "warn",
            ),
        );
    }

    if (!diagnostic.ready && config.diagnosticsCommand) {
        appendHint(
            hints,
            createHint(
                "run_diagnostics",
                "Check " + config.displayName + " diagnostics",
                "Run diagnostics to confirm readiness and reason codes.",
                config.diagnosticsCommand,
                "info",
            ),
        );
    }

    if (hints.length === 0 && normalizeString(diagnostic.lastError, "").trim()) {
        appendHint(
            hints,
            createHint(
                "inspect_last_error",
                config.displayName + " reported an error",
                normalizeString(diagnostic.lastError, "").trim(),
                "",
                status === "degraded" ? "error" : "warn",
            ),
        );
    }

    return hints;
}

function normalizeIntegrationDiagnostic(rawDiagnostic) {
    const source = rawDiagnostic && typeof rawDiagnostic === "object" ? rawDiagnostic : {};
    const rawIntegrationId = normalizeString(source.integrationId, "").trim();
    const config = integrationConfig(rawIntegrationId);
    const integrationId = rawIntegrationId || config.integrationId;
    const enabled = normalizeBoolean(source.enabled);
    const ready = normalizeBoolean(source.ready);
    const degraded = normalizeBoolean(source.degraded);
    const available = normalizeBoolean(source.available);
    const reasonCode = normalizeReasonCode(source.reasonCode, enabled);
    const status = statusFromState(enabled, ready, degraded);
    const hints = createHintsForDiagnostic(
        {
            integrationId: integrationId,
            commandPath: source.commandPath,
            applyCommandPath: source.applyCommandPath,
            enabled: enabled,
            available: available,
            ready: ready,
            degraded: degraded,
            reasonCode: reasonCode,
            status: status,
            lastError: normalizeString(source.lastError, ""),
        },
        {
            displayName: config.displayName,
            enableEnvVar: config.enableEnvVar,
            searchRootsEnvVar: config.searchRootsEnvVar,
            catalogEnvVar: config.catalogEnvVar,
            diagnosticsCommand: config.diagnosticsCommand,
            refreshCommand: config.refreshCommand,
        },
    );

    return {
        integrationId: integrationId,
        kind: normalizeString(source.kind, config.kind),
        displayName: config.displayName,
        enabled: enabled,
        available: available,
        ready: ready,
        degraded: degraded,
        status: status,
        severity: severityFromStatus(status),
        reasonCode: reasonCode,
        lastUpdatedAt: normalizeString(source.lastUpdatedAt, ""),
        lastError: normalizeString(source.lastError, ""),
        diagnosticsCommand: config.diagnosticsCommand,
        refreshCommand: config.refreshCommand,
        hintCount: hints.length,
        hints: hints,
    };
}

function countByStatus(integrations) {
    const counts = {
        total: integrations.length,
        ready: 0,
        disabled: 0,
        degraded: 0,
        initializing: 0,
    };

    for (let index = 0; index < integrations.length; index += 1) {
        const status = normalizeString(integrations[index].status, "");
        if (status === "ready") counts.ready += 1;
        else if (status === "disabled") counts.disabled += 1;
        else if (status === "degraded") counts.degraded += 1;
        else counts.initializing += 1;
    }

    return counts;
}

function overallStatusFromCounts(counts) {
    if (counts.total === 0) return "no_integrations";
    if (counts.degraded > 0) return "degraded";
    if (counts.initializing > 0) return "initializing";
    if (counts.ready === counts.total) return "ready";
    if (counts.disabled === counts.total) return "disabled";
    if (counts.ready > 0 && counts.ready + counts.disabled === counts.total)
        return "ready_with_disabled";
    return "mixed";
}

function collectTopRecommendations(integrations) {
    const recommendations = [];

    for (let index = 0; index < integrations.length; index += 1) {
        const integration = integrations[index];
        if (integration.status === "ready") continue;
        if (!Array.isArray(integration.hints) || integration.hints.length === 0) continue;

        const topHint = integration.hints[0];
        recommendations.push({
            integrationId: integration.integrationId,
            displayName: integration.displayName,
            status: integration.status,
            severity: topHint.severity,
            code: topHint.code,
            message: topHint.message,
            action: topHint.action,
            command: topHint.command,
        });
    }

    return recommendations;
}

function createOptionalIntegrationsHealthSnapshot(input) {
    const source = input && typeof input === "object" ? input : {};
    const rawIntegrations = Array.isArray(source.integrations) ? source.integrations : [];
    const normalized = [];

    for (let index = 0; index < rawIntegrations.length; index += 1)
        normalized.push(normalizeIntegrationDiagnostic(rawIntegrations[index]));

    normalized.sort((left, right) => {
        const leftId = normalizeString(left.integrationId, "");
        const rightId = normalizeString(right.integrationId, "");
        if (leftId < rightId) return -1;
        if (leftId > rightId) return 1;
        return 0;
    });

    const counts = countByStatus(normalized);
    const generatedAt = normalizeString(source.generatedAt, "").trim() || new Date().toISOString();
    const recommendations = collectTopRecommendations(normalized);

    return {
        kind: "shell.optional_integrations.health",
        generatedAt: generatedAt,
        overallStatus: overallStatusFromCounts(counts),
        counts: counts,
        recommendationCount: recommendations.length,
        recommendations: recommendations,
        integrations: normalized,
    };
}

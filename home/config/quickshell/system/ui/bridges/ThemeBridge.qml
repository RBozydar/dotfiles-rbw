import "../../adapters/theming/matugen-theme-provider.js" as MatugenThemeProviderAdapters
import "../../adapters/theming/static-theme-provider.js" as StaticThemeProviderAdapters
import "../../core/contracts/operation-outcome.js" as OperationOutcomes
import "../../core/contracts/theme-contracts.js" as ThemeContracts
import "../../core/ports/theme-provider-port.js" as ThemeProviderPort
import QtQml
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property string providerId: "static"
    property string fallbackProviderId: "static"
    property string mode: "dark"
    property string variant: "tonal-spot"
    property string sourceKind: "static"
    property string sourceValue: ""
    property string matugenSchemePath: ""
    property string matugenCommandPath: "matugen"
    property string fallbackWallpaperPath: ""

    property string matugenLastError: ""
    property string matugenLastRequestKey: ""
    property string matugenActiveRequestKey: ""
    property string matugenLastStdoutText: ""
    property string matugenLastStderrText: ""
    property string matugenLastUpdatedAt: ""
    property bool matugenGenerating: false
    property var matugenLastParsedScheme: null
    property var matugenActiveCommand: []
    property var matugenQueuedCommand: []
    property string matugenQueuedRequestKey: ""

    property var staticProvider: StaticThemeProviderAdapters.createStaticThemeProvider({
        providerId: "static"
    })
    property var matugenProvider: root.createMatugenProvider()
    readonly property var providerCatalog: ({
            "static": root.staticProvider,
            "matugen": root.matugenProvider
        })

    property var scheme: ThemeContracts.createThemeSchemeDocument({
        provider: "static",
        mode: root.mode
    })
    property var lastOutcome: OperationOutcomes.applied({
        code: "theme.scheme.initialized",
        targetId: "theme"
    })
    property string phase: "ready"
    property string error: ""

    function nowIsoString(): string {
        return new Date().toISOString();
    }

    function normalizeThemeSourceKind(sourceKind): string {
        const normalized = String(sourceKind === undefined ? "static" : sourceKind).trim().toLowerCase();

        if (normalized !== "wallpaper" && normalized !== "color" && normalized !== "file" && normalized !== "generated")
            return "static";

        return normalized;
    }

    function normalizeMatugenVariantType(variant): string {
        const normalized = String(variant === undefined ? "tonal-spot" : variant).trim().toLowerCase();

        if (normalized.startsWith("scheme-"))
            return normalized;

        switch (normalized) {
        case "content":
            return "scheme-content";
        case "expressive":
            return "scheme-expressive";
        case "fidelity":
            return "scheme-fidelity";
        case "fruit-salad":
            return "scheme-fruit-salad";
        case "monochrome":
            return "scheme-monochrome";
        case "neutral":
            return "scheme-neutral";
        case "rainbow":
            return "scheme-rainbow";
        case "vibrant":
            return "scheme-vibrant";
        default:
            return "scheme-tonal-spot";
        }
    }

    function normalizeThemeMode(mode): string {
        const normalized = String(mode === undefined ? "dark" : mode).trim().toLowerCase();
        return normalized === "light" ? "light" : "dark";
    }

    function parseJsonText(text): var {
        const normalized = String(text === undefined || text === null ? "" : text).trim();
        if (!normalized)
            return null;

        try {
            return JSON.parse(normalized);
        } catch (error) {
            return null;
        }
    }

    function normalizeColorSource(sourceValue): string {
        const normalized = String(sourceValue === undefined ? "" : sourceValue).trim();
        if (!normalized)
            return "";
        if (/^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(normalized))
            return normalized;
        if (/^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(normalized))
            return "#" + normalized;
        return "";
    }

    function resolveMatugenRequestSource(request): var {
        const normalizedRequest = request && typeof request === "object" ? request : {};
        const normalizedKind = normalizeThemeSourceKind(normalizedRequest.sourceKind);
        const explicitValue = String(normalizedRequest.sourceValue === undefined ? "" : normalizedRequest.sourceValue).trim();
        const fallbackWallpaper = String(root.fallbackWallpaperPath || "").trim();
        const fallbackWallpaperPath = fallbackWallpaper.startsWith("/") ? fallbackWallpaper : "";

        if (normalizedKind === "color")
            return {
                kind: "color",
                value: normalizeColorSource(explicitValue)
            };

        if (explicitValue)
            return {
                kind: normalizedKind,
                value: explicitValue
            };

        if (fallbackWallpaperPath) {
            return {
                kind: normalizedKind === "file" ? "file" : "wallpaper",
                value: fallbackWallpaperPath
            };
        }

        return {
            kind: normalizedKind,
            value: explicitValue
        };
    }

    function createGenerationRequest(reasonCode, resolvedProviderId) {
        const requestMeta = {
            source: String(reasonCode || "theme.bridge.regenerate")
        };
        let requestSourceKind = root.sourceKind;
        let requestSourceValue = root.sourceValue;

        if (resolvedProviderId === "matugen") {
            const resolvedSource = resolveMatugenRequestSource({
                sourceKind: root.sourceKind,
                sourceValue: root.sourceValue
            });
            requestSourceKind = resolvedSource.kind;
            requestSourceValue = resolvedSource.value;
            requestMeta.resolvedSourceKind = resolvedSource.kind;
            requestMeta.resolvedSourceValue = resolvedSource.value;
        }

        return ThemeContracts.createThemeGenerationRequest({
            provider: resolvedProviderId,
            mode: root.mode,
            variant: root.variant,
            sourceKind: requestSourceKind,
            sourceValue: requestSourceValue,
            meta: requestMeta
        });
    }

    function matugenCommandForRequest(request): var {
        const normalizedRequest = request && typeof request === "object" ? request : {};
        const commandPath = String(root.matugenCommandPath || "").trim();
        if (!commandPath)
            return [];

        const modeValue = normalizeThemeMode(normalizedRequest.mode);
        const variantType = normalizeMatugenVariantType(normalizedRequest.variant);
        const resolvedSource = resolveMatugenRequestSource(normalizedRequest);
        const sourceKind = resolvedSource.kind;
        const sourceValue = resolvedSource.value;

        if (sourceKind === "color") {
            const colorValue = normalizeColorSource(sourceValue);
            if (!colorValue)
                return [];
            return [commandPath, "color", "hex", colorValue, "--mode", modeValue, "--type", variantType, "--json", "hex", "--dry-run", "--quiet",];
        }

        if (!sourceValue || !sourceValue.startsWith("/"))
            return [];

        const sourcePath = String(sourceValue);
        const looksLikeJsonFile = sourceKind === "file" && sourcePath.toLowerCase().endsWith(".json");

        const command = [commandPath, looksLikeJsonFile ? "json" : "image", sourcePath, "--mode", modeValue, "--type", variantType, "--json", "hex", "--dry-run", "--quiet",];

        if (!looksLikeJsonFile)
            command.push("--prefer", "darkness");

        return command;
    }

    function matugenRequestKey(request): string {
        const command = matugenCommandForRequest(request);
        if (!Array.isArray(command) || command.length <= 0)
            return "";
        return command.join("\u001f");
    }

    function readMatugenSchemeFromPath(): var {
        const schemePath = String(root.matugenSchemePath || "").trim();
        if (!schemePath)
            return null;

        const sourceText = String(matugenSchemeFile.text ?? "").trim();
        if (!sourceText)
            return null;

        return parseJsonText(sourceText);
    }

    function readMatugenCachedScheme(request): var {
        const requestKey = matugenRequestKey(request);
        if (!requestKey || requestKey !== root.matugenLastRequestKey)
            return null;

        return root.matugenLastParsedScheme;
    }

    function readMatugenScheme(request): var {
        const fromFile = readMatugenSchemeFromPath();
        if (fromFile)
            return fromFile;

        return readMatugenCachedScheme(request);
    }

    function queueMatugenGeneration(request): bool {
        const command = matugenCommandForRequest(request);
        if (!Array.isArray(command) || command.length <= 0)
            return false;

        const requestKey = command.join("\u001f");
        if (requestKey === root.matugenLastRequestKey && root.matugenLastParsedScheme)
            return true;

        if (matugenRunner.running) {
            if (requestKey !== root.matugenActiveRequestKey) {
                root.matugenQueuedCommand = command;
                root.matugenQueuedRequestKey = requestKey;
            }
            return true;
        }

        root.matugenActiveCommand = command;
        root.matugenActiveRequestKey = requestKey;
        root.matugenQueuedCommand = [];
        root.matugenQueuedRequestKey = "";
        root.matugenGenerating = true;
        matugenRunner.running = true;
        return true;
    }

    function generateMatugenScheme(request): var {
        const existing = readMatugenScheme(request);
        if (existing)
            return existing;

        queueMatugenGeneration(request);
        return readMatugenScheme(request);
    }

    function startQueuedMatugenRunIfNeeded(): bool {
        if (!Array.isArray(root.matugenQueuedCommand) || root.matugenQueuedCommand.length <= 0 || !root.matugenQueuedRequestKey) {
            root.matugenQueuedCommand = [];
            root.matugenQueuedRequestKey = "";
            return false;
        }

        if (root.matugenQueuedRequestKey === root.matugenLastRequestKey) {
            root.matugenQueuedCommand = [];
            root.matugenQueuedRequestKey = "";
            return false;
        }

        root.matugenActiveCommand = root.matugenQueuedCommand;
        root.matugenActiveRequestKey = root.matugenQueuedRequestKey;
        root.matugenQueuedCommand = [];
        root.matugenQueuedRequestKey = "";
        root.matugenGenerating = true;
        matugenRunner.running = true;
        return true;
    }

    function describeMatugenRuntime(): var {
        const hasSchemePath = String(root.matugenSchemePath || "").trim().length > 0;
        const sourceMode = hasSchemePath ? "file_or_runtime" : "runtime";
        const ready = hasSchemePath || String(root.matugenCommandPath || "").trim().length > 0 || root.matugenLastParsedScheme !== null;

        return {
            ready: ready,
            mode: sourceMode,
            commandPath: String(root.matugenCommandPath || ""),
            generating: Boolean(root.matugenGenerating || matugenRunner.running),
            activeRequestKey: String(root.matugenActiveRequestKey || ""),
            lastRequestKey: String(root.matugenLastRequestKey || ""),
            lastUpdatedAt: String(root.matugenLastUpdatedAt || ""),
            lastError: String(root.matugenLastError || ""),
            lastStderr: String(root.matugenLastStderrText || ""),
            schemePath: String(root.matugenSchemePath || ""),
            fallbackWallpaperPath: String(root.fallbackWallpaperPath || "")
        };
    }

    function createMatugenProvider() {
        return MatugenThemeProviderAdapters.createMatugenThemeProvider({
            providerId: "matugen",
            schemePath: root.matugenSchemePath,
            readScheme: request => root.readMatugenScheme(request),
            generateScheme: request => root.generateMatugenScheme(request),
            describeRuntime: () => root.describeMatugenRuntime()
        });
    }

    function resolveProvider() {
        return ThemeProviderPort.resolveThemeProvider(root.providerCatalog, root.providerId, root.fallbackProviderId);
    }

    function applyGeneratedScheme(rawScheme, resolvedProviderId, fallbackUsed, reasonCode) {
        const nextScheme = ThemeContracts.validateThemeSchemeDocument(rawScheme);
        root.scheme = nextScheme;
        root.phase = "ready";
        root.error = "";
        root.lastOutcome = OperationOutcomes.applied({
            code: "theme.scheme.generated",
            targetId: "theme",
            meta: {
                provider: resolvedProviderId,
                fallbackUsed: Boolean(fallbackUsed),
                mode: nextScheme.mode,
                variant: nextScheme.variant,
                source: String(reasonCode || "theme.bridge.regenerate")
            }
        });
        return root.lastOutcome;
    }

    function currentSchemeOrFallback() {
        try {
            return ThemeContracts.validateThemeSchemeDocument(root.scheme);
        } catch (error) {
            return ThemeContracts.createThemeSchemeDocument({
                provider: "static",
                mode: root.mode
            });
        }
    }

    function regenerate(reasonCode) {
        try {
            const resolved = resolveProvider();
            if (!resolved.adapter) {
                root.phase = "error";
                root.error = "No theme provider is available";
                root.lastOutcome = OperationOutcomes.failed({
                    code: "theme.provider.unavailable",
                    targetId: "theme",
                    reason: root.error
                });
                return root.lastOutcome;
            }

            const activeRequest = createGenerationRequest(reasonCode, resolved.providerId);
            const activePort = ThemeProviderPort.createThemeProviderPort(resolved.adapter);
            let rawScheme = activePort.generate(activeRequest);
            let fallbackUsed = Boolean(resolved.fallbackUsed);
            let resolvedProviderId = resolved.providerId;

            if (!rawScheme && resolved.providerId !== root.fallbackProviderId) {
                const fallback = ThemeProviderPort.resolveThemeProvider(root.providerCatalog, root.fallbackProviderId, root.fallbackProviderId);
                if (fallback.adapter) {
                    const fallbackRequest = createGenerationRequest(reasonCode, fallback.providerId);
                    const fallbackPort = ThemeProviderPort.createThemeProviderPort(fallback.adapter);
                    rawScheme = fallbackPort.generate(fallbackRequest);
                    resolvedProviderId = fallback.providerId;
                    fallbackUsed = true;
                }
            }

            if (!rawScheme) {
                root.phase = "error";
                root.error = "Theme provider returned no scheme";
                root.lastOutcome = OperationOutcomes.failed({
                    code: "theme.scheme.missing",
                    targetId: "theme",
                    reason: root.error,
                    meta: {
                        provider: resolvedProviderId,
                        source: String(reasonCode || "theme.bridge.regenerate")
                    }
                });
                return root.lastOutcome;
            }

            return applyGeneratedScheme(rawScheme, resolvedProviderId, fallbackUsed, reasonCode);
        } catch (error) {
            root.phase = "error";
            root.error = error && error.message ? String(error.message) : "Theme regeneration failed";
            root.lastOutcome = OperationOutcomes.failed({
                code: "theme.scheme.regeneration_failed",
                targetId: "theme",
                reason: root.error,
                meta: {
                    source: String(reasonCode || "theme.bridge.regenerate")
                }
            });
            return root.lastOutcome;
        }
    }

    function describe() {
        const resolved = resolveProvider();
        return {
            kind: "theme.runtime_snapshot",
            phase: root.phase,
            error: root.error,
            requestedProviderId: root.providerId,
            resolvedProviderId: resolved.providerId,
            fallbackProviderId: root.fallbackProviderId,
            mode: root.mode,
            variant: root.variant,
            sourceKind: root.sourceKind,
            sourceValue: root.sourceValue,
            scheme: currentSchemeOrFallback(),
            providers: ThemeProviderPort.describeThemeProviderCatalog(root.providerCatalog),
            matugenRuntime: describeMatugenRuntime(),
            lastOutcome: root.lastOutcome
        };
    }

    Process {
        id: matugenRunner

        command: root.matugenActiveCommand
        stdout: StdioCollector {
            id: matugenOutput
        }
        stderr: StdioCollector {
            id: matugenErrors
        }

        // qmllint disable signal-handler-parameters
        onExited: {
            root.matugenGenerating = false;
            root.matugenLastUpdatedAt = root.nowIsoString();
            root.matugenLastStderrText = String(matugenErrors.text ?? "").trim();

            const stdoutText = String(matugenOutput.text ?? "").trim();
            if (!stdoutText) {
                root.matugenLastError = root.matugenLastStderrText || "Matugen returned no scheme output";
                root.matugenLastStdoutText = "";
                root.matugenLastParsedScheme = null;
                root.startQueuedMatugenRunIfNeeded();
                if (root.providerId === "matugen" || root.fallbackProviderId === "matugen")
                    Qt.callLater(() => root.regenerate("theme.provider.matugen.generation_failed"));
                return;
            }

            const parsed = root.parseJsonText(stdoutText);
            if (!parsed) {
                root.matugenLastError = "Matugen returned invalid JSON";
                root.matugenLastStdoutText = stdoutText;
                root.matugenLastParsedScheme = null;
                root.startQueuedMatugenRunIfNeeded();
                if (root.providerId === "matugen" || root.fallbackProviderId === "matugen")
                    Qt.callLater(() => root.regenerate("theme.provider.matugen.invalid_json"));
                return;
            }

            root.matugenLastError = "";
            root.matugenLastStdoutText = stdoutText;
            root.matugenLastParsedScheme = parsed;
            root.matugenLastRequestKey = String(root.matugenActiveRequestKey || "");
            root.startQueuedMatugenRunIfNeeded();

            if (root.providerId === "matugen" || root.fallbackProviderId === "matugen")
                Qt.callLater(() => root.regenerate("theme.provider.matugen.generated"));
        }
        // qmllint enable signal-handler-parameters
    }

    FileView {
        id: matugenSchemeFile
        path: root.matugenSchemePath
        blockWrites: true
        watchChanges: true
        onTextChanged: {
            if (root.providerId === "matugen" || root.fallbackProviderId === "matugen")
                Qt.callLater(() => root.regenerate("theme.provider.matugen.scheme_file_changed"));
        }
    }

    Component.onCompleted: {
        root.regenerate("theme.bridge.init");
    }

    onProviderIdChanged: root.regenerate("theme.provider.updated")
    onFallbackProviderIdChanged: root.regenerate("theme.fallback_provider.updated")
    onModeChanged: root.regenerate("theme.mode.updated")
    onVariantChanged: root.regenerate("theme.variant.updated")
    onSourceKindChanged: root.regenerate("theme.source_kind.updated")
    onSourceValueChanged: root.regenerate("theme.source_value.updated")
    onFallbackWallpaperPathChanged: {
        if (root.providerId === "matugen")
            root.regenerate("theme.provider.matugen.wallpaper_fallback_updated");
    }
    onMatugenSchemePathChanged: {
        root.matugenProvider = root.createMatugenProvider();
        root.regenerate("theme.provider.matugen.updated");
    }
    onMatugenCommandPathChanged: root.regenerate("theme.provider.matugen.command_updated")
    onMatugenProviderChanged: root.regenerate("theme.provider.matugen.object_updated")
    onStaticProviderChanged: root.regenerate("theme.provider.static.updated")
}

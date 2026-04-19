import "../../adapters/theming/matugen-theme-provider.js" as MatugenThemeProviderAdapters
import "../../adapters/theming/static-theme-provider.js" as StaticThemeProviderAdapters
import "../../core/contracts/operation-outcome.js" as OperationOutcomes
import "../../core/contracts/theme-contracts.js" as ThemeContracts
import "../../core/ports/theme-provider-port.js" as ThemeProviderPort
import QtQml

QtObject {
    id: root

    property string providerId: "static"
    property string fallbackProviderId: "static"
    property string mode: "dark"
    property string variant: "tonal-spot"
    property string sourceKind: "static"
    property string sourceValue: ""
    property string matugenSchemePath: ""

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

    function createMatugenProvider() {
        return MatugenThemeProviderAdapters.createMatugenThemeProvider({
            providerId: "matugen",
            schemePath: root.matugenSchemePath
        });
    }

    function resolveProvider() {
        return ThemeProviderPort.resolveThemeProvider(root.providerCatalog, root.providerId, root.fallbackProviderId);
    }

    function createGenerationRequest(reasonCode, resolvedProviderId) {
        return ThemeContracts.createThemeGenerationRequest({
            provider: resolvedProviderId,
            mode: root.mode,
            variant: root.variant,
            sourceKind: root.sourceKind,
            sourceValue: root.sourceValue,
            meta: {
                source: String(reasonCode || "theme.bridge.regenerate")
            }
        });
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
            lastOutcome: root.lastOutcome
        };
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
    onMatugenSchemePathChanged: {
        root.matugenProvider = root.createMatugenProvider();
        root.regenerate("theme.provider.matugen.updated");
    }
    onMatugenProviderChanged: root.regenerate("theme.provider.matugen.object_updated")
    onStaticProviderChanged: root.regenerate("theme.provider.static.updated")
}

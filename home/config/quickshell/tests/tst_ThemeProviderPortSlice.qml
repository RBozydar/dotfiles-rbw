import "../system/adapters/theming/matugen-theme-provider.js" as MatugenThemeProviderAdapters
import "../system/adapters/theming/static-theme-provider.js" as StaticThemeProviderAdapters
import "../system/core/contracts/theme-contracts.js" as ThemeContracts
import "../system/core/ports/theme-provider-port.js" as ThemeProviderPort
import QtQuick 2.15
import QtTest 1.3

TestCase {
    name: "ThemeProviderPortSlice"

    function test_resolveThemeProvider_prefers_preferred_provider() {
        const providers = {
            static: StaticThemeProviderAdapters.createStaticThemeProvider({
                providerId: "static"
            }),
            matugen: MatugenThemeProviderAdapters.createMatugenThemeProvider({
                providerId: "matugen"
            })
        };
        const resolved = ThemeProviderPort.resolveThemeProvider(providers, "matugen", "static");

        compare(resolved.providerId, "matugen");
        compare(resolved.fallbackUsed, false);
        verify(resolved.adapter !== null);
    }

    function test_resolveThemeProvider_uses_fallback_when_preferred_missing() {
        const providers = {
            static: StaticThemeProviderAdapters.createStaticThemeProvider({
                providerId: "static"
            })
        };
        const resolved = ThemeProviderPort.resolveThemeProvider(providers, "matugen", "static");

        compare(resolved.providerId, "static");
        compare(resolved.fallbackUsed, true);
        verify(resolved.adapter !== null);
    }

    function test_describeThemeProviderCatalog_reports_sorted_provider_details() {
        const providers = {
            static: StaticThemeProviderAdapters.createStaticThemeProvider({
                providerId: "static"
            }),
            matugen: MatugenThemeProviderAdapters.createMatugenThemeProvider({
                providerId: "matugen"
            })
        };
        const description = ThemeProviderPort.describeThemeProviderCatalog(providers);

        compare(description.kind, "theme.provider_catalog");
        compare(description.providers.length, 2);
        compare(description.providers[0].providerId, "matugen");
        compare(description.providers[1].providerId, "static");
        compare(description.providers[0].ready, false);
        compare(description.providers[1].ready, true);
    }

    function test_staticThemeProvider_generate_returns_valid_theme_scheme_document() {
        const adapter = StaticThemeProviderAdapters.createStaticThemeProvider({
            providerId: "static"
        });
        const port = ThemeProviderPort.createThemeProviderPort(adapter);
        const request = ThemeContracts.createThemeGenerationRequest({
            provider: "static",
            mode: "light",
            sourceKind: "static",
            sourceValue: ""
        });
        const rawScheme = port.generate(request);
        const scheme = ThemeContracts.validateThemeSchemeDocument(rawScheme);

        compare(scheme.provider, "static");
        compare(scheme.mode, "light");
        compare(scheme.kind, "shell.theme.scheme");
    }

    function test_matugenThemeProvider_generate_extracts_nested_roles() {
        const darkRoles = ThemeContracts.createDefaultThemeRoleMap("dark");
        const adapter = MatugenThemeProviderAdapters.createMatugenThemeProvider({
            providerId: "matugen",
            readScheme: function () {
                return {
                    schemes: {
                        dark: {
                            colors: darkRoles
                        }
                    }
                };
            }
        });
        const port = ThemeProviderPort.createThemeProviderPort(adapter);
        const request = ThemeContracts.createThemeGenerationRequest({
            provider: "matugen",
            mode: "dark",
            sourceKind: "file",
            sourceValue: "/tmp/scheme.json"
        });
        const rawScheme = port.generate(request);
        const scheme = ThemeContracts.validateThemeSchemeDocument(rawScheme);

        compare(scheme.provider, "matugen");
        compare(scheme.mode, "dark");
        compare(scheme.sourceKind, "file");
    }
}

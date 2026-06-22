import "../system/adapters/theming/matugen-theme-provider.js" as MatugenThemeProviderAdapters
import "../system/adapters/theming/static-theme-provider.js" as StaticThemeProviderAdapters
import "../system/core/contracts/theme-contracts.js" as ThemeContracts
import "../system/core/ports/theme-provider-port.js" as ThemeProviderPort
import QtQuick 2.15
import QtTest 1.3

TestCase {
    name: "ThemeProviderPortSlice"

    function toSnakeCase(value) {
        return String(value).replace(/[A-Z]/g, match => "_" + match.toLowerCase());
    }

    function toMatugenColors(roleMap) {
        const colors = {};
        for (const rawRoleName in roleMap) {
            const roleName = String(rawRoleName);
            colors[toSnakeCase(roleName)] = {
                dark: {
                    color: String(roleMap[roleName])
                },
                default: {
                    color: String(roleMap[roleName])
                },
                light: {
                    color: "#ffffff"
                }
            };
        }
        return colors;
    }

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

    function test_staticThemeProvider_generate_applies_named_variant_overrides() {
        const adapter = StaticThemeProviderAdapters.createStaticThemeProvider({
            providerId: "static"
        });
        const port = ThemeProviderPort.createThemeProviderPort(adapter);
        const evangelionRequest = ThemeContracts.createThemeGenerationRequest({
            provider: "static",
            mode: "dark",
            variant: "evangelion",
            sourceKind: "static",
            sourceValue: ""
        });
        const evangelionRawScheme = port.generate(evangelionRequest);
        const evangelionScheme = ThemeContracts.validateThemeSchemeDocument(evangelionRawScheme);

        compare(evangelionScheme.roles.primary, "#95ff00");
        compare(evangelionScheme.roles.onPrimary, "#102300");

        const moonSpaceRequest = ThemeContracts.createThemeGenerationRequest({
            provider: "static",
            mode: "light",
            variant: "moon-space",
            sourceKind: "static",
            sourceValue: ""
        });
        const moonSpaceRawScheme = port.generate(moonSpaceRequest);
        const moonSpaceScheme = ThemeContracts.validateThemeSchemeDocument(moonSpaceRawScheme);

        compare(moonSpaceScheme.roles.primary, "#365ba8");
        compare(moonSpaceScheme.roles.onBackground, "#151c2c");
    }

    function test_matugenThemeProvider_generate_extracts_nested_roles() {
        const darkRoles = ThemeContracts.createDefaultThemeRoleMap("dark");
        const adapter = MatugenThemeProviderAdapters.createMatugenThemeProvider({
            providerId: "matugen",
            readScheme: function () {
                return {
                    colors: toMatugenColors(darkRoles)
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
        compare(scheme.roles.onPrimary, String(darkRoles.onPrimary).toLowerCase());
        compare(scheme.roles.surfaceContainerHighest, String(darkRoles.surfaceContainerHighest).toLowerCase());
    }

    function test_matugenThemeProvider_generate_uses_generate_callback_when_read_returns_null() {
        const darkRoles = ThemeContracts.createDefaultThemeRoleMap("dark");
        const adapter = MatugenThemeProviderAdapters.createMatugenThemeProvider({
            providerId: "matugen",
            readScheme: function () {
                return null;
            },
            generateScheme: function () {
                return {
                    colors: toMatugenColors(darkRoles)
                };
            }
        });
        const port = ThemeProviderPort.createThemeProviderPort(adapter);
        const request = ThemeContracts.createThemeGenerationRequest({
            provider: "matugen",
            mode: "dark",
            sourceKind: "wallpaper",
            sourceValue: "/tmp/wallpaper.jpg"
        });
        const rawScheme = port.generate(request);
        const scheme = ThemeContracts.validateThemeSchemeDocument(rawScheme);

        compare(scheme.provider, "matugen");
        compare(scheme.mode, "dark");
        compare(scheme.sourceKind, "wallpaper");
        compare(scheme.roles.primary, String(darkRoles.primary).toLowerCase());
    }
}

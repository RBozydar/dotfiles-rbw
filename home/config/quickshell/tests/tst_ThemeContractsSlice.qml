import "../system/core/contracts/theme-contracts.js" as ThemeContracts
import QtQuick 2.15
import QtTest 1.3

TestCase {
    name: "ThemeContractsSlice"

    function requiredRoleNames() {
        return ["primary", "onPrimary", "primaryContainer", "onPrimaryContainer", "secondary", "onSecondary", "secondaryContainer", "onSecondaryContainer", "tertiary", "onTertiary", "tertiaryContainer", "onTertiaryContainer", "error", "onError", "errorContainer", "onErrorContainer", "background", "onBackground", "surface", "onSurface", "surfaceVariant", "onSurfaceVariant", "outline", "outlineVariant", "shadow", "scrim", "inverseSurface", "inverseOnSurface", "inversePrimary", "surfaceTint", "surfaceContainerLowest", "surfaceContainerLow", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceBright", "surfaceDim",];
    }

    function test_createThemeSchemeDocument_defaults_include_required_roles() {
        const scheme = ThemeContracts.createThemeSchemeDocument({
            provider: "static",
            mode: "dark"
        });

        compare(scheme.kind, "shell.theme.scheme");
        compare(scheme.schemaVersion, 1);
        compare(scheme.provider, "static");
        compare(scheme.mode, "dark");
        compare(scheme.variant, "tonal-spot");

        const requiredRoles = requiredRoleNames();
        for (let index = 0; index < requiredRoles.length; index += 1) {
            const roleName = requiredRoles[index];
            verify(Object.prototype.hasOwnProperty.call(scheme.roles, roleName));
        }
    }

    function test_validateThemeSchemeDocument_rejects_missing_required_role() {
        const scheme = ThemeContracts.createThemeSchemeDocument({
            provider: "static",
            mode: "light"
        });
        delete scheme.roles.primary;

        let failed = false;
        try {
            ThemeContracts.validateThemeSchemeDocument(scheme);
        } catch (error) {
            failed = true;
        }

        verify(failed);
    }

    function test_createThemeGenerationRequest_normalizes_defaults() {
        const request = ThemeContracts.createThemeGenerationRequest({
            provider: "matugen",
            mode: "light",
            sourceKind: "wallpaper",
            sourceValue: "/tmp/wallpaper.png",
            meta: {
                source: "test"
            }
        });

        compare(request.kind, "shell.theme.generate");
        compare(request.schemaVersion, 1);
        compare(request.provider, "matugen");
        compare(request.mode, "light");
        compare(request.variant, "tonal-spot");
        compare(request.sourceKind, "wallpaper");
        compare(request.sourceValue, "/tmp/wallpaper.png");
        compare(request.meta.source, "test");
    }

    function test_validateThemeGenerationRequest_rejects_invalid_mode() {
        let failed = false;
        try {
            ThemeContracts.validateThemeGenerationRequest({
                kind: "shell.theme.generate",
                schemaVersion: 1,
                provider: "matugen",
                mode: "invalid",
                variant: "tonal-spot",
                sourceKind: "static",
                sourceValue: "",
                meta: {}
            });
        } catch (error) {
            failed = true;
        }

        verify(failed);
    }
}

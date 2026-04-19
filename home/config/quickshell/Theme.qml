import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    property bool darkMode: true
    property var schemeDocument: null
    property var roleMap: ({})
    readonly property string fontSans: "Fira Sans"
    readonly property string fontMono: "JetBrains Mono"

    function roleColor(roleName, darkFallback, lightFallback): color {
        const fallback = darkMode ? darkFallback : lightFallback;
        if (!roleMap || typeof roleMap !== "object" || Array.isArray(roleMap))
            return fallback;

        const candidate = roleMap[roleName];
        const value = String(candidate === undefined ? "" : candidate).trim();
        if (!value)
            return fallback;

        return value;
    }

    function applyThemeScheme(scheme): void {
        if (!scheme || typeof scheme !== "object" || Array.isArray(scheme)) {
            schemeDocument = null;
            roleMap = ({});
            return;
        }
        if (scheme.kind !== "shell.theme.scheme" || !scheme.roles || typeof scheme.roles !== "object" || Array.isArray(scheme.roles)) {
            schemeDocument = null;
            roleMap = ({});
            return;
        }

        const nextRoleMap = {};
        for (const rawRoleName in scheme.roles) {
            const roleName = String(rawRoleName || "").trim();
            if (!roleName)
                continue;
            const roleValue = String(scheme.roles[rawRoleName] === undefined ? "" : scheme.roles[rawRoleName]).trim();
            if (!roleValue)
                continue;
            nextRoleMap[roleName] = roleValue;
        }

        schemeDocument = scheme;
        roleMap = nextRoleMap;
        darkMode = String(scheme.mode || "dark").trim().toLowerCase() !== "light";
    }

    function clampOpacity(value, fallback): real {
        const parsed = Number(value);
        if (!Number.isFinite(parsed))
            return fallback;
        if (parsed < 0)
            return 0;
        if (parsed > 1)
            return 1;
        return parsed;
    }

    function withAlpha(inputColor, alpha): color {
        const parsed = Qt.color(String(inputColor));
        const resolvedAlpha = clampOpacity(alpha, parsed.a);
        return Qt.rgba(parsed.r, parsed.g, parsed.b, resolvedAlpha);
    }

    function clampOpacityScale(value, fallback): real {
        const parsed = Number(value);
        if (!Number.isFinite(parsed))
            return fallback;
        if (parsed < 0)
            return 0;
        if (parsed > 4)
            return 4;
        return parsed;
    }

    function parseUiOpacityConfig(text): var {
        const defaults = {
            "global": 1,
            "modules": ({})
        };

        const rawText = String(text || "").trim();
        if (!rawText)
            return defaults;

        try {
            const parsed = JSON.parse(rawText);
            if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
                return defaults;

            const modules = {};
            if (parsed.modules && typeof parsed.modules === "object" && !Array.isArray(parsed.modules)) {
                for (const rawModuleId in parsed.modules) {
                    const moduleId = String(rawModuleId || "").trim();
                    if (!moduleId)
                        continue;
                    modules[moduleId] = clampOpacityScale(parsed.modules[rawModuleId], 1);
                }
            }

            return {
                "global": clampOpacityScale(parsed.global, 1),
                "modules": modules
            };
        } catch (error) {
            return defaults;
        }
    }

    function moduleOpacity(moduleId, fallbackOpacity): real {
        const baseOpacity = clampOpacity(fallbackOpacity, 1);
        const configDocument = uiOpacityConfig;
        const globalScale = clampOpacityScale(configDocument && configDocument.global, 1);
        const modules = configDocument && configDocument.modules && typeof configDocument.modules === "object" && !Array.isArray(configDocument.modules) ? configDocument.modules : ({});
        const key = String(moduleId || "").trim();
        const moduleScale = key.length > 0 ? clampOpacityScale(modules[key], 1) : 1;
        return clampOpacity(baseOpacity * globalScale * moduleScale, baseOpacity);
    }

    readonly property string uiOpacityConfigPath: Quickshell.shellPath("config/ui-opacity.json")
    readonly property var uiOpacityConfig: parseUiOpacityConfig(uiOpacityConfigFile.text)

    FileView {
        id: uiOpacityConfigFile
        path: uiOpacityConfigPath
        watchChanges: true
        blockWrites: true
    }

    readonly property color primary: roleColor("primary", "#82dccc", "#0f9684")
    readonly property color roleOnPrimary: Qt.color(roleColor("onPrimary", "#003731", "#ffffff"))
    readonly property color onPrimary: roleOnPrimary
    readonly property color primaryContainer: roleColor("primaryContainer", "#1b3b36", "#cbe7e1")
    readonly property color roleOnPrimaryContainer: Qt.color(
        roleColor("onPrimaryContainer", "#c8d2e0", "#132235"),
    )
    readonly property color onPrimaryContainer: roleOnPrimaryContainer
    readonly property color secondary: roleColor("secondary", "#01ccff", "#0077cc")
    readonly property color roleOnSecondary: Qt.color(
        roleColor("onSecondary", "#003547", "#ffffff"),
    )
    readonly property color onSecondary: roleOnSecondary
    readonly property color secondaryContainer: roleColor("secondaryContainer", "#1a2b44", "#cedceb")
    readonly property color roleOnSecondaryContainer: Qt.color(
        roleColor("onSecondaryContainer", "#c8d2e0", "#132235"),
    )
    readonly property color onSecondaryContainer: roleOnSecondaryContainer
    readonly property color tertiary: roleColor("tertiary", "#fb958b", "#cf6b5d")
    readonly property color roleOnTertiary: Qt.color(roleColor("onTertiary", "#4f1d17", "#ffffff"))
    readonly property color onTertiary: roleOnTertiary
    readonly property color tertiaryContainer: roleColor("tertiaryContainer", "#5e2a22", "#f9d4ce")
    readonly property color roleOnTertiaryContainer: Qt.color(
        roleColor("onTertiaryContainer", "#ffd7d1", "#132235"),
    )
    readonly property color onTertiaryContainer: roleOnTertiaryContainer
    readonly property color error: roleColor("error", "#ff857d", "#d64f44")
    readonly property color roleOnError: Qt.color(roleColor("onError", "#601410", "#ffffff"))
    readonly property color onError: roleOnError
    readonly property color errorContainer: roleColor("errorContainer", "#7f221a", "#f9d4ce")
    readonly property color roleOnErrorContainer: Qt.color(
        roleColor("onErrorContainer", "#ffdad6", "#132235"),
    )
    readonly property color onErrorContainer: roleOnErrorContainer
    readonly property color background: roleColor("background", "#09111f", "#edf4fb")
    readonly property color roleOnBackground: Qt.color(
        roleColor("onBackground", "#c8d2e0", "#132235"),
    )
    readonly property color onBackground: roleOnBackground
    readonly property color surface: roleColor("surface", "#d9111827", "#eef7fbff")
    readonly property color roleOnSurface: Qt.color(roleColor("onSurface", "#c8d2e0", "#132235"))
    readonly property color onSurface: roleOnSurface
    readonly property color surfaceVariant: roleColor("surfaceVariant", "#111827", "#ffffff")
    readonly property color roleOnSurfaceVariant: Qt.color(
        roleColor("onSurfaceVariant", "#8ea4bf", "#5d7389"),
    )
    readonly property color onSurfaceVariant: roleOnSurfaceVariant
    readonly property color outline: roleColor("outline", "#33526e", "#9bb1c6")
    readonly property color outlineVariant: roleColor("outlineVariant", "#274058", "#b8c8d8")
    readonly property color shadow: roleColor("shadow", "#000000", "#000000")
    readonly property color scrim: roleColor("scrim", "#000000", "#000000")
    readonly property color inverseSurface: roleColor("inverseSurface", "#c8d2e0", "#132235")
    readonly property color inverseOnSurface: roleColor("inverseOnSurface", "#132235", "#edf4fb")
    readonly property color inversePrimary: roleColor("inversePrimary", "#0077cc", "#82dccc")
    readonly property color surfaceTint: roleColor("surfaceTint", "#82dccc", "#0f9684")
    readonly property color surfaceContainerLowest: roleColor("surfaceContainerLowest", "#09111f", "#ffffff")
    readonly property color surfaceContainerLow: roleColor("surfaceContainerLow", "#132033", "#dfe9f4")
    readonly property color surfaceContainer: roleColor("surfaceContainer", "#111827", "#ffffff")
    readonly property color surfaceContainerHigh: roleColor("surfaceContainerHigh", "#1a2b44", "#cedceb")
    readonly property color surfaceContainerHighest: roleColor("surfaceContainerHighest", "#1b3b36", "#cbe7e1")
    readonly property color surfaceBright: roleColor("surfaceBright", "#1a2b44", "#ffffff")
    readonly property color surfaceDim: roleColor("surfaceDim", "#09111f", "#dfe9f4")

    readonly property int barOuterHeight: 52
    readonly property int barInnerHeight: 40
    readonly property int barChipHeight: barInnerHeight - 4
    readonly property int barMargin: 6
    readonly property real barSurfaceOpacity: darkMode ? 0.72 : 0.82
    readonly property real workspaceStripOpacity: darkMode ? 0.54 : 0.62
    readonly property real workspaceStripBorderOpacity: darkMode ? 0.58 : 0.72
    readonly property real workspaceButtonActiveOpacity: darkMode ? 0.72 : 0.8
    readonly property real workspaceButtonHoverOpacity: darkMode ? 0.62 : 0.72
    readonly property real workspaceButtonOccupiedOpacity: darkMode ? 0.54 : 0.64
    readonly property real workspaceSpecialOpacity: darkMode ? 0.7 : 0.8
    readonly property int radius: 18
    readonly property int chipRadius: 14
    readonly property int gap: 8
    readonly property int padding: 12
    readonly property int chipPadding: 10

    function toggleDarkMode(): void {
        darkMode = !darkMode;
        schemeDocument = null;
        roleMap = ({});
    }
}

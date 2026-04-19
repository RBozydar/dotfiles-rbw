import "../adapters/quickshell" as QuickshellAdapters
import "../adapters/persistence" as PersistenceAdapters
import "../adapters/search/system-launcher-search-adapter.js" as LauncherSearchAdapters
import "../adapters/search" as SearchAdapters
import "../core/application/ipc/dispatch-shell-command.js" as ShellIpcUseCases
import "../core/application/integrations/describe-optional-integrations-health.js" as OptionalIntegrationHealthUseCases
import "../core/application/integrations/wallpaper-workflow.js" as WallpaperWorkflowUseCases
import "../core/application/launcher/activate-launcher-item.js" as LauncherActivationUseCases
import "../core/application/launcher/apply-launcher-async-provider-result.js" as LauncherAsyncProviderUseCases
import "../core/application/launcher/launcher-async-provider-registry.js" as LauncherAsyncProviderRegistry
import "../core/application/launcher/launcher-async-provider-runtime.js" as LauncherAsyncProviderRuntimeUseCases
import "../core/application/launcher/run-launcher-search.js" as LauncherSearchUseCases
import "../core/application/settings/hydrate-settings.js" as SettingsUseCases
import "../core/application/settings/persist-settings.js" as SettingsPersistUseCases
import "../core/application/settings/update-settings.js" as SettingsUpdateUseCases
import "../core/contracts/launcher-contracts.js" as LauncherContracts
import "../core/contracts/ipc-command-contracts.js" as IpcContracts
import "../core/contracts/operation-outcome.js" as OperationOutcomes
import "../core/contracts/notification-contracts.js" as NotificationContracts
import "../core/contracts/settings-contracts.js" as SettingsContracts
import "../core/domain/launcher/launcher-store.js" as LauncherStore
import "../core/domain/settings/settings-store.js" as SettingsStore
import "../core/policies/launcher/launcher-scoring-policy.js" as LauncherScoringPolicy
import "../core/ports/command-execution-port.js" as CommandExecutionPort
import "../core/ports/persistence-port.js" as PersistencePort
import "../core/ports/shell-command-port.js" as ShellCommandPort
import "../core/selectors/launcher/select-launcher-sections.js" as LauncherSelectors
import QtQml
import Quickshell
import qs
import "bridges" as SystemBridges
import "modules/bar" as SystemBarModules
import "modules/launcher" as SystemLauncherModules
import "modules/notifications" as SystemNotificationModules
import "modules/osd" as SystemOsdModules
import "modules/session" as SystemSessionModules

ShellRoot {
    id: root

    settings.watchFiles: true

    property bool sessionOverlayOpen: false
    property bool launcherOverlayOpen: false
    property var commandExecutionAdapter: QuickshellAdapters.CommandExecutionAdapter {}
    readonly property var commandExecutionPort: CommandExecutionPort.createCommandExecutionPort(commandExecutionAdapter)
    readonly property var launcherAppCatalogAdapter: SearchAdapters.DesktopAppCatalogAdapter {}
    property bool launcherEmojiIntegrationEnabled: true
    property bool launcherClipboardIntegrationEnabled: true
    property bool launcherFileSearchIntegrationEnabled: true
    property bool launcherWallpaperIntegrationEnabled: true
    property bool homeAssistantIntegrationEnabled: true
    property bool launcherHomeAssistantIntegrationEnabled: true
    property string launcherEmojiCatalogPath: String(Quickshell.env("RBW_LAUNCHER_EMOJI_CATALOG_PATH") || "")
    property string launcherFileSearchRoots: String(Quickshell.env("RBW_LAUNCHER_FILE_SEARCH_ROOTS") || "")
    property string launcherWallpaperSearchRoots: String(Quickshell.env("RBW_LAUNCHER_WALLPAPER_DIRS") || "")
    readonly property var launcherEmojiCatalogAdapter: SearchAdapters.EmojiCatalogAdapter {
        enabled: root.launcherEmojiIntegrationEnabled
        catalogPathOverride: root.launcherEmojiCatalogPath
    }
    readonly property var launcherClipboardHistoryAdapter: SearchAdapters.ClipboardHistoryAdapter {
        enabled: root.launcherClipboardIntegrationEnabled
    }
    readonly property var launcherFileSearchAdapter: SearchAdapters.FileSearchAdapter {
        enabled: root.launcherFileSearchIntegrationEnabled
        searchRootsOverride: root.launcherFileSearchRoots
    }
    readonly property var launcherWallpaperCatalogAdapter: SearchAdapters.WallpaperCatalogAdapter {
        enabled: root.launcherWallpaperIntegrationEnabled
        wallpaperRootsOverride: root.launcherWallpaperSearchRoots
    }
    readonly property QtObject shellChromeBridge: SystemBridges.ShellChromeBridge {
        homeAssistantEnabled: root.homeAssistantIntegrationEnabled
    }
    readonly property var launcherHomeAssistantAdapter: SearchAdapters.HomeAssistantLauncherAdapter {
        enabled: root.homeAssistantIntegrationEnabled && root.launcherHomeAssistantIntegrationEnabled
        homeAssistantState: root.shellChromeBridge ? root.shellChromeBridge.homeAssistant : null
    }
    readonly property QtObject notificationBridge: SystemBridges.NotificationBridge {
        commandExecutionPort: root.commandExecutionPort
        codexFocusScriptPath: Quickshell.shellPath("scripts/focus-codex-ghostty.sh")
        onHistoryMutated: payload => {
            root.queueNotificationHistorySync(payload && payload.history ? payload.history : []);
        }
    }
    property string themeProviderId: String(Quickshell.env("RBW_THEME_PROVIDER") || "static")
    property string themeFallbackProviderId: String(Quickshell.env("RBW_THEME_FALLBACK_PROVIDER") || "static")
    property string themeMode: String(Quickshell.env("RBW_THEME_MODE") || "dark")
    property string themeVariant: String(Quickshell.env("RBW_THEME_VARIANT") || "tonal-spot")
    property string themeSourceKind: String(Quickshell.env("RBW_THEME_SOURCE_KIND") || "static")
    property string themeSourceValue: String(Quickshell.env("RBW_THEME_SOURCE_VALUE") || "")
    property string themeMatugenSchemePath: String(Quickshell.env("RBW_THEME_MATUGEN_SCHEME_PATH") || "")
    readonly property QtObject themeBridge: SystemBridges.ThemeBridge {
        providerId: root.themeProviderId
        fallbackProviderId: root.themeFallbackProviderId
        mode: root.themeMode
        variant: root.themeVariant
        sourceKind: root.themeSourceKind
        sourceValue: root.themeSourceValue
        matugenSchemePath: root.themeMatugenSchemePath
    }
    property var settingsStore: SettingsStore.createSettingsStore()
    property var launcherStore: LauncherStore.createLauncherStore()
    property int launcherGenerationCounter: 0
    property var launcherTelemetryQueue: []
    property int launcherTelemetryQueueCapacity: 2048
    property int launcherTelemetryFlushIntervalMs: 900
    property int launcherTelemetryMaxBatchSize: 64
    property int launcherQueryHistoryRetentionDays: 90
    property int launcherQueryHistoryMaxEntries: 20000
    property var launcherAsyncProviderRuntime: null
    property int launcherAsyncProviderTimeoutMs: 2500
    property int launcherAsyncProviderSweepIntervalMs: 220
    property int launcherAsyncProviderFailureRetention: 24
    property int wallpaperHistoryLimit: Number(Quickshell.env("RBW_WALLPAPER_HISTORY_LIMIT") || 80)
    property var wallpaperHistoryState: WallpaperWorkflowUseCases.createWallpaperHistoryState({
        limit: Number(Quickshell.env("RBW_WALLPAPER_HISTORY_LIMIT") || 80)
    })
    property bool notificationHistorySyncEnabled: true
    property int notificationHistorySyncIntervalMs: 700
    property int notificationHistoryMaxEntries: 240
    property bool notificationHistorySyncPending: false
    property var notificationHistoryPendingSnapshot: []
    property bool settingsAutoPersistEnabled: true
    property int settingsAutoPersistIntervalMs: 450
    readonly property var settingsPersistenceAdapter: settingsPersistenceAdapterObject
    readonly property var persistencePort: PersistencePort.createPersistencePort(settingsPersistenceAdapterObject)
    readonly property var shellCommandPort: ShellCommandPort.createShellCommandPort(shellIpcCommandHandlers)

    readonly property var shellIpcCommandSpecs: [IpcContracts.createShellIpcCommandSpec({
            name: "session.toggle",
            summary: "Toggle the native session overlay",
            usage: "session.toggle",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "session.open",
            summary: "Open the native session overlay",
            usage: "session.open",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "session.close",
            summary: "Close the native session overlay",
            usage: "session.close",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "shell.command.run",
            summary: "Run an external command through the Quickshell command adapter",
            usage: "shell.command.run <argv0> [argv1...]",
            minArgs: 1,
            maxArgs: 32
        }), IpcContracts.createShellIpcCommandSpec({
            name: "launcher.search",
            summary: "Run launcher search and update launcher store state",
            usage: "launcher.search [query...]",
            minArgs: 0,
            maxArgs: 32
        }), IpcContracts.createShellIpcCommandSpec({
            name: "launcher.toggle",
            summary: "Toggle launcher overlay visibility",
            usage: "launcher.toggle",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "launcher.open",
            summary: "Open launcher overlay",
            usage: "launcher.open",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "launcher.close",
            summary: "Close launcher overlay",
            usage: "launcher.close",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "launcher.activate",
            summary: "Activate one launcher result item by id",
            usage: "launcher.activate <item-id>",
            minArgs: 1,
            maxArgs: 1
        }), IpcContracts.createShellIpcCommandSpec({
            name: "launcher.describe",
            summary: "Return launcher state snapshot and section projection",
            usage: "launcher.describe",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "launcher.providers.describe",
            summary: "Return launcher async provider diagnostics",
            usage: "launcher.providers.describe",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "launcher.catalog.describe",
            summary: "Return launcher app catalog adapter diagnostics",
            usage: "launcher.catalog.describe",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "launcher.integrations.describe",
            summary: "Return optional launcher integration diagnostics",
            usage: "launcher.integrations.describe",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "integrations.health",
            summary: "Return consolidated optional integration health with remediation hints",
            usage: "integrations.health",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.reload",
            summary: "Reload settings from the persistence port",
            usage: "settings.reload",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.describe",
            summary: "Return the effective runtime settings snapshot",
            usage: "settings.describe",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.paths",
            summary: "Return persistence adapter path details",
            usage: "settings.paths",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.session_overlay.enable",
            summary: "Enable session overlay setting and persist it",
            usage: "settings.session_overlay.enable",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.session_overlay.disable",
            summary: "Disable session overlay setting and persist it",
            usage: "settings.session_overlay.disable",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.launcher.command_prefix.set",
            summary: "Set launcher command prefix and persist it",
            usage: "settings.launcher.command_prefix.set <prefix>",
            minArgs: 1,
            maxArgs: 1
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.launcher.max_results.set",
            summary: "Set launcher max result count and persist it",
            usage: "settings.launcher.max_results.set <count>",
            minArgs: 1,
            maxArgs: 1
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.launcher.pin_command",
            summary: "Pin a launcher command id for command-mode priority",
            usage: "settings.launcher.pin_command <command-id>",
            minArgs: 1,
            maxArgs: 1
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.launcher.unpin_command",
            summary: "Remove a pinned launcher command id",
            usage: "settings.launcher.unpin_command <command-id>",
            minArgs: 1,
            maxArgs: 1
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.launcher.personalization.reset",
            summary: "Reset launcher personalization (pins, usage, query history)",
            usage: "settings.launcher.personalization.reset",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.persist",
            summary: "Persist current settings snapshots through the persistence port",
            usage: "settings.persist",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.integrations.homeassistant.enable",
            summary: "Enable Home Assistant shell integration and persist it",
            usage: "settings.integrations.homeassistant.enable",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.integrations.homeassistant.disable",
            summary: "Disable Home Assistant shell integration and persist it",
            usage: "settings.integrations.homeassistant.disable",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.integrations.launcher.homeassistant.enable",
            summary: "Enable launcher Home Assistant integration and persist it",
            usage: "settings.integrations.launcher.homeassistant.enable",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.integrations.launcher.homeassistant.disable",
            summary: "Disable launcher Home Assistant integration and persist it",
            usage: "settings.integrations.launcher.homeassistant.disable",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.integrations.launcher.emoji.enable",
            summary: "Enable launcher emoji integration and persist it",
            usage: "settings.integrations.launcher.emoji.enable",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.integrations.launcher.emoji.disable",
            summary: "Disable launcher emoji integration and persist it",
            usage: "settings.integrations.launcher.emoji.disable",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.integrations.launcher.clipboard.enable",
            summary: "Enable launcher clipboard integration and persist it",
            usage: "settings.integrations.launcher.clipboard.enable",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.integrations.launcher.clipboard.disable",
            summary: "Disable launcher clipboard integration and persist it",
            usage: "settings.integrations.launcher.clipboard.disable",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.integrations.launcher.file_search.enable",
            summary: "Enable launcher file-search integration and persist it",
            usage: "settings.integrations.launcher.file_search.enable",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.integrations.launcher.file_search.disable",
            summary: "Disable launcher file-search integration and persist it",
            usage: "settings.integrations.launcher.file_search.disable",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.integrations.launcher.wallpaper.enable",
            summary: "Enable launcher wallpaper integration and persist it",
            usage: "settings.integrations.launcher.wallpaper.enable",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "settings.integrations.launcher.wallpaper.disable",
            summary: "Disable launcher wallpaper integration and persist it",
            usage: "settings.integrations.launcher.wallpaper.disable",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "theme.describe",
            summary: "Return theme runtime snapshot and provider diagnostics",
            usage: "theme.describe",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "theme.regenerate",
            summary: "Regenerate theme scheme through the active provider",
            usage: "theme.regenerate",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "theme.provider.set",
            summary: "Set preferred theme provider id",
            usage: "theme.provider.set <provider-id>",
            minArgs: 1,
            maxArgs: 1
        }), IpcContracts.createShellIpcCommandSpec({
            name: "theme.mode.set",
            summary: "Set theme mode (dark|light)",
            usage: "theme.mode.set <mode>",
            minArgs: 1,
            maxArgs: 1
        }), IpcContracts.createShellIpcCommandSpec({
            name: "theme.variant.set",
            summary: "Set theme generation variant",
            usage: "theme.variant.set <variant>",
            minArgs: 1,
            maxArgs: 1
        }), IpcContracts.createShellIpcCommandSpec({
            name: "notifications.describe",
            summary: "Return notifications runtime snapshot",
            usage: "notifications.describe",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "notifications.mark_all_read",
            summary: "Mark all notification history entries as read",
            usage: "notifications.mark_all_read",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "notifications.clear_history",
            summary: "Clear notification history and active popups",
            usage: "notifications.clear_history",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "notifications.clear_entry",
            summary: "Remove one notification entry and matching popup by key",
            usage: "notifications.clear_entry <key>",
            minArgs: 1,
            maxArgs: 1
        }), IpcContracts.createShellIpcCommandSpec({
            name: "notifications.dismiss_popup",
            summary: "Dismiss one popup notification by key",
            usage: "notifications.dismiss_popup <key>",
            minArgs: 1,
            maxArgs: 1
        }), IpcContracts.createShellIpcCommandSpec({
            name: "notifications.activate",
            summary: "Activate one notification entry by key",
            usage: "notifications.activate <key>",
            minArgs: 1,
            maxArgs: 1
        }), IpcContracts.createShellIpcCommandSpec({
            name: "notifications.activate_action",
            summary: "Invoke one notification action by key and action id",
            usage: "notifications.activate_action <key> <action-id>",
            minArgs: 2,
            maxArgs: 2
        }), IpcContracts.createShellIpcCommandSpec({
            name: "wallpaper.describe",
            summary: "Return wallpaper integration runtime snapshot",
            usage: "wallpaper.describe",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "wallpaper.refresh_catalog",
            summary: "Refresh wallpaper catalog integration state",
            usage: "wallpaper.refresh_catalog",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "wallpaper.set",
            summary: "Set wallpaper image through configured backend",
            usage: "wallpaper.set <absolute-path>",
            minArgs: 1,
            maxArgs: 1
        }), IpcContracts.createShellIpcCommandSpec({
            name: "wallpaper.random",
            summary: "Set a random wallpaper from the current catalog",
            usage: "wallpaper.random",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "wallpaper.previous",
            summary: "Set previous wallpaper from local runtime history",
            usage: "wallpaper.previous",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "wallpaper.next",
            summary: "Set next wallpaper from local runtime history",
            usage: "wallpaper.next",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "wallpaper.history.describe",
            summary: "Return wallpaper runtime history snapshot",
            usage: "wallpaper.history.describe",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "homeassistant.describe",
            summary: "Return Home Assistant integration runtime snapshot",
            usage: "homeassistant.describe",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "homeassistant.refresh",
            summary: "Queue Home Assistant state refresh",
            usage: "homeassistant.refresh",
            minArgs: 0,
            maxArgs: 0
        }), IpcContracts.createShellIpcCommandSpec({
            name: "homeassistant.toggle_light",
            summary: "Queue Home Assistant light toggle action",
            usage: "homeassistant.toggle_light <entity-id>",
            minArgs: 1,
            maxArgs: 1
        }), IpcContracts.createShellIpcCommandSpec({
            name: "homeassistant.turn_on_light",
            summary: "Queue Home Assistant light turn-on action",
            usage: "homeassistant.turn_on_light <entity-id>",
            minArgs: 1,
            maxArgs: 1
        }), IpcContracts.createShellIpcCommandSpec({
            name: "homeassistant.turn_off_light",
            summary: "Queue Home Assistant light turn-off action",
            usage: "homeassistant.turn_off_light <entity-id>",
            minArgs: 1,
            maxArgs: 1
        }), IpcContracts.createShellIpcCommandSpec({
            name: "homeassistant.set_brightness",
            summary: "Queue Home Assistant light brightness action",
            usage: "homeassistant.set_brightness <entity-id> <percent>",
            minArgs: 2,
            maxArgs: 2
        }), IpcContracts.createShellIpcCommandSpec({
            name: "homeassistant.set_color_temp",
            summary: "Queue Home Assistant light color temperature action",
            usage: "homeassistant.set_color_temp <entity-id> <kelvin>",
            minArgs: 2,
            maxArgs: 2
        }), IpcContracts.createShellIpcCommandSpec({
            name: "homeassistant.activate_scene",
            summary: "Queue Home Assistant scene activation action",
            usage: "homeassistant.activate_scene <entity-id>",
            minArgs: 1,
            maxArgs: 1
        })]
    readonly property var shellIpcCommandHandlers: ({
            "session.toggle": function () {
                return root.toggleSessionOverlayWithOutcome();
            },
            "session.open": function () {
                return root.setSessionOverlayOpen(true, "session.overlay.opened");
            },
            "session.close": function () {
                return root.setSessionOverlayOpen(false, "session.overlay.closed");
            },
            "shell.command.run": function (args) {
                return root.runExternalCommand(args);
            },
            "launcher.search": function (args) {
                return root.runLauncherSearchFromArgs(args);
            },
            "launcher.toggle": function () {
                return root.toggleLauncherOverlayWithOutcome();
            },
            "launcher.open": function () {
                return root.setLauncherOverlayOpen(true, "launcher.overlay.opened");
            },
            "launcher.close": function () {
                return root.setLauncherOverlayOpen(false, "launcher.overlay.closed");
            },
            "launcher.activate": function (args) {
                return root.activateLauncherItemById(args[0]);
            },
            "launcher.describe": function () {
                return root.describeLauncher();
            },
            "launcher.providers.describe": function () {
                return root.describeLauncherAsyncProviders();
            },
            "launcher.catalog.describe": function () {
                return root.describeLauncherCatalog();
            },
            "launcher.integrations.describe": function () {
                return root.describeLauncherIntegrations();
            },
            "integrations.health": function () {
                return root.describeOptionalIntegrationsHealth();
            },
            "settings.reload": function () {
                return root.reloadSettings();
            },
            "settings.describe": function () {
                return root.describeSettings();
            },
            "settings.paths": function () {
                return root.describePersistencePaths();
            },
            "settings.session_overlay.enable": function () {
                return root.setSessionOverlayEnabledSetting(true);
            },
            "settings.session_overlay.disable": function () {
                return root.setSessionOverlayEnabledSetting(false);
            },
            "settings.launcher.command_prefix.set": function (args) {
                return root.setLauncherCommandPrefixSetting(args[0]);
            },
            "settings.launcher.max_results.set": function (args) {
                return root.setLauncherMaxResultsSetting(args[0]);
            },
            "settings.launcher.pin_command": function (args) {
                return root.pinLauncherCommandSetting(args[0]);
            },
            "settings.launcher.unpin_command": function (args) {
                return root.unpinLauncherCommandSetting(args[0]);
            },
            "settings.launcher.personalization.reset": function () {
                return root.resetLauncherPersonalizationSetting();
            },
            "settings.persist": function () {
                return root.persistSettings();
            },
            "settings.integrations.homeassistant.enable": function () {
                return root.setHomeAssistantIntegrationEnabledSetting(true);
            },
            "settings.integrations.homeassistant.disable": function () {
                return root.setHomeAssistantIntegrationEnabledSetting(false);
            },
            "settings.integrations.launcher.homeassistant.enable": function () {
                return root.setLauncherHomeAssistantIntegrationEnabledSetting(true);
            },
            "settings.integrations.launcher.homeassistant.disable": function () {
                return root.setLauncherHomeAssistantIntegrationEnabledSetting(false);
            },
            "settings.integrations.launcher.emoji.enable": function () {
                return root.setLauncherEmojiIntegrationEnabledSetting(true);
            },
            "settings.integrations.launcher.emoji.disable": function () {
                return root.setLauncherEmojiIntegrationEnabledSetting(false);
            },
            "settings.integrations.launcher.clipboard.enable": function () {
                return root.setLauncherClipboardIntegrationEnabledSetting(true);
            },
            "settings.integrations.launcher.clipboard.disable": function () {
                return root.setLauncherClipboardIntegrationEnabledSetting(false);
            },
            "settings.integrations.launcher.file_search.enable": function () {
                return root.setLauncherFileSearchIntegrationEnabledSetting(true);
            },
            "settings.integrations.launcher.file_search.disable": function () {
                return root.setLauncherFileSearchIntegrationEnabledSetting(false);
            },
            "settings.integrations.launcher.wallpaper.enable": function () {
                return root.setLauncherWallpaperIntegrationEnabledSetting(true);
            },
            "settings.integrations.launcher.wallpaper.disable": function () {
                return root.setLauncherWallpaperIntegrationEnabledSetting(false);
            },
            "theme.describe": function () {
                return root.describeTheme();
            },
            "theme.regenerate": function () {
                return root.regenerateTheme();
            },
            "theme.provider.set": function (args) {
                return root.setThemeProvider(args[0]);
            },
            "theme.mode.set": function (args) {
                return root.setThemeMode(args[0]);
            },
            "theme.variant.set": function (args) {
                return root.setThemeVariant(args[0]);
            },
            "notifications.describe": function () {
                return root.describeNotifications();
            },
            "notifications.mark_all_read": function () {
                return root.markAllNotificationsRead();
            },
            "notifications.clear_history": function () {
                return root.clearNotificationHistory();
            },
            "notifications.clear_entry": function (args) {
                return root.clearNotificationEntryByKey(args[0]);
            },
            "notifications.dismiss_popup": function (args) {
                return root.dismissNotificationPopupByKey(args[0]);
            },
            "notifications.activate": function (args) {
                return root.activateNotificationEntryByKey(args[0]);
            },
            "notifications.activate_action": function (args) {
                return root.activateNotificationEntryActionByKey(args[0], args[1]);
            },
            "wallpaper.describe": function () {
                return root.describeWallpaperIntegration();
            },
            "wallpaper.refresh_catalog": function () {
                return root.refreshWallpaperCatalog();
            },
            "wallpaper.set": function (args) {
                return root.setWallpaper(args[0]);
            },
            "wallpaper.random": function () {
                return root.setRandomWallpaper();
            },
            "wallpaper.previous": function () {
                return root.setPreviousWallpaper();
            },
            "wallpaper.next": function () {
                return root.setNextWallpaper();
            },
            "wallpaper.history.describe": function () {
                return root.describeWallpaperHistory();
            },
            "homeassistant.describe": function () {
                return root.describeHomeAssistant();
            },
            "homeassistant.refresh": function () {
                return root.refreshHomeAssistant();
            },
            "homeassistant.toggle_light": function (args) {
                return root.toggleHomeAssistantLight(args[0]);
            },
            "homeassistant.turn_on_light": function (args) {
                return root.turnOnHomeAssistantLight(args[0]);
            },
            "homeassistant.turn_off_light": function (args) {
                return root.turnOffHomeAssistantLight(args[0]);
            },
            "homeassistant.set_brightness": function (args) {
                return root.setHomeAssistantBrightness(args[0], args[1]);
            },
            "homeassistant.set_color_temp": function (args) {
                return root.setHomeAssistantColorTemp(args[0], args[1]);
            },
            "homeassistant.activate_scene": function (args) {
                return root.activateHomeAssistantScene(args[0]);
            }
        })

    Timer {
        id: settingsPersistTimer
        interval: root.settingsAutoPersistIntervalMs
        repeat: false
        running: false
        onTriggered: {
            root.persistSettingsIfDirty("settings.auto_persist");
        }
    }

    Timer {
        id: launcherTelemetryFlushTimer
        interval: root.launcherTelemetryFlushIntervalMs
        repeat: false
        running: false
        onTriggered: {
            root.flushLauncherTelemetryQueue();
        }
    }

    Timer {
        id: notificationHistorySyncTimer
        interval: root.notificationHistorySyncIntervalMs
        repeat: false
        running: false
        onTriggered: {
            root.flushNotificationHistorySync();
        }
    }

    Timer {
        id: launcherAsyncProviderSweepTimer
        interval: root.launcherAsyncProviderSweepIntervalMs
        repeat: true
        running: true
        onTriggered: {
            root.expireLauncherAsyncProviders();
        }
    }

    Connections {
        target: root.themeBridge
        function onSchemeChanged() {
            root.syncThemeSingletonScheme();
        }
    }

    Component.onCompleted: {
        root.reloadSettings();
        root.syncThemeSingletonScheme();
    }

    function settingsUpdateDeps() {
        return {
            "validateSettingsConfigDocument": SettingsContracts.validateSettingsConfigDocument,
            "validateSettingsStateDocument": SettingsContracts.validateSettingsStateDocument,
            "createRuntimeSettings": SettingsContracts.createRuntimeSettings,
            "outcomes": OperationOutcomes
        };
    }

    function settingsPersistenceDeps() {
        return {
            "validateSettingsConfigDocument": SettingsContracts.validateSettingsConfigDocument,
            "validateSettingsStateDocument": SettingsContracts.validateSettingsStateDocument,
            "outcomes": OperationOutcomes,
            "persistencePort": root.persistencePort
        };
    }

    function createDefaultSettingsConfigDocumentWithRuntimeDefaults() {
        const defaults = SettingsContracts.createDefaultSettingsConfigDocument();
        const themeDefaults = defaults.theme && typeof defaults.theme === "object" ? defaults.theme : {};
        defaults.theme = themeDefaults;
        themeDefaults.providerId = String(root.themeProviderId || "static").trim() || "static";
        themeDefaults.fallbackProviderId = String(root.themeFallbackProviderId || "static").trim() || "static";
        themeDefaults.mode = String(root.themeMode || "dark").trim().toLowerCase() === "light" ? "light" : "dark";
        themeDefaults.variant = String(root.themeVariant || "tonal-spot").trim() || "tonal-spot";
        const sourceKind = String(root.themeSourceKind || "static").trim().toLowerCase();
        themeDefaults.sourceKind = sourceKind === "wallpaper" || sourceKind === "color" || sourceKind === "file" || sourceKind === "generated" || sourceKind === "static" ? sourceKind : "static";
        themeDefaults.sourceValue = String(root.themeSourceValue || "");
        themeDefaults.matugenSchemePath = String(root.themeMatugenSchemePath || "");

        const integrationDefaults = defaults.integrations && typeof defaults.integrations === "object" ? defaults.integrations : {};
        defaults.integrations = integrationDefaults;
        const integrationOverrides = integrationEnvOverrides();
        integrationDefaults.homeAssistantEnabled = integrationOverrides.homeAssistantEnabled === null ? root.homeAssistantIntegrationEnabled : integrationOverrides.homeAssistantEnabled;
        integrationDefaults.launcherHomeAssistantEnabled = integrationOverrides.launcherHomeAssistantEnabled === null ? root.launcherHomeAssistantIntegrationEnabled : integrationOverrides.launcherHomeAssistantEnabled;
        integrationDefaults.launcherEmojiEnabled = integrationOverrides.launcherEmojiEnabled === null ? root.launcherEmojiIntegrationEnabled : integrationOverrides.launcherEmojiEnabled;
        integrationDefaults.launcherClipboardEnabled = integrationOverrides.launcherClipboardEnabled === null ? root.launcherClipboardIntegrationEnabled : integrationOverrides.launcherClipboardEnabled;
        integrationDefaults.launcherFileSearchEnabled = integrationOverrides.launcherFileSearchEnabled === null ? root.launcherFileSearchIntegrationEnabled : integrationOverrides.launcherFileSearchEnabled;
        integrationDefaults.launcherWallpaperEnabled = integrationOverrides.launcherWallpaperEnabled === null ? root.launcherWallpaperIntegrationEnabled : integrationOverrides.launcherWallpaperEnabled;
        return defaults;
    }

    function currentRuntimeSettings() {
        if (settingsStore && settingsStore.state && settingsStore.state.runtime && typeof settingsStore.state.runtime === "object")
            return settingsStore.state.runtime;

        return SettingsContracts.createRuntimeSettings(SettingsContracts.createDefaultSettingsConfigDocument(), SettingsContracts.createDefaultSettingsStateDocument());
    }

    function isSettingsDirty() {
        return Boolean(settingsStore && settingsStore.state && Number(settingsStore.state.revision) > Number(settingsStore.state.persistedRevision));
    }

    function isSessionOverlayEnabled() {
        const runtimeSettings = currentRuntimeSettings();
        return !runtimeSettings.session || runtimeSettings.session.overlayEnabled !== false;
    }

    function currentLauncherSettings() {
        const runtimeSettings = currentRuntimeSettings();
        if (runtimeSettings && runtimeSettings.launcher && typeof runtimeSettings.launcher === "object")
            return runtimeSettings.launcher;

        return {
            commandPrefix: ">",
            maxResults: 8,
            lastQuery: "",
            pinnedCommandIds: [],
            telemetry: {
                usageItemCount: 0,
                queryHistoryEntryCount: 0
            }
        };
    }

    function currentThemeSettings() {
        const runtimeSettings = currentRuntimeSettings();
        if (runtimeSettings && runtimeSettings.theme && typeof runtimeSettings.theme === "object")
            return runtimeSettings.theme;

        return {
            providerId: "static",
            fallbackProviderId: "static",
            mode: "dark",
            variant: "tonal-spot",
            sourceKind: "static",
            sourceValue: "",
            matugenSchemePath: ""
        };
    }

    function envBooleanOverride(name) {
        const raw = Quickshell.env(String(name || ""));
        if (raw === undefined || raw === null)
            return null;

        const normalized = String(raw).trim().toLowerCase();
        if (!normalized)
            return null;
        if (normalized === "0" || normalized === "false" || normalized === "off" || normalized === "no")
            return false;
        return true;
    }

    function integrationEnvOverrides() {
        return {
            launcherEmojiEnabled: envBooleanOverride("RBW_LAUNCHER_EMOJI_ENABLED"),
            launcherClipboardEnabled: envBooleanOverride("RBW_LAUNCHER_CLIPBOARD_ENABLED"),
            launcherFileSearchEnabled: envBooleanOverride("RBW_LAUNCHER_FILE_SEARCH_ENABLED"),
            launcherWallpaperEnabled: envBooleanOverride("RBW_LAUNCHER_WALLPAPER_ENABLED"),
            homeAssistantEnabled: envBooleanOverride("RBW_HOME_ASSISTANT_ENABLED"),
            launcherHomeAssistantEnabled: envBooleanOverride("RBW_LAUNCHER_HOME_ASSISTANT_ENABLED")
        };
    }

    function currentIntegrationSettings() {
        const runtimeSettings = currentRuntimeSettings();
        const integrations = runtimeSettings && runtimeSettings.integrations && typeof runtimeSettings.integrations === "object" ? runtimeSettings.integrations : {};

        return {
            launcherEmojiEnabled: integrations.launcherEmojiEnabled !== false,
            launcherClipboardEnabled: integrations.launcherClipboardEnabled !== false,
            launcherFileSearchEnabled: integrations.launcherFileSearchEnabled !== false,
            launcherWallpaperEnabled: integrations.launcherWallpaperEnabled !== false,
            homeAssistantEnabled: integrations.homeAssistantEnabled !== false,
            launcherHomeAssistantEnabled: integrations.launcherHomeAssistantEnabled !== false
        };
    }

    function applyIntegrationRuntimeSettings() {
        const settings = currentIntegrationSettings();
        const overrides = integrationEnvOverrides();
        const resolvedHomeAssistantEnabled = overrides.homeAssistantEnabled === null ? settings.homeAssistantEnabled : overrides.homeAssistantEnabled;

        root.homeAssistantIntegrationEnabled = resolvedHomeAssistantEnabled;
        root.launcherEmojiIntegrationEnabled = overrides.launcherEmojiEnabled === null ? settings.launcherEmojiEnabled : overrides.launcherEmojiEnabled;
        root.launcherClipboardIntegrationEnabled = overrides.launcherClipboardEnabled === null ? settings.launcherClipboardEnabled : overrides.launcherClipboardEnabled;
        root.launcherFileSearchIntegrationEnabled = overrides.launcherFileSearchEnabled === null ? settings.launcherFileSearchEnabled : overrides.launcherFileSearchEnabled;
        root.launcherWallpaperIntegrationEnabled = overrides.launcherWallpaperEnabled === null ? settings.launcherWallpaperEnabled : overrides.launcherWallpaperEnabled;
        root.launcherHomeAssistantIntegrationEnabled = overrides.launcherHomeAssistantEnabled === null ? settings.launcherHomeAssistantEnabled : overrides.launcherHomeAssistantEnabled;
    }

    function syncThemeSingletonScheme() {
        if (typeof Theme === "undefined" || !Theme || typeof Theme.applyThemeScheme !== "function")
            return;
        Theme.applyThemeScheme(root.themeBridge && root.themeBridge.scheme ? root.themeBridge.scheme : null);
    }

    function applyThemeRuntimeSettings() {
        const themeSettings = currentThemeSettings();
        root.themeProviderId = String(themeSettings.providerId === undefined ? "static" : themeSettings.providerId);
        root.themeFallbackProviderId = String(themeSettings.fallbackProviderId === undefined ? "static" : themeSettings.fallbackProviderId);
        root.themeMode = String(themeSettings.mode === undefined ? "dark" : themeSettings.mode).toLowerCase() === "light" ? "light" : "dark";
        root.themeVariant = String(themeSettings.variant === undefined ? "tonal-spot" : themeSettings.variant);
        root.themeSourceKind = String(themeSettings.sourceKind === undefined ? "static" : themeSettings.sourceKind);
        root.themeSourceValue = String(themeSettings.sourceValue === undefined ? "" : themeSettings.sourceValue);
        root.themeMatugenSchemePath = String(themeSettings.matugenSchemePath === undefined ? "" : themeSettings.matugenSchemePath);
    }

    function currentLauncherMaxResults() {
        const launcherSettings = currentLauncherSettings();
        const parsed = Number(launcherSettings.maxResults);
        if (!Number.isInteger(parsed) || parsed < 1)
            return 8;
        if (parsed > 50)
            return 50;
        return parsed;
    }

    function currentLauncherTelemetrySummary() {
        const launcherState = root.settingsStore && root.settingsStore.state && root.settingsStore.state.durableState && root.settingsStore.state.durableState.launcher && typeof root.settingsStore.state.durableState.launcher === "object" ? root.settingsStore.state.durableState.launcher : {
            queryHistory: [],
            usageByItemId: {}
        };

        const queryHistory = Array.isArray(launcherState.queryHistory) ? launcherState.queryHistory : [];
        const usageByItemId = launcherState.usageByItemId && typeof launcherState.usageByItemId === "object" && !Array.isArray(launcherState.usageByItemId) ? launcherState.usageByItemId : {};

        return {
            queryHistoryEntries: queryHistory.length,
            usageItemCount: Object.keys(usageByItemId).length,
            pendingQueueSize: Array.isArray(root.launcherTelemetryQueue) ? root.launcherTelemetryQueue.length : 0,
            queryHistoryRetentionDays: Number(root.launcherQueryHistoryRetentionDays),
            queryHistoryMaxEntries: Number(root.launcherQueryHistoryMaxEntries)
        };
    }

    function currentNotificationsPersistenceSummary() {
        const durableState = root.settingsStore && root.settingsStore.state && root.settingsStore.state.durableState && typeof root.settingsStore.state.durableState === "object" ? root.settingsStore.state.durableState : {};
        const notificationsState = durableState.notifications && typeof durableState.notifications === "object" ? durableState.notifications : {
            history: []
        };
        const history = Array.isArray(notificationsState.history) ? notificationsState.history : [];
        let unreadCount = 0;
        for (let index = 0; index < history.length; index += 1) {
            const entry = history[index];
            if (!entry || entry.read !== true)
                unreadCount += 1;
        }

        return {
            historyEntries: history.length,
            unreadCount: unreadCount,
            pendingQueueSize: root.notificationHistorySyncPending ? 1 : 0,
            maxEntries: Number(root.notificationHistoryMaxEntries)
        };
    }

    function currentLauncherUsageByItemId() {
        const launcherState = root.settingsStore && root.settingsStore.state && root.settingsStore.state.durableState && root.settingsStore.state.durableState.launcher && typeof root.settingsStore.state.durableState.launcher === "object" ? root.settingsStore.state.durableState.launcher : {
            usageByItemId: {}
        };

        const usageByItemId = launcherState.usageByItemId;
        if (!usageByItemId || typeof usageByItemId !== "object" || Array.isArray(usageByItemId))
            return {};
        return usageByItemId;
    }

    function currentLauncherAsyncProviderTimeoutMs() {
        const parsed = Number(root.launcherAsyncProviderTimeoutMs);
        if (!Number.isFinite(parsed) || parsed < 100)
            return 2500;
        if (parsed > 120000)
            return 120000;
        return Math.round(parsed);
    }

    function currentLauncherAsyncProviderFailureRetention() {
        const parsed = Number(root.launcherAsyncProviderFailureRetention);
        if (!Number.isInteger(parsed) || parsed < 1)
            return 24;
        if (parsed > 256)
            return 256;
        return parsed;
    }

    function launcherAsyncProviderRuntimeDeps() {
        return {
            createRegistry: LauncherAsyncProviderRegistry.createRegistry,
            normalizePendingProviderEvent: LauncherAsyncProviderRegistry.normalizePendingProviderEvent,
            createPendingEntry: LauncherAsyncProviderRegistry.createPendingEntry,
            upsertPendingEntry: LauncherAsyncProviderRegistry.upsertPendingEntry,
            removePendingEntry: LauncherAsyncProviderRegistry.removePendingEntry,
            listPendingEntries: LauncherAsyncProviderRegistry.listPendingEntries,
            collectExpiredEntries: LauncherAsyncProviderRegistry.collectExpiredEntries
        };
    }

    function ensureLauncherAsyncProviderRuntime() {
        if (!root.launcherAsyncProviderRuntime || typeof root.launcherAsyncProviderRuntime.handlePendingEvent !== "function")
            root.launcherAsyncProviderRuntime = LauncherAsyncProviderRuntimeUseCases.createLauncherAsyncProviderRuntime(launcherAsyncProviderRuntimeDeps());
        return root.launcherAsyncProviderRuntime;
    }

    function resetLauncherAsyncProviderRuntime() {
        ensureLauncherAsyncProviderRuntime().reset();
    }

    function currentLauncherAsyncProviderRuntimeOptions(nowMs) {
        return {
            nowMs: nowMs === undefined ? Date.now() : Number(nowMs),
            timeoutMs: currentLauncherAsyncProviderTimeoutMs(),
            failureRetention: currentLauncherAsyncProviderFailureRetention(),
            fallbackQuery: root.launcherStore && root.launcherStore.state && root.launcherStore.state.query ? root.launcherStore.state.query : ""
        };
    }

    function launcherAsyncProviderHandlers() {
        return {
            markPending: function (event) {
                if (!root.launcherStore || typeof root.launcherStore.markAsyncProviderPending !== "function")
                    return false;
                return root.launcherStore.markAsyncProviderPending(event);
            },
            resolve: function (event, rawItems) {
                return root.applyLauncherAsyncProviderResolved(event, rawItems);
            },
            reject: function (event, error) {
                return root.applyLauncherAsyncProviderRejected(event, error);
            },
            createTimeoutError: function (entry) {
                const timeoutMs = entry && entry.timeoutMs !== undefined ? Number(entry.timeoutMs) : currentLauncherAsyncProviderTimeoutMs();
                return new Error("Async provider timed out after " + String(timeoutMs) + "ms");
            }
        };
    }

    function expireLauncherAsyncProviders() {
        ensureLauncherAsyncProviderRuntime().expirePending(launcherAsyncProviderHandlers(), currentLauncherAsyncProviderRuntimeOptions(Date.now()));
    }

    function describeLauncherAsyncProviderRuntime(nowMs) {
        return ensureLauncherAsyncProviderRuntime().describe(currentLauncherAsyncProviderRuntimeOptions(nowMs));
    }

    function scoreLauncherItemsWithSignals(items, query) {
        return LauncherScoringPolicy.scoreLauncherItems(items, query, {
            usageByItemId: currentLauncherUsageByItemId(),
            personalizationEnabled: true,
            nowIso: new Date().toISOString(),
            includeScoreMeta: true
        });
    }

    function createLauncherTelemetryQueryEvent(query, source) {
        const normalizedQuery = String(query || "");
        if (!normalizedQuery.trim())
            return null;

        return {
            kind: "query",
            query: normalizedQuery,
            at: new Date().toISOString(),
            source: source === undefined ? "launcher.search" : String(source)
        };
    }

    function createLauncherTelemetryUsageEvent(itemId, source) {
        const normalizedItemId = String(itemId || "").trim();
        if (!normalizedItemId)
            return null;

        return {
            kind: "usage",
            itemId: normalizedItemId,
            at: new Date().toISOString(),
            source: source === undefined ? "launcher.activate" : String(source)
        };
    }

    function enqueueLauncherTelemetryEvent(event) {
        if (!event || typeof event !== "object")
            return;
        if (!Array.isArray(root.launcherTelemetryQueue))
            root.launcherTelemetryQueue = [];

        root.launcherTelemetryQueue.push(event);

        const overflow = root.launcherTelemetryQueue.length - Number(root.launcherTelemetryQueueCapacity);
        if (overflow > 0)
            root.launcherTelemetryQueue.splice(0, overflow);

        launcherTelemetryFlushTimer.restart();
    }

    function dequeueLauncherTelemetryBatch(maxBatchSize) {
        if (!Array.isArray(root.launcherTelemetryQueue) || root.launcherTelemetryQueue.length === 0)
            return [];

        const parsedLimit = Number(maxBatchSize);
        const batchLimit = Number.isInteger(parsedLimit) && parsedLimit > 0 ? parsedLimit : 1;
        const count = Math.min(batchLimit, root.launcherTelemetryQueue.length);
        const batch = root.launcherTelemetryQueue.slice(0, count);
        root.launcherTelemetryQueue.splice(0, count);
        return batch;
    }

    function launcherOptionalProviders() {
        const providers = [];

        if (root.launcherEmojiCatalogAdapter && typeof root.launcherEmojiCatalogAdapter.search === "function") {
            providers.push({
                id: "optional.emoji",
                order: 40,
                modes: ["query"],
                search: function (context) {
                    return root.launcherEmojiCatalogAdapter.search(context.command);
                }
            });
        }

        if (root.launcherClipboardHistoryAdapter && typeof root.launcherClipboardHistoryAdapter.search === "function") {
            providers.push({
                id: "optional.clipboard",
                order: 50,
                modes: ["query"],
                search: function (context) {
                    return root.launcherClipboardHistoryAdapter.search(context.command);
                }
            });
        }

        if (root.launcherFileSearchAdapter && typeof root.launcherFileSearchAdapter.search === "function") {
            providers.push({
                id: "optional.file_search",
                order: 60,
                kind: "async",
                modes: ["query"],
                search: function (context) {
                    return root.launcherFileSearchAdapter.search(context.command);
                }
            });
        }

        if (root.launcherHomeAssistantAdapter && typeof root.launcherHomeAssistantAdapter.search === "function") {
            providers.push({
                id: "optional.homeassistant",
                order: 65,
                modes: ["query"],
                search: function (context) {
                    return root.launcherHomeAssistantAdapter.search(context.command);
                }
            });
        }

        if (root.launcherWallpaperCatalogAdapter && typeof root.launcherWallpaperCatalogAdapter.search === "function") {
            providers.push({
                id: "optional.wallpaper",
                order: 70,
                modes: ["query"],
                search: function (context) {
                    return root.launcherWallpaperCatalogAdapter.search(context.command);
                }
            });
        }

        return providers;
    }

    function launcherSearchDeps() {
        const launcherSettings = currentLauncherSettings();

        return {
            "validateLauncherSearchCommand": LauncherContracts.validateLauncherSearchCommand,
            "scoreLauncherItems": root.scoreLauncherItemsWithSignals,
            "createLauncherResultList": LauncherContracts.createLauncherResultList,
            "outcomes": OperationOutcomes,
            "searchAdapter": LauncherSearchAdapters.createSystemLauncherSearchAdapter({
                "commandPrefix": launcherSettings.commandPrefix,
                "maxResults": currentLauncherMaxResults(),
                "commandSpecs": root.shellIpcCommandSpecs,
                "pinnedCommandIds": launcherSettings.pinnedCommandIds,
                "appSearchAdapter": root.launcherAppCatalogAdapter,
                "providers": root.launcherOptionalProviders(),
                "onAsyncProviderResult": function (event) {
                    root.handleLauncherAsyncProviderPending(event);
                }
            }),
            "limitLauncherItems": function (items) {
                const maxResults = currentLauncherMaxResults();
                const limited = [];

                for (let index = 0; index < items.length && limited.length < maxResults; index += 1)
                    limited.push(items[index]);

                return limited;
            }
        };
    }

    function launcherAsyncProviderDeps() {
        return {
            "scoreLauncherItems": root.scoreLauncherItemsWithSignals,
            "createLauncherResultList": LauncherContracts.createLauncherResultList,
            "outcomes": OperationOutcomes,
            "limitLauncherItems": function (items) {
                const maxResults = currentLauncherMaxResults();
                const limited = [];

                for (let index = 0; index < items.length && limited.length < maxResults; index += 1)
                    limited.push(items[index]);

                return limited;
            }
        };
    }

    function applyLauncherAsyncProviderResolved(event, rawItems) {
        return LauncherAsyncProviderUseCases.applyLauncherAsyncProviderResult(launcherAsyncProviderDeps(), root.launcherStore, event, rawItems);
    }

    function applyLauncherAsyncProviderRejected(event, error) {
        return LauncherAsyncProviderUseCases.failLauncherAsyncProviderResult(launcherAsyncProviderDeps(), root.launcherStore, event, error);
    }

    function handleLauncherAsyncProviderPending(event) {
        return ensureLauncherAsyncProviderRuntime().handlePendingEvent(event, launcherAsyncProviderHandlers(), currentLauncherAsyncProviderRuntimeOptions(Date.now()));
    }

    function dispatchShellIpcCommand(commandName, args, meta) {
        return ShellIpcUseCases.dispatchShellIpcCommand({
            "normalizeShellIpcCommandSpecs": IpcContracts.normalizeShellIpcCommandSpecs,
            "createShellIpcCommand": IpcContracts.createShellIpcCommand,
            "validateOperationOutcome": OperationOutcomes.validateOperationOutcome,
            "outcomes": OperationOutcomes,
            "shellCommandPort": root.shellCommandPort
        }, root.shellIpcCommandSpecs, commandName, args || [], meta || {});
    }

    function launcherActivationDeps() {
        return {
            "validateLauncherItem": LauncherContracts.validateLauncherItem,
            "dispatchShellIpcCommand": root.dispatchShellIpcCommand,
            "commandExecutionPort": root.commandExecutionPort,
            "outcomes": OperationOutcomes
        };
    }

    function nextLauncherGeneration() {
        launcherGenerationCounter += 1;
        return launcherGenerationCounter;
    }

    function argsToQuery(args) {
        if (!Array.isArray(args) || args.length === 0)
            return "";

        return args.join(" ");
    }

    function runLauncherSearchFromArgs(args) {
        const query = argsToQuery(args);
        return runLauncherSearchQuery(query, "launcher.search");
    }

    function runLauncherSearchQuery(query, sourceCode) {
        resetLauncherAsyncProviderRuntime();
        const command = LauncherContracts.createLauncherSearchCommand(String(query || ""), nextLauncherGeneration(), "shell.ipc");
        const outcome = LauncherSearchUseCases.runLauncherSearch(launcherSearchDeps(), root.launcherStore, command);

        if (outcome && outcome.status === "applied")
            root.enqueueLauncherTelemetryEvent(root.createLauncherTelemetryQueryEvent(String(query || ""), sourceCode === undefined ? "launcher.search" : String(sourceCode)));

        return outcome;
    }

    function activateLauncherItemById(itemId) {
        const normalizedId = String(itemId || "");
        if (!normalizedId) {
            return OperationOutcomes.rejected({
                code: "launcher.activate.item_required",
                reason: "launcher.activate requires an item id",
                targetId: "launcher"
            });
        }

        const outcome = LauncherActivationUseCases.activateLauncherItem(launcherActivationDeps(), root.launcherStore, normalizedId);

        if (outcome && outcome.status === "applied")
            root.enqueueLauncherTelemetryEvent(root.createLauncherTelemetryUsageEvent(normalizedId, "launcher.activate"));

        return outcome;
    }

    function activateLauncherItemFromUi(itemId) {
        const outcome = activateLauncherItemById(itemId);

        if (outcome && outcome.status === "applied")
            setLauncherOverlayOpen(false, "launcher.overlay.closed");

        return outcome;
    }

    function describeLauncher() {
        const sections = LauncherSelectors.selectLauncherSections(root.launcherStore.state.results || [], currentLauncherMaxResults());
        const totalItems = LauncherSelectors.countLauncherItems(sections);
        const pendingProviders = Array.isArray(root.launcherStore.state.pendingProviders) ? root.launcherStore.state.pendingProviders : [];
        const runtimeDiagnostics = describeLauncherAsyncProviderRuntime(Date.now());

        return OperationOutcomes.applied({
            code: "launcher.snapshot",
            targetId: "launcher",
            generation: Number(root.launcherStore.state.generation),
            meta: {
                query: root.launcherStore.state.query,
                phase: root.launcherStore.state.phase,
                totalItems: totalItems,
                sourceItemCount: Array.isArray(root.launcherStore.state.sourceItems) ? root.launcherStore.state.sourceItems.length : 0,
                pendingProviders: pendingProviders,
                pendingProviderCount: pendingProviders.length,
                trackedPendingProviderCount: Number(runtimeDiagnostics.pendingProviderCount),
                sections: sections
            }
        });
    }

    function describeLauncherAsyncProviders() {
        const runtimeDiagnostics = describeLauncherAsyncProviderRuntime(Date.now());

        return OperationOutcomes.applied({
            code: "launcher.providers.snapshot",
            targetId: "launcher",
            meta: {
                timeoutMs: runtimeDiagnostics.timeoutMs,
                pendingProviders: runtimeDiagnostics.pendingProviders,
                pendingProviderCount: runtimeDiagnostics.pendingProviderCount,
                recentFailures: runtimeDiagnostics.recentFailures,
                recentFailureCount: runtimeDiagnostics.recentFailureCount
            }
        });
    }

    function describeLauncherCatalog() {
        if (!root.launcherAppCatalogAdapter || typeof root.launcherAppCatalogAdapter.describe !== "function") {
            return OperationOutcomes.rejected({
                code: "launcher.catalog.adapter_unavailable",
                reason: "Launcher app catalog adapter is unavailable",
                targetId: "launcher"
            });
        }

        return OperationOutcomes.applied({
            code: "launcher.catalog.snapshot",
            targetId: "launcher",
            meta: {
                catalog: root.launcherAppCatalogAdapter.describe()
            }
        });
    }

    function describeLauncherIntegrations() {
        const integrations = [];

        if (root.launcherEmojiCatalogAdapter && typeof root.launcherEmojiCatalogAdapter.describe === "function")
            integrations.push(root.launcherEmojiCatalogAdapter.describe());
        else
            integrations.push({
                kind: "adapter.search.emoji_catalog",
                integrationId: "launcher.emoji",
                enabled: false,
                available: false,
                ready: false,
                degraded: true,
                reasonCode: "adapter_unavailable",
                lastUpdatedAt: "",
                entryCount: 0,
                lastError: "Emoji adapter is unavailable"
            });

        if (root.launcherClipboardHistoryAdapter && typeof root.launcherClipboardHistoryAdapter.describe === "function")
            integrations.push(root.launcherClipboardHistoryAdapter.describe());
        else
            integrations.push({
                kind: "adapter.search.clipboard_history",
                integrationId: "launcher.clipboard_history",
                enabled: false,
                available: false,
                ready: false,
                degraded: true,
                reasonCode: "adapter_unavailable",
                lastUpdatedAt: "",
                entryCount: 0,
                refreshing: false,
                autoRefresh: false,
                lastError: "Clipboard history adapter is unavailable"
            });

        if (root.launcherFileSearchAdapter && typeof root.launcherFileSearchAdapter.describe === "function")
            integrations.push(root.launcherFileSearchAdapter.describe());
        else
            integrations.push({
                kind: "adapter.search.file_search",
                integrationId: "launcher.file_search",
                enabled: false,
                available: false,
                ready: false,
                degraded: true,
                reasonCode: "adapter_unavailable",
                lastUpdatedAt: "",
                entryCount: 0,
                searching: false,
                queued: false,
                lastQuery: "",
                lastResultCount: 0,
                lastError: "File search adapter is unavailable"
            });

        if (root.launcherHomeAssistantAdapter && typeof root.launcherHomeAssistantAdapter.describe === "function")
            integrations.push(root.launcherHomeAssistantAdapter.describe());
        else
            integrations.push({
                kind: "adapter.search.homeassistant_launcher",
                integrationId: "launcher.home_assistant",
                enabled: false,
                available: false,
                ready: false,
                degraded: true,
                reasonCode: "adapter_unavailable",
                lastUpdatedAt: "",
                lightCount: 0,
                sceneCount: 0,
                lastError: "Home Assistant launcher adapter is unavailable"
            });

        if (root.launcherWallpaperCatalogAdapter && typeof root.launcherWallpaperCatalogAdapter.describe === "function")
            integrations.push(root.launcherWallpaperCatalogAdapter.describe());
        else
            integrations.push({
                kind: "adapter.search.wallpaper_catalog",
                integrationId: "launcher.wallpaper",
                enabled: false,
                available: false,
                ready: false,
                degraded: true,
                reasonCode: "adapter_unavailable",
                lastUpdatedAt: "",
                entryCount: 0,
                refreshing: false,
                autoRefresh: false,
                lastError: "Wallpaper adapter is unavailable"
            });

        return OperationOutcomes.applied({
            code: "launcher.integrations.snapshot",
            targetId: "launcher",
            meta: {
                integrationCount: integrations.length,
                integrations: integrations
            }
        });
    }

    function collectOptionalIntegrationDiagnostics() {
        const diagnostics = [];
        const launcherOutcome = root.describeLauncherIntegrations();

        if (launcherOutcome && launcherOutcome.status === "applied" && launcherOutcome.meta && Array.isArray(launcherOutcome.meta.integrations)) {
            const launcherIntegrations = launcherOutcome.meta.integrations;
            for (let index = 0; index < launcherIntegrations.length; index += 1)
                diagnostics.push(launcherIntegrations[index]);
        }

        const homeAssistantState = homeAssistantBridgeState();
        if (homeAssistantState && typeof homeAssistantState.describe === "function") {
            diagnostics.push(homeAssistantState.describe());
            return diagnostics;
        }

        diagnostics.push({
            kind: "adapter.integration.home_assistant",
            integrationId: "shell.home_assistant",
            enabled: root.homeAssistantIntegrationEnabled,
            configured: false,
            available: false,
            ready: false,
            degraded: true,
            reasonCode: "bridge_unavailable",
            refreshing: false,
            busy: false,
            queuedActionCount: 0,
            lightCount: 0,
            activeLightCount: 0,
            anyOn: false,
            chipLabel: "",
            summaryLabel: "Unavailable",
            lastUpdatedAt: "",
            lastError: "Home Assistant bridge is unavailable"
        });
        return diagnostics;
    }

    function describeOptionalIntegrationsHealth() {
        const health = OptionalIntegrationHealthUseCases.createOptionalIntegrationsHealthSnapshot({
            integrations: collectOptionalIntegrationDiagnostics()
        });

        return OperationOutcomes.applied({
            code: "integrations.health.snapshot",
            targetId: "shell",
            meta: {
                health: health
            }
        });
    }

    function reloadSettings() {
        settingsPersistTimer.stop();
        launcherTelemetryFlushTimer.stop();
        notificationHistorySyncTimer.stop();
        root.notificationHistorySyncPending = false;
        root.notificationHistoryPendingSnapshot = [];
        resetLauncherAsyncProviderRuntime();
        const outcome = SettingsUseCases.hydrateSettings({
            "createDefaultSettingsConfigDocument": root.createDefaultSettingsConfigDocumentWithRuntimeDefaults,
            "createDefaultSettingsStateDocument": SettingsContracts.createDefaultSettingsStateDocument,
            "validateSettingsConfigDocument": SettingsContracts.validateSettingsConfigDocument,
            "validateSettingsStateDocument": SettingsContracts.validateSettingsStateDocument,
            "createRuntimeSettings": SettingsContracts.createRuntimeSettings,
            "outcomes": OperationOutcomes,
            "persistencePort": root.persistencePort
        }, root.settingsStore, "shell");

        applyThemeRuntimeSettings();
        applyIntegrationRuntimeSettings();
        restoreNotificationHistoryFromSettings();
        restoreWallpaperHistoryFromSettings();
        syncThemeSingletonScheme();

        if (Array.isArray(root.launcherTelemetryQueue) && root.launcherTelemetryQueue.length > 0)
            launcherTelemetryFlushTimer.restart();

        return outcome;
    }

    function persistSettingsIfDirty(sourceCode) {
        if (!isSettingsDirty()) {
            return OperationOutcomes.noop({
                code: "settings.persist_not_required",
                reason: "Settings persistence is already up to date",
                targetId: "shell",
                meta: {
                    source: sourceCode
                }
            });
        }

        return SettingsPersistUseCases.persistSettings(settingsPersistenceDeps(), root.settingsStore, "shell", sourceCode);
    }

    function persistSettings() {
        if (root.notificationHistorySyncPending)
            flushNotificationHistorySync();
        return persistSettingsIfDirty("settings.manual_persist");
    }

    function scheduleSettingsPersist(sourceCode) {
        if (!root.settingsAutoPersistEnabled)
            return;
        if (!isSettingsDirty())
            return;

        settingsPersistTimer.restart();
    }

    function appendLauncherTelemetryBatchSetting(events) {
        const outcome = SettingsUpdateUseCases.applyLauncherTelemetryBatch(settingsUpdateDeps(), root.settingsStore, events, {
            queryHistoryRetentionDays: Number(root.launcherQueryHistoryRetentionDays),
            maxQueryHistoryEntries: Number(root.launcherQueryHistoryMaxEntries)
        });
        return finalizeSettingsMutation(outcome, "settings.launcher.telemetry.updated");
    }

    function flushLauncherTelemetryQueue() {
        if (!Array.isArray(root.launcherTelemetryQueue) || root.launcherTelemetryQueue.length === 0) {
            return OperationOutcomes.noop({
                code: "settings.launcher.telemetry.flush.noop",
                reason: "Launcher telemetry queue is empty",
                targetId: "shell"
            });
        }

        if (!root.settingsStore || !root.settingsStore.state || root.settingsStore.state.phase !== "ready") {
            launcherTelemetryFlushTimer.restart();
            return OperationOutcomes.noop({
                code: "settings.launcher.telemetry.flush.deferred",
                reason: "Settings store is not ready for launcher telemetry flush",
                targetId: "shell"
            });
        }

        const batch = dequeueLauncherTelemetryBatch(Number(root.launcherTelemetryMaxBatchSize));
        if (batch.length === 0)
            return OperationOutcomes.noop({
                code: "settings.launcher.telemetry.flush.noop",
                reason: "Launcher telemetry queue is empty",
                targetId: "shell"
            });

        const outcome = appendLauncherTelemetryBatchSetting(batch);
        if (!outcome || (outcome.status !== "applied" && outcome.status !== "noop")) {
            root.launcherTelemetryQueue = batch.concat(root.launcherTelemetryQueue);
            launcherTelemetryFlushTimer.restart();
            return outcome;
        }

        if (root.launcherTelemetryQueue.length > 0)
            launcherTelemetryFlushTimer.restart();

        return outcome;
    }

    function currentPersistedNotificationHistory() {
        const state = root.settingsStore && root.settingsStore.state ? root.settingsStore.state : null;
        const durableState = state && state.durableState && typeof state.durableState === "object" ? state.durableState : null;
        const notificationsState = durableState && durableState.notifications && typeof durableState.notifications === "object" ? durableState.notifications : null;
        return NotificationContracts.cloneNotificationEntries(notificationsState && Array.isArray(notificationsState.history) ? notificationsState.history : []);
    }

    function restoreNotificationHistoryFromSettings() {
        if (!root.notificationBridge || typeof root.notificationBridge.restoreHistory !== "function")
            return OperationOutcomes.noop({
                code: "notifications.history.restore.bridge_unavailable",
                reason: "Notification bridge does not support history restore",
                targetId: "notifications"
            });

        return root.notificationBridge.restoreHistory(currentPersistedNotificationHistory(), "settings.reload");
    }

    function queueNotificationHistorySync(historyEntries) {
        if (!root.notificationHistorySyncEnabled)
            return;

        root.notificationHistoryPendingSnapshot = NotificationContracts.cloneNotificationEntries(Array.isArray(historyEntries) ? historyEntries : []);
        root.notificationHistorySyncPending = true;
        notificationHistorySyncTimer.restart();
    }

    function setNotificationHistorySetting(historyEntries) {
        const outcome = SettingsUpdateUseCases.setNotificationHistory(settingsUpdateDeps(), root.settingsStore, historyEntries, {
            maxEntries: Number(root.notificationHistoryMaxEntries)
        });
        return finalizeSettingsMutation(outcome, "settings.notifications.history.updated");
    }

    function currentPersistedWallpaperHistoryState() {
        const state = root.settingsStore && root.settingsStore.state ? root.settingsStore.state : null;
        const durableState = state && state.durableState && typeof state.durableState === "object" ? state.durableState : null;
        const wallpaperState = durableState && durableState.wallpaper && typeof durableState.wallpaper === "object" ? durableState.wallpaper : null;
        const history = wallpaperState && Array.isArray(wallpaperState.history) ? wallpaperState.history : [];
        const cursor = wallpaperState && Number.isInteger(Number(wallpaperState.cursor)) ? Number(wallpaperState.cursor) : -1;

        return WallpaperWorkflowUseCases.createWallpaperHistoryState({
            entries: history,
            cursor: cursor,
            limit: Number(root.wallpaperHistoryLimit)
        });
    }

    function restoreWallpaperHistoryFromSettings() {
        root.wallpaperHistoryState = currentPersistedWallpaperHistoryState();
    }

    function setWallpaperHistorySetting(historyEntries, cursor) {
        const outcome = SettingsUpdateUseCases.setWallpaperHistory(settingsUpdateDeps(), root.settingsStore, historyEntries, cursor, {
            maxEntries: Number(root.wallpaperHistoryLimit)
        });
        return finalizeSettingsMutation(outcome, "settings.wallpaper.history.updated");
    }

    function syncWallpaperHistorySetting() {
        if (!root.settingsStore || !root.settingsStore.state || root.settingsStore.state.phase !== "ready") {
            return OperationOutcomes.noop({
                code: "settings.wallpaper.history.sync.deferred",
                reason: "Settings store is not ready for wallpaper history sync",
                targetId: "shell"
            });
        }

        const state = ensureWallpaperHistoryState();
        const entries = state && Array.isArray(state.entries) ? state.entries : [];
        const cursor = state && Number.isInteger(Number(state.cursor)) ? Number(state.cursor) : -1;
        return setWallpaperHistorySetting(entries, cursor);
    }

    function flushNotificationHistorySync() {
        if (!root.notificationHistorySyncPending) {
            return OperationOutcomes.noop({
                code: "settings.notifications.history.sync.noop",
                reason: "Notification history sync queue is empty",
                targetId: "shell"
            });
        }

        if (!root.settingsStore || !root.settingsStore.state || root.settingsStore.state.phase !== "ready") {
            notificationHistorySyncTimer.restart();
            return OperationOutcomes.noop({
                code: "settings.notifications.history.sync.deferred",
                reason: "Settings store is not ready for notification history sync",
                targetId: "shell"
            });
        }

        const snapshot = NotificationContracts.cloneNotificationEntries(root.notificationHistoryPendingSnapshot);
        const outcome = setNotificationHistorySetting(snapshot);
        if (!outcome || (outcome.status !== "applied" && outcome.status !== "noop")) {
            notificationHistorySyncTimer.restart();
            return outcome;
        }

        root.notificationHistorySyncPending = false;
        root.notificationHistoryPendingSnapshot = [];
        return outcome;
    }

    function finalizeSettingsMutation(outcome, sourceCode) {
        if (outcome && outcome.status === "applied")
            scheduleSettingsPersist(sourceCode);
        return outcome;
    }

    function setSessionOverlayEnabledSetting(enabled) {
        const outcome = SettingsUpdateUseCases.setSessionOverlayEnabled(settingsUpdateDeps(), root.settingsStore, enabled);
        return finalizeSettingsMutation(outcome, "settings.session_overlay.updated");
    }

    function setLauncherCommandPrefixSetting(commandPrefix) {
        const outcome = SettingsUpdateUseCases.setLauncherCommandPrefix(settingsUpdateDeps(), root.settingsStore, commandPrefix);
        return finalizeSettingsMutation(outcome, "settings.launcher.command_prefix.updated");
    }

    function setLauncherMaxResultsSetting(maxResults) {
        const outcome = SettingsUpdateUseCases.setLauncherMaxResults(settingsUpdateDeps(), root.settingsStore, maxResults);
        return finalizeSettingsMutation(outcome, "settings.launcher.max_results.updated");
    }

    function setLauncherLastQuerySetting(lastQuery) {
        const outcome = SettingsUpdateUseCases.setLauncherLastQuery(settingsUpdateDeps(), root.settingsStore, lastQuery);
        return finalizeSettingsMutation(outcome, "settings.launcher.last_query.updated");
    }

    function setThemeProviderSetting(providerId) {
        const outcome = SettingsUpdateUseCases.setThemeProviderId(settingsUpdateDeps(), root.settingsStore, providerId);
        if (outcome && outcome.status === "applied")
            applyThemeRuntimeSettings();
        return finalizeSettingsMutation(outcome, "settings.theme.provider.updated");
    }

    function setThemeModeSetting(mode) {
        const outcome = SettingsUpdateUseCases.setThemeMode(settingsUpdateDeps(), root.settingsStore, mode);
        if (outcome && outcome.status === "applied")
            applyThemeRuntimeSettings();
        return finalizeSettingsMutation(outcome, "settings.theme.mode.updated");
    }

    function setThemeVariantSetting(variant) {
        const outcome = SettingsUpdateUseCases.setThemeVariant(settingsUpdateDeps(), root.settingsStore, variant);
        if (outcome && outcome.status === "applied")
            applyThemeRuntimeSettings();
        return finalizeSettingsMutation(outcome, "settings.theme.variant.updated");
    }

    function setHomeAssistantIntegrationEnabledSetting(enabled) {
        const outcome = SettingsUpdateUseCases.setHomeAssistantIntegrationEnabled(settingsUpdateDeps(), root.settingsStore, enabled);
        if (outcome && outcome.status === "applied")
            applyIntegrationRuntimeSettings();
        return finalizeSettingsMutation(outcome, "settings.integrations.homeassistant.updated");
    }

    function setLauncherHomeAssistantIntegrationEnabledSetting(enabled) {
        const outcome = SettingsUpdateUseCases.setLauncherHomeAssistantIntegrationEnabled(settingsUpdateDeps(), root.settingsStore, enabled);
        if (outcome && outcome.status === "applied")
            applyIntegrationRuntimeSettings();
        return finalizeSettingsMutation(outcome, "settings.integrations.launcher_homeassistant.updated");
    }

    function setLauncherEmojiIntegrationEnabledSetting(enabled) {
        const outcome = SettingsUpdateUseCases.setLauncherEmojiIntegrationEnabled(settingsUpdateDeps(), root.settingsStore, enabled);
        if (outcome && outcome.status === "applied")
            applyIntegrationRuntimeSettings();
        return finalizeSettingsMutation(outcome, "settings.integrations.launcher_emoji.updated");
    }

    function setLauncherClipboardIntegrationEnabledSetting(enabled) {
        const outcome = SettingsUpdateUseCases.setLauncherClipboardIntegrationEnabled(settingsUpdateDeps(), root.settingsStore, enabled);
        if (outcome && outcome.status === "applied")
            applyIntegrationRuntimeSettings();
        return finalizeSettingsMutation(outcome, "settings.integrations.launcher_clipboard.updated");
    }

    function setLauncherFileSearchIntegrationEnabledSetting(enabled) {
        const outcome = SettingsUpdateUseCases.setLauncherFileSearchIntegrationEnabled(settingsUpdateDeps(), root.settingsStore, enabled);
        if (outcome && outcome.status === "applied")
            applyIntegrationRuntimeSettings();
        return finalizeSettingsMutation(outcome, "settings.integrations.launcher_file_search.updated");
    }

    function setLauncherWallpaperIntegrationEnabledSetting(enabled) {
        const outcome = SettingsUpdateUseCases.setLauncherWallpaperIntegrationEnabled(settingsUpdateDeps(), root.settingsStore, enabled);
        if (outcome && outcome.status === "applied")
            applyIntegrationRuntimeSettings();
        return finalizeSettingsMutation(outcome, "settings.integrations.launcher_wallpaper.updated");
    }

    function pinLauncherCommandSetting(commandId) {
        const outcome = SettingsUpdateUseCases.pinLauncherCommand(settingsUpdateDeps(), root.settingsStore, commandId);
        return finalizeSettingsMutation(outcome, "settings.launcher.pin_command.updated");
    }

    function unpinLauncherCommandSetting(commandId) {
        const outcome = SettingsUpdateUseCases.unpinLauncherCommand(settingsUpdateDeps(), root.settingsStore, commandId);
        return finalizeSettingsMutation(outcome, "settings.launcher.unpin_command.updated");
    }

    function resetLauncherPersonalizationSetting() {
        launcherTelemetryFlushTimer.stop();
        root.launcherTelemetryQueue = [];
        const outcome = SettingsUpdateUseCases.resetLauncherPersonalization(settingsUpdateDeps(), root.settingsStore);
        return finalizeSettingsMutation(outcome, "settings.launcher.personalization.reset");
    }

    function currentPersistenceDescription() {
        if (!root.settingsPersistenceAdapter || typeof root.settingsPersistenceAdapter.describe !== "function")
            return {
                kind: "adapter.persistence.unknown"
            };

        return root.settingsPersistenceAdapter.describe();
    }

    function describePersistencePaths() {
        return OperationOutcomes.applied({
            code: "settings.persistence.paths",
            targetId: "shell",
            meta: {
                persistence: currentPersistenceDescription()
            }
        });
    }

    function describeSettings() {
        return OperationOutcomes.applied({
            code: "settings.snapshot",
            targetId: "shell",
            meta: {
                phase: root.settingsStore && root.settingsStore.state ? root.settingsStore.state.phase : "unknown",
                revision: root.settingsStore && root.settingsStore.state ? Number(root.settingsStore.state.revision) : 0,
                persistedRevision: root.settingsStore && root.settingsStore.state ? Number(root.settingsStore.state.persistedRevision) : 0,
                dirty: isSettingsDirty(),
                runtime: currentRuntimeSettings(),
                launcherTelemetry: currentLauncherTelemetrySummary(),
                notifications: currentNotificationsPersistenceSummary(),
                persistence: currentPersistenceDescription()
            }
        });
    }

    function wallpaperIntegrationState() {
        if (!root.launcherWallpaperCatalogAdapter)
            return null;
        return root.launcherWallpaperCatalogAdapter;
    }

    function ensureWallpaperIntegrationMethod(methodName, fallbackCode) {
        const state = wallpaperIntegrationState();
        if (!state || typeof state[methodName] !== "function") {
            return OperationOutcomes.rejected({
                code: fallbackCode,
                reason: "Wallpaper integration adapter is unavailable",
                targetId: "wallpaper"
            });
        }

        return null;
    }

    function ensureWallpaperIntegrationEnabled(state, fallbackCode) {
        if (!state || state.enabled !== true) {
            return OperationOutcomes.rejected({
                code: fallbackCode,
                reason: "Wallpaper integration is disabled",
                targetId: "wallpaper"
            });
        }

        return null;
    }

    function normalizeWallpaperPath(path) {
        const normalized = String(path || "").trim();
        if (!normalized.startsWith("/"))
            return "";
        return normalized;
    }

    function ensureWallpaperHistoryState() {
        if (root.wallpaperHistoryState && typeof root.wallpaperHistoryState === "object" && !Array.isArray(root.wallpaperHistoryState))
            return root.wallpaperHistoryState;

        root.wallpaperHistoryState = WallpaperWorkflowUseCases.createWallpaperHistoryState({
            limit: Number(root.wallpaperHistoryLimit)
        });
        return root.wallpaperHistoryState;
    }

    function appendWallpaperHistory(path, sourceCode) {
        root.wallpaperHistoryState = WallpaperWorkflowUseCases.appendWallpaperHistoryEntry(ensureWallpaperHistoryState(), path, sourceCode, new Date().toISOString());
        syncWallpaperHistorySetting();
    }

    function describeWallpaperHistory() {
        const snapshot = WallpaperWorkflowUseCases.describeWallpaperHistory(ensureWallpaperHistoryState(), 128);
        return OperationOutcomes.applied({
            code: "wallpaper.history.snapshot",
            targetId: "wallpaper",
            meta: {
                history: snapshot
            }
        });
    }

    function dispatchWallpaperSet(normalizedPath, sourceCode) {
        const state = wallpaperIntegrationState();
        const normalizedSourceCode = String(sourceCode || "wallpaper.set").trim() || "wallpaper.set";
        const codePrefix = normalizedSourceCode;

        if (!root.commandExecutionPort || typeof root.commandExecutionPort.execute !== "function") {
            return OperationOutcomes.rejected({
                code: codePrefix + ".command_port_unavailable",
                reason: "Command execution port is unavailable",
                targetId: normalizedPath
            });
        }

        const commandPath = String(state && state.applyCommandPath ? state.applyCommandPath : "swww");
        const dispatched = root.commandExecutionPort.execute([commandPath, "img", normalizedPath]);
        if (!dispatched) {
            return OperationOutcomes.failed({
                code: codePrefix + ".dispatch_failed",
                reason: "Wallpaper command dispatch failed",
                targetId: normalizedPath
            });
        }

        return OperationOutcomes.applied({
            code: codePrefix + ".dispatched",
            targetId: normalizedPath,
            meta: {
                commandPath: commandPath,
                source: normalizedSourceCode
            }
        });
    }

    function describeWallpaperIntegration() {
        const guard = ensureWallpaperIntegrationMethod("describe", "wallpaper.describe.adapter_unavailable");
        if (guard)
            return guard;

        const state = wallpaperIntegrationState();
        return OperationOutcomes.applied({
            code: "wallpaper.snapshot",
            targetId: "wallpaper",
            meta: {
                wallpaper: state.describe()
            }
        });
    }

    function refreshWallpaperCatalog() {
        const guard = ensureWallpaperIntegrationMethod("refresh", "wallpaper.refresh_catalog.adapter_unavailable");
        if (guard)
            return guard;

        const state = wallpaperIntegrationState();
        const enabledGuard = ensureWallpaperIntegrationEnabled(state, "wallpaper.refresh_catalog.disabled");
        if (enabledGuard)
            return enabledGuard;

        state.refresh();
        return OperationOutcomes.applied({
            code: "wallpaper.catalog.refresh_queued",
            targetId: "wallpaper"
        });
    }

    function setWallpaper(path, sourceCode, appendHistory) {
        const state = wallpaperIntegrationState();
        const normalizedSourceCode = String(sourceCode || "wallpaper.set").trim() || "wallpaper.set";
        const codePrefix = normalizedSourceCode;
        const shouldAppendHistory = appendHistory !== false;
        const enabledGuard = ensureWallpaperIntegrationEnabled(state, codePrefix + ".disabled");
        if (enabledGuard)
            return enabledGuard;

        if (!state || state.ready !== true) {
            return OperationOutcomes.rejected({
                code: codePrefix + ".not_ready",
                reason: "Wallpaper integration is not ready",
                targetId: "wallpaper"
            });
        }

        const normalizedPath = normalizeWallpaperPath(path);
        if (!normalizedPath) {
            return OperationOutcomes.rejected({
                code: codePrefix + ".invalid_path",
                reason: "wallpaper.set requires an absolute image path",
                targetId: "wallpaper"
            });
        }

        const outcome = dispatchWallpaperSet(normalizedPath, normalizedSourceCode);
        if (outcome && outcome.status === "applied" && shouldAppendHistory)
            appendWallpaperHistory(normalizedPath, normalizedSourceCode);

        return outcome;
    }

    function setRandomWallpaper() {
        const state = wallpaperIntegrationState();
        const enabledGuard = ensureWallpaperIntegrationEnabled(state, "wallpaper.random.disabled");
        if (enabledGuard)
            return enabledGuard;

        if (!state || state.ready !== true) {
            return OperationOutcomes.rejected({
                code: "wallpaper.random.not_ready",
                reason: "Wallpaper integration is not ready",
                targetId: "wallpaper"
            });
        }

        const currentPath = WallpaperWorkflowUseCases.currentWallpaperPath(ensureWallpaperHistoryState());
        const nextPath = WallpaperWorkflowUseCases.chooseRandomWallpaperPath(state.catalogEntries, currentPath, Math.random());
        if (!nextPath) {
            return OperationOutcomes.noop({
                code: "wallpaper.random.no_candidates",
                reason: "Wallpaper catalog is empty",
                targetId: "wallpaper"
            });
        }

        return setWallpaper(nextPath, "wallpaper.random", true);
    }

    function setPreviousWallpaper() {
        const previous = WallpaperWorkflowUseCases.peekWallpaperHistoryPrevious(ensureWallpaperHistoryState());
        if (!previous.movable || !previous.path) {
            return OperationOutcomes.noop({
                code: "wallpaper.previous.no_history",
                reason: "No previous wallpaper available in runtime history",
                targetId: "wallpaper"
            });
        }

        const outcome = setWallpaper(previous.path, "wallpaper.previous", false);
        if (outcome && outcome.status === "applied") {
            root.wallpaperHistoryState = WallpaperWorkflowUseCases.setWallpaperHistoryCursor(ensureWallpaperHistoryState(), Number(previous.cursor));
            syncWallpaperHistorySetting();
        }
        return outcome;
    }

    function setNextWallpaper() {
        const next = WallpaperWorkflowUseCases.peekWallpaperHistoryNext(ensureWallpaperHistoryState());
        if (!next.movable || !next.path) {
            return OperationOutcomes.noop({
                code: "wallpaper.next.no_history",
                reason: "No next wallpaper available in runtime history",
                targetId: "wallpaper"
            });
        }

        const outcome = setWallpaper(next.path, "wallpaper.next", false);
        if (outcome && outcome.status === "applied") {
            root.wallpaperHistoryState = WallpaperWorkflowUseCases.setWallpaperHistoryCursor(ensureWallpaperHistoryState(), Number(next.cursor));
            syncWallpaperHistorySetting();
        }
        return outcome;
    }

    onWallpaperHistoryLimitChanged: {
        root.wallpaperHistoryState = WallpaperWorkflowUseCases.createWallpaperHistoryState({
            entries: root.wallpaperHistoryState && Array.isArray(root.wallpaperHistoryState.entries) ? root.wallpaperHistoryState.entries : [],
            cursor: root.wallpaperHistoryState ? root.wallpaperHistoryState.cursor : -1,
            limit: Number(root.wallpaperHistoryLimit)
        });
        syncWallpaperHistorySetting();
    }

    function homeAssistantBridgeState() {
        if (!root.shellChromeBridge)
            return null;
        return root.shellChromeBridge.homeAssistant || null;
    }

    function ensureHomeAssistantBridgeMethod(methodName, fallbackCode) {
        const state = homeAssistantBridgeState();
        if (!state || typeof state[methodName] !== "function") {
            return OperationOutcomes.rejected({
                code: fallbackCode,
                reason: "Home Assistant bridge is unavailable",
                targetId: "homeassistant"
            });
        }

        return null;
    }

    function ensureHomeAssistantEnabledState(state, fallbackCode) {
        if (!state || state.enabled !== true) {
            return OperationOutcomes.rejected({
                code: fallbackCode,
                reason: "Home Assistant integration is disabled",
                targetId: "homeassistant"
            });
        }

        return null;
    }

    function normalizeHomeAssistantEntityId(entityId) {
        const normalized = String(entityId || "").trim();
        if (!/^light\.[a-z0-9_]+$/.test(normalized))
            return "";
        return normalized;
    }

    function normalizeHomeAssistantSceneId(entityId) {
        const normalized = String(entityId || "").trim();
        if (!/^scene\.[a-z0-9_]+$/.test(normalized))
            return "";
        return normalized;
    }

    function parseHomeAssistantInteger(value, minimum, maximum) {
        const parsed = Number(value);
        if (!Number.isInteger(parsed))
            return NaN;
        if (parsed < minimum || parsed > maximum)
            return NaN;
        return parsed;
    }

    function describeHomeAssistant() {
        const guard = ensureHomeAssistantBridgeMethod("describe", "homeassistant.describe.bridge_unavailable");
        if (guard)
            return guard;

        const state = homeAssistantBridgeState();
        return OperationOutcomes.applied({
            code: "homeassistant.snapshot",
            targetId: "homeassistant",
            meta: {
                homeAssistant: state.describe()
            }
        });
    }

    function refreshHomeAssistant() {
        const guard = ensureHomeAssistantBridgeMethod("refresh", "homeassistant.refresh.bridge_unavailable");
        if (guard)
            return guard;

        const state = homeAssistantBridgeState();
        const enabledGuard = ensureHomeAssistantEnabledState(state, "homeassistant.refresh.disabled");
        if (enabledGuard)
            return enabledGuard;

        state.refresh();
        return OperationOutcomes.applied({
            code: "homeassistant.refresh.queued",
            targetId: "homeassistant"
        });
    }

    function toggleHomeAssistantLight(entityId) {
        const guard = ensureHomeAssistantBridgeMethod("toggleLight", "homeassistant.toggle_light.bridge_unavailable");
        if (guard)
            return guard;

        const state = homeAssistantBridgeState();
        const enabledGuard = ensureHomeAssistantEnabledState(state, "homeassistant.toggle_light.disabled");
        if (enabledGuard)
            return enabledGuard;

        const normalizedEntityId = normalizeHomeAssistantEntityId(entityId);
        if (!normalizedEntityId) {
            return OperationOutcomes.rejected({
                code: "homeassistant.toggle_light.invalid_entity_id",
                reason: "Entity id must match light.<id>",
                targetId: "homeassistant"
            });
        }

        if (!state.toggleLight(normalizedEntityId)) {
            return OperationOutcomes.failed({
                code: "homeassistant.toggle_light.dispatch_failed",
                reason: "Failed to queue Home Assistant light toggle action",
                targetId: normalizedEntityId
            });
        }

        return OperationOutcomes.applied({
            code: "homeassistant.toggle_light.queued",
            targetId: normalizedEntityId
        });
    }

    function turnOnHomeAssistantLight(entityId) {
        const guard = ensureHomeAssistantBridgeMethod("turnOnLight", "homeassistant.turn_on_light.bridge_unavailable");
        if (guard)
            return guard;

        const state = homeAssistantBridgeState();
        const enabledGuard = ensureHomeAssistantEnabledState(state, "homeassistant.turn_on_light.disabled");
        if (enabledGuard)
            return enabledGuard;

        const normalizedEntityId = normalizeHomeAssistantEntityId(entityId);
        if (!normalizedEntityId) {
            return OperationOutcomes.rejected({
                code: "homeassistant.turn_on_light.invalid_entity_id",
                reason: "Entity id must match light.<id>",
                targetId: "homeassistant"
            });
        }

        if (!state.turnOnLight(normalizedEntityId)) {
            return OperationOutcomes.failed({
                code: "homeassistant.turn_on_light.dispatch_failed",
                reason: "Failed to queue Home Assistant light turn-on action",
                targetId: normalizedEntityId
            });
        }

        return OperationOutcomes.applied({
            code: "homeassistant.turn_on_light.queued",
            targetId: normalizedEntityId
        });
    }

    function turnOffHomeAssistantLight(entityId) {
        const guard = ensureHomeAssistantBridgeMethod("turnOffLight", "homeassistant.turn_off_light.bridge_unavailable");
        if (guard)
            return guard;

        const state = homeAssistantBridgeState();
        const enabledGuard = ensureHomeAssistantEnabledState(state, "homeassistant.turn_off_light.disabled");
        if (enabledGuard)
            return enabledGuard;

        const normalizedEntityId = normalizeHomeAssistantEntityId(entityId);
        if (!normalizedEntityId) {
            return OperationOutcomes.rejected({
                code: "homeassistant.turn_off_light.invalid_entity_id",
                reason: "Entity id must match light.<id>",
                targetId: "homeassistant"
            });
        }

        if (!state.turnOffLight(normalizedEntityId)) {
            return OperationOutcomes.failed({
                code: "homeassistant.turn_off_light.dispatch_failed",
                reason: "Failed to queue Home Assistant light turn-off action",
                targetId: normalizedEntityId
            });
        }

        return OperationOutcomes.applied({
            code: "homeassistant.turn_off_light.queued",
            targetId: normalizedEntityId
        });
    }

    function setHomeAssistantBrightness(entityId, brightnessPercent) {
        const guard = ensureHomeAssistantBridgeMethod("setBrightness", "homeassistant.set_brightness.bridge_unavailable");
        if (guard)
            return guard;

        const state = homeAssistantBridgeState();
        const enabledGuard = ensureHomeAssistantEnabledState(state, "homeassistant.set_brightness.disabled");
        if (enabledGuard)
            return enabledGuard;

        const normalizedEntityId = normalizeHomeAssistantEntityId(entityId);
        if (!normalizedEntityId) {
            return OperationOutcomes.rejected({
                code: "homeassistant.set_brightness.invalid_entity_id",
                reason: "Entity id must match light.<id>",
                targetId: "homeassistant"
            });
        }

        const normalizedBrightness = parseHomeAssistantInteger(brightnessPercent, 0, 100);
        if (!Number.isInteger(normalizedBrightness)) {
            return OperationOutcomes.rejected({
                code: "homeassistant.set_brightness.invalid_percent",
                reason: "Brightness percent must be an integer in range 0-100",
                targetId: normalizedEntityId
            });
        }

        if (!state.setBrightness(normalizedEntityId, normalizedBrightness)) {
            return OperationOutcomes.failed({
                code: "homeassistant.set_brightness.dispatch_failed",
                reason: "Failed to queue Home Assistant brightness action",
                targetId: normalizedEntityId
            });
        }

        return OperationOutcomes.applied({
            code: "homeassistant.set_brightness.queued",
            targetId: normalizedEntityId,
            meta: {
                brightnessPercent: normalizedBrightness
            }
        });
    }

    function setHomeAssistantColorTemp(entityId, colorTempKelvin) {
        const guard = ensureHomeAssistantBridgeMethod("setColorTemp", "homeassistant.set_color_temp.bridge_unavailable");
        if (guard)
            return guard;

        const state = homeAssistantBridgeState();
        const enabledGuard = ensureHomeAssistantEnabledState(state, "homeassistant.set_color_temp.disabled");
        if (enabledGuard)
            return enabledGuard;

        const normalizedEntityId = normalizeHomeAssistantEntityId(entityId);
        if (!normalizedEntityId) {
            return OperationOutcomes.rejected({
                code: "homeassistant.set_color_temp.invalid_entity_id",
                reason: "Entity id must match light.<id>",
                targetId: "homeassistant"
            });
        }

        const normalizedColorTemp = parseHomeAssistantInteger(colorTempKelvin, 1000, 20000);
        if (!Number.isInteger(normalizedColorTemp)) {
            return OperationOutcomes.rejected({
                code: "homeassistant.set_color_temp.invalid_kelvin",
                reason: "Color temperature must be an integer in range 1000-20000",
                targetId: normalizedEntityId
            });
        }

        if (!state.setColorTemp(normalizedEntityId, normalizedColorTemp)) {
            return OperationOutcomes.failed({
                code: "homeassistant.set_color_temp.dispatch_failed",
                reason: "Failed to queue Home Assistant color temperature action",
                targetId: normalizedEntityId
            });
        }

        return OperationOutcomes.applied({
            code: "homeassistant.set_color_temp.queued",
            targetId: normalizedEntityId,
            meta: {
                colorTempKelvin: normalizedColorTemp
            }
        });
    }

    function activateHomeAssistantScene(entityId) {
        const guard = ensureHomeAssistantBridgeMethod("activateScene", "homeassistant.activate_scene.bridge_unavailable");
        if (guard)
            return guard;

        const state = homeAssistantBridgeState();
        const enabledGuard = ensureHomeAssistantEnabledState(state, "homeassistant.activate_scene.disabled");
        if (enabledGuard)
            return enabledGuard;

        const normalizedEntityId = normalizeHomeAssistantSceneId(entityId);
        if (!normalizedEntityId) {
            return OperationOutcomes.rejected({
                code: "homeassistant.activate_scene.invalid_entity_id",
                reason: "Entity id must match scene.<id>",
                targetId: "homeassistant"
            });
        }

        if (!state.activateScene(normalizedEntityId)) {
            return OperationOutcomes.failed({
                code: "homeassistant.activate_scene.dispatch_failed",
                reason: "Failed to queue Home Assistant scene activation",
                targetId: normalizedEntityId
            });
        }

        return OperationOutcomes.applied({
            code: "homeassistant.activate_scene.queued",
            targetId: normalizedEntityId
        });
    }

    function ensureThemeBridgeMethod(methodName, fallbackCode) {
        if (!root.themeBridge || typeof root.themeBridge[methodName] !== "function") {
            return OperationOutcomes.rejected({
                code: fallbackCode,
                reason: "Theme bridge is unavailable",
                targetId: "theme"
            });
        }

        return null;
    }

    function describeTheme() {
        const guard = ensureThemeBridgeMethod("describe", "theme.bridge_unavailable");
        if (guard)
            return guard;

        return OperationOutcomes.applied({
            code: "theme.snapshot",
            targetId: "theme",
            meta: {
                theme: root.themeBridge.describe()
            }
        });
    }

    function regenerateTheme() {
        const guard = ensureThemeBridgeMethod("regenerate", "theme.regenerate.bridge_unavailable");
        if (guard)
            return guard;
        return root.themeBridge.regenerate("shell.ipc.theme.regenerate");
    }

    function setThemeProvider(providerId) {
        const normalizedProviderId = String(providerId || "").trim();
        const settingsOutcome = setThemeProviderSetting(normalizedProviderId);
        if (!settingsOutcome)
            return settingsOutcome;
        if (settingsOutcome.status === "applied") {
            return OperationOutcomes.applied({
                code: "theme.provider.updated",
                targetId: "theme",
                meta: {
                    providerId: normalizedProviderId
                }
            });
        }
        if (settingsOutcome.status === "noop") {
            return OperationOutcomes.noop({
                code: "theme.provider.noop",
                reason: settingsOutcome.reason || "Theme provider is already selected",
                targetId: "theme",
                meta: {
                    providerId: normalizedProviderId
                }
            });
        }
        return OperationOutcomes.rejected({
            code: "theme.provider.invalid",
            reason: settingsOutcome.reason || "Theme provider id must be a non-empty string",
            targetId: "theme"
        });
    }

    function setThemeMode(mode) {
        const normalizedMode = String(mode || "").trim().toLowerCase();
        const settingsOutcome = setThemeModeSetting(normalizedMode);
        if (!settingsOutcome)
            return settingsOutcome;
        if (settingsOutcome.status === "applied") {
            return OperationOutcomes.applied({
                code: "theme.mode.updated",
                targetId: "theme",
                meta: {
                    mode: normalizedMode
                }
            });
        }
        if (settingsOutcome.status === "noop") {
            return OperationOutcomes.noop({
                code: "theme.mode.noop",
                reason: settingsOutcome.reason || "Theme mode is already selected",
                targetId: "theme",
                meta: {
                    mode: normalizedMode
                }
            });
        }
        return OperationOutcomes.rejected({
            code: "theme.mode.invalid",
            reason: settingsOutcome.reason || "Theme mode must be dark or light",
            targetId: "theme"
        });
    }

    function setThemeVariant(variant) {
        const normalizedVariant = String(variant || "").trim();
        const settingsOutcome = setThemeVariantSetting(normalizedVariant);
        if (!settingsOutcome)
            return settingsOutcome;
        if (settingsOutcome.status === "applied") {
            return OperationOutcomes.applied({
                code: "theme.variant.updated",
                targetId: "theme",
                meta: {
                    variant: normalizedVariant
                }
            });
        }
        if (settingsOutcome.status === "noop") {
            return OperationOutcomes.noop({
                code: "theme.variant.noop",
                reason: settingsOutcome.reason || "Theme variant is already selected",
                targetId: "theme",
                meta: {
                    variant: normalizedVariant
                }
            });
        }
        return OperationOutcomes.rejected({
            code: "theme.variant.invalid",
            reason: settingsOutcome.reason || "Theme variant must be a non-empty string",
            targetId: "theme"
        });
    }

    function ensureNotificationBridgeMethod(methodName, fallbackCode) {
        if (!root.notificationBridge || typeof root.notificationBridge[methodName] !== "function") {
            return OperationOutcomes.rejected({
                code: fallbackCode,
                reason: "Notification bridge is unavailable",
                targetId: "notifications"
            });
        }

        return null;
    }

    function describeNotifications() {
        const guard = ensureNotificationBridgeMethod("describe", "notifications.bridge_unavailable");
        if (guard)
            return guard;

        return OperationOutcomes.applied({
            code: "notifications.snapshot",
            targetId: "notifications",
            meta: {
                notifications: root.notificationBridge.describe()
            }
        });
    }

    function markAllNotificationsRead() {
        const guard = ensureNotificationBridgeMethod("markAllRead", "notifications.mark_all_read.bridge_unavailable");
        if (guard)
            return guard;

        return root.notificationBridge.markAllRead();
    }

    function clearNotificationHistory() {
        const guard = ensureNotificationBridgeMethod("clearHistory", "notifications.clear_history.bridge_unavailable");
        if (guard)
            return guard;

        return root.notificationBridge.clearHistory();
    }

    function clearNotificationEntryByKey(key) {
        const guard = ensureNotificationBridgeMethod("clearEntry", "notifications.clear_entry.bridge_unavailable");
        if (guard)
            return guard;

        return root.notificationBridge.clearEntry(String(key || ""));
    }

    function dismissNotificationPopupByKey(key) {
        const guard = ensureNotificationBridgeMethod("dismissPopup", "notifications.dismiss_popup.bridge_unavailable");
        if (guard)
            return guard;

        return root.notificationBridge.dismissPopup(String(key || ""));
    }

    function activateNotificationEntryByKey(key) {
        const guard = ensureNotificationBridgeMethod("activateEntry", "notifications.activate.bridge_unavailable");
        if (guard)
            return guard;

        return root.notificationBridge.activateEntry(String(key || ""));
    }

    function activateNotificationEntryActionByKey(key, actionId) {
        const guard = ensureNotificationBridgeMethod("activateEntry", "notifications.activate_action.bridge_unavailable");
        if (guard)
            return guard;

        return root.notificationBridge.activateEntry(String(key || ""), String(actionId || ""));
    }

    function setSessionOverlayOpen(nextOpen, appliedCode) {
        const targetOpen = Boolean(nextOpen);
        if (sessionOverlayOpen === targetOpen) {
            return OperationOutcomes.noop({
                code: "session.overlay.already_in_state",
                reason: targetOpen ? "Session overlay is already open" : "Session overlay is already closed",
                targetId: "session_overlay"
            });
        }

        if (targetOpen && !root.isSessionOverlayEnabled()) {
            return OperationOutcomes.rejected({
                code: "session.overlay.disabled_by_settings",
                reason: "Session overlay is disabled by current settings",
                targetId: "session_overlay"
            });
        }

        if (targetOpen && launcherOverlayOpen)
            launcherOverlayOpen = false;

        sessionOverlayOpen = targetOpen;
        return OperationOutcomes.applied({
            code: appliedCode,
            targetId: "session_overlay"
        });
    }

    function setLauncherOverlayOpen(nextOpen, appliedCode) {
        const targetOpen = Boolean(nextOpen);
        if (launcherOverlayOpen === targetOpen) {
            return OperationOutcomes.noop({
                code: "launcher.overlay.already_in_state",
                reason: targetOpen ? "Launcher overlay is already open" : "Launcher overlay is already closed",
                targetId: "launcher_overlay"
            });
        }

        if (targetOpen && sessionOverlayOpen)
            sessionOverlayOpen = false;

        launcherOverlayOpen = targetOpen;
        return OperationOutcomes.applied({
            code: appliedCode,
            targetId: "launcher_overlay"
        });
    }

    function runExternalCommand(args) {
        if (!root.commandExecutionPort || typeof root.commandExecutionPort.execute !== "function") {
            return OperationOutcomes.rejected({
                code: "shell.command.port_unavailable",
                reason: "Command execution port is unavailable",
                targetId: "shell.command.run"
            });
        }

        const argv = Array.isArray(args) ? args : [];
        const dispatched = root.commandExecutionPort.execute(argv);
        if (!dispatched) {
            return OperationOutcomes.failed({
                code: "shell.command.dispatch_failed",
                reason: "Command execution adapter did not accept the command",
                targetId: "shell.command.run"
            });
        }

        return OperationOutcomes.applied({
            code: "shell.command.dispatched",
            targetId: argv.length > 0 ? String(argv[0]) : "shell.command.run"
        });
    }

    function toggleSessionOverlayWithOutcome() {
        return setSessionOverlayOpen(!sessionOverlayOpen, sessionOverlayOpen ? "session.overlay.closed" : "session.overlay.opened");
    }

    function toggleLauncherOverlayWithOutcome() {
        return setLauncherOverlayOpen(!launcherOverlayOpen, launcherOverlayOpen ? "launcher.overlay.closed" : "launcher.overlay.opened");
    }

    function toggleSessionOverlay(): void {
        toggleSessionOverlayWithOutcome();
    }

    function openSessionOverlay(): void {
        setSessionOverlayOpen(true, "session.overlay.opened");
    }

    function closeSessionOverlay(): void {
        setSessionOverlayOpen(false, "session.overlay.closed");
    }

    function toggleLauncherOverlay(): void {
        toggleLauncherOverlayWithOutcome();
    }

    function openLauncherOverlay(): void {
        setLauncherOverlayOpen(true, "launcher.overlay.opened");
    }

    function closeLauncherOverlay(): void {
        setLauncherOverlayOpen(false, "launcher.overlay.closed");
    }

    QuickshellAdapters.ShellIpcAdapter {
        target: "shell"
        commandSpecs: root.shellIpcCommandSpecs
        commandHandlers: root.shellIpcCommandHandlers
        sharedCommandPort: root.shellCommandPort
    }

    PersistenceAdapters.FilePersistenceAdapter {
        id: settingsPersistenceAdapterObject
        domainKey: "shell"
    }

    SystemBarModules.BarRoot {
        shell: root
        commandExecutionAdapter: root.commandExecutionAdapter
        chromeBridge: root.shellChromeBridge
        notificationsBridge: root.notificationBridge
    }

    SystemLauncherModules.LauncherOverlay {
        shell: root
    }

    SystemNotificationModules.NotificationPopups {
        shell: root
        notificationsBridge: root.notificationBridge
    }

    SystemOsdModules.VolumeOsd {
        shell: root
        chromeBridge: root.shellChromeBridge
    }

    SystemSessionModules.SessionOverlay {
        shell: root
        commandAdapter: root.commandExecutionAdapter
    }
}

import "../system/adapters/persistence/settings-file-migrations.js" as SettingsFileMigrations
import "../system/core/contracts/settings-contracts.js" as SettingsContracts
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function test_migrateSettingsConfigDocument_promotes_legacy_flat_fields() {
        const migrated = SettingsFileMigrations.migrateSettingsConfigDocument({
            "sessionOverlayEnabled": false,
            "launcherCommandPrefix": ":",
            "maxResults": 12,
            "themeProviderId": "matugen",
            "themeFallbackProviderId": "static",
            "themeMode": "light",
            "themeVariant": "expressive",
            "themeSourceKind": "wallpaper",
            "themeSourceValue": "/tmp/wallpapers/a.png",
            "themeMatugenSchemePath": "/tmp/schemes/matugen.json",
            "homeAssistantIntegrationEnabled": false,
            "launcherHomeAssistantIntegrationEnabled": false,
            "launcherEmojiIntegrationEnabled": true,
            "launcherClipboardIntegrationEnabled": false,
            "launcherFileSearchIntegrationEnabled": true,
            "launcherWallpaperIntegrationEnabled": false
        });
        const validated = SettingsContracts.validateSettingsConfigDocument(migrated);

        compare(validated.kind, "shell.settings.config");
        compare(validated.schemaVersion, 1);
        compare(validated.session.overlayEnabled, false);
        compare(validated.launcher.commandPrefix, ":");
        compare(validated.launcher.maxResults, 12);
        compare(validated.theme.providerId, "matugen");
        compare(validated.theme.fallbackProviderId, "static");
        compare(validated.theme.mode, "light");
        compare(validated.theme.variant, "expressive");
        compare(validated.theme.sourceKind, "wallpaper");
        compare(validated.theme.sourceValue, "/tmp/wallpapers/a.png");
        compare(validated.theme.matugenSchemePath, "/tmp/schemes/matugen.json");
        compare(validated.integrations.homeAssistantEnabled, false);
        compare(validated.integrations.launcherHomeAssistantEnabled, false);
        compare(validated.integrations.launcherEmojiEnabled, true);
        compare(validated.integrations.launcherClipboardEnabled, false);
        compare(validated.integrations.launcherFileSearchEnabled, true);
        compare(validated.integrations.launcherWallpaperEnabled, false);
    }

    function test_migrateSettingsStateDocument_promotes_legacy_flat_fields() {
        const migrated = SettingsFileMigrations.migrateSettingsStateDocument({
            "lastLauncherQuery": "firefox",
            "pinnedLauncherCommands": ["session.toggle", "settings.reload"],
            "wallpaperHistory": [
                {
                    "path": "/tmp/wallpapers/a.png",
                    "source": "wallpaper.random",
                    "at": "2026-04-19T08:00:00.000Z"
                }
            ],
            "wallpaperHistoryCursor": 0
        });
        const validated = SettingsContracts.validateSettingsStateDocument(migrated);

        compare(validated.kind, "shell.settings.state");
        compare(validated.schemaVersion, 1);
        compare(validated.launcher.lastQuery, "firefox");
        compare(validated.launcher.pinnedCommandIds.length, 2);
        compare(validated.launcher.pinnedCommandIds[0], "session.toggle");
        compare(validated.launcher.pinnedCommandIds[1], "settings.reload");
        compare(validated.wallpaper.history.length, 1);
        compare(validated.wallpaper.history[0].path, "/tmp/wallpapers/a.png");
        compare(validated.wallpaper.cursor, 0);
    }

    function test_migrate_documents_keeps_existing_schema_fields() {
        const configDocument = {
            "kind": "shell.settings.config",
            "schemaVersion": 1,
            "session": {
                "overlayEnabled": true
            },
            "launcher": {
                "commandPrefix": ">",
                "maxResults": 9
            },
            "theme": {
                "providerId": "static",
                "fallbackProviderId": "matugen",
                "mode": "dark",
                "variant": "tonal-spot",
                "sourceKind": "generated",
                "sourceValue": "",
                "matugenSchemePath": ""
            }
        };
        const stateDocument = {
            "kind": "shell.settings.state",
            "schemaVersion": 1,
            "launcher": {
                "lastQuery": "alacritty",
                "pinnedCommandIds": ["shell.command.run"]
            }
        };

        const migratedConfig = SettingsFileMigrations.migrateSettingsConfigDocument(configDocument);
        const migratedState = SettingsFileMigrations.migrateSettingsStateDocument(stateDocument);

        compare(migratedConfig.launcher.maxResults, 9);
        compare(migratedConfig.launcher.commandPrefix, ">");
        compare(migratedConfig.theme.fallbackProviderId, "matugen");
        compare(migratedConfig.theme.sourceKind, "generated");
        compare(migratedState.launcher.lastQuery, "alacritty");
        compare(migratedState.launcher.pinnedCommandIds[0], "shell.command.run");
    }

    name: "SettingsFileMigrationSlice"
}

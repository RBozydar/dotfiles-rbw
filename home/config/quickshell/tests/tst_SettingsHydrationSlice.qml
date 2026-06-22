import "../system/adapters/persistence/in-memory-persistence-adapter.js" as PersistenceAdapters
import "../system/core/application/settings/hydrate-settings.js" as SettingsUseCases
import "../system/core/contracts/operation-outcome.js" as OperationOutcomes
import "../system/core/contracts/settings-contracts.js" as SettingsContracts
import "../system/core/domain/settings/settings-store.js" as SettingsStore
import "../system/core/ports/persistence-port.js" as PersistencePort
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function deps(persistencePort) {
        return {
            "createDefaultSettingsConfigDocument": SettingsContracts.createDefaultSettingsConfigDocument,
            "createDefaultSettingsStateDocument": SettingsContracts.createDefaultSettingsStateDocument,
            "validateSettingsConfigDocument": SettingsContracts.validateSettingsConfigDocument,
            "validateSettingsStateDocument": SettingsContracts.validateSettingsStateDocument,
            "createRuntimeSettings": SettingsContracts.createRuntimeSettings,
            "outcomes": OperationOutcomes,
            "persistencePort": persistencePort
        };
    }

    function test_hydrateSettings_loads_valid_config_and_state() {
        const adapter = PersistenceAdapters.createInMemoryPersistenceAdapter({
            config: {
                shell: {
                    "kind": "shell.settings.config",
                    "schemaVersion": 1,
                    "session": {
                        "overlayEnabled": false
                    },
                    "launcher": {
                        "commandPrefix": ":",
                        "maxResults": 12
                    },
                    "theme": {
                        "providerId": "matugen",
                        "fallbackProviderId": "static",
                        "mode": "light",
                        "variant": "expressive",
                        "sourceKind": "wallpaper",
                        "sourceValue": "/tmp/wallpapers/a.png",
                        "matugenSchemePath": "/tmp/schemes/matugen.json"
                    },
                    "integrations": {
                        "homeAssistantEnabled": true,
                        "launcherHomeAssistantEnabled": false,
                        "launcherEmojiEnabled": true,
                        "launcherClipboardEnabled": false,
                        "launcherFileSearchEnabled": true,
                        "launcherWallpaperEnabled": false
                    }
                }
            },
            state: {
                shell: {
                    "kind": "shell.settings.state",
                    "schemaVersion": 1,
                    "launcher": {
                        "lastQuery": "firefox",
                        "pinnedCommandIds": ["session.toggle"],
                        "usageByItemId": {
                            "app:firefox.desktop": {
                                "count": 3,
                                "lastUsedAt": "2026-04-17T09:59:00.000Z"
                            }
                        },
                        "queryHistory": [
                            {
                                "query": "firefox",
                                "at": "2026-04-17T09:58:00.000Z",
                                "source": "launcher.search"
                            }
                        ]
                    },
                    "wallpaper": {
                        "history": [
                            {
                                "path": "/tmp/wallpapers/a.png",
                                "source": "wallpaper.random",
                                "at": "2026-04-17T09:57:00.000Z"
                            },
                            {
                                "path": "/tmp/wallpapers/b.png",
                                "source": "wallpaper.set",
                                "at": "2026-04-17T09:58:30.000Z"
                            }
                        ],
                        "cursor": 1
                    }
                }
            }
        });
        const store = SettingsStore.createSettingsStore();
        const outcome = SettingsUseCases.hydrateSettings(deps(PersistencePort.createPersistencePort(adapter)), store, "shell");

        compare(outcome.status, "applied");
        compare(outcome.code, "settings.hydrated");
        compare(store.state.phase, "ready");
        compare(store.state.revision, 1);
        compare(store.state.persistedRevision, 1);
        compare(store.state.runtime.session.overlayEnabled, false);
        compare(store.state.runtime.launcher.commandPrefix, ":");
        compare(store.state.runtime.launcher.maxResults, 12);
        compare(store.state.runtime.launcher.lastQuery, "firefox");
        compare(store.state.runtime.launcher.pinnedCommandIds.length, 1);
        compare(store.state.runtime.launcher.pinnedCommandIds[0], "session.toggle");
        compare(store.state.runtime.launcher.telemetry.usageItemCount, 1);
        compare(store.state.runtime.launcher.telemetry.queryHistoryEntryCount, 1);
        compare(store.state.runtime.theme.providerId, "matugen");
        compare(store.state.runtime.theme.fallbackProviderId, "static");
        compare(store.state.runtime.theme.mode, "light");
        compare(store.state.runtime.theme.variant, "expressive");
        compare(store.state.runtime.theme.sourceKind, "wallpaper");
        compare(store.state.runtime.theme.sourceValue, "/tmp/wallpapers/a.png");
        compare(store.state.runtime.theme.matugenSchemePath, "/tmp/schemes/matugen.json");
        compare(store.state.runtime.integrations.homeAssistantEnabled, true);
        compare(store.state.runtime.integrations.launcherHomeAssistantEnabled, false);
        compare(store.state.runtime.integrations.launcherEmojiEnabled, true);
        compare(store.state.runtime.integrations.launcherClipboardEnabled, false);
        compare(store.state.runtime.integrations.launcherFileSearchEnabled, true);
        compare(store.state.runtime.integrations.launcherWallpaperEnabled, false);
        compare(store.state.runtime.wallpaper.historyEntryCount, 2);
        compare(store.state.runtime.wallpaper.currentHistoryIndex, 1);
        compare(store.state.runtime.wallpaper.currentPath, "/tmp/wallpapers/b.png");
    }

    function test_hydrateSettings_falls_back_for_invalid_config() {
        const adapter = PersistenceAdapters.createInMemoryPersistenceAdapter({
            config: {
                shell: {
                    "kind": "shell.settings.config",
                    "schemaVersion": 1,
                    "session": {
                        "overlayEnabled": "yes"
                    }
                }
            }
        });
        const store = SettingsStore.createSettingsStore();
        const outcome = SettingsUseCases.hydrateSettings(deps(PersistencePort.createPersistencePort(adapter)), store, "shell");

        compare(outcome.status, "applied");
        compare(outcome.code, "settings.hydrated_with_fallback");
        verify(outcome.meta.warnings.length >= 1);
        compare(store.state.persistedRevision, 1);
        compare(store.state.runtime.session.overlayEnabled, true);
        compare(store.state.runtime.launcher.commandPrefix, ">");
        compare(store.state.runtime.launcher.maxResults, 8);
        compare(store.state.runtime.theme.providerId, "static");
        compare(store.state.runtime.theme.mode, "dark");
    }

    function test_hydrateSettings_falls_back_when_port_is_missing() {
        const store = SettingsStore.createSettingsStore();
        const outcome = SettingsUseCases.hydrateSettings(deps({}), store, "shell");

        compare(outcome.status, "applied");
        compare(outcome.code, "settings.hydrated_with_fallback");
        compare(outcome.meta.warnings.length, 2);
        compare(outcome.meta.warnings[0].code, "settings.config.port_missing");
        compare(outcome.meta.warnings[1].code, "settings.state.port_missing");
        compare(store.state.persistedRevision, 1);
        compare(store.state.runtime.session.overlayEnabled, true);
    }

    function test_hydrateSettings_propagates_snapshot_warnings_and_generation() {
        const store = SettingsStore.createSettingsStore();
        const snapshotPort = {
            "readSnapshot": function () {
                return {
                    config: {
                        "kind": "shell.settings.config",
                        "schemaVersion": 1,
                        "session": {
                            "overlayEnabled": true
                        },
                        "launcher": {
                            "commandPrefix": ">",
                            "maxResults": 8
                        }
                    },
                    state: {
                        "kind": "shell.settings.state",
                        "schemaVersion": 1,
                        "launcher": {
                            "lastQuery": "wezterm",
                            "pinnedCommandIds": ["settings.persist"]
                        }
                    },
                    generation: 17,
                    meta: {
                        warnings: [
                            {
                                code: "settings.config.recovered_from_backup",
                                reason: "Recovered persisted snapshot from backup"
                            }
                        ]
                    }
                };
            }
        };

        const outcome = SettingsUseCases.hydrateSettings(deps(snapshotPort), store, "shell");

        compare(outcome.status, "applied");
        compare(outcome.code, "settings.hydrated_with_fallback");
        compare(outcome.meta.snapshotGeneration, 17);
        compare(outcome.meta.warnings[0].code, "settings.config.recovered_from_backup");
        compare(store.state.persistedRevision, 1);
        compare(store.state.runtime.launcher.lastQuery, "wezterm");
    }

    function test_hydrateSettings_marks_store_error_when_runtime_construction_throws() {
        const adapter = PersistenceAdapters.createInMemoryPersistenceAdapter({});
        const store = SettingsStore.createSettingsStore();
        const failingDeps = deps(PersistencePort.createPersistencePort(adapter));
        failingDeps.createRuntimeSettings = function () {
            throw new Error("runtime boom");
        };

        const outcome = SettingsUseCases.hydrateSettings(failingDeps, store, "shell");

        compare(outcome.status, "failed");
        compare(outcome.code, "settings.hydration_failed");
        compare(store.state.phase, "error");
        compare(store.state.persistedRevision, 0);
        compare(store.state.error, "runtime boom");
    }

    name: "SettingsHydrationSlice"
}

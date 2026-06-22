import "../system/adapters/persistence/in-memory-persistence-adapter.js" as PersistenceAdapters
import "../system/core/application/settings/persist-settings.js" as SettingsPersistUseCases
import "../system/core/application/settings/update-settings.js" as SettingsUpdateUseCases
import "../system/core/contracts/operation-outcome.js" as OperationOutcomes
import "../system/core/contracts/settings-contracts.js" as SettingsContracts
import "../system/core/domain/settings/settings-store.js" as SettingsStore
import "../system/core/ports/persistence-port.js" as PersistencePort
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function updateDeps() {
        return {
            "validateSettingsConfigDocument": SettingsContracts.validateSettingsConfigDocument,
            "validateSettingsStateDocument": SettingsContracts.validateSettingsStateDocument,
            "createRuntimeSettings": SettingsContracts.createRuntimeSettings,
            "outcomes": OperationOutcomes
        };
    }

    function persistDeps(persistencePort) {
        return {
            "validateSettingsConfigDocument": SettingsContracts.validateSettingsConfigDocument,
            "validateSettingsStateDocument": SettingsContracts.validateSettingsStateDocument,
            "outcomes": OperationOutcomes,
            "persistencePort": persistencePort
        };
    }

    function readyStore() {
        const store = SettingsStore.createSettingsStore();
        const config = SettingsContracts.createDefaultSettingsConfigDocument();
        const durableState = SettingsContracts.createDefaultSettingsStateDocument();
        const runtime = SettingsContracts.createRuntimeSettings(config, durableState);

        store.applyHydrated(config, durableState, runtime, OperationOutcomes.applied({
            code: "settings.hydrated",
            targetId: "shell"
        }));
        return store;
    }

    function test_persistSettings_writes_documents_and_updates_persisted_revision() {
        const adapter = PersistenceAdapters.createInMemoryPersistenceAdapter({});
        const persistencePort = PersistencePort.createPersistencePort(adapter);
        const store = readyStore();

        SettingsUpdateUseCases.setSessionOverlayEnabled(updateDeps(), store, false);
        SettingsUpdateUseCases.setThemeProviderId(updateDeps(), store, "matugen");
        SettingsUpdateUseCases.setThemeMode(updateDeps(), store, "light");
        SettingsUpdateUseCases.setThemeVariant(updateDeps(), store, "expressive");
        SettingsUpdateUseCases.applyLauncherTelemetryBatch(updateDeps(), store, [
            {
                kind: "query",
                query: "firefox",
                at: "2026-04-17T10:00:00.000Z",
                source: "launcher.search"
            },
            {
                kind: "usage",
                itemId: "app:firefox.desktop",
                at: "2026-04-17T10:00:01.000Z",
                source: "launcher.activate"
            }
        ], {
            queryHistoryRetentionDays: 90,
            maxQueryHistoryEntries: 20000
        });
        SettingsUpdateUseCases.setWallpaperHistory(updateDeps(), store, [
            {
                path: "/tmp/wallpapers/a.png",
                source: "wallpaper.random",
                at: "2026-04-17T10:02:00.000Z"
            },
            {
                path: "/tmp/wallpapers/b.png",
                source: "wallpaper.set",
                at: "2026-04-17T10:03:00.000Z"
            }
        ], 1, {
            maxEntries: 80
        });
        compare(store.state.revision, 7);
        compare(store.state.persistedRevision, 1);

        const outcome = SettingsPersistUseCases.persistSettings(persistDeps(persistencePort), store, "shell", "test.persist");

        compare(outcome.status, "applied");
        compare(outcome.code, "settings.persisted");
        compare(outcome.meta.source, "test.persist");
        compare(outcome.generation, 2);
        compare(outcome.meta.persistence.kind, "adapter.persistence.snapshot.in_memory");
        compare(store.state.persistedRevision, 7);

        const persistedConfig = persistencePort.readConfig("shell");
        compare(persistedConfig.session.overlayEnabled, false);
        compare(persistedConfig.theme.providerId, "matugen");
        compare(persistedConfig.theme.mode, "light");
        compare(persistedConfig.theme.variant, "expressive");
        const persistedSnapshot = persistencePort.readSnapshot("shell");
        compare(persistedSnapshot.generation, 2);
        compare(persistedSnapshot.config.theme.providerId, "matugen");
        compare(persistedSnapshot.config.theme.mode, "light");
        compare(persistedSnapshot.config.theme.variant, "expressive");
        compare(persistedSnapshot.state.launcher.lastQuery, "firefox");
        compare(persistedSnapshot.state.launcher.queryHistory.length, 1);
        compare(persistedSnapshot.state.launcher.usageByItemId["app:firefox.desktop"].count, 1);
        compare(persistedSnapshot.state.wallpaper.history.length, 2);
        compare(persistedSnapshot.state.wallpaper.cursor, 1);
        compare(persistedSnapshot.state.wallpaper.history[1].path, "/tmp/wallpapers/b.png");
    }

    function test_persistSettings_reports_failed_write_confirmation() {
        const store = readyStore();
        SettingsUpdateUseCases.setSessionOverlayEnabled(updateDeps(), store, false);

        const failingPort = {
            "writeConfig": function () {
                return false;
            },
            "writeState": function () {
                return true;
            }
        };
        const outcome = SettingsPersistUseCases.persistSettings(persistDeps(failingPort), store, "shell", "test.persist");

        compare(outcome.status, "failed");
        compare(outcome.code, "settings.persist_failed");
        compare(store.state.persistedRevision, 1);
        compare(store.state.error, "Persistence adapter did not confirm all writes");
    }

    name: "SettingsPersistSlice"
}

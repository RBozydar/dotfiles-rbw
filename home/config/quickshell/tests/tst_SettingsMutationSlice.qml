import "../system/core/application/settings/update-settings.js" as SettingsUpdateUseCases
import "../system/core/contracts/operation-outcome.js" as OperationOutcomes
import "../system/core/contracts/settings-contracts.js" as SettingsContracts
import "../system/core/domain/settings/settings-store.js" as SettingsStore
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

    function test_setSessionOverlayEnabled_updates_runtime_and_marks_dirty() {
        const store = readyStore();
        const outcome = SettingsUpdateUseCases.setSessionOverlayEnabled(updateDeps(), store, false);

        compare(outcome.status, "applied");
        compare(outcome.code, "settings.session_overlay.updated");
        compare(store.state.runtime.session.overlayEnabled, false);
        compare(store.state.revision, 2);
        compare(store.state.persistedRevision, 1);
    }

    function test_setSessionOverlayEnabled_returns_noop_when_unchanged() {
        const store = readyStore();
        const first = SettingsUpdateUseCases.setSessionOverlayEnabled(updateDeps(), store, false);
        const second = SettingsUpdateUseCases.setSessionOverlayEnabled(updateDeps(), store, false);

        compare(first.status, "applied");
        compare(second.status, "noop");
        compare(second.code, "settings.session_overlay.updated.noop");
        compare(store.state.revision, 2);
        compare(store.state.persistedRevision, 1);
    }

    function test_setLauncherCommandPrefix_rejects_invalid_prefix() {
        const store = readyStore();
        const outcome = SettingsUpdateUseCases.setLauncherCommandPrefix(updateDeps(), store, "");

        compare(outcome.status, "rejected");
        compare(outcome.code, "settings.launcher.command_prefix.updated.invalid");
        compare(store.state.revision, 1);
        compare(store.state.persistedRevision, 1);
    }

    function test_setLauncherMaxResults_updates_and_rejects_non_integer() {
        const store = readyStore();
        const applied = SettingsUpdateUseCases.setLauncherMaxResults(updateDeps(), store, 14);
        const rejected = SettingsUpdateUseCases.setLauncherMaxResults(updateDeps(), store, "not-a-number");

        compare(applied.status, "applied");
        compare(applied.code, "settings.launcher.max_results.updated");
        compare(store.state.runtime.launcher.maxResults, 14);
        compare(store.state.revision, 2);
        compare(store.state.persistedRevision, 1);

        compare(rejected.status, "rejected");
        compare(rejected.code, "settings.launcher.max_results.invalid");
        compare(store.state.revision, 2);
    }

    function test_setThemeProviderId_updates_runtime_theme_and_noops_when_unchanged() {
        const store = readyStore();
        const applied = SettingsUpdateUseCases.setThemeProviderId(updateDeps(), store, "matugen");
        const noopOutcome = SettingsUpdateUseCases.setThemeProviderId(updateDeps(), store, "matugen");
        const rejected = SettingsUpdateUseCases.setThemeProviderId(updateDeps(), store, "   ");

        compare(applied.status, "applied");
        compare(applied.code, "settings.theme.provider.updated");
        compare(store.state.runtime.theme.providerId, "matugen");

        compare(noopOutcome.status, "noop");
        compare(noopOutcome.code, "settings.theme.provider.updated.noop");

        compare(rejected.status, "rejected");
        compare(rejected.code, "settings.theme.provider.invalid");
    }

    function test_setThemeMode_updates_runtime_theme_and_rejects_invalid_values() {
        const store = readyStore();
        const applied = SettingsUpdateUseCases.setThemeMode(updateDeps(), store, "light");
        const noopOutcome = SettingsUpdateUseCases.setThemeMode(updateDeps(), store, "LIGHT");
        const rejected = SettingsUpdateUseCases.setThemeMode(updateDeps(), store, "sunset");

        compare(applied.status, "applied");
        compare(applied.code, "settings.theme.mode.updated");
        compare(store.state.runtime.theme.mode, "light");

        compare(noopOutcome.status, "noop");
        compare(noopOutcome.code, "settings.theme.mode.updated.noop");

        compare(rejected.status, "rejected");
        compare(rejected.code, "settings.theme.mode.invalid");
    }

    function test_setThemeVariant_updates_runtime_theme_and_rejects_empty() {
        const store = readyStore();
        const applied = SettingsUpdateUseCases.setThemeVariant(updateDeps(), store, "expressive");
        const noopOutcome = SettingsUpdateUseCases.setThemeVariant(updateDeps(), store, "expressive");
        const rejected = SettingsUpdateUseCases.setThemeVariant(updateDeps(), store, "  ");

        compare(applied.status, "applied");
        compare(applied.code, "settings.theme.variant.updated");
        compare(store.state.runtime.theme.variant, "expressive");

        compare(noopOutcome.status, "noop");
        compare(noopOutcome.code, "settings.theme.variant.updated.noop");

        compare(rejected.status, "rejected");
        compare(rejected.code, "settings.theme.variant.invalid");
    }

    function test_setIntegrationToggles_updates_runtime_and_noops_when_unchanged() {
        const store = readyStore();

        const disableHomeAssistant = SettingsUpdateUseCases.setHomeAssistantIntegrationEnabled(updateDeps(), store, false);
        compare(disableHomeAssistant.status, "applied");
        compare(disableHomeAssistant.code, "settings.integrations.homeassistant.updated");
        compare(store.state.runtime.integrations.homeAssistantEnabled, false);

        const disableHomeAssistantNoop = SettingsUpdateUseCases.setHomeAssistantIntegrationEnabled(updateDeps(), store, false);
        compare(disableHomeAssistantNoop.status, "noop");
        compare(disableHomeAssistantNoop.code, "settings.integrations.homeassistant.updated.noop");

        const disableLauncherEmoji = SettingsUpdateUseCases.setLauncherEmojiIntegrationEnabled(updateDeps(), store, false);
        compare(disableLauncherEmoji.status, "applied");
        compare(disableLauncherEmoji.code, "settings.integrations.launcher_emoji.updated");
        compare(store.state.runtime.integrations.launcherEmojiEnabled, false);

        const disableLauncherHomeAssistant = SettingsUpdateUseCases.setLauncherHomeAssistantIntegrationEnabled(updateDeps(), store, false);
        compare(disableLauncherHomeAssistant.status, "applied");
        compare(disableLauncherHomeAssistant.code, "settings.integrations.launcher_homeassistant.updated");
        compare(store.state.runtime.integrations.launcherHomeAssistantEnabled, false);
    }

    function test_setLauncherLastQuery_updates_durable_state() {
        const store = readyStore();
        const outcome = SettingsUpdateUseCases.setLauncherLastQuery(updateDeps(), store, "firefox");

        compare(outcome.status, "applied");
        compare(outcome.code, "settings.launcher.last_query.updated");
        compare(store.state.runtime.launcher.lastQuery, "firefox");
        compare(store.state.revision, 2);
        compare(store.state.persistedRevision, 1);
    }

    function test_pin_and_unpinLauncherCommand_update_pinned_list() {
        const store = readyStore();

        const firstPin = SettingsUpdateUseCases.pinLauncherCommand(updateDeps(), store, "session.toggle");

        compare(firstPin.status, "applied");
        compare(firstPin.code, "settings.launcher.pin_command.updated");
        compare(store.state.runtime.launcher.pinnedCommandIds.length, 1);
        compare(store.state.runtime.launcher.pinnedCommandIds[0], "session.toggle");

        const duplicatePin = SettingsUpdateUseCases.pinLauncherCommand(updateDeps(), store, "session.toggle");

        compare(duplicatePin.status, "noop");
        compare(duplicatePin.code, "settings.launcher.pin_command.updated.noop");

        const unpin = SettingsUpdateUseCases.unpinLauncherCommand(updateDeps(), store, "session.toggle");
        compare(unpin.status, "applied");
        compare(unpin.code, "settings.launcher.unpin_command.updated");
        compare(store.state.runtime.launcher.pinnedCommandIds.length, 0);
    }

    function test_movePinnedLauncherCommand_reorders_pinned_list() {
        const store = readyStore();
        SettingsUpdateUseCases.pinLauncherCommand(updateDeps(), store, "settings.reload");
        SettingsUpdateUseCases.pinLauncherCommand(updateDeps(), store, "session.toggle");
        SettingsUpdateUseCases.pinLauncherCommand(updateDeps(), store, "launcher.toggle");

        const moveUp = SettingsUpdateUseCases.movePinnedLauncherCommandUp(updateDeps(), store, "launcher.toggle");
        compare(moveUp.status, "applied");
        compare(moveUp.code, "settings.launcher.pin_command.move_up.updated");
        compare(store.state.runtime.launcher.pinnedCommandIds.length, 3);
        compare(store.state.runtime.launcher.pinnedCommandIds[0], "settings.reload");
        compare(store.state.runtime.launcher.pinnedCommandIds[1], "launcher.toggle");
        compare(store.state.runtime.launcher.pinnedCommandIds[2], "session.toggle");

        const moveDown = SettingsUpdateUseCases.movePinnedLauncherCommandDown(updateDeps(), store, "launcher.toggle");
        compare(moveDown.status, "applied");
        compare(moveDown.code, "settings.launcher.pin_command.move_down.updated");
        compare(store.state.runtime.launcher.pinnedCommandIds[0], "settings.reload");
        compare(store.state.runtime.launcher.pinnedCommandIds[1], "session.toggle");
        compare(store.state.runtime.launcher.pinnedCommandIds[2], "launcher.toggle");
    }

    function test_movePinnedLauncherCommand_noops_when_position_cannot_change() {
        const store = readyStore();
        SettingsUpdateUseCases.pinLauncherCommand(updateDeps(), store, "session.toggle");

        const moveUpAtTop = SettingsUpdateUseCases.movePinnedLauncherCommandUp(updateDeps(), store, "session.toggle");
        compare(moveUpAtTop.status, "noop");
        compare(moveUpAtTop.code, "settings.launcher.pin_command.move_up.updated.noop");

        const moveDownAtBottom = SettingsUpdateUseCases.movePinnedLauncherCommandDown(updateDeps(), store, "session.toggle");
        compare(moveDownAtBottom.status, "noop");
        compare(moveDownAtBottom.code, "settings.launcher.pin_command.move_down.updated.noop");

        const moveUnknown = SettingsUpdateUseCases.movePinnedLauncherCommandUp(updateDeps(), store, "settings.reload");
        compare(moveUnknown.status, "noop");
        compare(moveUnknown.code, "settings.launcher.pin_command.move_up.updated.noop");
    }

    function test_applyLauncherTelemetryBatch_tracks_query_history_and_usage() {
        const store = readyStore();
        const first = SettingsUpdateUseCases.applyLauncherTelemetryBatch(updateDeps(), store, [
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

        compare(first.status, "applied");
        compare(first.code, "settings.launcher.telemetry.updated");
        compare(store.state.runtime.launcher.lastQuery, "firefox");
        compare(store.state.durableState.launcher.queryHistory.length, 1);
        compare(store.state.durableState.launcher.queryHistory[0].query, "firefox");
        compare(store.state.durableState.launcher.queryHistory[0].source, "launcher.search");
        compare(store.state.durableState.launcher.usageByItemId["app:firefox.desktop"].count, 1);
        compare(store.state.durableState.launcher.usageByItemId["app:firefox.desktop"].lastUsedAt, "2026-04-17T10:00:01.000Z");

        const second = SettingsUpdateUseCases.applyLauncherTelemetryBatch(updateDeps(), store, [
            {
                kind: "usage",
                itemId: "app:firefox.desktop",
                at: "2026-04-17T10:00:05.000Z",
                source: "launcher.activate"
            }
        ], {
            queryHistoryRetentionDays: 90,
            maxQueryHistoryEntries: 20000
        });

        compare(second.status, "applied");
        compare(store.state.durableState.launcher.usageByItemId["app:firefox.desktop"].count, 2);
    }

    function test_applyLauncherTelemetryBatch_compacts_history_by_limits() {
        const store = readyStore();
        const outcome = SettingsUpdateUseCases.applyLauncherTelemetryBatch(updateDeps(), store, [
            {
                kind: "query",
                query: "alpha",
                at: "2026-04-17T10:00:00.000Z",
                source: "launcher.search"
            },
            {
                kind: "query",
                query: "beta",
                at: "2026-04-17T10:01:00.000Z",
                source: "launcher.search"
            },
            {
                kind: "query",
                query: "gamma",
                at: "2026-04-17T10:02:00.000Z",
                source: "launcher.search"
            }
        ], {
            queryHistoryRetentionDays: 3650,
            maxQueryHistoryEntries: 2
        });

        compare(outcome.status, "applied");
        compare(store.state.durableState.launcher.queryHistory.length, 2);
        compare(store.state.durableState.launcher.queryHistory[0].query, "beta");
        compare(store.state.durableState.launcher.queryHistory[1].query, "gamma");
    }

    function test_resetLauncherPersonalization_clears_launcher_signals() {
        const store = readyStore();
        SettingsUpdateUseCases.pinLauncherCommand(updateDeps(), store, "session.toggle");
        SettingsUpdateUseCases.applyLauncherTelemetryBatch(updateDeps(), store, [
            {
                kind: "query",
                query: "wezterm",
                at: "2026-04-17T10:00:00.000Z",
                source: "launcher.search"
            },
            {
                kind: "usage",
                itemId: "app:wezterm.desktop",
                at: "2026-04-17T10:00:01.000Z",
                source: "launcher.activate"
            }
        ], {
            queryHistoryRetentionDays: 3650,
            maxQueryHistoryEntries: 20
        });

        const reset = SettingsUpdateUseCases.resetLauncherPersonalization(updateDeps(), store);
        compare(reset.status, "applied");
        compare(reset.code, "settings.launcher.personalization.reset");
        compare(store.state.runtime.launcher.lastQuery, "");
        compare(store.state.runtime.launcher.pinnedCommandIds.length, 0);
        compare(store.state.durableState.launcher.queryHistory.length, 0);
        compare(Object.keys(store.state.durableState.launcher.usageByItemId).length, 0);

        const secondReset = SettingsUpdateUseCases.resetLauncherPersonalization(updateDeps(), store);
        compare(secondReset.status, "noop");
        compare(secondReset.code, "settings.launcher.personalization.reset.noop");
    }

    function test_setNotificationHistory_updates_durable_notifications_state() {
        const store = readyStore();
        const outcome = SettingsUpdateUseCases.setNotificationHistory(updateDeps(), store, [
            {
                key: "7-1000",
                id: 7,
                appName: "Ghostty",
                summary: "Codex",
                body: "Need input",
                appIcon: "utilities-terminal",
                image: "",
                urgency: 1,
                timestamp: 1000,
                read: false,
                repeatCount: 1,
                actions: [
                    {
                        id: "open",
                        label: "Open"
                    }
                ],
                defaultActionId: "open"
            }
        ], {
            maxEntries: 50
        });

        compare(outcome.status, "applied");
        compare(outcome.code, "settings.notifications.history.updated");
        compare(store.state.durableState.notifications.history.length, 1);
        compare(store.state.runtime.notifications.historyCount, 1);
        compare(store.state.runtime.notifications.unreadCount, 1);

        const noopOutcome = SettingsUpdateUseCases.setNotificationHistory(updateDeps(), store, [
            {
                key: "7-1000",
                id: 7,
                appName: "Ghostty",
                summary: "Codex",
                body: "Need input",
                appIcon: "utilities-terminal",
                image: "",
                urgency: 1,
                timestamp: 1000,
                read: false,
                repeatCount: 1,
                actions: [
                    {
                        id: "open",
                        label: "Open"
                    }
                ],
                defaultActionId: "open"
            }
        ], {
            maxEntries: 50
        });

        compare(noopOutcome.status, "noop");
        compare(noopOutcome.code, "settings.notifications.history.updated.noop");
    }

    function test_setWallpaperHistory_updates_durable_wallpaper_state() {
        const store = readyStore();
        const outcome = SettingsUpdateUseCases.setWallpaperHistory(updateDeps(), store, [
            {
                path: "/tmp/wallpapers/a.png",
                source: "wallpaper.random",
                at: "2026-04-19T09:00:00.000Z"
            },
            {
                path: "/tmp/wallpapers/b.png",
                source: "wallpaper.set",
                at: "2026-04-19T09:05:00.000Z"
            }
        ], 0, {
            maxEntries: 80
        });

        compare(outcome.status, "applied");
        compare(outcome.code, "settings.wallpaper.history.updated");
        compare(store.state.durableState.wallpaper.history.length, 2);
        compare(store.state.durableState.wallpaper.history[0].path, "/tmp/wallpapers/a.png");
        compare(store.state.durableState.wallpaper.cursor, 0);
        compare(store.state.runtime.wallpaper.historyEntryCount, 2);
        compare(store.state.runtime.wallpaper.currentHistoryIndex, 0);
        compare(store.state.runtime.wallpaper.currentPath, "/tmp/wallpapers/a.png");

        const noopOutcome = SettingsUpdateUseCases.setWallpaperHistory(updateDeps(), store, [
            {
                path: "/tmp/wallpapers/a.png",
                source: "wallpaper.random",
                at: "2026-04-19T09:00:00.000Z"
            },
            {
                path: "/tmp/wallpapers/b.png",
                source: "wallpaper.set",
                at: "2026-04-19T09:05:00.000Z"
            }
        ], 0, {
            maxEntries: 80
        });

        compare(noopOutcome.status, "noop");
        compare(noopOutcome.code, "settings.wallpaper.history.updated.noop");
    }

    name: "SettingsMutationSlice"
}

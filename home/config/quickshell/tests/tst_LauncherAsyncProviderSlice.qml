import "../system/core/application/launcher/apply-launcher-async-provider-result.js" as LauncherAsyncProviderUseCases
import "../system/core/application/launcher/run-launcher-search.js" as LauncherSearchUseCases
import "../system/core/contracts/launcher-contracts.js" as LauncherContracts
import "../system/core/contracts/operation-outcome.js" as OperationOutcomes
import "../system/core/domain/launcher/launcher-store.js" as LauncherStore
import "../system/core/policies/launcher/launcher-scoring-policy.js" as LauncherScoringPolicy
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function createLauncherItem(id, title, score, targetId) {
        return LauncherContracts.createLauncherItem({
            id: id,
            title: title,
            subtitle: "",
            provider: "apps",
            score: score,
            action: {
                type: "app.launch",
                targetId: targetId
            }
        });
    }

    function scoreItems(items, query) {
        return LauncherScoringPolicy.scoreLauncherItems(items, query, {
            includeScoreMeta: false,
            nowIso: "2026-04-17T12:00:00.000Z"
        });
    }

    function asyncDeps() {
        return {
            "scoreLauncherItems": scoreItems,
            "createLauncherResultList": LauncherContracts.createLauncherResultList,
            "outcomes": OperationOutcomes
        };
    }

    function runSearchDeps(items) {
        return {
            "validateLauncherSearchCommand": LauncherContracts.validateLauncherSearchCommand,
            "searchAdapter": {
                "search": function () {
                    return items;
                }
            },
            "scoreLauncherItems": scoreItems,
            "createLauncherResultList": LauncherContracts.createLauncherResultList,
            "outcomes": OperationOutcomes
        };
    }

    function readyStore(query, generation, items) {
        const store = LauncherStore.createLauncherStore();
        const command = LauncherContracts.createLauncherSearchCommand(query, generation, "test");
        const scored = scoreItems(items, query);
        const resultList = LauncherContracts.createLauncherResultList(scored, generation);

        store.applySearchStarted(command);
        store.applySearchCompleted(resultList, OperationOutcomes.applied({
            code: "launcher.search_applied",
            targetId: "launcher",
            generation: generation
        }), items);

        return store;
    }

    function findById(items, id) {
        for (let index = 0; index < items.length; index += 1) {
            if (items[index].id === id)
                return items[index];
        }
        return null;
    }

    function test_runLauncherSearch_persists_source_items_for_late_merge() {
        const store = LauncherStore.createLauncherStore();
        const command = LauncherContracts.createLauncherSearchCommand("fire", 3, "test");
        const sourceItems = [createLauncherItem("app:firefox.desktop", "Firefox", 120, "firefox.desktop")];

        const outcome = LauncherSearchUseCases.runLauncherSearch(runSearchDeps(sourceItems), store, command);

        compare(outcome.status, "applied");
        compare(store.state.sourceItems.length, 1);
        compare(store.state.sourceItems[0].id, "app:firefox.desktop");
    }

    function test_applyLauncherAsyncProviderResult_merges_late_results_for_active_generation() {
        const store = readyStore("fire", 7, [createLauncherItem("app:firefox.desktop", "Firefox", 120, "firefox.desktop")]);
        compare(store.markAsyncProviderPending({
            generation: 7,
            providerId: "apps.remote"
        }), true);

        const outcome = LauncherAsyncProviderUseCases.applyLauncherAsyncProviderResult(asyncDeps(), store, {
            generation: 7,
            providerId: "apps.remote",
            query: "fire"
        }, [createLauncherItem("app:files.desktop", "Files", 100, "org.gnome.Nautilus.desktop")]);

        compare(outcome.status, "applied");
        compare(outcome.code, "launcher.async_provider.applied");
        compare(store.state.phase, "ready");
        compare(store.state.pendingProviders.length, 0);
        compare(store.state.sourceItems.length, 2);
        verify(findById(store.state.results, "app:files.desktop") !== null);
    }

    function test_applyLauncherAsyncProviderResult_returns_stale_for_mismatched_generation() {
        const store = readyStore("fire", 7, [createLauncherItem("app:firefox.desktop", "Firefox", 120, "firefox.desktop")]);
        const beforeCount = store.state.results.length;

        const outcome = LauncherAsyncProviderUseCases.applyLauncherAsyncProviderResult(asyncDeps(), store, {
            generation: 6,
            providerId: "apps.remote",
            query: "fire"
        }, [createLauncherItem("app:files.desktop", "Files", 100, "org.gnome.Nautilus.desktop")]);

        compare(outcome.status, "stale");
        compare(outcome.code, "launcher.async_provider.stale_generation");
        compare(store.state.results.length, beforeCount);
        compare(store.state.sourceItems.length, 1);
    }

    function test_applyLauncherAsyncProviderResult_updates_existing_item_by_id() {
        const store = readyStore("firefox", 9, [createLauncherItem("app:firefox.desktop", "Firefox", 120, "firefox.desktop")]);
        compare(store.markAsyncProviderPending({
            generation: 9,
            providerId: "apps.remote"
        }), true);

        const outcome = LauncherAsyncProviderUseCases.applyLauncherAsyncProviderResult(asyncDeps(), store, {
            generation: 9,
            providerId: "apps.remote",
            query: "firefox"
        }, [LauncherContracts.createLauncherItem({
                id: "app:firefox.desktop",
                title: "Firefox Dev",
                subtitle: "",
                provider: "apps",
                score: 240,
                action: {
                    type: "app.launch",
                    targetId: "firefox-developer-edition.desktop"
                }
            })]);

        compare(outcome.status, "applied");
        compare(store.state.sourceItems.length, 1);
        const item = findById(store.state.sourceItems, "app:firefox.desktop");
        verify(item !== null);
        compare(item.title, "Firefox Dev");
        compare(item.action.targetId, "firefox-developer-edition.desktop");
    }

    function test_failLauncherAsyncProviderResult_clears_pending_provider() {
        const store = readyStore("fire", 5, [createLauncherItem("app:firefox.desktop", "Firefox", 120, "firefox.desktop")]);
        compare(store.markAsyncProviderPending({
            generation: 5,
            providerId: "apps.remote"
        }), true);

        const outcome = LauncherAsyncProviderUseCases.failLauncherAsyncProviderResult(asyncDeps(), store, {
            generation: 5,
            providerId: "apps.remote",
            query: "fire"
        }, new Error("provider timeout"));

        compare(outcome.status, "failed");
        compare(outcome.code, "launcher.async_provider.failed");
        compare(store.state.pendingProviders.length, 0);
        compare(store.state.phase, "ready");
        compare(store.state.results.length, 1);
    }

    function test_applyLauncherAsyncProviderResult_failure_clears_pending_provider() {
        const store = readyStore("fire", 12, [createLauncherItem("app:firefox.desktop", "Firefox", 120, "firefox.desktop")]);
        compare(store.markAsyncProviderPending({
            generation: 12,
            providerId: "apps.remote"
        }), true);

        const outcome = LauncherAsyncProviderUseCases.applyLauncherAsyncProviderResult(asyncDeps(), store, {
            generation: 12,
            providerId: "apps.remote",
            query: "fire"
        }, [
            {
                id: "broken:item",
                title: "Broken Item",
                provider: "apps"
                // Missing action.type; should fail validation and still clear pending.
            }
        ]);

        compare(outcome.status, "failed");
        compare(outcome.code, "launcher.async_provider.apply_failed");
        compare(store.state.pendingProviders.length, 0);
        compare(store.state.phase, "ready");
    }

    name: "LauncherAsyncProviderSlice"
}

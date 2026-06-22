import "../system/core/application/launcher/launcher-async-provider-registry.js" as LauncherAsyncProviderRegistry
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function test_createPendingEntry_requires_generation_and_provider() {
        let threwGeneration = false;
        let threwProvider = false;

        try {
            LauncherAsyncProviderRegistry.createPendingEntry({
                providerId: "apps.remote"
            }, 1000, 2000);
        } catch (error) {
            threwGeneration = true;
        }

        try {
            LauncherAsyncProviderRegistry.createPendingEntry({
                generation: 1
            }, 1000, 2000);
        } catch (error) {
            threwProvider = true;
        }

        compare(threwGeneration, true);
        compare(threwProvider, true);
    }

    function test_upsert_and_removePendingEntry() {
        let registry = LauncherAsyncProviderRegistry.createRegistry();
        const entry = LauncherAsyncProviderRegistry.createPendingEntry({
            generation: 3,
            providerId: "apps.remote",
            query: "fire"
        }, 2000, 2500);

        registry = LauncherAsyncProviderRegistry.upsertPendingEntry(registry, entry);
        const pending = LauncherAsyncProviderRegistry.pendingEntry(registry, 3, "apps.remote");
        verify(pending !== null);
        compare(pending.query, "fire");

        const removed = LauncherAsyncProviderRegistry.removePendingEntry(registry, 3, "apps.remote");
        compare(removed.removedEntry !== null, true);
        compare(LauncherAsyncProviderRegistry.pendingEntry(removed.registry, 3, "apps.remote"), null);
    }

    function test_collectExpiredEntries_filters_by_deadline() {
        let registry = LauncherAsyncProviderRegistry.createRegistry();
        const a = LauncherAsyncProviderRegistry.createPendingEntry({
            generation: 1,
            providerId: "provider.a"
        }, 1000, 300);
        const b = LauncherAsyncProviderRegistry.createPendingEntry({
            generation: 1,
            providerId: "provider.b"
        }, 1500, 3000);

        registry = LauncherAsyncProviderRegistry.upsertPendingEntry(registry, a);
        registry = LauncherAsyncProviderRegistry.upsertPendingEntry(registry, b);

        const expired = LauncherAsyncProviderRegistry.collectExpiredEntries(registry, 1400);
        compare(expired.length, 1);
        compare(expired[0].providerId, "provider.a");
    }

    function test_listPendingEntries_includes_age_and_sorted_order() {
        let registry = LauncherAsyncProviderRegistry.createRegistry();
        const first = LauncherAsyncProviderRegistry.createPendingEntry({
            generation: 2,
            providerId: "provider.b"
        }, 3000, 2000);
        const second = LauncherAsyncProviderRegistry.createPendingEntry({
            generation: 1,
            providerId: "provider.a"
        }, 1000, 2000);

        registry = LauncherAsyncProviderRegistry.upsertPendingEntry(registry, first);
        registry = LauncherAsyncProviderRegistry.upsertPendingEntry(registry, second);

        const pending = LauncherAsyncProviderRegistry.listPendingEntries(registry, 3600);
        compare(pending.length, 2);
        compare(pending[0].providerId, "provider.a");
        compare(pending[1].providerId, "provider.b");
        compare(pending[0].ageMs, 2600);
    }

    name: "LauncherAsyncProviderRegistrySlice"
}

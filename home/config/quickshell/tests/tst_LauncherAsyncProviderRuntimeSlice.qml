import "../system/core/application/launcher/launcher-async-provider-registry.js" as LauncherAsyncProviderRegistry
import "../system/core/application/launcher/launcher-async-provider-runtime.js" as LauncherAsyncProviderRuntimeUseCases
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function runtimeDeps() {
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

    function createRuntime() {
        return LauncherAsyncProviderRuntimeUseCases.createLauncherAsyncProviderRuntime(runtimeDeps());
    }

    function createDeferredThenable() {
        let onResolve = null;
        let onReject = null;

        return {
            promise: {
                then: function (resolveFn, rejectFn) {
                    onResolve = resolveFn;
                    onReject = rejectFn;
                }
            },
            resolve: function (value) {
                if (onResolve)
                    onResolve(value);
            },
            reject: function (error) {
                if (onReject)
                    onReject(error);
            }
        };
    }

    function test_handlePendingEvent_tracks_and_resolves() {
        const runtime = createRuntime();
        const deferred = createDeferredThenable();
        let markCalls = 0;
        let resolveCalls = 0;
        let rejectCalls = 0;

        const tracking = runtime.handlePendingEvent({
            generation: 4,
            providerId: "async.apps",
            query: "fir",
            promise: deferred.promise
        }, {
            markPending: function () {
                markCalls += 1;
                return true;
            },
            resolve: function () {
                resolveCalls += 1;
                return {
                    status: "applied",
                    code: "launcher.async_provider.applied"
                };
            },
            reject: function () {
                rejectCalls += 1;
                return {
                    status: "failed",
                    code: "launcher.async_provider.failed"
                };
            }
        }, {
            nowMs: 1000,
            timeoutMs: 600,
            failureRetention: 5
        });

        compare(tracking.status, "tracked");
        compare(markCalls, 1);
        compare(runtime.listPending(1100).length, 1);

        deferred.resolve([]);

        compare(resolveCalls, 1);
        compare(rejectCalls, 0);
        compare(runtime.listPending(1300).length, 0);
    }

    function test_handlePendingEvent_ignores_when_markPending_rejects() {
        const runtime = createRuntime();
        const deferred = createDeferredThenable();
        let resolveCalls = 0;

        const tracking = runtime.handlePendingEvent({
            generation: 7,
            providerId: "async.apps",
            query: "foo",
            promise: deferred.promise
        }, {
            markPending: function () {
                return false;
            },
            resolve: function () {
                resolveCalls += 1;
                return {
                    status: "applied"
                };
            }
        }, {
            nowMs: 2000,
            timeoutMs: 700,
            failureRetention: 4
        });

        compare(tracking.status, "ignored");
        compare(tracking.code, "launcher.provider.async_not_marked");
        compare(runtime.listPending(2100).length, 0);

        deferred.resolve([]);
        compare(resolveCalls, 0);
    }

    function test_expirePending_rejects_and_records_timeout_failure() {
        const runtime = createRuntime();
        const deferred = createDeferredThenable();
        let rejectCalls = 0;

        runtime.handlePendingEvent({
            generation: 9,
            providerId: "async.apps",
            query: "fire",
            promise: deferred.promise
        }, {
            markPending: function () {
                return true;
            },
            resolve: function () {
                return {
                    status: "applied"
                };
            },
            reject: function () {
                rejectCalls += 1;
                return {
                    status: "failed",
                    code: "launcher.async_provider.failed"
                };
            }
        }, {
            nowMs: 3000,
            timeoutMs: 250,
            failureRetention: 5
        });

        const expired = runtime.expirePending({
            reject: function () {
                rejectCalls += 1;
                return {
                    status: "failed",
                    code: "launcher.async_provider.failed"
                };
            }
        }, {
            nowMs: 3300,
            timeoutMs: 250,
            failureRetention: 5
        });

        compare(expired.expiredCount, 1);
        compare(runtime.listPending(3300).length, 0);
        compare(rejectCalls, 1);

        const diagnostics = runtime.describe({
            nowMs: 3400,
            timeoutMs: 250,
            failureRetention: 5
        });
        compare(diagnostics.recentFailureCount, 1);
        compare(diagnostics.recentFailures[0].kind, "launcher.provider.async_timeout");
    }

    function test_late_resolution_after_timeout_is_ignored() {
        const runtime = createRuntime();
        const deferred = createDeferredThenable();
        let resolveCalls = 0;
        let rejectCalls = 0;

        runtime.handlePendingEvent({
            generation: 12,
            providerId: "async.apps",
            query: "chrome",
            promise: deferred.promise
        }, {
            markPending: function () {
                return true;
            },
            resolve: function () {
                resolveCalls += 1;
                return {
                    status: "applied"
                };
            },
            reject: function () {
                rejectCalls += 1;
                return {
                    status: "failed"
                };
            }
        }, {
            nowMs: 5000,
            timeoutMs: 200,
            failureRetention: 5
        });

        runtime.expirePending({
            reject: function () {
                rejectCalls += 1;
                return {
                    status: "failed"
                };
            }
        }, {
            nowMs: 5300,
            timeoutMs: 200,
            failureRetention: 5
        });

        deferred.resolve([]);

        compare(resolveCalls, 0);
        compare(rejectCalls, 1);
    }

    function test_recent_failure_retention_keeps_latest_entries() {
        const runtime = createRuntime();
        const first = createDeferredThenable();
        const second = createDeferredThenable();
        const third = createDeferredThenable();

        runtime.handlePendingEvent({
            generation: 21,
            providerId: "provider.a",
            query: "a",
            promise: first.promise
        }, {
            markPending: function () {
                return true;
            },
            reject: function () {
                return {
                    status: "failed",
                    code: "launcher.async_provider.failed"
                };
            }
        }, {
            nowMs: 7000,
            timeoutMs: 600,
            failureRetention: 2
        });
        first.reject(new Error("a"));

        runtime.handlePendingEvent({
            generation: 22,
            providerId: "provider.b",
            query: "b",
            promise: second.promise
        }, {
            markPending: function () {
                return true;
            },
            reject: function () {
                return {
                    status: "failed",
                    code: "launcher.async_provider.failed"
                };
            }
        }, {
            nowMs: 7100,
            timeoutMs: 600,
            failureRetention: 2
        });
        second.reject(new Error("b"));

        runtime.handlePendingEvent({
            generation: 23,
            providerId: "provider.c",
            query: "c",
            promise: third.promise
        }, {
            markPending: function () {
                return true;
            },
            reject: function () {
                return {
                    status: "failed",
                    code: "launcher.async_provider.failed"
                };
            }
        }, {
            nowMs: 7200,
            timeoutMs: 600,
            failureRetention: 2
        });
        third.reject(new Error("c"));

        const diagnostics = runtime.describe({
            nowMs: 7300,
            timeoutMs: 600,
            failureRetention: 2
        });
        compare(diagnostics.recentFailureCount, 2);
        compare(diagnostics.recentFailures[0].providerId, "provider.b");
        compare(diagnostics.recentFailures[1].providerId, "provider.c");
    }

    name: "LauncherAsyncProviderRuntimeSlice"
}

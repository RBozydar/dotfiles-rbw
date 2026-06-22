function isThenable(value) {
    if (!value) return false;
    const kind = typeof value;
    if (kind !== "object" && kind !== "function") return false;
    return typeof value.then === "function";
}

function normalizeNowMs(nowMs) {
    const parsed = Number(nowMs);
    if (!Number.isFinite(parsed)) return Date.now();
    return Math.round(parsed);
}

function normalizeTimeoutMs(timeoutMs) {
    const parsed = Number(timeoutMs);
    if (!Number.isFinite(parsed) || parsed < 100) return 2500;
    if (parsed > 120000) return 120000;
    return Math.round(parsed);
}

function normalizeFailureRetention(failureRetention) {
    const parsed = Number(failureRetention);
    if (!Number.isInteger(parsed) || parsed < 1) return 24;
    if (parsed > 256) return 256;
    return parsed;
}

function copyArray(values) {
    if (!Array.isArray(values)) return [];

    const next = [];
    for (let index = 0; index < values.length; index += 1) next.push(values[index]);
    return next;
}

function normalizeOptions(options) {
    const config = options && typeof options === "object" ? options : {};
    return {
        nowMs: normalizeNowMs(config.nowMs),
        timeoutMs: normalizeTimeoutMs(config.timeoutMs),
        failureRetention: normalizeFailureRetention(config.failureRetention),
        fallbackQuery: config.fallbackQuery === undefined ? "" : String(config.fallbackQuery),
    };
}

function normalizeHandlers(handlers) {
    const source = handlers && typeof handlers === "object" ? handlers : {};

    return {
        markPending:
            typeof source.markPending === "function"
                ? source.markPending
                : function () {
                      return true;
                  },
        resolve:
            typeof source.resolve === "function"
                ? source.resolve
                : function () {
                      return null;
                  },
        reject:
            typeof source.reject === "function"
                ? source.reject
                : function () {
                      return null;
                  },
        createTimeoutError:
            typeof source.createTimeoutError === "function"
                ? source.createTimeoutError
                : function (entry) {
                      return new Error(
                          "Async provider timed out after " +
                              String(
                                  entry && entry.timeoutMs !== undefined ? entry.timeoutMs : 2500,
                              ) +
                              "ms",
                      );
                  },
    };
}

function isFailedOutcome(outcome) {
    return Boolean(outcome && outcome.status === "failed");
}

function recordFailure(state, kind, event, outcome, details, failureRetention, nowMs) {
    const next = copyArray(state.recentFailures);

    next.push({
        at: new Date(normalizeNowMs(nowMs)).toISOString(),
        kind: String(kind || "launcher.provider.async_failure"),
        providerId: String(event && event.providerId ? event.providerId : ""),
        generation: Number(event && event.generation),
        query: event && event.query !== undefined ? String(event.query) : "",
        status: outcome && outcome.status ? String(outcome.status) : "unknown",
        code: outcome && outcome.code ? String(outcome.code) : "",
        reason: outcome && outcome.reason ? String(outcome.reason) : "",
        details: details && typeof details === "object" ? details : {},
    });

    const limit = normalizeFailureRetention(failureRetention);
    const overflow = next.length - limit;
    if (overflow > 0) next.splice(0, overflow);

    state.recentFailures = next;
}

function createRuntimeState(createRegistry) {
    return {
        registry: createRegistry(),
        recentFailures: [],
    };
}

function createLauncherAsyncProviderRuntime(deps) {
    const createRegistry =
        deps && typeof deps.createRegistry === "function"
            ? deps.createRegistry
            : function () {
                  return {};
              };
    const normalizePendingProviderEvent =
        deps && typeof deps.normalizePendingProviderEvent === "function"
            ? deps.normalizePendingProviderEvent
            : function (event, fallbackQuery) {
                  const generation = Number(event && event.generation);
                  const providerId = String(
                      event && event.providerId ? event.providerId : "",
                  ).trim();
                  if (!Number.isInteger(generation) || !providerId)
                      throw new Error("Invalid async provider event");
                  return {
                      generation: generation,
                      providerId: providerId,
                      query:
                          event && event.query !== undefined
                              ? String(event.query)
                              : String(fallbackQuery || ""),
                  };
              };
    const createPendingEntry =
        deps && typeof deps.createPendingEntry === "function"
            ? deps.createPendingEntry
            : function (event, startedAtMs, timeoutMs) {
                  return {
                      token: String(event.generation) + ":" + String(event.providerId),
                      generation: Number(event.generation),
                      providerId: String(event.providerId),
                      query: String(event.query || ""),
                      startedAtMs: normalizeNowMs(startedAtMs),
                      startedAt: new Date(normalizeNowMs(startedAtMs)).toISOString(),
                      timeoutMs: normalizeTimeoutMs(timeoutMs),
                      deadlineMs: normalizeNowMs(startedAtMs) + normalizeTimeoutMs(timeoutMs),
                  };
              };
    const upsertPendingEntry =
        deps && typeof deps.upsertPendingEntry === "function"
            ? deps.upsertPendingEntry
            : function (registry, entry) {
                  const next = {};
                  const source = registry && typeof registry === "object" ? registry : {};
                  for (const key in source) next[key] = source[key];
                  next[String(entry.token)] = entry;
                  return next;
              };
    const removePendingEntry =
        deps && typeof deps.removePendingEntry === "function"
            ? deps.removePendingEntry
            : function (registry, generation, providerId) {
                  const source = registry && typeof registry === "object" ? registry : {};
                  const token = String(generation) + ":" + String(providerId);
                  const next = {};
                  let removedEntry = null;
                  for (const key in source) {
                      if (key === token) {
                          removedEntry = source[key];
                          continue;
                      }
                      next[key] = source[key];
                  }
                  return {
                      registry: next,
                      removedEntry: removedEntry,
                  };
              };
    const listPendingEntries =
        deps && typeof deps.listPendingEntries === "function"
            ? deps.listPendingEntries
            : function () {
                  return [];
              };
    const collectExpiredEntries =
        deps && typeof deps.collectExpiredEntries === "function"
            ? deps.collectExpiredEntries
            : function () {
                  return [];
              };

    const state = createRuntimeState(createRegistry);

    function takePendingEntry(generation, providerId) {
        try {
            const removed = removePendingEntry(state.registry, generation, providerId);
            state.registry = removed.registry;
            return removed.removedEntry;
        } catch (error) {
            return null;
        }
    }

    function finalizePending(event, handlers, options, applyFn, failureKind, failureDetails) {
        const removedEntry = takePendingEntry(event.generation, event.providerId);
        if (!removedEntry) {
            return {
                status: "ignored",
                code: "launcher.provider.async_missing_pending",
                generation: Number(event.generation),
                providerId: String(event.providerId),
            };
        }

        const outcome = applyFn();
        if (isFailedOutcome(outcome))
            recordFailure(
                state,
                failureKind,
                removedEntry,
                outcome,
                failureDetails,
                options.failureRetention,
                options.nowMs,
            );

        return outcome;
    }

    return {
        reset: function () {
            state.registry = createRegistry();
            state.recentFailures = [];
        },

        listPending: function (nowMs) {
            return listPendingEntries(state.registry, normalizeNowMs(nowMs));
        },

        describe: function (options) {
            const config = normalizeOptions(options);
            const pendingProviders = listPendingEntries(state.registry, config.nowMs);
            const recentFailures = copyArray(state.recentFailures);

            return {
                timeoutMs: config.timeoutMs,
                pendingProviders: pendingProviders,
                pendingProviderCount: pendingProviders.length,
                recentFailures: recentFailures,
                recentFailureCount: recentFailures.length,
            };
        },

        handlePendingEvent: function (event, handlers, options) {
            if (!event || typeof event !== "object")
                return {
                    status: "ignored",
                    code: "launcher.provider.async_invalid_event",
                    reason: "Event payload is required",
                };
            if (!isThenable(event.promise))
                return {
                    status: "ignored",
                    code: "launcher.provider.async_missing_promise",
                    reason: "Event promise is required",
                };

            const normalizedHandlers = normalizeHandlers(handlers);
            const config = normalizeOptions(options);

            let normalizedEvent = null;
            try {
                normalizedEvent = normalizePendingProviderEvent(event, config.fallbackQuery);
            } catch (error) {
                return {
                    status: "ignored",
                    code: "launcher.provider.async_invalid_event",
                    reason:
                        error && error.message
                            ? String(error.message)
                            : "Invalid async provider event",
                };
            }

            if (!normalizedHandlers.markPending(normalizedEvent)) {
                return {
                    status: "ignored",
                    code: "launcher.provider.async_not_marked",
                    reason: "Pending event rejected by markPending handler",
                    generation: normalizedEvent.generation,
                    providerId: normalizedEvent.providerId,
                };
            }

            const pendingEntry = createPendingEntry(
                normalizedEvent,
                config.nowMs,
                config.timeoutMs,
            );
            state.registry = upsertPendingEntry(state.registry, pendingEntry);

            event.promise.then(
                function (rawItems) {
                    finalizePending(
                        normalizedEvent,
                        normalizedHandlers,
                        {
                            nowMs: Date.now(),
                            failureRetention: config.failureRetention,
                        },
                        function () {
                            return normalizedHandlers.resolve(normalizedEvent, rawItems);
                        },
                        "launcher.provider.async_apply_failed",
                        {},
                    );
                },
                function (error) {
                    finalizePending(
                        normalizedEvent,
                        normalizedHandlers,
                        {
                            nowMs: Date.now(),
                            failureRetention: config.failureRetention,
                        },
                        function () {
                            return normalizedHandlers.reject(normalizedEvent, error);
                        },
                        "launcher.provider.async_failed",
                        {},
                    );
                },
            );

            return {
                status: "tracked",
                code: "launcher.provider.async_pending_tracked",
                generation: normalizedEvent.generation,
                providerId: normalizedEvent.providerId,
                entry: pendingEntry,
            };
        },

        expirePending: function (handlers, options) {
            const normalizedHandlers = normalizeHandlers(handlers);
            const config = normalizeOptions(options);
            const expiredEntries = collectExpiredEntries(state.registry, config.nowMs);
            let expiredCount = 0;

            for (let index = 0; index < expiredEntries.length; index += 1) {
                const entry = expiredEntries[index];
                const removedEntry = takePendingEntry(entry.generation, entry.providerId);
                if (!removedEntry) continue;

                const timeoutError = normalizedHandlers.createTimeoutError(
                    removedEntry,
                    config.timeoutMs,
                );
                const timeoutEvent = {
                    generation: removedEntry.generation,
                    providerId: removedEntry.providerId,
                    query: removedEntry.query,
                };
                const outcome = normalizedHandlers.reject(timeoutEvent, timeoutError);

                expiredCount += 1;

                if (isFailedOutcome(outcome)) {
                    recordFailure(
                        state,
                        "launcher.provider.async_timeout",
                        removedEntry,
                        outcome,
                        {
                            timeoutMs: Number(removedEntry.timeoutMs),
                            startedAt: removedEntry.startedAt,
                            ageMs: Math.max(0, config.nowMs - Number(removedEntry.startedAtMs)),
                        },
                        config.failureRetention,
                        config.nowMs,
                    );
                }
            }

            return {
                expiredCount: expiredCount,
            };
        },
    };
}

import "./file-search-model.js" as FileSearchModel
import Quickshell
import Quickshell.Io
import QtQml

Scope {
    id: root

    property bool enabled: true
    property int resultLimit: 80
    property int queryResultLimit: 200
    property int minQueryLength: 2
    property string commandPath: "fd"
    property string searchRootsOverride: ""
    property var lastEntries: []
    property bool searching: false
    property bool queued: false
    property bool available: false
    property bool ready: false
    property bool degraded: false
    property string reasonCode: "initializing"
    property string lastUpdatedAt: ""
    property string lastError: ""
    property string lastQuery: ""
    property int lastResultCount: 0
    property var activeRequest: null
    property var queuedRequest: null
    property var activeCommand: []

    readonly property var searchRoots: {
        const overrideRoots = String(searchRootsOverride || "").trim();
        const fallbackRoot = String(Quickshell.env("HOME") || "").trim();
        const source = overrideRoots ? overrideRoots.split(":") : [fallbackRoot];
        const roots = [];
        const dedupe = {};

        for (let index = 0; index < source.length; index += 1) {
            const rootPath = String(source[index] || "").trim();
            if (!rootPath)
                continue;
            if (dedupe[rootPath])
                continue;
            dedupe[rootPath] = true;
            roots.push(rootPath);
        }

        return roots;
    }

    function nowIsoString(): string {
        return new Date().toISOString();
    }

    function normalizeQuery(command): string {
        const payload = command && command.payload ? command.payload : {};
        return String(payload.query === undefined ? "" : payload.query).trim();
    }

    function commandGeneration(command): int {
        const parsed = command && command.meta && command.meta.generation !== undefined ? Number(command.meta.generation) : NaN;
        if (!Number.isInteger(parsed))
            return -1;
        return parsed;
    }

    function createDeferredRequest(query, generation): var {
        const deferred = {
            query: String(query),
            generation: Number(generation),
            settled: false,
            resolved: false,
            value: [],
            error: null,
            resolveCallbacks: [],
            rejectCallbacks: [],
            promise: {
                then: function (onResolve, onReject) {
                    if (typeof onResolve === "function")
                        deferred.resolveCallbacks.push(onResolve);
                    if (typeof onReject === "function")
                        deferred.rejectCallbacks.push(onReject);

                    if (!deferred.settled)
                        return;

                    if (deferred.resolved) {
                        if (typeof onResolve === "function")
                            onResolve(deferred.value);
                        return;
                    }

                    if (typeof onReject === "function")
                        onReject(deferred.error);
                }
            }
        };

        return deferred;
    }

    function resolveDeferredRequest(request, items): void {
        if (!request || request.settled)
            return;

        request.settled = true;
        request.resolved = true;
        request.value = Array.isArray(items) ? items : [];
        const callbacks = Array.isArray(request.resolveCallbacks) ? request.resolveCallbacks : [];

        for (let index = 0; index < callbacks.length; index += 1) {
            const callback = callbacks[index];
            if (typeof callback !== "function")
                continue;
            callback(request.value);
        }
    }

    function rejectDeferredRequest(request, reason): void {
        if (!request || request.settled)
            return;

        request.settled = true;
        request.resolved = false;
        request.error = reason instanceof Error ? reason : new Error(String(reason || "File search request failed"));
        const callbacks = Array.isArray(request.rejectCallbacks) ? request.rejectCallbacks : [];

        for (let index = 0; index < callbacks.length; index += 1) {
            const callback = callbacks[index];
            if (typeof callback !== "function")
                continue;
            callback(request.error);
        }
    }

    function clearPendingRequests(reason): void {
        if (root.activeRequest) {
            rejectDeferredRequest(root.activeRequest, reason);
            root.activeRequest = null;
        }

        if (root.queuedRequest) {
            rejectDeferredRequest(root.queuedRequest, reason);
            root.queuedRequest = null;
        }

        root.searching = false;
        root.queued = false;
    }

    function setDisabledState(): void {
        clearPendingRequests("Launcher file search integration is disabled");
        available = false;
        ready = false;
        degraded = false;
        reasonCode = "integration_disabled";
        lastUpdatedAt = nowIsoString();
        lastError = "";
        lastEntries = [];
        lastQuery = "";
        lastResultCount = 0;
    }

    function applyAvailableState(code): void {
        available = true;
        ready = true;
        degraded = false;
        reasonCode = String(code || "ok");
        lastUpdatedAt = nowIsoString();
        lastError = "";
    }

    function applyFailure(code, reason): void {
        clearPendingRequests(reason);
        available = false;
        ready = false;
        degraded = true;
        reasonCode = String(code || "search_failed");
        lastUpdatedAt = nowIsoString();
        lastError = String(reason || "Launcher file search failed");
    }

    function buildSearchCommand(query): var {
        const command = [root.commandPath, "--absolute-path", "--color", "never", "--fixed-strings", "--ignore-case", "--hidden", "--max-results", String(root.queryResultLimit), "--exclude", ".git", "--exclude", "node_modules", "--exclude", ".cache", "--exclude", ".steam", "--exclude", ".local/share/Steam", "--exclude", ".local/share/Trash", "--", String(query)];

        for (let index = 0; index < root.searchRoots.length; index += 1)
            command.push(String(root.searchRoots[index]));

        return command;
    }

    function startNextRequest(): void {
        if (!enabled || !ready)
            return;
        if (searchRunner.running)
            return;

        if (!root.activeRequest) {
            if (!root.queuedRequest)
                return;
            root.activeRequest = root.queuedRequest;
            root.queuedRequest = null;
        }

        root.activeCommand = buildSearchCommand(root.activeRequest.query);
        root.searching = true;
        root.queued = root.queuedRequest !== null;
        searchRunner.running = true;
    }

    function probeAvailability(): void {
        if (!enabled) {
            setDisabledState();
            return;
        }

        if (!Array.isArray(searchRoots) || searchRoots.length === 0) {
            applyFailure("search_root_missing", "File search roots are empty");
            return;
        }

        if (!capabilityProbe.running)
            capabilityProbe.running = true;
    }

    function search(command): var {
        if (!enabled)
            return [];
        if (!ready) {
            const stableFailure = root.degraded && (root.reasonCode === "dependency_missing" || root.reasonCode === "search_root_missing");
            if (!stableFailure)
                probeAvailability();
            return [];
        }

        const query = normalizeQuery(command);
        if (!query)
            return [];
        if (query.length < Number(root.minQueryLength))
            return [];

        const request = createDeferredRequest(query, commandGeneration(command));
        if (root.searching || searchRunner.running || root.activeRequest !== null) {
            if (root.queuedRequest)
                rejectDeferredRequest(root.queuedRequest, "Superseded by newer launcher file query");
            root.queuedRequest = request;
            root.queued = true;
            return request.promise;
        }

        root.activeRequest = request;
        startNextRequest();
        return request.promise;
    }

    function describe(): var {
        return {
            kind: "adapter.search.file_search",
            integrationId: "launcher.file_search",
            commandPath: root.commandPath,
            searchRoots: root.searchRoots,
            enabled: root.enabled,
            available: root.available,
            ready: root.ready,
            degraded: root.degraded,
            reasonCode: root.reasonCode,
            lastUpdatedAt: root.lastUpdatedAt,
            entryCount: Array.isArray(root.lastEntries) ? root.lastEntries.length : 0,
            searching: root.searching,
            queued: root.queued,
            lastQuery: root.lastQuery,
            lastResultCount: Number(root.lastResultCount),
            lastError: root.lastError
        };
    }

    onEnabledChanged: {
        if (enabled) {
            reasonCode = "initializing";
            probeAvailability();
            return;
        }

        setDisabledState();
    }

    onCommandPathChanged: {
        reasonCode = "initializing";
        ready = false;
        available = false;
        probeAvailability();
    }

    onSearchRootsChanged: {
        reasonCode = "initializing";
        ready = false;
        available = false;
        probeAvailability();
    }

    Component.onCompleted: {
        if (enabled) {
            reasonCode = "initializing";
            probeAvailability();
            return;
        }

        setDisabledState();
    }

    Process {
        id: capabilityProbe

        command: [root.commandPath, "--version"]
        stdout: StdioCollector {
            id: capabilityOutput
        }
        stderr: StdioCollector {
            id: capabilityErrors
        }

        // qmllint disable signal-handler-parameters
        onExited: {
            const stdoutText = String(capabilityOutput.text ?? "").trim();
            const stderrText = String(capabilityErrors.text ?? "").trim();

            if (stdoutText.length > 0 || stderrText.length === 0) {
                root.applyAvailableState("ok");
                Qt.callLater(root.startNextRequest);
                return;
            }

            const normalizedError = stderrText.toLowerCase();
            const failureCode = normalizedError.indexOf("not found") >= 0 || normalizedError.indexOf("no such file") >= 0 ? "dependency_missing" : "dependency_probe_failed";
            root.applyFailure(failureCode, stderrText);
        }
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: searchRunner

        command: root.activeCommand
        stdout: StdioCollector {
            id: searchOutput
        }
        stderr: StdioCollector {
            id: searchErrors
        }

        // qmllint disable signal-handler-parameters
        onExited: {
            const request = root.activeRequest;
            root.activeRequest = null;
            root.searching = false;
            root.queued = root.queuedRequest !== null;

            if (!request) {
                Qt.callLater(root.startNextRequest);
                return;
            }

            const stdoutText = String(searchOutput.text ?? "");
            const stderrText = String(searchErrors.text ?? "").trim();
            const parsedEntries = FileSearchModel.parseFdOutput(stdoutText);

            if (stderrText.length > 0 && parsedEntries.length === 0) {
                const normalizedError = stderrText.toLowerCase();
                const failureCode = normalizedError.indexOf("not found") >= 0 || normalizedError.indexOf("no such file") >= 0 ? "dependency_missing" : "search_failed";
                root.applyFailure(failureCode, stderrText);
                root.rejectDeferredRequest(request, stderrText);
            } else {
                const items = FileSearchModel.searchEntries(parsedEntries, request.query, root.resultLimit);
                root.lastEntries = parsedEntries;
                root.lastQuery = request.query;
                root.lastResultCount = items.length;
                root.applyAvailableState(items.length > 0 ? "ok" : "empty_results");
                root.resolveDeferredRequest(request, items);
            }

            Qt.callLater(root.startNextRequest);
        }
        // qmllint enable signal-handler-parameters
    }
}

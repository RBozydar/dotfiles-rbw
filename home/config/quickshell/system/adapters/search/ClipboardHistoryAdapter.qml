import "./clipboard-history-model.js" as ClipboardHistoryModel
import Quickshell
import Quickshell.Io
import QtQml

Scope {
    id: root

    property bool enabled: true
    property bool autoRefresh: true
    property int refreshIntervalMs: 15 * 1000
    property int resultLimit: 120
    property string commandPath: "cliphist"
    property var historyEntries: []
    property bool refreshing: false
    property bool refreshQueued: false
    property bool hasRefreshed: false
    property bool available: false
    property bool ready: false
    property bool degraded: false
    property string reasonCode: "initializing"
    property string lastUpdatedAt: ""
    property string lastError: ""

    function nowIsoString(): string {
        return new Date().toISOString();
    }

    function setDisabledState(): void {
        historyEntries = [];
        refreshing = false;
        refreshQueued = false;
        hasRefreshed = true;
        available = false;
        ready = false;
        degraded = false;
        reasonCode = "integration_disabled";
        lastUpdatedAt = nowIsoString();
        lastError = "";
    }

    function applyEntries(entries): void {
        const normalizedEntries = ClipboardHistoryModel.normalizeEntries(entries);
        historyEntries = normalizedEntries;
        refreshing = false;
        hasRefreshed = true;
        available = true;
        ready = true;
        degraded = false;
        reasonCode = normalizedEntries.length > 0 ? "ok" : "empty_history";
        lastUpdatedAt = nowIsoString();
        lastError = "";
    }

    function applyFailure(code, reason): void {
        refreshing = false;
        hasRefreshed = true;
        available = false;
        ready = false;
        degraded = true;
        reasonCode = String(code || "refresh_failed");
        lastUpdatedAt = nowIsoString();
        lastError = String(reason || "Clipboard history refresh failed");
    }

    function refresh(): void {
        if (!enabled) {
            setDisabledState();
            return;
        }
        if (historyLoader.running) {
            refreshQueued = true;
            return;
        }

        refreshing = true;
        historyLoader.running = true;
    }

    function search(command): var {
        if (!enabled || !ready)
            return [];

        const payload = command && command.payload ? command.payload : {};
        const query = payload.query === undefined ? "" : String(payload.query);
        return ClipboardHistoryModel.searchEntries(historyEntries, query, resultLimit);
    }

    function describe(): var {
        return {
            kind: "adapter.search.clipboard_history",
            integrationId: "launcher.clipboard_history",
            enabled: root.enabled,
            available: root.available,
            ready: root.ready,
            degraded: root.degraded,
            reasonCode: root.reasonCode,
            lastUpdatedAt: root.lastUpdatedAt,
            entryCount: Array.isArray(root.historyEntries) ? root.historyEntries.length : 0,
            refreshing: root.refreshing,
            autoRefresh: root.autoRefresh,
            lastError: root.lastError
        };
    }

    onEnabledChanged: {
        if (enabled) {
            reasonCode = "initializing";
            refresh();
            return;
        }

        setDisabledState();
    }

    Component.onCompleted: {
        if (enabled) {
            reasonCode = "initializing";
            refresh();
            return;
        }

        setDisabledState();
    }

    Timer {
        interval: root.refreshIntervalMs
        running: root.autoRefresh && root.enabled
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: historyLoader

        command: [root.commandPath, "list"]
        stdout: StdioCollector {
            id: historyOutput
        }
        stderr: StdioCollector {
            id: historyErrors
        }

        // qmllint disable signal-handler-parameters
        onExited: {
            root.refreshing = false;
            root.hasRefreshed = true;

            const stdoutText = historyOutput.text ?? "";
            const stderrText = (historyErrors.text ?? "").trim();
            const parsedEntries = ClipboardHistoryModel.parseListOutput(stdoutText);

            if (stderrText.length > 0 && parsedEntries.length === 0) {
                const normalizedError = stderrText.toLowerCase();
                const failureCode = normalizedError.indexOf("not found") >= 0 ? "dependency_missing" : "refresh_failed";
                root.applyFailure(failureCode, stderrText);
            } else {
                root.applyEntries(parsedEntries);
            }

            if (root.refreshQueued) {
                root.refreshQueued = false;
                Qt.callLater(root.refresh);
            }
        }
        // qmllint enable signal-handler-parameters
    }
}

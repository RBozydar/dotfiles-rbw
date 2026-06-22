import "./homeassistant-model.js" as HomeAssistantModel
import Quickshell
import Quickshell.Io
import QtQml

Scope {
    id: root

    property bool enabled: false
    property bool autoRefresh: true
    property int refreshIntervalMs: 20 * 1000
    property int refreshAfterActionDelayMs: 900
    property string commandPath: Quickshell.shellPath("scripts/homeassistant.sh")
    property bool configured: false
    property bool available: false
    property bool ready: false
    property bool degraded: false
    property string reasonCode: "integration_disabled"
    property bool refreshing: false
    property bool refreshQueued: false
    property string lastUpdatedAt: ""
    property string lastError: ""
    property string error: ""
    property var lights: []
    property var scenes: []
    property int lightCount: 0
    property int activeLightCount: 0
    property int sceneCount: 0
    property bool anyOn: false
    property string chipLabel: ""
    property string summaryLabel: "Disabled"
    property var actionQueue: []
    property var activeActionCommand: []

    readonly property bool busy: actionRunner.running || (Array.isArray(root.actionQueue) && root.actionQueue.length > 0)

    function nowIsoString(): string {
        return new Date().toISOString();
    }

    function clearQueue(): void {
        root.actionQueue = [];
        root.activeActionCommand = [];
    }

    function applySummary(summary): void {
        root.configured = Boolean(summary.configured);
        root.available = Boolean(summary.available);
        root.ready = Boolean(summary.ready);
        root.degraded = Boolean(summary.degraded);
        root.reasonCode = String(summary.reasonCode === undefined ? "" : summary.reasonCode);
        root.lastUpdatedAt = String(summary.lastUpdatedAt === undefined ? "" : summary.lastUpdatedAt);
        root.error = String(summary.error === undefined ? "" : summary.error);
        root.lastError = root.error;
        root.lights = Array.isArray(summary.lights) ? summary.lights : [];
        root.scenes = Array.isArray(summary.scenes) ? summary.scenes : [];
        root.lightCount = Number(summary.lightCount);
        root.activeLightCount = Number(summary.activeLightCount);
        root.sceneCount = Number(summary.sceneCount);
        root.anyOn = summary.anyOn === true;
        root.chipLabel = String(summary.chipLabel === undefined ? "" : summary.chipLabel);
        root.summaryLabel = String(summary.summaryLabel === undefined ? "" : summary.summaryLabel);
    }

    function setDisabledState(): void {
        root.refreshing = false;
        root.refreshQueued = false;
        clearQueue();
        applySummary(HomeAssistantModel.summarizeSnapshot(false, null, nowIsoString()));
    }

    function applyRefreshFailure(stderrText): void {
        const failure = HomeAssistantModel.createRefreshFailure(stderrText);
        const summary = HomeAssistantModel.summarizeSnapshot(true, {
            configured: root.configured,
            available: false,
            error: failure.error,
            lights: []
        }, nowIsoString());

        summary.reasonCode = failure.reasonCode;
        summary.degraded = true;
        summary.ready = false;
        applySummary(summary);
    }

    function applySnapshotText(rawText): void {
        const parsed = HomeAssistantModel.parseSnapshotText(rawText);
        if (!parsed.ok) {
            const summary = HomeAssistantModel.summarizeSnapshot(true, {
                configured: root.configured,
                available: false,
                error: parsed.error,
                lights: []
            }, nowIsoString());

            summary.reasonCode = parsed.reasonCode;
            summary.degraded = true;
            summary.ready = false;
            applySummary(summary);
            return;
        }

        applySummary(HomeAssistantModel.summarizeSnapshot(true, parsed.snapshot, nowIsoString()));
    }

    function refresh(): void {
        if (!root.enabled) {
            setDisabledState();
            return;
        }

        if (fetcher.running) {
            root.refreshQueued = true;
            return;
        }

        root.refreshing = true;
        fetcher.running = true;
    }

    function queueAction(command): bool {
        if (!root.enabled) {
            setDisabledState();
            return false;
        }

        const nextCommand = Array.isArray(command) ? command.slice() : [];
        if (nextCommand.length === 0)
            return false;

        const queue = Array.isArray(root.actionQueue) ? root.actionQueue.slice() : [];
        queue.push(nextCommand);
        root.actionQueue = queue;
        root.startNextAction();
        return true;
    }

    function startNextAction(): void {
        if (!root.enabled) {
            clearQueue();
            return;
        }
        if (actionRunner.running)
            return;

        const queue = Array.isArray(root.actionQueue) ? root.actionQueue : [];
        if (queue.length === 0)
            return;

        const nextCommand = queue[0];
        root.actionQueue = queue.slice(1);
        root.activeActionCommand = Array.isArray(nextCommand) ? nextCommand.slice() : [];

        if (root.activeActionCommand.length === 0) {
            Qt.callLater(root.startNextAction);
            return;
        }

        actionRunner.running = true;
    }

    function applyActionResult(result): void {
        if (result.success) {
            root.error = "";
            root.lastError = "";
            return;
        }

        root.error = String(result.error || "Home Assistant action failed");
        root.lastError = root.error;
        root.reasonCode = String(result.reasonCode || "action_failed");
        root.degraded = true;
        root.ready = false;
        root.lastUpdatedAt = nowIsoString();
    }

    function toggleLight(entityId): bool {
        const normalizedEntityId = String(entityId || "").trim();
        if (!normalizedEntityId)
            return false;

        return root.queueAction(["sh", root.commandPath, "action", "toggle", normalizedEntityId]);
    }

    function setBrightness(entityId, brightnessPercent): bool {
        const normalizedEntityId = String(entityId || "").trim();
        if (!normalizedEntityId)
            return false;

        return root.queueAction(["sh", root.commandPath, "set-brightness", normalizedEntityId, String(Math.round(Number(brightnessPercent)))]);
    }

    function setColorTemp(entityId, colorTempKelvin): bool {
        const normalizedEntityId = String(entityId || "").trim();
        if (!normalizedEntityId)
            return false;

        return root.queueAction(["sh", root.commandPath, "set-color-temp", normalizedEntityId, String(Math.round(Number(colorTempKelvin)))]);
    }

    function turnOnLight(entityId): bool {
        const normalizedEntityId = String(entityId || "").trim();
        if (!normalizedEntityId)
            return false;

        return root.queueAction(["sh", root.commandPath, "action", "turn_on", normalizedEntityId]);
    }

    function turnOffLight(entityId): bool {
        const normalizedEntityId = String(entityId || "").trim();
        if (!normalizedEntityId)
            return false;

        return root.queueAction(["sh", root.commandPath, "action", "turn_off", normalizedEntityId]);
    }

    function activateScene(entityId): bool {
        const normalizedEntityId = String(entityId || "").trim();
        if (!normalizedEntityId)
            return false;

        return root.queueAction(["sh", root.commandPath, "activate-scene", normalizedEntityId]);
    }

    function describe(): var {
        return {
            kind: "adapter.integration.home_assistant",
            integrationId: "shell.home_assistant",
            dependencyClass: "network_service",
            dataSensitivity: "remote_account",
            effectType: "state_mutation",
            latencyExpectation: "interactive",
            commandPath: root.commandPath,
            enabled: root.enabled,
            configured: root.configured,
            available: root.available,
            ready: root.ready,
            degraded: root.degraded,
            reasonCode: root.reasonCode,
            refreshing: root.refreshing,
            busy: root.busy,
            queuedActionCount: Array.isArray(root.actionQueue) ? root.actionQueue.length : 0,
            lightCount: Number(root.lightCount),
            activeLightCount: Number(root.activeLightCount),
            sceneCount: Number(root.sceneCount),
            anyOn: root.anyOn,
            chipLabel: root.chipLabel,
            summaryLabel: root.summaryLabel,
            lastUpdatedAt: root.lastUpdatedAt,
            lastError: root.lastError
        };
    }

    onEnabledChanged: {
        if (root.enabled) {
            root.reasonCode = "initializing";
            root.refresh();
            return;
        }

        setDisabledState();
    }

    onCommandPathChanged: {
        if (!root.enabled)
            return;
        root.reasonCode = "initializing";
        root.refresh();
    }

    Component.onCompleted: {
        if (root.enabled) {
            root.reasonCode = "initializing";
            root.refresh();
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

    Timer {
        id: refreshAfterAction

        interval: root.refreshAfterActionDelayMs
        repeat: false
        onTriggered: root.refresh()
    }

    Process {
        id: fetcher

        command: ["sh", root.commandPath, "lights"]
        workingDirectory: Quickshell.shellDir

        stdout: StdioCollector {
            id: fetchCollector
        }

        stderr: StdioCollector {
            id: fetchErrors
        }

        // qmllint disable signal-handler-parameters
        onExited: {
            root.refreshing = false;

            if (!root.enabled) {
                root.setDisabledState();
                return;
            }

            const stdoutText = String(fetchCollector.text ?? "");
            const stderrText = String(fetchErrors.text ?? "").trim();

            if (stdoutText.trim().length > 0)
                root.applySnapshotText(stdoutText);
            else
                root.applyRefreshFailure(stderrText);

            if (root.refreshQueued) {
                root.refreshQueued = false;
                Qt.callLater(root.refresh);
            }
        }
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: actionRunner

        command: root.activeActionCommand
        workingDirectory: Quickshell.shellDir

        stdout: StdioCollector {
            id: actionCollector
        }

        stderr: StdioCollector {
            id: actionErrors
        }

        // qmllint disable signal-handler-parameters
        onExited: {
            if (!root.enabled) {
                root.setDisabledState();
                return;
            }

            const actionResult = HomeAssistantModel.parseActionResult(actionCollector.text ?? "", actionErrors.text ?? "");
            root.applyActionResult(actionResult);
            root.startNextAction();

            if (!actionRunner.running && (!Array.isArray(root.actionQueue) || root.actionQueue.length === 0))
                refreshAfterAction.restart();
        }
        // qmllint enable signal-handler-parameters
    }
}

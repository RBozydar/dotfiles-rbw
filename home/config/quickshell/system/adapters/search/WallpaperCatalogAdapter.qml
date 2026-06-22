import "./wallpaper-catalog-model.js" as WallpaperCatalogModel
import Quickshell
import Quickshell.Io
import QtQml

Scope {
    id: root

    property bool enabled: false
    property bool autoRefresh: true
    property int refreshIntervalMs: 10 * 60 * 1000
    property int maxSearchDepth: 4
    property int resultLimit: 80
    property int catalogLimit: 1200
    property string wallpaperRootsOverride: ""
    property string commandPath: "find"
    property string applyCommandPath: "swww"
    property string fallbackApplyCommandPath: "awww"
    property string resolvedApplyCommandPath: String(root.applyCommandPath || "swww")
    property var catalogEntries: []
    property bool refreshing: false
    property bool refreshQueued: false
    property bool available: false
    property bool ready: false
    property bool degraded: false
    property string reasonCode: "integration_disabled"
    property string lastUpdatedAt: ""
    property string lastError: ""

    readonly property var searchRoots: {
        const overrideRoots = String(wallpaperRootsOverride || "").trim();
        const home = String(Quickshell.env("HOME") || "").trim();
        const source = overrideRoots ? overrideRoots.split(":") : [home + "/Pictures/wallpapers", home + "/Pictures/Wallpapers", "/usr/share/wallpapers"];
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
    readonly property var refreshCommand: {
        if (!Array.isArray(searchRoots) || searchRoots.length === 0)
            return [];

        const command = [root.commandPath];
        for (let index = 0; index < searchRoots.length; index += 1)
            command.push(String(searchRoots[index]));

        command.push("-maxdepth", String(Math.max(1, Number(root.maxSearchDepth))), "-type", "f", "(", "-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", "-o", "-iname", "*.bmp", "-o", "-iname", "*.gif", ")");
        return command;
    }
    readonly property var applyCommandCandidates: root.collectApplyCommandCandidates()
    readonly property string capabilityProbeCommand: {
        const findCommand = root.shellSingleQuote(root.commandPath);
        const applyCandidates = Array.isArray(root.applyCommandCandidates) ? root.applyCommandCandidates : [];
        let applyCommandWords = "";
        let applyCommandLabel = "";

        for (let index = 0; index < applyCandidates.length; index += 1) {
            const candidate = String(applyCandidates[index] || "").trim();
            if (!candidate)
                continue;
            applyCommandWords += (applyCommandWords.length > 0 ? " " : "") + root.shellSingleQuote(candidate);
            applyCommandLabel += (applyCommandLabel.length > 0 ? ", " : "") + candidate;
        }

        if (!applyCommandWords)
            applyCommandWords = root.shellSingleQuote("swww");
        if (!applyCommandLabel)
            applyCommandLabel = "swww";

        return "missing=''; command -v -- " + findCommand + " >/dev/null 2>&1 || missing=\"$missing " + root.commandPath + "\"; resolved=''; for cmd in " + applyCommandWords + "; do if command -v -- \"$cmd\" >/dev/null 2>&1; then resolved=\"$cmd\"; break; fi; done; if [ -n \"$missing\" ]; then printf '%s\\n' \"${missing# }\" >&2; exit 1; fi; if [ -z \"$resolved\" ]; then printf '%s\\n' " + root.shellSingleQuote(applyCommandLabel) + " >&2; exit 1; fi; printf '%s\\n' \"$resolved\"";
    }

    function nowIsoString(): string {
        return new Date().toISOString();
    }

    function shellSingleQuote(value): string {
        const raw = String(value || "");
        return "'" + raw.replace(/'/g, "'\"'\"'") + "'";
    }

    function collectApplyCommandCandidates(): var {
        const source = [String(root.applyCommandPath || "").trim(), String(root.fallbackApplyCommandPath || "").trim()];
        const dedupe = {};
        const next = [];
        for (let index = 0; index < source.length; index += 1) {
            const candidate = source[index];
            if (!candidate)
                continue;
            if (dedupe[candidate])
                continue;
            dedupe[candidate] = true;
            next.push(candidate);
        }
        return next;
    }

    function setDisabledState(): void {
        root.catalogEntries = [];
        root.refreshing = false;
        root.refreshQueued = false;
        root.available = false;
        root.ready = false;
        root.degraded = false;
        root.reasonCode = "integration_disabled";
        root.lastUpdatedAt = nowIsoString();
        root.lastError = "";
        root.resolvedApplyCommandPath = String(root.applyCommandPath || "swww");
    }

    function classifyFailureReason(message, fallbackCode): string {
        const normalized = String(message || "").toLowerCase();
        if (!normalized)
            return String(fallbackCode || "refresh_failed");
        if (normalized.indexOf("not found") >= 0 || normalized.indexOf("no such file or directory") >= 0)
            return "dependency_missing";
        if (normalized.indexOf("permission denied") >= 0)
            return "permission_denied";
        return String(fallbackCode || "refresh_failed");
    }

    function applyFailure(code, reason): void {
        root.refreshing = false;
        root.available = false;
        root.ready = false;
        root.degraded = true;
        root.reasonCode = String(code || "refresh_failed");
        root.lastUpdatedAt = nowIsoString();
        root.lastError = String(reason || "Wallpaper integration refresh failed");
        root.catalogEntries = [];
    }

    function applyCatalogEntries(paths): void {
        const normalizedEntries = WallpaperCatalogModel.normalizeEntries(paths, Number(root.catalogLimit));
        root.catalogEntries = normalizedEntries;
        root.refreshing = false;
        root.available = true;
        root.ready = true;
        root.degraded = false;
        root.reasonCode = normalizedEntries.length > 0 ? "ok" : "catalog_empty";
        root.lastUpdatedAt = nowIsoString();
        root.lastError = "";
    }

    function probeAvailability(): void {
        if (!root.enabled) {
            root.setDisabledState();
            return;
        }
        if (!Array.isArray(root.searchRoots) || root.searchRoots.length === 0) {
            root.applyFailure("search_root_missing", "Wallpaper search roots are empty");
            return;
        }

        if (capabilityProbe.running)
            return;

        capabilityProbe.running = true;
        Qt.callLater(() => {
            if (!root.enabled)
                return;
            if (root.ready || root.degraded)
                return;
            if (root.reasonCode !== "initializing")
                return;
            if (capabilityProbe.running)
                return;

            const stderrText = String(capabilityErrors.text ?? "").trim();
            if (stderrText.length > 0) {
                root.applyFailure(root.classifyFailureReason(stderrText, "dependency_probe_failed"), stderrText);
                return;
            }

            root.applyFailure("dependency_probe_failed", "Wallpaper dependency probe did not start");
        });
    }

    function refresh(): void {
        if (!root.enabled) {
            root.setDisabledState();
            return;
        }
        if (!root.ready) {
            const stableFailure = root.degraded && (root.reasonCode === "dependency_missing" || root.reasonCode === "search_root_missing");
            if (!stableFailure)
                root.probeAvailability();
            return;
        }
        if (catalogRefresh.running) {
            root.refreshQueued = true;
            return;
        }

        root.refreshing = true;
        catalogRefresh.running = true;
    }

    function search(command): var {
        if (!root.enabled || !root.ready)
            return [];

        const payload = command && command.payload ? command.payload : {};
        const query = payload.query === undefined ? "" : String(payload.query);
        return WallpaperCatalogModel.searchEntries(root.catalogEntries, query, root.resultLimit);
    }

    function describe(): var {
        return {
            kind: "adapter.search.wallpaper_catalog",
            integrationId: "launcher.wallpaper",
            dependencyClass: "local_tool",
            dataSensitivity: "none",
            effectType: "command_execution",
            latencyExpectation: "background",
            commandPath: root.commandPath,
            applyCommandPath: root.applyCommandPath,
            fallbackApplyCommandPath: root.fallbackApplyCommandPath,
            resolvedApplyCommandPath: root.resolvedApplyCommandPath,
            searchRoots: root.searchRoots,
            enabled: root.enabled,
            available: root.available,
            ready: root.ready,
            degraded: root.degraded,
            reasonCode: root.reasonCode,
            lastUpdatedAt: root.lastUpdatedAt,
            entryCount: Array.isArray(root.catalogEntries) ? root.catalogEntries.length : 0,
            refreshing: root.refreshing,
            autoRefresh: root.autoRefresh,
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

    onSearchRootsChanged: {
        reasonCode = "initializing";
        ready = false;
        available = false;
        probeAvailability();
    }

    onCommandPathChanged: {
        reasonCode = "initializing";
        ready = false;
        available = false;
        probeAvailability();
    }

    onApplyCommandPathChanged: {
        reasonCode = "initializing";
        ready = false;
        available = false;
        probeAvailability();
    }

    onFallbackApplyCommandPathChanged: {
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

    Timer {
        interval: root.refreshIntervalMs
        running: root.autoRefresh && root.enabled
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: capabilityProbe

        command: ["/bin/sh", "-lc", root.capabilityProbeCommand]
        stdout: StdioCollector {
            id: capabilityOutput
        }
        stderr: StdioCollector {
            id: capabilityErrors
        }

        // qmllint disable signal-handler-parameters
        onExited: {
            if (!root.enabled) {
                root.setDisabledState();
                return;
            }

            const stdoutText = String(capabilityOutput.text ?? "").trim();
            const stderrText = String(capabilityErrors.text ?? "").trim();

            if (stdoutText.length > 0) {
                root.resolvedApplyCommandPath = String(stdoutText.split("\n")[0] || "").trim() || String(root.applyCommandPath || "swww");
                root.available = true;
                root.ready = true;
                root.degraded = false;
                root.reasonCode = "ok";
                root.lastUpdatedAt = root.nowIsoString();
                root.lastError = "";
                Qt.callLater(root.refresh);
                return;
            }

            const message = stderrText.length > 0 ? "Missing required commands: " + stderrText : "Missing required wallpaper integration dependencies";
            root.resolvedApplyCommandPath = String(root.applyCommandPath || "swww");
            root.applyFailure(root.classifyFailureReason(message, "dependency_missing"), message);
        }
        // qmllint enable signal-handler-parameters
    }

    Process {
        id: catalogRefresh

        command: root.refreshCommand
        stdout: StdioCollector {
            id: catalogOutput
        }
        stderr: StdioCollector {
            id: catalogErrors
        }

        // qmllint disable signal-handler-parameters
        onExited: {
            root.refreshing = false;

            if (!root.enabled) {
                root.setDisabledState();
                return;
            }

            const stdoutText = String(catalogOutput.text ?? "");
            const stderrText = String(catalogErrors.text ?? "").trim();
            const paths = WallpaperCatalogModel.parseFindOutput(stdoutText);

            if (paths.length > 0) {
                root.applyCatalogEntries(paths);
            } else if (stderrText.length > 0) {
                root.applyFailure(root.classifyFailureReason(stderrText, "refresh_failed"), stderrText);
            } else {
                root.applyCatalogEntries([]);
            }

            if (root.refreshQueued) {
                root.refreshQueued = false;
                Qt.callLater(root.refresh);
            }
        }
        // qmllint enable signal-handler-parameters
    }
}

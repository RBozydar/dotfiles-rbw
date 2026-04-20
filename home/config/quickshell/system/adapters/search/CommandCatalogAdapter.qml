import "./command-catalog-model.js" as CommandCatalogModel
import Quickshell
import Quickshell.Io
import QtQml

Scope {
    id: root

    property bool autoRefresh: true
    property int refreshIntervalMs: 20 * 60 * 1000
    property int resultLimit: 120
    property string cachePathOverride: ""
    property var catalogOverride: null
    property var catalogEntries: []
    property bool refreshing: false
    property string lastError: ""

    readonly property string cachePath: {
        if (cachePathOverride && cachePathOverride.length > 0)
            return cachePathOverride;

        const cacheHome = Quickshell.env("XDG_CACHE_HOME");
        const home = Quickshell.env("HOME");
        const resolvedCacheHome = cacheHome && cacheHome.length > 0 ? cacheHome : home + "/.cache";
        return resolvedCacheHome + "/rbw-shell.launcher-command-catalog.json";
    }
    readonly property var effectiveCatalog: {
        if (catalogOverride !== null && catalogOverride !== undefined)
            return CommandCatalogModel.normalizeEntries(catalogOverride);
        return catalogEntries;
    }

    function parseCatalogText(text): var {
        return CommandCatalogModel.parseCatalogJson(text);
    }

    function applyCatalogText(text): void {
        const parsed = parseCatalogText(text);
        if (parsed.length <= 0)
            return;

        catalogEntries = parsed;
        catalogCacheFile.setText(JSON.stringify(parsed, null, 2) + "\n");
        catalogCacheFile.waitForJob();
        lastError = "";
    }

    function refresh(): void {
        if (!autoRefresh)
            return;
        if (catalogOverride !== null && catalogOverride !== undefined)
            return;
        if (catalogBuilder.running)
            return;

        refreshing = true;
        catalogBuilder.running = true;
    }

    function searchTerm(term): var {
        return CommandCatalogModel.searchEntries(effectiveCatalog, term, resultLimit);
    }

    function describe(): var {
        return {
            kind: "adapter.search.command_catalog",
            cachePath: root.cachePath,
            entryCount: Array.isArray(root.effectiveCatalog) ? root.effectiveCatalog.length : 0,
            refreshing: root.refreshing,
            autoRefresh: root.autoRefresh,
            lastError: root.lastError
        };
    }

    Component.onCompleted: {
        if (catalogOverride !== null && catalogOverride !== undefined)
            return;

        catalogEntries = parseCatalogText(catalogCacheFile.text);
        refresh();
    }

    Timer {
        interval: root.refreshIntervalMs
        running: root.autoRefresh
        repeat: true
        onTriggered: root.refresh()
    }

    FileView {
        id: catalogCacheFile
        path: root.cachePath
        blockWrites: false
        watchChanges: true
        atomicWrites: true
    }

    Process {
        id: catalogBuilder

        command: ["python3", Quickshell.shellPath("scripts/build-launcher-command-catalog.py")]
        workingDirectory: Quickshell.shellDir

        stdout: StdioCollector {
            id: catalogOutput
        }

        stderr: StdioCollector {
            id: catalogErrors
        }

        // qmllint disable signal-handler-parameters
        onExited: {
            root.refreshing = false;

            const stdoutText = catalogOutput.text ?? "";
            const stderrText = (catalogErrors.text ?? "").trim();

            if (stdoutText.trim().length > 0)
                root.applyCatalogText(stdoutText);
            else if (stderrText.length > 0)
                root.lastError = stderrText;
            else
                root.lastError = "Launcher command catalog refresh returned no data";
        }
        // qmllint enable signal-handler-parameters
    }
}

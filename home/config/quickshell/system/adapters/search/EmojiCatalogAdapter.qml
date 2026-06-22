import "./emoji-catalog-model.js" as EmojiCatalogModel
import Quickshell
import Quickshell.Io
import QtQml

Scope {
    id: root

    property bool enabled: true
    property int resultLimit: 60
    property string catalogPathOverride: ""
    property var catalogOverride: null
    property var catalogEntries: []
    property bool available: false
    property bool ready: false
    property bool degraded: false
    property string reasonCode: "initializing"
    property string lastUpdatedAt: ""
    property string lastError: ""

    readonly property string catalogPath: {
        if (catalogPathOverride && catalogPathOverride.length > 0)
            return catalogPathOverride;
        return "/usr/share/oh-my-zsh/plugins/emoji/gemoji_db.json";
    }
    readonly property var effectiveCatalog: {
        if (catalogOverride !== null && catalogOverride !== undefined)
            return EmojiCatalogModel.normalizeEmojiEntries(catalogOverride);
        return catalogEntries;
    }

    function nowIsoString(): string {
        return new Date().toISOString();
    }

    function setDisabledState(): void {
        catalogEntries = [];
        available = false;
        ready = false;
        degraded = false;
        reasonCode = "integration_disabled";
        lastUpdatedAt = nowIsoString();
        lastError = "";
    }

    function applyCatalogEntries(entries, reason): void {
        const normalized = EmojiCatalogModel.normalizeEmojiEntries(entries);
        catalogEntries = normalized;
        available = true;
        ready = true;
        degraded = false;
        reasonCode = reason === undefined ? "ok" : String(reason);
        lastUpdatedAt = nowIsoString();
        lastError = "";
    }

    function applyCatalogFailure(code, reason): void {
        catalogEntries = [];
        available = false;
        ready = false;
        degraded = true;
        reasonCode = String(code || "catalog_invalid");
        lastUpdatedAt = nowIsoString();
        lastError = String(reason || "Emoji catalog is unavailable");
    }

    function parseCatalogText(text): var {
        return EmojiCatalogModel.parseEmojiCatalogJson(text);
    }

    function catalogFileText(): string {
        if (!emojiCatalogFile)
            return "";

        const value = emojiCatalogFile.text;
        if (typeof value === "function") {
            try {
                return String(value.call(emojiCatalogFile));
            } catch (error) {
                return "";
            }
        }

        return value === undefined || value === null ? "" : String(value);
    }

    function reload(): void {
        if (!enabled) {
            setDisabledState();
            return;
        }

        if (catalogOverride !== null && catalogOverride !== undefined) {
            applyCatalogEntries(catalogOverride, "override");
            return;
        }

        const sourceText = catalogFileText();
        const parsed = parseCatalogText(sourceText);
        if (parsed.length > 0) {
            applyCatalogEntries(parsed, "ok");
            return;
        }

        if (!sourceText.trim()) {
            applyCatalogFailure("catalog_missing", "Emoji catalog file is unavailable: " + root.catalogPath);
            return;
        }

        applyCatalogFailure("catalog_invalid", "Emoji catalog data is invalid JSON");
    }

    function search(command): var {
        if (!enabled || !ready)
            return [];

        const payload = command && command.payload ? command.payload : {};
        const query = payload.query === undefined ? "" : String(payload.query);
        return EmojiCatalogModel.searchEmojiEntries(effectiveCatalog, query, resultLimit);
    }

    function describe(): var {
        return {
            kind: "adapter.search.emoji_catalog",
            integrationId: "launcher.emoji",
            catalogPath: root.catalogPath,
            enabled: root.enabled,
            available: root.available,
            ready: root.ready,
            degraded: root.degraded,
            reasonCode: root.reasonCode,
            lastUpdatedAt: root.lastUpdatedAt,
            entryCount: Array.isArray(root.effectiveCatalog) ? root.effectiveCatalog.length : 0,
            lastError: root.lastError
        };
    }

    onEnabledChanged: reload()
    onCatalogPathChanged: reload()
    onCatalogOverrideChanged: reload()

    Component.onCompleted: reload()

    FileView {
        id: emojiCatalogFile
        path: root.catalogPath
        blockWrites: true
        watchChanges: true
        onTextChanged: root.reload()
    }
}

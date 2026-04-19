import "./settings-file-migrations.js" as SettingsFileMigrations
import Quickshell
import Quickshell.Io
import QtQml

Scope {
    id: root

    property string domainKey: "shell"
    property string appKey: "rbw-shell"
    property string configPathOverride: ""
    property string statePathOverride: ""
    property string metadataPathOverride: ""
    property string backupSuffix: ".bak"

    readonly property string configPath: {
        if (configPathOverride && configPathOverride.length > 0)
            return configPathOverride;
        const configHome = Quickshell.env("XDG_CONFIG_HOME");
        const home = Quickshell.env("HOME");
        const resolvedConfigHome = configHome && configHome.length > 0 ? configHome : home + "/.config";
        return resolvedConfigHome + "/" + appKey + ".settings.config.json";
    }
    readonly property string statePath: {
        if (statePathOverride && statePathOverride.length > 0)
            return statePathOverride;
        const stateHome = Quickshell.env("XDG_STATE_HOME");
        const home = Quickshell.env("HOME");
        const resolvedStateHome = stateHome && stateHome.length > 0 ? stateHome : home + "/.local/state";
        return resolvedStateHome + "/" + appKey + ".settings.state.json";
    }
    readonly property string metadataPath: {
        if (metadataPathOverride && metadataPathOverride.length > 0)
            return metadataPathOverride;
        const stateHome = Quickshell.env("XDG_STATE_HOME");
        const home = Quickshell.env("HOME");
        const resolvedStateHome = stateHome && stateHome.length > 0 ? stateHome : home + "/.local/state";
        return resolvedStateHome + "/" + appKey + ".settings.meta.json";
    }
    readonly property string configBackupPath: root.configPath + root.backupSuffix
    readonly property string stateBackupPath: root.statePath + root.backupSuffix

    FileView {
        id: configFile
        path: root.configPath
        blockWrites: false
        watchChanges: true
        atomicWrites: true
    }

    FileView {
        id: stateFile
        path: root.statePath
        blockWrites: false
        watchChanges: true
        atomicWrites: true
    }

    FileView {
        id: configBackupFile
        path: root.configBackupPath
        blockWrites: false
        watchChanges: true
        atomicWrites: true
    }

    FileView {
        id: stateBackupFile
        path: root.stateBackupPath
        blockWrites: false
        watchChanges: true
        atomicWrites: true
    }

    FileView {
        id: metadataFile
        path: root.metadataPath
        blockWrites: false
        watchChanges: true
        atomicWrites: true
    }

    function isDomainSupported(key): bool {
        return String(key) === root.domainKey;
    }

    function parseErrorReason(error, fallbackReason): string {
        if (error && error.message)
            return String(error.message);
        return fallbackReason;
    }

    function normalizeNonNegativeInteger(value, fallback): int {
        const normalized = Number(value);
        if (Number.isInteger(normalized) && normalized >= 0)
            return normalized;
        return Number(fallback) >= 0 ? Number(fallback) : 0;
    }

    function cloneJsonValue(value): var {
        if (Array.isArray(value)) {
            const nextArray = [];
            for (let index = 0; index < value.length; index += 1)
                nextArray.push(cloneJsonValue(value[index]));
            return nextArray;
        }

        if (value && typeof value === "object") {
            const nextObject = {};
            for (const key in value)
                nextObject[key] = cloneJsonValue(value[key]);
            return nextObject;
        }

        return value;
    }

    function canonicalizeJsonValue(value): var {
        if (Array.isArray(value)) {
            const nextArray = [];
            for (let index = 0; index < value.length; index += 1)
                nextArray.push(canonicalizeJsonValue(value[index]));
            return nextArray;
        }

        if (value && typeof value === "object") {
            const keys = Object.keys(value).sort();
            const nextObject = {};
            for (let index = 0; index < keys.length; index += 1) {
                const key = keys[index];
                nextObject[key] = canonicalizeJsonValue(value[key]);
            }
            return nextObject;
        }

        return value;
    }

    function parseDocument(text): var {
        if (!text || text.length === 0)
            return null;

        try {
            const parsed = JSON.parse(text);
            return parsed && typeof parsed === "object" ? parsed : null;
        } catch (error) {
            return null;
        }
    }

    function serializeDocument(document): string {
        return JSON.stringify(canonicalizeJsonValue(document), null, 2) + "\n";
    }

    function hasText(text): bool {
        if (!text || typeof text !== "string")
            return false;
        return text.trim().length > 0;
    }

    function computeTextDigest(text): string {
        const value = String(text === undefined || text === null ? "" : text);
        let hash = 2166136261;

        for (let index = 0; index < value.length; index += 1) {
            hash ^= value.charCodeAt(index);
            hash = Math.imul(hash, 16777619);
        }

        return (hash >>> 0).toString(16).padStart(8, "0");
    }

    function parseMetadataDocument(): var {
        const parsed = parseDocument(metadataFile.text);
        if (!parsed || typeof parsed !== "object")
            return null;

        const generation = normalizeNonNegativeInteger(parsed.generation, 0);
        const schemaVersion = normalizeNonNegativeInteger(parsed.schemaVersion, 1);

        return {
            kind: String(parsed.kind === undefined ? "shell.settings.snapshot.meta" : parsed.kind),
            schemaVersion: schemaVersion,
            domainKey: String(parsed.domainKey === undefined ? root.domainKey : parsed.domainKey),
            generation: generation,
            writtenAt: String(parsed.writtenAt === undefined ? "" : parsed.writtenAt),
            configDigest: String(parsed.configDigest === undefined ? "" : parsed.configDigest),
            stateDigest: String(parsed.stateDigest === undefined ? "" : parsed.stateDigest)
        };
    }

    function determineNextGeneration(requestedGeneration): int {
        const metadata = parseMetadataDocument();
        const persistedGeneration = metadata ? metadata.generation : 0;
        const desiredGeneration = normalizeNonNegativeInteger(requestedGeneration, persistedGeneration);
        return Math.max(persistedGeneration, desiredGeneration) + 1;
    }

    function readMigratedDocumentWithRecovery(primaryText, backupText, migrateFn, warningPrefix): var {
        const warnings = [];

        const primaryParsed = parseDocument(primaryText);
        if (primaryParsed) {
            try {
                return {
                    document: migrateFn(primaryParsed),
                    source: "primary",
                    warnings: warnings
                };
            } catch (error) {
                warnings.push({
                    code: warningPrefix + ".primary_invalid",
                    reason: parseErrorReason(error, "Primary document failed validation")
                });
            }
        } else if (hasText(primaryText)) {
            warnings.push({
                code: warningPrefix + ".primary_invalid_json",
                reason: "Primary document contains invalid JSON"
            });
        }

        const backupParsed = parseDocument(backupText);
        if (backupParsed) {
            try {
                const migratedBackup = migrateFn(backupParsed);
                warnings.push({
                    code: warningPrefix + ".recovered_from_backup",
                    reason: "Recovered persisted snapshot from backup"
                });
                return {
                    document: migratedBackup,
                    source: "backup",
                    warnings: warnings
                };
            } catch (error) {
                warnings.push({
                    code: warningPrefix + ".backup_invalid",
                    reason: parseErrorReason(error, "Backup document failed validation")
                });
            }
        } else if (hasText(backupText)) {
            warnings.push({
                code: warningPrefix + ".backup_invalid_json",
                reason: "Backup document contains invalid JSON"
            });
        }

        return {
            document: null,
            source: "missing",
            warnings: warnings
        };
    }

    function backupCurrentDocuments(): void {
        const parsedConfig = parseDocument(configFile.text);
        if (parsedConfig) {
            configBackupFile.setText(serializeDocument(parsedConfig));
            configBackupFile.waitForJob();
        }

        const parsedState = parseDocument(stateFile.text);
        if (parsedState) {
            stateBackupFile.setText(serializeDocument(parsedState));
            stateBackupFile.waitForJob();
        }
    }

    function readSnapshot(key): var {
        if (!isDomainSupported(key))
            return null;

        const configRead = readMigratedDocumentWithRecovery(configFile.text, configBackupFile.text, SettingsFileMigrations.migrateSettingsConfigDocument, "settings.config");
        const stateRead = readMigratedDocumentWithRecovery(stateFile.text, stateBackupFile.text, SettingsFileMigrations.migrateSettingsStateDocument, "settings.state");

        if (!configRead.document && !stateRead.document)
            return null;

        const metadata = parseMetadataDocument();
        const warnings = [];
        for (let index = 0; index < configRead.warnings.length; index += 1)
            warnings.push(cloneJsonValue(configRead.warnings[index]));
        for (let index = 0; index < stateRead.warnings.length; index += 1)
            warnings.push(cloneJsonValue(stateRead.warnings[index]));

        if (metadata && metadata.kind !== "shell.settings.snapshot.meta") {
            warnings.push({
                code: "settings.snapshot.metadata_kind_invalid",
                reason: "Snapshot metadata kind is invalid"
            });
        }
        if (metadata && metadata.domainKey !== root.domainKey) {
            warnings.push({
                code: "settings.snapshot.metadata_domain_mismatch",
                reason: "Snapshot metadata domain does not match adapter domain"
            });
        }

        const configDigest = configRead.document ? computeTextDigest(serializeDocument(configRead.document)) : "";
        const stateDigest = stateRead.document ? computeTextDigest(serializeDocument(stateRead.document)) : "";

        if (metadata && metadata.configDigest && configDigest && metadata.configDigest !== configDigest) {
            warnings.push({
                code: "settings.config.digest_mismatch",
                reason: "Config snapshot digest does not match metadata"
            });
        }
        if (metadata && metadata.stateDigest && stateDigest && metadata.stateDigest !== stateDigest) {
            warnings.push({
                code: "settings.state.digest_mismatch",
                reason: "State snapshot digest does not match metadata"
            });
        }

        return {
            config: configRead.document,
            state: stateRead.document,
            generation: metadata ? metadata.generation : 0,
            meta: {
                kind: "adapter.persistence.file.snapshot",
                configSource: configRead.source,
                stateSource: stateRead.source,
                metadataPath: root.metadataPath,
                warnings: warnings
            }
        };
    }

    function writeSnapshot(key, snapshot): var {
        if (!isDomainSupported(key))
            return {
                saved: false,
                configSaved: false,
                stateSaved: false,
                generation: 0,
                reason: "Unsupported persistence domain"
            };

        const normalizedSnapshot = snapshot && typeof snapshot === "object" ? snapshot : {};
        const existingSnapshot = readSnapshot(key);

        const rawConfig = normalizedSnapshot.config === undefined ? existingSnapshot ? existingSnapshot.config : null : normalizedSnapshot.config;
        const rawState = normalizedSnapshot.state === undefined ? existingSnapshot ? existingSnapshot.state : null : normalizedSnapshot.state;

        if (!rawConfig || !rawState) {
            return {
                saved: false,
                configSaved: false,
                stateSaved: false,
                generation: existingSnapshot ? normalizeNonNegativeInteger(existingSnapshot.generation, 0) : 0,
                reason: "Snapshot write requires both config and state documents",
                meta: {
                    kind: "adapter.persistence.file.snapshot"
                }
            };
        }

        try {
            const configDocument = SettingsFileMigrations.migrateSettingsConfigDocument(rawConfig);
            const stateDocument = SettingsFileMigrations.migrateSettingsStateDocument(rawState);
            const serializedConfig = serializeDocument(configDocument);
            const serializedState = serializeDocument(stateDocument);
            const nextGeneration = determineNextGeneration(normalizedSnapshot.generation);

            backupCurrentDocuments();

            configFile.setText(serializedConfig);
            configFile.waitForJob();
            stateFile.setText(serializedState);
            stateFile.waitForJob();

            const metadataDocument = {
                kind: "shell.settings.snapshot.meta",
                schemaVersion: 1,
                domainKey: root.domainKey,
                generation: nextGeneration,
                writtenAt: new Date().toISOString(),
                configDigest: computeTextDigest(serializedConfig),
                stateDigest: computeTextDigest(serializedState)
            };

            metadataFile.setText(serializeDocument(metadataDocument));
            metadataFile.waitForJob();

            return {
                saved: true,
                configSaved: true,
                stateSaved: true,
                generation: nextGeneration,
                meta: {
                    kind: "adapter.persistence.file.snapshot",
                    metadataPath: root.metadataPath,
                    configBackupPath: root.configBackupPath,
                    stateBackupPath: root.stateBackupPath
                }
            };
        } catch (error) {
            return {
                saved: false,
                configSaved: false,
                stateSaved: false,
                generation: existingSnapshot ? normalizeNonNegativeInteger(existingSnapshot.generation, 0) : 0,
                reason: parseErrorReason(error, "Snapshot write failed"),
                meta: {
                    kind: "adapter.persistence.file.snapshot"
                }
            };
        }
    }

    function readConfig(key): var {
        if (!isDomainSupported(key))
            return null;
        const parsed = parseDocument(configFile.text);
        if (!parsed)
            return null;
        return SettingsFileMigrations.migrateSettingsConfigDocument(parsed);
    }

    function readState(key): var {
        if (!isDomainSupported(key))
            return null;
        const parsed = parseDocument(stateFile.text);
        if (!parsed)
            return null;
        return SettingsFileMigrations.migrateSettingsStateDocument(parsed);
    }

    function writeConfig(key, document): bool {
        if (!isDomainSupported(key))
            return false;
        try {
            const migrated = SettingsFileMigrations.migrateSettingsConfigDocument(document);
            configFile.setText(serializeDocument(migrated));
            configFile.waitForJob();
            return true;
        } catch (error) {
            return false;
        }
    }

    function writeState(key, document): bool {
        if (!isDomainSupported(key))
            return false;
        try {
            const migrated = SettingsFileMigrations.migrateSettingsStateDocument(document);
            stateFile.setText(serializeDocument(migrated));
            stateFile.waitForJob();
            return true;
        } catch (error) {
            return false;
        }
    }

    function describe(): var {
        return {
            kind: "adapter.persistence.file",
            domainKey: root.domainKey,
            configPath: root.configPath,
            statePath: root.statePath,
            metadataPath: root.metadataPath,
            configBackupPath: root.configBackupPath,
            stateBackupPath: root.stateBackupPath
        };
    }
}

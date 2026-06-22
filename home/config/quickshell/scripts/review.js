#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");

const scriptDir = __dirname;
const quickshellRoot = path.resolve(scriptDir, "..");
const repoRoot = process.env.REVIEW_REPO_ROOT;
const quickshellRel = normalizePath(path.relative(repoRoot, quickshellRoot));
const defaultOutputPath = path.join(quickshellRoot, ".review", "latest.json");
const defaultEvidenceDir = path.join(quickshellRoot, ".review", "evidence");
const workflowRel = ".github/workflows/quickshell-verify.yml";

function normalizePath(value) {
    return value.split(path.sep).join("/");
}

function parseArgs(argv) {
    const options = {
        classifyOnly: false,
        requireSecondary: false,
        output: defaultOutputPath,
        evidencePaths: [],
    };

    for (let index = 0; index < argv.length; index += 1) {
        const arg = argv[index];

        if (arg === "--classify-only") {
            options.classifyOnly = true;
            continue;
        }

        if (arg === "--require-secondary") {
            options.requireSecondary = true;
            continue;
        }

        if (arg === "--output") {
            index += 1;
            if (index >= argv.length) throw new Error("--output requires a path");
            options.output = path.resolve(argv[index]);
            continue;
        }

        if (arg === "--evidence") {
            index += 1;
            if (index >= argv.length) throw new Error("--evidence requires a path");
            options.evidencePaths.push(path.resolve(argv[index]));
            continue;
        }

        throw new Error("Unknown argument: " + arg);
    }

    if (
        !options.classifyOnly &&
        !options.requireSecondary &&
        (process.env.CI === "1" || process.env.CI === "true")
    )
        options.classifyOnly = true;

    return options;
}

function parseStatusLine(line) {
    if (line.includes("\t")) {
        const fields = line.split("\t");
        const rawStatus = fields[0];
        const statusCode = rawStatus.replace(/[0-9]+$/, "");
        const filePath = fields.length >= 3 ? fields[2] : fields[1];

        return {
            statusCode,
            path: normalizePath(filePath),
        };
    }

    const statusCode = line.slice(0, 2).trim() || "??";
    let filePath = line.slice(3).trim();

    if (filePath.includes(" -> ")) filePath = filePath.split(" -> ").pop();

    return {
        statusCode,
        path: normalizePath(filePath),
    };
}

function loadChangedFiles() {
    const statusFile = process.env.REVIEW_STATUS_FILE;
    if (!statusFile) throw new Error("REVIEW_STATUS_FILE is required");

    const output = fs.readFileSync(statusFile, "utf8");

    if (!output.trim()) return [];

    return output
        .trim()
        .split("\n")
        .map(parseStatusLine)
        .filter(
            (entry) => entry.path.startsWith(quickshellRel + "/") || entry.path === workflowRel,
        );
}

function classifyFile(filePath) {
    if (filePath === workflowRel) return "ci";

    const quickshellPrefix = quickshellRel + "/";
    if (!filePath.startsWith(quickshellPrefix)) return "external";

    const localPath = filePath.slice(quickshellPrefix.length);

    if (localPath.startsWith("system/core/")) return "system/core";
    if (localPath.startsWith("system/adapters/")) return "system/adapters";
    if (localPath.startsWith("system/ui/")) return "system/ui";
    if (localPath.startsWith("system/tests/")) return "system/tests";
    if (localPath.startsWith("adr/")) return "adr";
    if (localPath.endsWith("AGENTS.md")) return "agents";
    if (localPath.endsWith("SKILL.md")) return "skill";
    if (localPath.startsWith("system/")) return "system/misc";
    return "legacy";
}

function detectTreeClassification(layers) {
    const hasLegacy = layers.has("legacy");
    const hasSystem = Array.from(layers).some((layer) => layer.startsWith("system/"));

    if (hasLegacy && hasSystem) return "cross-tree";
    if (hasLegacy) return "legacy-only";
    if (hasSystem) return "system-only";
    if (layers.size === 0) return "clean";
    return "governance-only";
}

function countDiffStats(changedFiles) {
    let added = 0;
    let deleted = 0;
    const numstatFile = process.env.REVIEW_NUMSTAT_FILE;

    if (numstatFile && fs.existsSync(numstatFile)) {
        const output = fs.readFileSync(numstatFile, "utf8");
        for (const line of output.trim().split("\n").filter(Boolean)) {
            const fields = line.split("\t");
            added += Number(fields[0]) || 0;
            deleted += Number(fields[1]) || 0;
        }
    }

    for (const entry of changedFiles) {
        if (entry.statusCode !== "??") continue;

        try {
            const content = fs.readFileSync(path.join(repoRoot, entry.path), "utf8");
            added += content.split("\n").length;
        } catch (error) {
            added += 1;
        }
    }

    return {
        files: changedFiles.length,
        added,
        deleted,
    };
}

function detectNewSubsystemSkeleton(changedFiles) {
    const counts = new Map();

    for (const entry of changedFiles) {
        if (entry.statusCode !== "??" || !entry.path.startsWith(quickshellRel + "/system/"))
            continue;

        const relative = entry.path.slice((quickshellRel + "/system/").length).split("/");
        if (relative.length < 2) continue;

        let key = null;

        if (relative[0] === "core" || relative[0] === "adapters")
            key = relative.slice(0, 2).join("/");
        else if (relative[0] === "ui" && relative.length >= 3) key = relative.slice(0, 3).join("/");

        if (!key) continue;

        counts.set(key, (counts.get(key) || 0) + 1);
    }

    for (const [key, count] of counts.entries()) {
        if (count >= 3) return key;
    }

    return null;
}

function loadEvidence(paths) {
    const evidenceFiles = [];
    const seen = new Set();

    if (fs.existsSync(defaultEvidenceDir)) {
        for (const entry of fs.readdirSync(defaultEvidenceDir)) {
            if (!entry.endsWith(".json")) continue;
            evidenceFiles.push(path.join(defaultEvidenceDir, entry));
        }
    }

    for (const explicitPath of paths) evidenceFiles.push(explicitPath);

    const results = [];

    for (const filePath of evidenceFiles) {
        const resolvedPath = path.resolve(filePath);
        if (seen.has(resolvedPath)) continue;
        seen.add(resolvedPath);

        if (!fs.existsSync(resolvedPath)) continue;

        let parsed = null;
        let errorMessage = null;

        try {
            parsed = JSON.parse(fs.readFileSync(resolvedPath, "utf8"));
        } catch (error) {
            errorMessage = error instanceof Error ? error.message : String(error);
        }

        const valid =
            parsed &&
            typeof parsed === "object" &&
            typeof parsed.reviewer === "string" &&
            typeof parsed.model === "string" &&
            typeof parsed.reviewedAt === "string" &&
            typeof parsed.summary === "string" &&
            typeof parsed.changeFingerprint === "string" &&
            typeof parsed.status === "string" &&
            ["pass", "pass-with-risks", "blocker"].includes(parsed.status);

        results.push({
            path: normalizePath(path.relative(repoRoot, resolvedPath)),
            valid,
            status: valid ? parsed.status : "blocker",
            reviewer: valid ? parsed.reviewer : null,
            model: valid ? parsed.model : null,
            summary: valid ? parsed.summary : "Invalid review evidence",
            changeFingerprint: valid ? parsed.changeFingerprint : null,
            error: valid ? null : errorMessage || "Missing required review evidence fields",
        });
    }

    return results;
}

function makeReview(changedFiles, options) {
    const touchedLayers = new Set(changedFiles.map((entry) => classifyFile(entry.path)));
    const treeClassification = detectTreeClassification(touchedLayers);
    const diffStats = countDiffStats(changedFiles);
    const highRiskReasons = [];
    const blockers = [];
    const architecturalDrift = [];
    const testGaps = [];
    const residualRisks = [];
    const architectureLayers = Array.from(touchedLayers).filter((layer) =>
        ["legacy", "system/core", "system/adapters", "system/ui"].includes(layer),
    );
    const evidence = loadEvidence(options.evidencePaths);
    const newSubsystem = detectNewSubsystemSkeleton(changedFiles);
    const comparison = {
        mode: process.env.REVIEW_MODE || "worktree",
        baseRef: process.env.REVIEW_BASE_REF || null,
        headRef: process.env.REVIEW_HEAD_REF || null,
    };

    if (new Set(architectureLayers).size >= 2)
        highRiskReasons.push("Touches multiple architectural layers");
    if (treeClassification === "cross-tree")
        highRiskReasons.push("Crosses between the legacy tree and system/");
    if (touchedLayers.has("adr")) highRiskReasons.push("Modifies ADRs");
    if (touchedLayers.has("agents")) highRiskReasons.push("Modifies AGENTS.md guidance");
    if (touchedLayers.has("skill"))
        highRiskReasons.push("Modifies skill packaging or operational prompts");
    if (newSubsystem)
        highRiskReasons.push("Introduces a likely subsystem skeleton under " + newSubsystem);
    if (diffStats.files >= 12 || diffStats.added + diffStats.deleted >= 400)
        highRiskReasons.push("Large change set");

    if (treeClassification === "cross-tree")
        architecturalDrift.push(
            "Cross-tree changes should stay narrow and explicitly justified by ADR-0020.",
        );

    if (
        (touchedLayers.has("system/core") ||
            touchedLayers.has("system/adapters") ||
            touchedLayers.has("system/ui")) &&
        !changedFiles.some(
            (entry) =>
                entry.path.startsWith(quickshellRel + "/tests/") ||
                entry.path.startsWith(quickshellRel + "/system/tests/"),
        )
    ) {
        testGaps.push("System-tree changes did not update any test files.");
    }

    const changeFingerprint = crypto
        .createHash("sha256")
        .update(
            JSON.stringify({
                changedFiles: changedFiles.map((entry) => ({
                    path: entry.path,
                    statusCode: entry.statusCode,
                })),
                diffStats,
                comparison,
            }),
        )
        .digest("hex");

    for (const reason of highRiskReasons) residualRisks.push(reason);

    const evidenceIssues = [];
    for (const entry of evidence) {
        if (!entry.valid)
            evidenceIssues.push("Invalid review evidence at " + entry.path + ": " + entry.error);
        else if (entry.changeFingerprint !== changeFingerprint)
            evidenceIssues.push(
                "Review evidence at " +
                    entry.path +
                    " does not match the current diff fingerprint.",
            );
        else if (entry.status === "blocker")
            evidenceIssues.push("Secondary review reported a blocker in " + entry.path + ".");
    }

    if (options.requireSecondary) {
        for (const issue of evidenceIssues) blockers.push(issue);
    } else if (evidenceIssues.length > 0) {
        residualRisks.push("Review evidence issues (non-blocking in classify-only mode).");
    }

    const secondaryReviewRequired = highRiskReasons.length > 0;
    const matchingEvidence = evidence.filter(
        (entry) =>
            entry.valid &&
            entry.changeFingerprint === changeFingerprint &&
            entry.status !== "blocker",
    );
    const secondaryReviewSatisfied = !secondaryReviewRequired || matchingEvidence.length > 0;

    if (options.requireSecondary && secondaryReviewRequired && !secondaryReviewSatisfied) {
        blockers.push(
            "High-risk change requires secondary review evidence in .review/evidence/ or via --evidence.",
        );
    }

    let status = "pass";
    if (blockers.length > 0) status = "blocker";
    else if (
        secondaryReviewRequired ||
        evidence.some((entry) => entry.valid && entry.status === "pass-with-risks")
    )
        status = "pass-with-risks";

    return {
        schemaVersion: 1,
        generatedAt: new Date().toISOString(),
        reviewer: "local-review-classifier",
        status,
        comparison,
        changeFingerprint,
        treeClassification,
        changedFiles: changedFiles.map((entry) => entry.path),
        touchedLayers: Array.from(touchedLayers).sort(),
        diffStats,
        secondaryReviewRequired,
        secondaryReviewSatisfied,
        blockers,
        architecturalDrift,
        testGaps,
        residualRisks,
        evidence,
    };
}

function writeReview(review, outputPath) {
    fs.mkdirSync(path.dirname(outputPath), {
        recursive: true,
    });
    fs.writeFileSync(outputPath, JSON.stringify(review, null, 2) + "\n");
}

function printSummary(review, outputPath) {
    console.log("review:", review.status);
    console.log("review: tree =", review.treeClassification);
    console.log("review: mode =", review.comparison.mode);
    console.log("review: layers =", review.touchedLayers.join(", ") || "none");
    console.log("review: artifact =", normalizePath(path.relative(repoRoot, outputPath)));

    if (review.blockers.length > 0) {
        for (const blocker of review.blockers) console.log("review: blocker:", blocker);
    }
}

function main() {
    if (!repoRoot) throw new Error("REVIEW_REPO_ROOT is required");

    const options = parseArgs(process.argv.slice(2));
    const changedFiles = loadChangedFiles();
    const outputPath = path.resolve(options.output);
    const review = makeReview(changedFiles, options);

    writeReview(review, outputPath);
    printSummary(review, outputPath);

    if (review.status === "blocker") process.exit(1);
}

main();

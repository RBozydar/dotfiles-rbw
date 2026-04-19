function normalizeOptionalInteger(value, minimum, maximum) {
    if (value === null || value === undefined) return null;

    const numeric = Number(value);
    if (!Number.isInteger(numeric)) return null;

    if (minimum !== undefined && numeric < minimum) return null;
    if (maximum !== undefined && numeric > maximum) return null;

    return numeric;
}

function normalizeLight(light) {
    if (!light || typeof light !== "object" || Array.isArray(light)) return null;

    const entityId = light.entityId === undefined ? "" : String(light.entityId).trim();
    if (!entityId) return null;

    const supportedColorModes = [];
    if (Array.isArray(light.supportedColorModes)) {
        for (let index = 0; index < light.supportedColorModes.length; index += 1) {
            const mode = String(
                light.supportedColorModes[index] === undefined
                    ? ""
                    : light.supportedColorModes[index],
            ).trim();
            if (!mode) continue;
            supportedColorModes.push(mode);
        }
    }

    return {
        entityId: entityId,
        name: light.name === undefined ? entityId : String(light.name),
        state: light.state === undefined ? "unknown" : String(light.state),
        available: light.available !== false,
        isOn: light.isOn === true,
        brightnessPercent: normalizeOptionalInteger(light.brightnessPercent, 0, 100),
        colorMode: light.colorMode === undefined ? "" : String(light.colorMode),
        supportedColorModes: supportedColorModes,
        supportsColorTemp: light.supportsColorTemp === true,
        colorTempKelvin: normalizeOptionalInteger(light.colorTempKelvin, 1000, 20000),
        minColorTempKelvin: normalizeOptionalInteger(light.minColorTempKelvin, 1000, 20000),
        maxColorTempKelvin: normalizeOptionalInteger(light.maxColorTempKelvin, 1000, 20000),
    };
}

function normalizeScene(scene) {
    if (!scene || typeof scene !== "object" || Array.isArray(scene)) return null;

    const entityId = scene.entityId === undefined ? "" : String(scene.entityId).trim();
    if (!entityId) return null;

    return {
        entityId: entityId,
        name: scene.name === undefined ? entityId : String(scene.name),
        state: scene.state === undefined ? "unknown" : String(scene.state),
        available: scene.available !== false,
    };
}

function normalizeLights(rawLights) {
    const source = Array.isArray(rawLights) ? rawLights : [];
    const lights = [];

    for (let index = 0; index < source.length; index += 1) {
        const light = normalizeLight(source[index]);
        if (!light) continue;
        lights.push(light);
    }

    return lights;
}

function normalizeScenes(rawScenes) {
    const source = Array.isArray(rawScenes) ? rawScenes : [];
    const scenes = [];

    for (let index = 0; index < source.length; index += 1) {
        const scene = normalizeScene(source[index]);
        if (!scene) continue;
        scenes.push(scene);
    }

    return scenes;
}

function normalizeSnapshotPayload(payload) {
    const source = payload && typeof payload === "object" && !Array.isArray(payload) ? payload : {};

    return {
        configured: source.configured === true,
        available: source.available === true,
        error: source.error === undefined ? "" : String(source.error),
        lights: normalizeLights(source.lights),
        scenes: normalizeScenes(source.scenes),
    };
}

function parseSnapshotText(rawText) {
    const text = String(rawText === undefined ? "" : rawText).trim();
    if (!text) {
        return {
            ok: false,
            reasonCode: "empty_response",
            error: "Home Assistant returned no data",
        };
    }

    try {
        return {
            ok: true,
            snapshot: normalizeSnapshotPayload(JSON.parse(text)),
        };
    } catch (error) {
        const message = error && error.message ? String(error.message) : String(error);
        return {
            ok: false,
            reasonCode: "parse_failed",
            error: "Home Assistant parse error: " + message,
        };
    }
}

function classifyFailureReason(errorText, fallbackCode) {
    const normalized = String(errorText === undefined ? "" : errorText)
        .trim()
        .toLowerCase();
    if (!normalized) return String(fallbackCode || "failed");

    if (
        normalized.indexOf("not found") >= 0 ||
        normalized.indexOf("no such file") >= 0 ||
        normalized.indexOf("uv not found") >= 0
    )
        return "dependency_missing";

    if (
        normalized.indexOf("missing ha_token") >= 0 ||
        normalized.indexOf("missing hass_token") >= 0
    )
        return "not_configured";

    if (
        normalized.indexOf("invalid light entity_id") >= 0 ||
        normalized.indexOf("not in rbw_ha_lights") >= 0 ||
        normalized.indexOf("invalid scene entity_id") >= 0 ||
        normalized.indexOf("not in rbw_ha_scenes") >= 0
    )
        return "invalid_entity";

    if (
        normalized.indexOf("network error") >= 0 ||
        normalized.indexOf("http ") >= 0 ||
        normalized.indexOf("timed out") >= 0
    )
        return "unavailable";

    return String(fallbackCode || "failed");
}

function summarizeSnapshot(enabled, snapshot, nowIso) {
    const lastUpdatedAt = String(nowIso === undefined ? "" : nowIso);
    if (enabled !== true) {
        return {
            configured: false,
            available: false,
            ready: false,
            degraded: false,
            reasonCode: "integration_disabled",
            error: "",
            lastUpdatedAt: lastUpdatedAt,
            lights: [],
            scenes: [],
            lightCount: 0,
            activeLightCount: 0,
            sceneCount: 0,
            anyOn: false,
            chipLabel: "",
            summaryLabel: "Disabled",
        };
    }

    const normalizedSnapshot = normalizeSnapshotPayload(snapshot);
    const lightCount = normalizedSnapshot.lights.length;
    let activeLightCount = 0;

    for (let index = 0; index < normalizedSnapshot.lights.length; index += 1) {
        if (normalizedSnapshot.lights[index].isOn) activeLightCount += 1;
    }

    const anyOn = activeLightCount > 0;
    const configured = normalizedSnapshot.configured;
    const available = normalizedSnapshot.available;
    const error = normalizedSnapshot.error;

    let ready = false;
    let degraded = false;
    let reasonCode = "ok";

    if (!configured) {
        reasonCode = classifyFailureReason(error, "not_configured");
        degraded = true;
    } else if (!available) {
        reasonCode = classifyFailureReason(error, "unavailable");
        degraded = true;
    } else {
        ready = true;
        reasonCode = lightCount === 0 ? "no_lights" : "ok";
    }

    let chipLabel = "";
    if (configured) {
        if (!available) chipLabel = "ha";
        else if (lightCount === 0) chipLabel = "0";
        else chipLabel = String(activeLightCount) + "/" + String(lightCount);
    }

    let summaryLabel = "Not configured";
    if (configured && !available) summaryLabel = "Unavailable";
    else if (configured && available && lightCount === 0) summaryLabel = "No lights";
    else if (configured && available && activeLightCount === 0) summaryLabel = "All off";
    else if (configured && available && activeLightCount === lightCount) summaryLabel = "All on";
    else if (configured && available)
        summaryLabel = String(activeLightCount) + " of " + String(lightCount) + " on";

    return {
        configured: configured,
        available: available,
        ready: ready,
        degraded: degraded,
        reasonCode: reasonCode,
        error: error,
        lastUpdatedAt: lastUpdatedAt,
        lights: normalizedSnapshot.lights,
        scenes: normalizedSnapshot.scenes,
        lightCount: lightCount,
        activeLightCount: activeLightCount,
        sceneCount: normalizedSnapshot.scenes.length,
        anyOn: anyOn,
        chipLabel: chipLabel,
        summaryLabel: summaryLabel,
    };
}

function createRefreshFailure(stderrText) {
    const text = String(stderrText === undefined ? "" : stderrText).trim();
    if (!text) {
        return {
            reasonCode: "refresh_failed",
            error: "Home Assistant refresh failed",
        };
    }

    return {
        reasonCode: classifyFailureReason(text, "refresh_failed"),
        error: text,
    };
}

function parseActionResult(stdoutText, stderrText) {
    const stdout = String(stdoutText === undefined ? "" : stdoutText).trim();
    const stderr = String(stderrText === undefined ? "" : stderrText).trim();

    if (stdout.length > 0) {
        try {
            const payload = JSON.parse(stdout);
            if (payload && payload.success === true) {
                return {
                    success: true,
                    reasonCode: "action_ok",
                    error: "",
                };
            }

            const payloadError =
                payload && payload.error !== undefined
                    ? String(payload.error)
                    : "Home Assistant action failed";
            return {
                success: false,
                reasonCode: classifyFailureReason(payloadError, "action_failed"),
                error: payloadError,
            };
        } catch (error) {
            const message = error && error.message ? String(error.message) : String(error);
            return {
                success: false,
                reasonCode: "action_parse_failed",
                error: "Home Assistant action parse error: " + message,
            };
        }
    }

    if (stderr.length > 0) {
        return {
            success: false,
            reasonCode: classifyFailureReason(stderr, "action_failed"),
            error: stderr,
        };
    }

    return {
        success: false,
        reasonCode: "action_failed",
        error: "Home Assistant action failed",
    };
}

function normalizeText(value) {
    return String(value === undefined ? "" : value).trim();
}

function lowercase(value) {
    return normalizeText(value).toLowerCase();
}

function normalizeLimit(value, fallback) {
    const parsed = Number(value);
    if (!Number.isInteger(parsed) || parsed <= 0) return Number(fallback);
    if (parsed > 200) return 200;
    return parsed;
}

function normalizeLight(light) {
    if (!light || typeof light !== "object" || Array.isArray(light)) return null;

    const entityId = normalizeText(light.entityId);
    if (!entityId) return null;

    return {
        entityId: entityId,
        name: normalizeText(light.name) || entityId,
        available: light.available !== false,
        isOn: light.isOn === true,
        brightnessPercent: Number.isInteger(Number(light.brightnessPercent))
            ? Number(light.brightnessPercent)
            : null,
        state: normalizeText(light.state) || "unknown",
    };
}

function normalizeScene(scene) {
    if (!scene || typeof scene !== "object" || Array.isArray(scene)) return null;

    const entityId = normalizeText(scene.entityId);
    if (!entityId) return null;

    return {
        entityId: entityId,
        name: normalizeText(scene.name) || entityId,
        available: scene.available !== false,
        state: normalizeText(scene.state) || "unknown",
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

function queryMatches(value, query) {
    const haystack = lowercase(value);
    if (!query) return false;
    if (haystack.indexOf(query) >= 0) return true;

    const terms = query.split(/\s+/).filter(Boolean);
    if (terms.length <= 1) return false;

    for (let index = 0; index < terms.length; index += 1) {
        if (haystack.indexOf(terms[index]) < 0) return false;
    }

    return true;
}

function computeScore(name, entityId, query, baseScore) {
    let score = Number(baseScore);
    const normalizedName = lowercase(name);
    const normalizedEntityId = lowercase(entityId);

    if (!query) return score;
    if (normalizedName === query) score += 240;
    else if (normalizedName.indexOf(query) === 0) score += 180;
    else if (normalizedName.indexOf(query) >= 0) score += 120;

    if (normalizedEntityId === query) score += 120;
    else if (normalizedEntityId.indexOf(query) >= 0) score += 70;

    return score;
}

function createToggleLightItem(light, query, commands) {
    const stateLabel = light.available ? (light.isOn ? "On" : "Off") : "Unavailable";
    const brightnessLabel =
        light.brightnessPercent === null ? "" : " • " + String(light.brightnessPercent) + "%";

    return {
        id: "ha:light:toggle:" + light.entityId,
        title: light.name,
        subtitle: "HA light • " + stateLabel + brightnessLabel,
        detail: light.entityId,
        iconName: "",
        provider: "homeassistant",
        score: computeScore(light.name, light.entityId, query, 420),
        action: {
            type: "shell.ipc.dispatch",
            command: commands.toggleLightCommand,
            args: [light.entityId],
        },
    };
}

function createSetLightStateItem(light, query, commands) {
    if (!light.available) return null;

    const turnOn = !light.isOn;
    const command = turnOn ? commands.turnOnLightCommand : commands.turnOffLightCommand;
    const verb = turnOn ? "Turn On" : "Turn Off";

    return {
        id: "ha:light:set:" + (turnOn ? "on:" : "off:") + light.entityId,
        title: verb + " " + light.name,
        subtitle: "HA light action",
        detail: light.entityId,
        iconName: "",
        provider: "homeassistant",
        score: computeScore(light.name, light.entityId, query, 360),
        action: {
            type: "shell.ipc.dispatch",
            command: command,
            args: [light.entityId],
        },
    };
}

function createActivateSceneItem(scene, query, commands) {
    const stateLabel = scene.available ? "Activate" : "Unavailable";
    return {
        id: "ha:scene:activate:" + scene.entityId,
        title: "Activate " + scene.name,
        subtitle: "HA scene • " + stateLabel,
        detail: scene.entityId,
        iconName: "",
        provider: "homeassistant",
        score: computeScore(scene.name, scene.entityId, query, 380),
        action: {
            type: "shell.ipc.dispatch",
            command: commands.activateSceneCommand,
            args: [scene.entityId],
        },
    };
}

function sortResults(items) {
    items.sort(function (left, right) {
        if (right.score !== left.score) return right.score - left.score;
        if (left.title < right.title) return -1;
        if (left.title > right.title) return 1;
        return 0;
    });
}

function searchHomeAssistantSnapshot(rawSnapshot, rawQuery, limit, commandConfig) {
    const query = lowercase(rawQuery);
    const normalizedQuery = query.trim();
    if (!normalizedQuery) return [];

    const snapshot =
        rawSnapshot && typeof rawSnapshot === "object" && !Array.isArray(rawSnapshot)
            ? rawSnapshot
            : {};
    const lights = normalizeLights(snapshot.lights);
    const scenes = normalizeScenes(snapshot.scenes);
    const maxResults = normalizeLimit(limit, 20);
    const commands = {
        toggleLightCommand:
            normalizeText(commandConfig && commandConfig.toggleLightCommand) ||
            "homeassistant.toggle_light",
        turnOnLightCommand:
            normalizeText(commandConfig && commandConfig.turnOnLightCommand) ||
            "homeassistant.turn_on_light",
        turnOffLightCommand:
            normalizeText(commandConfig && commandConfig.turnOffLightCommand) ||
            "homeassistant.turn_off_light",
        activateSceneCommand:
            normalizeText(commandConfig && commandConfig.activateSceneCommand) ||
            "homeassistant.activate_scene",
    };

    const items = [];

    for (let index = 0; index < lights.length; index += 1) {
        const light = lights[index];
        const searchable =
            "home assistant ha light " + light.name + " " + light.entityId + " " + light.state;
        if (!queryMatches(searchable, normalizedQuery)) continue;

        items.push(createToggleLightItem(light, normalizedQuery, commands));
        const setStateItem = createSetLightStateItem(light, normalizedQuery, commands);
        if (setStateItem) items.push(setStateItem);
    }

    for (let index = 0; index < scenes.length; index += 1) {
        const scene = scenes[index];
        const searchable =
            "home assistant ha scene " + scene.name + " " + scene.entityId + " " + scene.state;
        if (!queryMatches(searchable, normalizedQuery)) continue;

        items.push(createActivateSceneItem(scene, normalizedQuery, commands));
    }

    sortResults(items);
    if (items.length <= maxResults) return items;
    return items.slice(0, maxResults);
}

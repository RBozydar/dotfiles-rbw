import "../system/adapters/search/homeassistant-launcher-model.js" as HomeAssistantLauncherModel
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function findById(items, id) {
        for (let index = 0; index < items.length; index += 1) {
            if (items[index] && items[index].id === id)
                return items[index];
        }
        return null;
    }

    function test_searchHomeAssistantSnapshot_returns_light_toggle_and_set_state_actions() {
        const results = HomeAssistantLauncherModel.searchHomeAssistantSnapshot({
            lights: [
                {
                    entityId: "light.office",
                    name: "Office Lamp",
                    isOn: true,
                    available: true,
                    brightnessPercent: 82
                }
            ],
            scenes: []
        }, "office", 20, {});

        const toggle = findById(results, "ha:light:toggle:light.office");
        const setState = findById(results, "ha:light:set:off:light.office");

        verify(toggle !== null);
        compare(toggle.action.type, "shell.ipc.dispatch");
        compare(toggle.action.command, "homeassistant.toggle_light");
        compare(toggle.action.args[0], "light.office");

        verify(setState !== null);
        compare(setState.action.command, "homeassistant.turn_off_light");
    }

    function test_searchHomeAssistantSnapshot_returns_scene_activation_action() {
        const results = HomeAssistantLauncherModel.searchHomeAssistantSnapshot({
            lights: [],
            scenes: [
                {
                    entityId: "scene.movie_time",
                    name: "Movie Time",
                    available: true
                }
            ]
        }, "movie", 20, {});

        const scene = findById(results, "ha:scene:activate:scene.movie_time");
        verify(scene !== null);
        compare(scene.action.type, "shell.ipc.dispatch");
        compare(scene.action.command, "homeassistant.activate_scene");
        compare(scene.action.args[0], "scene.movie_time");
    }

    function test_searchHomeAssistantSnapshot_returns_empty_for_blank_query() {
        const results = HomeAssistantLauncherModel.searchHomeAssistantSnapshot({
            lights: [
                {
                    entityId: "light.office",
                    name: "Office Lamp",
                    isOn: false,
                    available: true
                }
            ],
            scenes: [
                {
                    entityId: "scene.goodnight",
                    name: "Goodnight",
                    available: true
                }
            ]
        }, "   ", 20, {});

        compare(results.length, 0);
    }

    name: "HomeAssistantLauncherModelSlice"
}

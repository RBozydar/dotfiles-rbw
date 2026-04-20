import "../system/core/selectors/launcher/select-launcher-sections.js" as LauncherSelectors
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function createItem(id, provider, score, action) {
        return {
            id: id,
            title: id,
            subtitle: "",
            provider: provider,
            score: score,
            action: action
        };
    }

    function test_selectLauncherSections_places_pinned_commands_first_without_duplicates() {
        const items = [Object.assign(createItem("ipc:settings.reload", "commands", 900, {
                type: "shell.ipc.dispatch",
                command: "settings.reload",
                args: []
            }), {
                pinned: true,
                pinOrder: 1
            }), Object.assign(createItem("ipc:launcher.toggle", "commands", 880, {
                type: "shell.ipc.dispatch",
                command: "launcher.toggle",
                args: []
            }), {
                pinned: true,
                pinOrder: 0
            }), createItem("ipc:session.toggle", "commands", 800, {
                type: "shell.ipc.dispatch",
                command: "session.toggle",
                args: []
            }), createItem("app:firefox.desktop", "apps", 700, {
                type: "app.launch",
                targetId: "firefox.desktop"
            })];
        const sections = LauncherSelectors.selectLauncherSections(items, 6);

        compare(sections.length, 3);
        compare(sections[0].id, "pinned");
        compare(sections[0].items.length, 2);
        compare(sections[0].items[0].id, "ipc:launcher.toggle");
        compare(sections[0].items[1].id, "ipc:settings.reload");

        compare(sections[1].id, "commands");
        compare(sections[1].items.length, 1);
        compare(sections[1].items[0].id, "ipc:session.toggle");
        compare(sections[2].id, "apps");
        compare(LauncherSelectors.countLauncherItems(sections), 4);
    }

    function test_selectLauncherSections_does_not_pin_dynamic_ipc_items() {
        const items = [Object.assign(createItem("win:0x1", "windows", 920, {
                type: "shell.ipc.dispatch",
                command: "window_switcher.focus",
                args: ["0x1"]
            }), {
                pinned: true,
                pinOrder: 0
            }), createItem("app:firefox.desktop", "apps", 700, {
                type: "app.launch",
                targetId: "firefox.desktop"
            })];
        const sections = LauncherSelectors.selectLauncherSections(items, 6);

        compare(sections.length, 2);
        compare(sections[0].id, "windows");
        compare(sections[1].id, "apps");
    }

    name: "LauncherSectionSelectorSlice"
}

import "../system/ui/modules/launcher/launcher-overlay-controller.js" as LauncherOverlayController
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function keyCodes() {
        return {
            escape: Qt.Key_Escape,
            tab: Qt.Key_Tab,
            n: Qt.Key_N,
            p: Qt.Key_P,
            down: Qt.Key_Down,
            up: Qt.Key_Up,
            pageDown: Qt.Key_PageDown,
            pageUp: Qt.Key_PageUp,
            home: Qt.Key_Home,
            end: Qt.Key_End,
            space: Qt.Key_Space,
            returnKey: Qt.Key_Return,
            enter: Qt.Key_Enter
        };
    }

    function sampleCommandItem(commandName, actionType) {
        return {
            id: "ipc:" + commandName,
            action: {
                type: actionType === undefined ? "shell.ipc.dispatch" : actionType,
                command: commandName
            }
        };
    }

    function test_resolveCommandPrefix_defaults_and_trims() {
        compare(LauncherOverlayController.resolveCommandPrefix(null, ">"), ">");
        compare(LauncherOverlayController.resolveCommandPrefix({
            commandPrefix: "  >  "
        }, ">"), ">");
        compare(LauncherOverlayController.resolveCommandPrefix({
            commandPrefix: " : "
        }, ">"), ":");
    }

    function test_commandAutocompleteCandidate_requires_command_mode_and_dispatch_item() {
        compare(LauncherOverlayController.commandAutocompleteCandidate("fire", ">", sampleCommandItem("settings.reload")), "");
        compare(LauncherOverlayController.commandAutocompleteCandidate(">set", ">", {
            action: {
                type: "app.launch",
                targetId: "firefox.desktop"
            }
        }), "");
        compare(LauncherOverlayController.commandAutocompleteCandidate(">set", ">", sampleCommandItem("settings.reload")), "settings.reload");
        compare(LauncherOverlayController.commandAutocompleteCandidate(">cmd py", ">", sampleCommandItem("python", "shell.command.run")), "python");
    }

    function test_autocompleteQuery_applies_when_candidate_exists() {
        const applied = LauncherOverlayController.autocompleteQuery(">set", ">", sampleCommandItem("settings.reload"));
        compare(applied.applied, true);
        compare(applied.query, ">settings.reload");

        const commandApplied = LauncherOverlayController.autocompleteQuery(">cmd py", ">", sampleCommandItem("python", "shell.command.run"));
        compare(commandApplied.applied, true);
        compare(commandApplied.query, ">cmd python");

        const skipped = LauncherOverlayController.autocompleteQuery("set", ">", sampleCommandItem("settings.reload"));
        compare(skipped.applied, false);
        compare(skipped.query, "set");
    }

    function test_decideNavigationAction_maps_keyboard_intents() {
        let action = LauncherOverlayController.decideNavigationAction({
            key: Qt.Key_Escape,
            totalItemCount: 4,
            keyCodes: keyCodes()
        });
        compare(action.kind, "close");

        action = LauncherOverlayController.decideNavigationAction({
            key: Qt.Key_Tab,
            hasAutocompleteCandidate: true,
            totalItemCount: 4,
            keyCodes: keyCodes()
        });
        compare(action.kind, "autocomplete");

        action = LauncherOverlayController.decideNavigationAction({
            key: Qt.Key_Space,
            controlPressed: true,
            hasPreviewCandidate: true,
            totalItemCount: 4,
            keyCodes: keyCodes()
        });
        compare(action.kind, "preview");

        action = LauncherOverlayController.decideNavigationAction({
            key: Qt.Key_P,
            controlPressed: true,
            shiftPressed: true,
            hasPinCandidate: true,
            totalItemCount: 4,
            keyCodes: keyCodes()
        });
        compare(action.kind, "pin_toggle");

        action = LauncherOverlayController.decideNavigationAction({
            key: Qt.Key_Up,
            controlPressed: true,
            shiftPressed: true,
            hasPinCandidate: true,
            canMovePinUp: true,
            totalItemCount: 4,
            keyCodes: keyCodes()
        });
        compare(action.kind, "pin_move_up");

        action = LauncherOverlayController.decideNavigationAction({
            key: Qt.Key_Down,
            controlPressed: true,
            shiftPressed: true,
            hasPinCandidate: true,
            canMovePinDown: true,
            totalItemCount: 4,
            keyCodes: keyCodes()
        });
        compare(action.kind, "pin_move_down");

        action = LauncherOverlayController.decideNavigationAction({
            key: Qt.Key_N,
            controlPressed: true,
            totalItemCount: 4,
            keyCodes: keyCodes()
        });
        compare(action.kind, "move");
        compare(action.delta, 1);

        action = LauncherOverlayController.decideNavigationAction({
            key: Qt.Key_PageUp,
            totalItemCount: 4,
            keyCodes: keyCodes()
        });
        compare(action.kind, "move");
        compare(action.delta, -6);

        action = LauncherOverlayController.decideNavigationAction({
            key: Qt.Key_Home,
            totalItemCount: 4,
            keyCodes: keyCodes()
        });
        compare(action.kind, "set_index");
        compare(action.index, 0);

        action = LauncherOverlayController.decideNavigationAction({
            key: Qt.Key_End,
            totalItemCount: 4,
            keyCodes: keyCodes()
        });
        compare(action.kind, "set_index");
        compare(action.index, 3);

        action = LauncherOverlayController.decideNavigationAction({
            key: Qt.Key_Return,
            totalItemCount: 4,
            keyCodes: keyCodes()
        });
        compare(action.kind, "activate");
    }

    function test_decideNavigationAction_returns_noop_for_non_actionable_input() {
        let action = LauncherOverlayController.decideNavigationAction({
            key: Qt.Key_Tab,
            hasAutocompleteCandidate: false,
            totalItemCount: 4,
            keyCodes: keyCodes()
        });
        compare(action.kind, "noop");

        action = LauncherOverlayController.decideNavigationAction({
            key: Qt.Key_Home,
            totalItemCount: 0,
            keyCodes: keyCodes()
        });
        compare(action.kind, "noop");

        action = LauncherOverlayController.decideNavigationAction({
            key: Qt.Key_Return,
            totalItemCount: 0,
            keyCodes: keyCodes()
        });
        compare(action.kind, "noop");

        action = LauncherOverlayController.decideNavigationAction({
            key: Qt.Key_P,
            controlPressed: true,
            shiftPressed: true,
            hasPinCandidate: false,
            totalItemCount: 4,
            keyCodes: keyCodes()
        });
        compare(action.kind, "noop");
    }

    function test_computeVisibleContentY_scrolls_up_when_item_is_above_viewport() {
        const nextContentY = LauncherOverlayController.computeVisibleContentY(40, 100, 400, 20, 18, 8);
        compare(nextContentY, 12);
    }

    function test_computeVisibleContentY_scrolls_down_when_item_is_below_viewport() {
        const nextContentY = LauncherOverlayController.computeVisibleContentY(0, 100, 400, 120, 20, 8);
        compare(nextContentY, 48);
    }

    function test_computeVisibleContentY_clamps_to_content_bounds() {
        const nextContentY = LauncherOverlayController.computeVisibleContentY(150, 100, 220, 210, 20, 8);
        compare(nextContentY, 120);
    }

    function test_computeVisibleContentY_keeps_position_when_item_is_visible() {
        const nextContentY = LauncherOverlayController.computeVisibleContentY(20, 120, 500, 40, 40, 8);
        compare(nextContentY, 20);
    }

    name: "LauncherOverlayControllerSlice"
}

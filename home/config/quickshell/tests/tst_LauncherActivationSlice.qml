import "../system/core/application/launcher/activate-launcher-item.js" as LauncherActivationUseCases
import "../system/core/contracts/launcher-contracts.js" as LauncherContracts
import "../system/core/contracts/operation-outcome.js" as OperationOutcomes
import "../system/core/domain/launcher/launcher-store.js" as LauncherStore
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function readyStore(items) {
        const store = LauncherStore.createLauncherStore();
        const generation = 1;
        const command = LauncherContracts.createLauncherSearchCommand("", generation, "test");
        const resultList = LauncherContracts.createLauncherResultList(items, generation);

        store.applySearchStarted(command);
        store.applySearchCompleted(resultList, OperationOutcomes.applied({
            code: "launcher.search_applied",
            targetId: "launcher",
            generation: generation
        }));

        return store;
    }

    function activationDeps(overrides) {
        const deps = {
            "validateLauncherItem": LauncherContracts.validateLauncherItem,
            "dispatchShellIpcCommand": function () {
                return OperationOutcomes.applied({
                    code: "session.overlay.opened",
                    targetId: "session_overlay"
                });
            },
            "commandExecutionPort": {
                "execute": function () {
                    return true;
                }
            },
            "outcomes": OperationOutcomes
        };

        if (overrides) {
            for (const key in overrides)
                deps[key] = overrides[key];
        }

        return deps;
    }

    function test_activateLauncherItem_dispatches_shell_ipc_command() {
        let calledCommandName = "";
        let calledArgs = [];

        const store = readyStore([LauncherContracts.createLauncherItem({
                id: "ipc:session.toggle",
                title: "session.toggle",
                provider: "commands",
                action: {
                    type: "shell.ipc.dispatch",
                    command: "session.toggle",
                    args: []
                }
            })]);

        const outcome = LauncherActivationUseCases.activateLauncherItem(activationDeps({
            "dispatchShellIpcCommand": function (commandName, args) {
                calledCommandName = commandName;
                calledArgs = args;
                return OperationOutcomes.applied({
                    code: "session.overlay.opened",
                    targetId: "session_overlay"
                });
            }
        }), store, "ipc:session.toggle");

        compare(outcome.status, "applied");
        compare(outcome.code, "session.overlay.opened");
        compare(calledCommandName, "session.toggle");
        compare(calledArgs.length, 0);
    }

    function test_activateLauncherItem_dispatches_wallpaper_ipc_command_with_args() {
        let calledCommandName = "";
        let calledArgs = [];

        const store = readyStore([LauncherContracts.createLauncherItem({
                id: "wallpaper:/home/rbw/Pictures/wallpapers/sunrise.png",
                title: "sunrise",
                provider: "wallpaper",
                action: {
                    type: "shell.ipc.dispatch",
                    command: "wallpaper.set",
                    args: ["/home/rbw/Pictures/wallpapers/sunrise.png"]
                }
            })]);

        const outcome = LauncherActivationUseCases.activateLauncherItem(activationDeps({
            "dispatchShellIpcCommand": function (commandName, args) {
                calledCommandName = commandName;
                calledArgs = args;
                return OperationOutcomes.applied({
                    code: "wallpaper.set.dispatched",
                    targetId: args[0]
                });
            }
        }), store, "wallpaper:/home/rbw/Pictures/wallpapers/sunrise.png");

        compare(outcome.status, "applied");
        compare(outcome.code, "wallpaper.set.dispatched");
        compare(calledCommandName, "wallpaper.set");
        compare(calledArgs.length, 1);
        compare(calledArgs[0], "/home/rbw/Pictures/wallpapers/sunrise.png");
    }

    function test_activateLauncherItem_dispatches_external_command() {
        let dispatchedArgv = [];

        const store = readyStore([LauncherContracts.createLauncherItem({
                id: "exec:ghostty",
                title: "ghostty",
                provider: "commands",
                action: {
                    type: "shell.command.run",
                    command: "ghostty -e btop"
                }
            })]);

        const outcome = LauncherActivationUseCases.activateLauncherItem(activationDeps({
            "commandExecutionPort": {
                "execute": function (argv) {
                    dispatchedArgv = argv;
                    return true;
                }
            }
        }), store, "exec:ghostty");

        compare(outcome.status, "applied");
        compare(outcome.code, "launcher.activate.command_dispatched");
        compare(dispatchedArgv[0], "ghostty");
        compare(dispatchedArgv[1], "-e");
        compare(dispatchedArgv[2], "btop");
    }

    function test_activateLauncherItem_opens_file_path() {
        let dispatchedArgv = [];

        const store = readyStore([LauncherContracts.createLauncherItem({
                id: "file:/home/rbw/repo/docs/plan.md",
                title: "plan.md",
                provider: "files",
                action: {
                    type: "file.open",
                    targetId: "/home/rbw/repo/docs/plan.md"
                }
            })]);

        const outcome = LauncherActivationUseCases.activateLauncherItem(activationDeps({
            "commandExecutionPort": {
                "execute": function (argv) {
                    dispatchedArgv = argv;
                    return true;
                }
            }
        }), store, "file:/home/rbw/repo/docs/plan.md");

        compare(outcome.status, "applied");
        compare(outcome.code, "launcher.activate.file_open_dispatched");
        compare(dispatchedArgv[0], "xdg-open");
        compare(dispatchedArgv[1], "/home/rbw/repo/docs/plan.md");
    }

    function test_previewLauncherItem_previews_file_path_with_sushi() {
        let dispatchedArgv = [];

        const store = readyStore([LauncherContracts.createLauncherItem({
                id: "file:/home/rbw/repo/docs/plan.md",
                title: "plan.md",
                provider: "files",
                action: {
                    type: "file.open",
                    targetId: "/home/rbw/repo/docs/plan.md"
                }
            })]);

        const outcome = LauncherActivationUseCases.previewLauncherItem(activationDeps({
            "commandExecutionPort": {
                "execute": function (argv) {
                    dispatchedArgv = argv;
                    return true;
                }
            }
        }), store, "file:/home/rbw/repo/docs/plan.md");

        compare(outcome.status, "applied");
        compare(outcome.code, "launcher.preview.file_dispatched");
        compare(dispatchedArgv[0], "sushi");
        compare(dispatchedArgv[1], "/home/rbw/repo/docs/plan.md");
    }

    function test_previewLauncherItem_rejects_non_file_actions() {
        const store = readyStore([LauncherContracts.createLauncherItem({
                id: "ipc:session.toggle",
                title: "session.toggle",
                provider: "commands",
                action: {
                    type: "shell.ipc.dispatch",
                    command: "session.toggle",
                    args: []
                }
            })]);

        const outcome = LauncherActivationUseCases.previewLauncherItem(activationDeps(), store, "ipc:session.toggle");

        compare(outcome.status, "rejected");
        compare(outcome.code, "launcher.preview.unsupported_action");
    }

    function test_activateLauncherItem_dispatches_desktop_entry_launch() {
        let dispatchedArgv = [];

        const store = readyStore([LauncherContracts.createLauncherItem({
                id: "app:firefox.desktop",
                title: "Firefox",
                provider: "apps",
                action: {
                    type: "app.launch",
                    targetId: "firefox.desktop"
                }
            })]);

        const outcome = LauncherActivationUseCases.activateLauncherItem(activationDeps({
            "commandExecutionPort": {
                "execute": function (argv) {
                    dispatchedArgv = argv;
                    return true;
                }
            }
        }), store, "app:firefox.desktop");

        compare(outcome.status, "applied");
        compare(outcome.code, "launcher.activate.app_dispatched");
        compare(dispatchedArgv[0], "gtk-launch");
        compare(dispatchedArgv[1], "firefox");
    }

    function test_activateLauncherItem_copies_calculator_result() {
        let dispatchedArgv = [];

        const store = readyStore([LauncherContracts.createLauncherItem({
                id: "calc:2+2",
                title: "4",
                provider: "calculator",
                action: {
                    type: "calculator.copy_result",
                    targetId: "4"
                }
            })]);

        const outcome = LauncherActivationUseCases.activateLauncherItem(activationDeps({
            "commandExecutionPort": {
                "execute": function (argv) {
                    dispatchedArgv = argv;
                    return true;
                }
            }
        }), store, "calc:2+2");

        compare(outcome.status, "applied");
        compare(outcome.code, "launcher.activate.calculator_copied");
        compare(dispatchedArgv[0], "wl-copy");
        compare(dispatchedArgv[1], "4");
    }

    function test_activateLauncherItem_copies_clipboard_text_payload() {
        let dispatchedArgv = [];

        const store = readyStore([LauncherContracts.createLauncherItem({
                id: "emoji:grinning",
                title: "😀 grinning face",
                provider: "emoji",
                action: {
                    type: "clipboard.copy_text",
                    targetId: "😀"
                }
            })]);

        const outcome = LauncherActivationUseCases.activateLauncherItem(activationDeps({
            "commandExecutionPort": {
                "execute": function (argv) {
                    dispatchedArgv = argv;
                    return true;
                }
            }
        }), store, "emoji:grinning");

        compare(outcome.status, "applied");
        compare(outcome.code, "launcher.activate.clipboard_copied");
        compare(dispatchedArgv[0], "wl-copy");
        compare(dispatchedArgv[1], "😀");
    }

    function test_activateLauncherItem_recalls_clipboard_history_item() {
        let dispatchedArgv = [];

        const store = readyStore([LauncherContracts.createLauncherItem({
                id: "clipboard:330",
                title: "Clipboard item #330",
                provider: "clipboard",
                action: {
                    type: "clipboard.copy_history_entry",
                    targetId: "330"
                }
            })]);

        const outcome = LauncherActivationUseCases.activateLauncherItem(activationDeps({
            "commandExecutionPort": {
                "execute": function (argv) {
                    dispatchedArgv = argv;
                    return true;
                }
            }
        }), store, "clipboard:330");

        compare(outcome.status, "applied");
        compare(outcome.code, "launcher.activate.clipboard_history_copied");
        compare(dispatchedArgv[0], "sh");
        compare(dispatchedArgv[1], "-lc");
        compare(dispatchedArgv[2], "cliphist decode 330 | wl-copy");
    }

    function test_activateLauncherItem_returns_stale_when_item_missing() {
        const store = readyStore([]);
        const outcome = LauncherActivationUseCases.activateLauncherItem(activationDeps(), store, "missing:id");

        compare(outcome.status, "stale");
        compare(outcome.code, "launcher.activate.item_missing");
    }

    name: "LauncherActivationSlice"
}

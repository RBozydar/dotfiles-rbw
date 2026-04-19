import "../system/core/application/ipc/dispatch-shell-command.js" as ShellIpcUseCases
import "../system/core/contracts/ipc-command-contracts.js" as IpcContracts
import "../system/core/contracts/operation-outcome.js" as OperationOutcomes
import "../system/core/ports/shell-command-port.js" as ShellCommandPort
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function commandSpecs() {
        return [IpcContracts.createShellIpcCommandSpec({
                name: "session.toggle",
                summary: "Toggle session overlay",
                usage: "session.toggle",
                minArgs: 0,
                maxArgs: 0
            }), IpcContracts.createShellIpcCommandSpec({
                name: "shell.command.run",
                summary: "Run external command",
                usage: "shell.command.run <argv0> [argv1...]",
                minArgs: 1,
                maxArgs: 8
            })];
    }

    function listDeps() {
        return {
            "normalizeShellIpcCommandSpecs": IpcContracts.normalizeShellIpcCommandSpecs,
            "createShellIpcCommandCatalog": IpcContracts.createShellIpcCommandCatalog
        };
    }

    function dispatchDeps(shellCommandPort) {
        return {
            "normalizeShellIpcCommandSpecs": IpcContracts.normalizeShellIpcCommandSpecs,
            "createShellIpcCommand": IpcContracts.createShellIpcCommand,
            "validateOperationOutcome": OperationOutcomes.validateOperationOutcome,
            "outcomes": OperationOutcomes,
            "shellCommandPort": shellCommandPort
        };
    }

    function test_listShellIpcCommands_returns_sorted_catalog() {
        const catalog = ShellIpcUseCases.listShellIpcCommands(listDeps(), [IpcContracts.createShellIpcCommandSpec({
                name: "zeta",
                summary: "z",
                minArgs: 0,
                maxArgs: 0
            }), IpcContracts.createShellIpcCommandSpec({
                name: "alpha",
                summary: "a",
                minArgs: 0,
                maxArgs: 0
            })]);

        compare(catalog.kind, "shell.ipc_command_catalog");
        compare(catalog.protocolVersion, 1);
        compare(catalog.commands.length, 2);
        compare(catalog.commands[0].name, "alpha");
        compare(catalog.commands[1].name, "zeta");
    }

    function test_dispatchShellIpcCommand_applies_known_command() {
        let capturedName = "";
        let capturedArgs = [];

        const port = ShellCommandPort.createShellCommandPort({
            "shell.command.run": function (args, meta, spec) {
                capturedName = spec.name;
                capturedArgs = args;
                return OperationOutcomes.applied({
                    code: "shell.command.dispatched",
                    targetId: args[0],
                    meta: {
                        source: meta.source
                    }
                });
            }
        });

        const outcome = ShellIpcUseCases.dispatchShellIpcCommand(dispatchDeps(port), commandSpecs(), "shell.command.run", ["ghostty", "-e", "btop"], {
            source: "test"
        });

        compare(outcome.status, "applied");
        compare(outcome.code, "shell.command.dispatched");
        compare(capturedName, "shell.command.run");
        compare(capturedArgs.length, 3);
        compare(capturedArgs[0], "ghostty");
        compare(capturedArgs[2], "btop");
    }

    function test_dispatchShellIpcCommand_rejects_unknown_command() {
        const port = ShellCommandPort.createShellCommandPort({});
        const outcome = ShellIpcUseCases.dispatchShellIpcCommand(dispatchDeps(port), commandSpecs(), "launcher.toggle", [], {
            source: "test"
        });

        compare(outcome.status, "rejected");
        compare(outcome.code, "shell.ipc.unknown_command");
    }

    function test_dispatchShellIpcCommand_rejects_invalid_arity() {
        const port = ShellCommandPort.createShellCommandPort({
            "session.toggle": function () {
                return OperationOutcomes.applied({
                    code: "session.overlay.toggled",
                    targetId: "session_overlay"
                });
            }
        });

        const outcome = ShellIpcUseCases.dispatchShellIpcCommand(dispatchDeps(port), commandSpecs(), "session.toggle", ["unexpected"], {
            source: "test"
        });

        compare(outcome.status, "rejected");
        compare(outcome.code, "shell.ipc.invalid_args");
    }

    function test_dispatchShellIpcCommand_rejects_when_handler_missing() {
        const port = ShellCommandPort.createShellCommandPort({});
        const outcome = ShellIpcUseCases.dispatchShellIpcCommand(dispatchDeps(port), commandSpecs(), "session.toggle", [], {
            source: "test"
        });

        compare(outcome.status, "rejected");
        compare(outcome.code, "shell.ipc.handler_missing");
    }

    name: "ShellIpcCommandSlice"
}

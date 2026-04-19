import "../../core/application/ipc/dispatch-shell-command.js" as ShellIpcUseCases
import "../../core/contracts/ipc-command-contracts.js" as IpcContracts
import "../../core/contracts/operation-outcome.js" as OperationOutcomes
import "../../core/ports/shell-command-port.js" as ShellCommandPort
import QtQml
import Quickshell
import Quickshell.Io

Scope {
    id: root

    required property var commandSpecs
    required property var commandHandlers
    property string target: "shell"
    property var sharedCommandPort: null

    readonly property var commandPort: sharedCommandPort && typeof sharedCommandPort.execute === "function" ? sharedCommandPort : ShellCommandPort.createShellCommandPort(commandHandlers)
    readonly property var commandCatalog: ShellIpcUseCases.listShellIpcCommands({
        "normalizeShellIpcCommandSpecs": IpcContracts.normalizeShellIpcCommandSpecs,
        "createShellIpcCommandCatalog": IpcContracts.createShellIpcCommandCatalog
    }, commandSpecs)

    function invoke(commandName, args): string {
        const outcome = ShellIpcUseCases.dispatchShellIpcCommand({
            "normalizeShellIpcCommandSpecs": IpcContracts.normalizeShellIpcCommandSpecs,
            "createShellIpcCommand": IpcContracts.createShellIpcCommand,
            "validateOperationOutcome": OperationOutcomes.validateOperationOutcome,
            "outcomes": OperationOutcomes,
            "shellCommandPort": root.commandPort
        }, root.commandSpecs, commandName, args || [], {
            "source": "qs.ipc"
        });

        return JSON.stringify(outcome);
    }

    function listCommands(): string {
        return JSON.stringify(root.commandCatalog.commands);
    }

    function describe(): string {
        return JSON.stringify(root.commandCatalog);
    }

    function decodeArgs(encodedArgs): var {
        if (encodedArgs === undefined || encodedArgs === null || encodedArgs.length === 0)
            return [];

        try {
            const serialized = decodeURIComponent(encodedArgs);
            const parsed = JSON.parse(serialized);
            if (!Array.isArray(parsed))
                return null;

            const normalized = [];
            for (let index = 0; index < parsed.length; index += 1)
                normalized.push(String(parsed[index]));
            return normalized;
        } catch (error) {
            return null;
        }
    }

    IpcHandler {
        target: root.target

        function dispatch(commandName: string, encodedArgs: string): string {
            const args = root.decodeArgs(encodedArgs);
            if (args === null) {
                return JSON.stringify(OperationOutcomes.rejected({
                    code: "shell.ipc.invalid_encoded_args",
                    reason: "encodedArgs must be a URI-encoded JSON array",
                    targetId: commandName
                }));
            }

            return root.invoke(commandName, args);
        }

        function commands(): string {
            return root.listCommands();
        }

        function describe(): string {
            return root.describe();
        }
    }
}

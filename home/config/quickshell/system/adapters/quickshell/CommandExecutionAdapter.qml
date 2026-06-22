import QtQml
import Quickshell

QtObject {
    id: root

    function exec(command) {
        if (!command || command.length === 0)
            return;

        Quickshell.execDetached({
            "command": command,
            "workingDirectory": Quickshell.workingDirectory
        });
    }
}

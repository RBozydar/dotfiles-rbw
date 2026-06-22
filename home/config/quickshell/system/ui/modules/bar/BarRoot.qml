pragma ComponentBehavior: Bound
import "../../../adapters/quickshell" as QuickshellAdapters
import "../../bridges" as SystemBridges
import "." as BarModuleLocal
import QtQml
import Quickshell

Variants {
    id: root

    required property var shell
    property bool active: true
    property QtObject chromeBridge: null
    property QtObject workspaceBridge: SystemBridges.HyprlandWorkspaceBridge {}
    property QtObject commandExecutionAdapter: QuickshellAdapters.CommandExecutionAdapter {}
    property QtObject notificationsBridge: null

    model: root.active ? Quickshell.screens : []

    BarModuleLocal.BarScreen {
        required property var modelData

        shell: root.shell
        screen: modelData
        chromeBridge: root.chromeBridge
        workspaceBridge: root.workspaceBridge
        commandAdapter: root.commandExecutionAdapter
        notificationsBridge: root.notificationsBridge
    }
}

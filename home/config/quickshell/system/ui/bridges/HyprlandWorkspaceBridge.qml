import "../../adapters/hyprland/workspace-snapshot-adapter.js" as HyprlandWorkspaceAdapter
import "../../core/application/compositor/sync-workspace-snapshots.js" as WorkspaceUseCases
import "../../core/contracts/compositor-contracts.js" as CompositorContracts
import "../../core/contracts/operation-outcome.js" as OperationOutcomes
import "../../core/domain/compositor/workspace-store.js" as WorkspaceStore
import QtQml
import Quickshell
import Quickshell.Hyprland

QtObject {
    id: root

    property var store: WorkspaceStore.createWorkspaceStore()
    property int storeRevision: 0
    readonly property var snapshots: HyprlandWorkspaceAdapter.createSnapshotsForScreens(Quickshell.screens, Hyprland)

    function refresh(nextSnapshots) {
        const snapshotsToSync = nextSnapshots || [];
        WorkspaceUseCases.syncWorkspaceSnapshots({
            "validateWorkspaceSnapshot": CompositorContracts.validateWorkspaceSnapshot,
            "outcomes": OperationOutcomes
        }, store, snapshotsToSync);
        storeRevision = store.state.revision;
    }

    function screenKey(screen) {
        const screenIndex = HyprlandWorkspaceAdapter.indexForScreen(Quickshell.screens, screen);
        return HyprlandWorkspaceAdapter.screenKeyForScreen(screen, Hyprland, screenIndex);
    }

    function focusWorkspaceForScreen(screen, workspaceId) {
        const command = CompositorContracts.createFocusWorkspaceCommand(screenKey(screen), workspaceId);
        WorkspaceUseCases.focusWorkspace({
            "validateFocusWorkspaceCommand": CompositorContracts.validateFocusWorkspaceCommand,
            "dispatchFocusWorkspace": function (innerCommand) {
                HyprlandWorkspaceAdapter.dispatchFocusWorkspace(innerCommand, function (message) {
                    Hyprland.dispatch(message);
                });
            },
            "outcomes": OperationOutcomes
        }, command);
    }

    onSnapshotsChanged: refresh(snapshots)
    Component.onCompleted: refresh(snapshots)
}

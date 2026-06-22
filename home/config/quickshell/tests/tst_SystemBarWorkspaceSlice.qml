import "../system/adapters/hyprland/workspace-snapshot-adapter.js" as HyprlandWorkspaceAdapter
import "../system/core/application/compositor/sync-workspace-snapshots.js" as WorkspaceUseCases
import "../system/core/contracts/compositor-contracts.js" as CompositorContracts
import "../system/core/contracts/operation-outcome.js" as OperationOutcomes
import "../system/core/domain/compositor/workspace-store.js" as WorkspaceStore
import "../system/core/selectors/bar/select-bar-workspace-strip.js" as BarSelectors
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function snapshot(screenKey, activeWorkspaceId, occupiedIds, specialWorkspaceOpen) {
        const workspaces = [];
        for (let workspaceId = 1; workspaceId <= 5; workspaceId += 1) {
            workspaces.push({
                "id": workspaceId,
                "occupied": occupiedIds.indexOf(workspaceId) >= 0
            });
        }
        return CompositorContracts.createWorkspaceSnapshot({
            "screenKey": screenKey,
            "activeWorkspaceId": activeWorkspaceId,
            "specialWorkspaceOpen": specialWorkspaceOpen,
            "workspaces": workspaces
        });
    }

    function test_syncWorkspaceSnapshots_updates_store_and_selector() {
        const store = WorkspaceStore.createWorkspaceStore();
        const outcome = WorkspaceUseCases.syncWorkspaceSnapshots({
            "validateWorkspaceSnapshot": CompositorContracts.validateWorkspaceSnapshot,
            "outcomes": OperationOutcomes
        }, store, [snapshot("DP-1", 3, [2, 3], false), snapshot("HDMI-A-1", 1, [1, 4], true)]);
        const strip = BarSelectors.selectBarWorkspaceStrip(store.state, "DP-1", 5);
        const secondScreen = BarSelectors.selectBarWorkspaceStrip(store.state, "HDMI-A-1", 5);
        compare(outcome.status, "applied");
        compare(store.state.revision, 1);
        compare(strip.buttons.length, 5);
        compare(strip.buttons[2].active, true);
        compare(strip.buttons[1].occupied, true);
        compare(strip.buttons[4].occupied, false);
        compare(secondScreen.specialWorkspaceOpen, true);
        compare(secondScreen.buttons[0].active, true);
    }

    function test_focusWorkspace_dispatches_validated_command() {
        let dispatchedWorkspaceId = -1;
        let dispatchedScreenKey = "";
        const outcome = WorkspaceUseCases.focusWorkspace({
            "validateFocusWorkspaceCommand": CompositorContracts.validateFocusWorkspaceCommand,
            "dispatchFocusWorkspace": function (command) {
                dispatchedWorkspaceId = command.payload.workspaceId;
                dispatchedScreenKey = command.payload.screenKey;
            },
            "outcomes": OperationOutcomes
        }, CompositorContracts.createFocusWorkspaceCommand("DP-1", 4));
        compare(outcome.status, "applied");
        compare(dispatchedScreenKey, "DP-1");
        compare(dispatchedWorkspaceId, 4);
    }

    function test_dispatchFocusWorkspace_targets_monitor_before_workspace_switch() {
        const messages = [];
        HyprlandWorkspaceAdapter.dispatchFocusWorkspace(CompositorContracts.createFocusWorkspaceCommand("DP-1", 5), function (message) {
            messages.push(message);
        });
        compare(messages.length, 2);
        compare(messages[0], "focusmonitor DP-1");
        compare(messages[1], "focusworkspaceoncurrentmonitor 5");
    }

    function test_dispatchFocusWorkspace_skips_monitor_target_when_screen_key_is_blank() {
        const messages = [];
        HyprlandWorkspaceAdapter.dispatchFocusWorkspace(CompositorContracts.createFocusWorkspaceCommand("", 6), function (message) {
            messages.push(message);
        });
        compare(messages.length, 1);
        compare(messages[0], "focusworkspaceoncurrentmonitor 6");
    }

    function test_createSnapshotsForScreens_uses_unique_unknown_screen_fallback_keys() {
        const screens = [
            {},
            {}
        ];
        const hyprland = {
            "monitorFor": function () {
                return null;
            },
            "workspaces": {
                "values": []
            },
            "focusedWorkspace": {
                "id": 3
            }
        };
        const snapshots = HyprlandWorkspaceAdapter.createSnapshotsForScreens(screens, hyprland);
        compare(snapshots.length, 2);
        compare(snapshots[0].screenKey, "unknown-screen-0");
        compare(snapshots[1].screenKey, "unknown-screen-1");
    }

    name: "SystemBarWorkspaceSlice"
}

import "../../adapters/hyprland" as HyprlandAdapters
import "../../adapters/hyprland/window-switcher-snapshot-adapter.js" as HyprlandWindowSwitcherModel
import "../../core/application/window-switcher/cycle-window-switcher.js" as WindowSwitcherUseCases
import "../../core/contracts/operation-outcome.js" as OperationOutcomes
import "../../core/contracts/window-switcher-contracts.js" as WindowSwitcherContracts
import "../../core/domain/window-switcher/window-switcher-store.js" as WindowSwitcherStore
import QtQml
import Quickshell
import Quickshell.Hyprland

Scope {
    id: root

    property var store: WindowSwitcherStore.createWindowSwitcherStore()
    property int storeRevision: 0
    readonly property var snapshot: windowSnapshotAdapter.snapshot
    readonly property var state: {
        root.storeRevision;
        return root.store && root.store.state ? root.store.state : {
            open: false,
            entries: [],
            focusedAddress: "",
            selectedIndex: -1,
            selectedAddress: "",
            revision: 0,
            lastOutcome: null
        };
    }

    function useCaseDeps() {
        return {
            validateWindowSwitcherSnapshot: WindowSwitcherContracts.validateWindowSwitcherSnapshot,
            createFocusWindowCommand: WindowSwitcherContracts.createFocusWindowCommand,
            validateFocusWindowCommand: WindowSwitcherContracts.validateFocusWindowCommand,
            pickInitialSelectionIndex: HyprlandWindowSwitcherModel.pickInitialSelectionIndex,
            dispatchFocusWindow: function (command) {
                Hyprland.dispatch("focuswindow address:" + command.payload.address);
            },
            outcomes: OperationOutcomes
        };
    }

    function commitStoreRevision() {
        root.storeRevision = root.store && root.store.state ? root.store.state.revision : 0;
    }

    function syncSnapshot(sourceCode) {
        const outcome = WindowSwitcherUseCases.syncWindowSwitcherSnapshot(useCaseDeps(), root.store, root.snapshot, sourceCode === undefined ? "window_switcher.snapshot.bridge_sync" : String(sourceCode));
        commitStoreRevision();
        return outcome;
    }

    function refreshSnapshot(sourceCode) {
        if (windowSnapshotAdapter && typeof windowSnapshotAdapter.refresh === "function")
            windowSnapshotAdapter.refresh();
        return syncSnapshot(sourceCode === undefined ? "window_switcher.snapshot.refresh" : String(sourceCode));
    }

    function cycle(direction, sourceCode) {
        const outcome = WindowSwitcherUseCases.cycleWindowSwitcher(useCaseDeps(), root.store, root.snapshot, direction, sourceCode === undefined ? "window_switcher.cycle.bridge" : String(sourceCode));
        commitStoreRevision();
        return outcome;
    }

    function accept(sourceCode) {
        const outcome = WindowSwitcherUseCases.acceptWindowSwitcherSelection(useCaseDeps(), root.store, sourceCode === undefined ? "window_switcher.accept.bridge" : String(sourceCode));
        commitStoreRevision();
        return outcome;
    }

    function focusAddress(address, sourceCode) {
        const outcome = WindowSwitcherUseCases.focusWindowByAddress(useCaseDeps(), root.store, address, sourceCode === undefined ? "window_switcher.focus.bridge" : String(sourceCode));
        commitStoreRevision();
        return outcome;
    }

    function cancel(sourceCode) {
        const outcome = WindowSwitcherUseCases.cancelWindowSwitcherSelection(useCaseDeps(), root.store, sourceCode === undefined ? "window_switcher.cancel.bridge" : String(sourceCode));
        commitStoreRevision();
        return outcome;
    }

    function describe() {
        return WindowSwitcherUseCases.describeWindowSwitcher(root.store);
    }

    HyprlandAdapters.WindowSwitcherSnapshotAdapter {
        id: windowSnapshotAdapter
        eventDebounceMs: 40
    }

    Connections {
        target: windowSnapshotAdapter
        function onSnapshotChanged() {
            root.syncSnapshot("window_switcher.snapshot.adapter_changed");
        }
    }

    Component.onCompleted: {
        root.syncSnapshot("window_switcher.snapshot.bridge_completed");
    }
}

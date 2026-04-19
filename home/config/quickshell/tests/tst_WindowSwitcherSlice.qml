import "../system/adapters/hyprland/window-switcher-snapshot-adapter.js" as WindowSwitcherAdapter
import "../system/core/application/window-switcher/cycle-window-switcher.js" as WindowSwitcherUseCases
import "../system/core/contracts/operation-outcome.js" as OperationOutcomes
import "../system/core/contracts/window-switcher-contracts.js" as WindowSwitcherContracts
import "../system/core/domain/window-switcher/window-switcher-store.js" as WindowSwitcherStore
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function sampleClients() {
        return [
            {
                address: "0x1",
                mapped: true,
                hidden: false,
                class: "firefox",
                title: "Firefox",
                workspace: {
                    id: 2,
                    name: "2"
                },
                monitor: 0,
                focusHistoryID: 1
            },
            {
                address: "0x2",
                mapped: true,
                hidden: false,
                class: "ghostty",
                title: "Ghostty",
                workspace: {
                    id: 1,
                    name: "1"
                },
                monitor: 0,
                focusHistoryID: 0
            },
            {
                address: "0x3",
                mapped: false,
                hidden: false,
                class: "hidden",
                title: "Should be filtered",
                workspace: {
                    id: 3,
                    name: "3"
                },
                monitor: 0,
                focusHistoryID: 2
            }
        ];
    }

    function createDeps(dispatchCalls) {
        return {
            validateWindowSwitcherSnapshot: WindowSwitcherContracts.validateWindowSwitcherSnapshot,
            createFocusWindowCommand: WindowSwitcherContracts.createFocusWindowCommand,
            validateFocusWindowCommand: WindowSwitcherContracts.validateFocusWindowCommand,
            pickInitialSelectionIndex: WindowSwitcherAdapter.pickInitialSelectionIndex,
            dispatchFocusWindow: function (command) {
                dispatchCalls.push(command);
            },
            outcomes: OperationOutcomes
        };
    }

    function test_createSnapshotFromRaw_filters_hidden_clients_and_sorts_by_focus_history() {
        const snapshot = WindowSwitcherAdapter.createSnapshotFromRaw(JSON.stringify(sampleClients()), JSON.stringify({
            address: "0x2"
        }));

        compare(snapshot.kind, "compositor.window_switcher_snapshot");
        compare(snapshot.entries.length, 2);
        compare(snapshot.entries[0].address, "0x2");
        compare(snapshot.entries[1].address, "0x1");
        compare(snapshot.focusedAddress, "0x2");
    }

    function test_cycleWindowSwitcher_opens_and_selects_next_entry_from_focused_window() {
        const store = WindowSwitcherStore.createWindowSwitcherStore();
        const dispatchCalls = [];
        const deps = createDeps(dispatchCalls);
        const snapshot = WindowSwitcherAdapter.createSnapshotFromObjects(sampleClients(), {
            address: "0x2"
        });

        const outcome = WindowSwitcherUseCases.cycleWindowSwitcher(deps, store, snapshot, 1, "test");

        compare(outcome.status, "applied");
        compare(outcome.code, "window_switcher.opened");
        compare(store.state.open, true);
        compare(store.state.selectedAddress, "0x1");
        compare(store.state.selectedIndex, 1);
        compare(dispatchCalls.length, 0);
    }

    function test_syncWindowSwitcherSnapshot_keeps_closed_state_without_selection() {
        const store = WindowSwitcherStore.createWindowSwitcherStore();
        const dispatchCalls = [];
        const deps = createDeps(dispatchCalls);
        const snapshot = WindowSwitcherAdapter.createSnapshotFromObjects(sampleClients(), {
            address: "0x2"
        });

        const outcome = WindowSwitcherUseCases.syncWindowSwitcherSnapshot(deps, store, snapshot, "test.sync.closed");

        compare(outcome.status, "applied");
        compare(store.state.open, false);
        compare(store.state.selectedIndex, -1);
        compare(store.state.selectedAddress, "");
        compare(dispatchCalls.length, 0);
    }

    function test_cycleWindowSwitcher_moves_selection_when_already_open() {
        const store = WindowSwitcherStore.createWindowSwitcherStore();
        const dispatchCalls = [];
        const deps = createDeps(dispatchCalls);
        const snapshot = WindowSwitcherAdapter.createSnapshotFromObjects(sampleClients(), {
            address: "0x2"
        });

        WindowSwitcherUseCases.cycleWindowSwitcher(deps, store, snapshot, 1, "test.open");
        const outcome = WindowSwitcherUseCases.cycleWindowSwitcher(deps, store, snapshot, 1, "test.move");

        compare(outcome.status, "applied");
        compare(outcome.code, "window_switcher.selection.moved");
        compare(store.state.selectedAddress, "0x2");
        compare(store.state.selectedIndex, 0);
    }

    function test_acceptWindowSwitcherSelection_dispatches_focus_command_and_closes_overlay() {
        const store = WindowSwitcherStore.createWindowSwitcherStore();
        const dispatchCalls = [];
        const deps = createDeps(dispatchCalls);
        const snapshot = WindowSwitcherAdapter.createSnapshotFromObjects(sampleClients(), {
            address: "0x2"
        });

        WindowSwitcherUseCases.cycleWindowSwitcher(deps, store, snapshot, 1, "test.open");
        const outcome = WindowSwitcherUseCases.acceptWindowSwitcherSelection(deps, store, "test.accept");

        compare(outcome.status, "applied");
        compare(outcome.code, "window_switcher.accepted");
        compare(dispatchCalls.length, 1);
        compare(dispatchCalls[0].type, "compositor.focus_window");
        compare(dispatchCalls[0].payload.address, "0x1");
        compare(store.state.open, false);
        compare(store.state.selectedIndex, -1);
        compare(store.state.selectedAddress, "");
    }

    function test_cancelWindowSwitcherSelection_closes_without_dispatch() {
        const store = WindowSwitcherStore.createWindowSwitcherStore();
        const dispatchCalls = [];
        const deps = createDeps(dispatchCalls);
        const snapshot = WindowSwitcherAdapter.createSnapshotFromObjects(sampleClients(), {
            address: "0x2"
        });

        WindowSwitcherUseCases.cycleWindowSwitcher(deps, store, snapshot, 1, "test.open");
        const outcome = WindowSwitcherUseCases.cancelWindowSwitcherSelection(deps, store, "test.cancel");

        compare(outcome.status, "applied");
        compare(outcome.code, "window_switcher.cancelled");
        compare(dispatchCalls.length, 0);
        compare(store.state.open, false);
    }

    name: "WindowSwitcherSlice"
}

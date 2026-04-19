function normalizeDirection(direction) {
    return Number(direction) < 0 ? -1 : 1;
}

function findIndexByAddress(entries, address) {
    const normalizedAddress = String(address || "").trim();
    if (!normalizedAddress) return -1;

    for (let index = 0; index < entries.length; index += 1) {
        if (String(entries[index].address || "").trim() === normalizedAddress) return index;
    }

    return -1;
}

function clampIndex(index, length) {
    if (length <= 0) return -1;

    const parsed = Number(index);
    if (!Number.isFinite(parsed)) return 0;
    const rounded = Math.round(parsed);
    if (rounded < 0) return 0;
    if (rounded >= length) return length - 1;
    return rounded;
}

function wrapIndex(index, length) {
    if (length <= 0) return -1;

    const parsed = Number(index);
    if (!Number.isFinite(parsed)) return 0;

    const total = Math.round(length);
    let value = Math.round(parsed) % total;
    if (value < 0) value += total;
    return value;
}

function selectedAddressFor(entries, selectedIndex) {
    if (!Array.isArray(entries) || entries.length === 0) return "";
    const parsedIndex = Number(selectedIndex);
    if (!Number.isFinite(parsedIndex) || Math.round(parsedIndex) < 0) return "";
    const index = clampIndex(selectedIndex, entries.length);
    if (index < 0) return "";
    return String(entries[index].address || "");
}

function createBaseState(store, snapshot) {
    const state =
        store && store.state
            ? store.state
            : {
                  open: false,
                  entries: [],
                  focusedAddress: "",
                  selectedIndex: -1,
                  selectedAddress: "",
              };
    const normalizedSnapshot = snapshot || {
        entries: [],
        focusedAddress: "",
    };

    return {
        open: state.open === true,
        entries: normalizedSnapshot.entries,
        focusedAddress: String(normalizedSnapshot.focusedAddress || ""),
        selectedIndex: Number(state.selectedIndex),
        selectedAddress: String(state.selectedAddress || ""),
    };
}

function syncWindowSwitcherSnapshot(deps, store, snapshot, sourceCode) {
    const normalizedSnapshot = deps.validateWindowSwitcherSnapshot(snapshot);
    const base = createBaseState(store, normalizedSnapshot);
    const entries = normalizedSnapshot.entries;

    if (entries.length === 0) {
        const outcome = deps.outcomes.noop({
            code: "window_switcher.snapshot.empty",
            targetId: "window_switcher",
            reason: "No mapped windows are available for switching",
            meta: {
                source:
                    sourceCode === undefined ? "window_switcher.snapshot.sync" : String(sourceCode),
            },
        });
        store.applyState(
            {
                open: false,
                entries: [],
                focusedAddress: base.focusedAddress,
                selectedIndex: -1,
                selectedAddress: "",
            },
            outcome,
        );
        return outcome;
    }

    let selectedIndex = -1;
    if (base.open) selectedIndex = findIndexByAddress(entries, base.selectedAddress);
    if (selectedIndex < 0 && base.open)
        selectedIndex = findIndexByAddress(entries, base.focusedAddress);
    if (selectedIndex < 0 && base.open) selectedIndex = 0;

    if (!base.open) selectedIndex = -1;

    const outcome = deps.outcomes.applied({
        code: "window_switcher.snapshot.synced",
        targetId: "window_switcher",
        meta: {
            source: sourceCode === undefined ? "window_switcher.snapshot.sync" : String(sourceCode),
            windowCount: entries.length,
            open: base.open,
        },
    });

    store.applyState(
        {
            open: base.open,
            entries: entries,
            focusedAddress: base.focusedAddress,
            selectedIndex: selectedIndex,
            selectedAddress: selectedAddressFor(entries, selectedIndex),
        },
        outcome,
    );

    return outcome;
}

function cycleWindowSwitcher(deps, store, snapshot, direction, sourceCode) {
    const normalizedSnapshot = deps.validateWindowSwitcherSnapshot(snapshot);
    const base = createBaseState(store, normalizedSnapshot);
    const entries = normalizedSnapshot.entries;

    if (entries.length === 0) {
        const outcome = deps.outcomes.noop({
            code: "window_switcher.cycle.empty",
            targetId: "window_switcher",
            reason: "No mapped windows are available for switching",
            meta: {
                source: sourceCode === undefined ? "window_switcher.cycle" : String(sourceCode),
            },
        });
        store.applyState(
            {
                open: false,
                entries: [],
                focusedAddress: base.focusedAddress,
                selectedIndex: -1,
                selectedAddress: "",
            },
            outcome,
        );
        return outcome;
    }

    const step = normalizeDirection(direction);
    let selectedIndex = -1;

    if (!base.open) {
        selectedIndex = deps.pickInitialSelectionIndex(entries, base.focusedAddress, step);
    } else {
        selectedIndex = findIndexByAddress(entries, base.selectedAddress);
        if (selectedIndex < 0) selectedIndex = findIndexByAddress(entries, base.focusedAddress);
        if (selectedIndex < 0) selectedIndex = 0;
        selectedIndex = wrapIndex(selectedIndex + step, entries.length);
    }

    const outcome = deps.outcomes.applied({
        code: base.open ? "window_switcher.selection.moved" : "window_switcher.opened",
        targetId: "window_switcher",
        meta: {
            source: sourceCode === undefined ? "window_switcher.cycle" : String(sourceCode),
            windowCount: entries.length,
            direction: step,
            selectedIndex: selectedIndex,
        },
    });

    store.applyState(
        {
            open: true,
            entries: entries,
            focusedAddress: base.focusedAddress,
            selectedIndex: selectedIndex,
            selectedAddress: selectedAddressFor(entries, selectedIndex),
        },
        outcome,
    );

    return outcome;
}

function acceptWindowSwitcherSelection(deps, store, sourceCode) {
    const state = store && store.state ? store.state : null;
    if (!state || state.open !== true) {
        return deps.outcomes.noop({
            code: "window_switcher.accept.not_open",
            targetId: "window_switcher",
            reason: "Window switcher is not open",
            meta: {
                source: sourceCode === undefined ? "window_switcher.accept" : String(sourceCode),
            },
        });
    }

    const entries = Array.isArray(state.entries) ? state.entries : [];
    const selectedIndex = clampIndex(state.selectedIndex, entries.length);
    if (selectedIndex < 0) {
        const outcome = deps.outcomes.noop({
            code: "window_switcher.accept.no_selection",
            targetId: "window_switcher",
            reason: "No window switcher selection is available",
            meta: {
                source: sourceCode === undefined ? "window_switcher.accept" : String(sourceCode),
            },
        });
        store.applyState(
            {
                open: false,
                entries: entries,
                focusedAddress: String(state.focusedAddress || ""),
                selectedIndex: -1,
                selectedAddress: "",
            },
            outcome,
        );
        return outcome;
    }

    const selected = entries[selectedIndex];
    const focusCommand = deps.createFocusWindowCommand(selected.address);
    deps.validateFocusWindowCommand(focusCommand);
    deps.dispatchFocusWindow(focusCommand);

    const outcome = deps.outcomes.applied({
        code: "window_switcher.accepted",
        targetId: "window_switcher",
        meta: {
            source: sourceCode === undefined ? "window_switcher.accept" : String(sourceCode),
            address: String(selected.address || ""),
            index: selectedIndex,
        },
    });

    store.applyState(
        {
            open: false,
            entries: entries,
            focusedAddress: String(selected.address || ""),
            selectedIndex: -1,
            selectedAddress: "",
        },
        outcome,
    );

    return outcome;
}

function cancelWindowSwitcherSelection(deps, store, sourceCode) {
    const state = store && store.state ? store.state : null;
    if (!state || state.open !== true) {
        return deps.outcomes.noop({
            code: "window_switcher.cancel.not_open",
            targetId: "window_switcher",
            reason: "Window switcher is not open",
            meta: {
                source: sourceCode === undefined ? "window_switcher.cancel" : String(sourceCode),
            },
        });
    }

    const outcome = deps.outcomes.applied({
        code: "window_switcher.cancelled",
        targetId: "window_switcher",
        meta: {
            source: sourceCode === undefined ? "window_switcher.cancel" : String(sourceCode),
        },
    });

    store.applyState(
        {
            open: false,
            entries: state.entries,
            focusedAddress: String(state.focusedAddress || ""),
            selectedIndex: -1,
            selectedAddress: "",
        },
        outcome,
    );

    return outcome;
}

function describeWindowSwitcher(store) {
    const state =
        store && store.state
            ? store.state
            : {
                  open: false,
                  entries: [],
                  focusedAddress: "",
                  selectedIndex: -1,
                  selectedAddress: "",
                  revision: 0,
                  lastOutcome: null,
              };

    return {
        kind: "window_switcher.snapshot",
        open: state.open === true,
        focusedAddress: String(state.focusedAddress || ""),
        selectedIndex: Number(state.selectedIndex),
        selectedAddress: String(state.selectedAddress || ""),
        entries: Array.isArray(state.entries) ? state.entries : [],
        revision: Number(state.revision || 0),
        lastOutcome: state.lastOutcome || null,
    };
}

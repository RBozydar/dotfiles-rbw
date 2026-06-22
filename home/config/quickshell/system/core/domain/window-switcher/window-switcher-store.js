function cloneEntries(entries) {
    const source = Array.isArray(entries) ? entries : [];
    const copy = [];

    for (let index = 0; index < source.length; index += 1) copy.push(source[index]);

    return copy;
}

function createInitialWindowSwitcherState() {
    return {
        open: false,
        entries: [],
        focusedAddress: "",
        selectedIndex: -1,
        selectedAddress: "",
        revision: 0,
        lastOutcome: null,
    };
}

function createWindowSwitcherStore() {
    return {
        state: createInitialWindowSwitcherState(),

        reset: function () {
            this.state = createInitialWindowSwitcherState();
        },

        applyState: function (nextState, outcome) {
            const source = nextState && typeof nextState === "object" ? nextState : {};
            const nextOpen = source.open === true;
            const nextSelectedIndex = Number.isFinite(Number(source.selectedIndex))
                ? Math.round(Number(source.selectedIndex))
                : -1;
            this.state = {
                open: nextOpen,
                entries: cloneEntries(source.entries),
                focusedAddress:
                    source.focusedAddress === undefined ? "" : String(source.focusedAddress),
                selectedIndex: nextOpen ? nextSelectedIndex : -1,
                selectedAddress:
                    nextOpen && source.selectedAddress !== undefined
                        ? String(source.selectedAddress)
                        : "",
                revision: this.state.revision + 1,
                lastOutcome: outcome || null,
            };
        },
    };
}

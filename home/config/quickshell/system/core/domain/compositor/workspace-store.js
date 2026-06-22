function cloneScreensMap(screens) {
    const next = {};

    for (const screenKey in screens) next[screenKey] = screens[screenKey];

    return next;
}

function createInitialWorkspaceState() {
    return {
        screens: {},
        revision: 0,
        lastOutcome: null,
    };
}

function createWorkspaceStore() {
    return {
        state: createInitialWorkspaceState(),

        reset: function () {
            this.state = createInitialWorkspaceState();
        },

        applySnapshots: function (snapshots, outcome) {
            const nextScreens = {};

            for (let index = 0; index < snapshots.length; index += 1) {
                const snapshot = snapshots[index];
                nextScreens[snapshot.screenKey] = snapshot;
            }

            this.state = {
                screens: cloneScreensMap(nextScreens),
                revision: this.state.revision + 1,
                lastOutcome: outcome,
            };
        },
    };
}

import "../system/adapters/search/system-launcher-search-adapter.js" as SystemLauncherSearchAdapter
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function commandSpecs() {
        return [
            {
                name: "session.toggle",
                summary: "Toggle session overlay",
                usage: "session.toggle",
                minArgs: 0,
                maxArgs: 0
            },
            {
                name: "settings.reload",
                summary: "Reload settings from disk",
                usage: "settings.reload",
                minArgs: 0,
                maxArgs: 0
            },
            {
                name: "launcher.toggle",
                summary: "Toggle launcher overlay",
                usage: "launcher.toggle",
                minArgs: 0,
                maxArgs: 0
            }
        ];
    }

    function createAdapter() {
        return SystemLauncherSearchAdapter.createSystemLauncherSearchAdapter({
            "commandPrefix": ">",
            "maxResults": 8,
            "commandSpecs": commandSpecs()
        });
    }

    function createItem(id, title, provider, score, action) {
        return {
            id: id,
            title: title,
            subtitle: "",
            provider: provider,
            score: score,
            action: action
        };
    }

    function findItemById(items, id) {
        for (let index = 0; index < items.length; index += 1) {
            if (items[index].id === id)
                return items[index];
        }

        return null;
    }

    function test_command_mode_returns_ipc_command_candidates() {
        const adapter = createAdapter();
        const items = adapter.search({
            payload: {
                query: ">session"
            }
        });

        verify(Array.isArray(items));
        verify(items.length >= 2);

        const ipcItem = findItemById(items, "ipc:session.toggle");
        verify(ipcItem !== null);
        compare(ipcItem.provider, "commands");
        compare(ipcItem.action.type, "shell.ipc.dispatch");
        compare(ipcItem.action.command, "session.toggle");
    }

    function test_command_mode_includes_external_command_candidate() {
        const adapter = createAdapter();
        const items = adapter.search({
            payload: {
                query: ">ghostty -e btop"
            }
        });

        const externalItem = findItemById(items, "exec:ghostty -e btop");
        verify(externalItem !== null);
        compare(externalItem.action.type, "shell.command.run");
        compare(externalItem.action.command, "ghostty -e btop");
    }

    function test_command_mode_prioritizes_pinned_commands() {
        const adapter = SystemLauncherSearchAdapter.createSystemLauncherSearchAdapter({
            "commandPrefix": ">",
            "maxResults": 8,
            "commandSpecs": commandSpecs(),
            "pinnedCommandIds": ["settings.reload"]
        });
        const items = adapter.search({
            payload: {
                query: ">settings"
            }
        });

        verify(items.length >= 1);
        compare(items[0].id, "ipc:settings.reload");
    }

    function test_command_mode_exposes_pin_metadata_for_pinned_items() {
        const adapter = SystemLauncherSearchAdapter.createSystemLauncherSearchAdapter({
            "commandPrefix": ">",
            "maxResults": 8,
            "commandSpecs": commandSpecs(),
            "pinnedCommandIds": ["settings.reload"]
        });
        const items = adapter.search({
            payload: {
                query: ">settings"
            }
        });
        const pinnedItem = findItemById(items, "ipc:settings.reload");

        verify(pinnedItem !== null);
        compare(pinnedItem.pinned, true);
        compare(pinnedItem.pinOrder, 0);
    }

    function test_command_mode_respects_explicit_pinned_command_order() {
        const adapter = SystemLauncherSearchAdapter.createSystemLauncherSearchAdapter({
            "commandPrefix": ">",
            "maxResults": 8,
            "commandSpecs": commandSpecs(),
            "pinnedCommandIds": ["launcher.toggle", "settings.reload"]
        });
        const items = adapter.search({
            payload: {
                query: ">"
            }
        });

        verify(items.length >= 2);
        compare(items[0].id, "ipc:launcher.toggle");
        compare(items[1].id, "ipc:settings.reload");
    }

    function test_cmd_route_returns_external_catalog_without_ipc_commands() {
        const adapter = SystemLauncherSearchAdapter.createSystemLauncherSearchAdapter({
            "commandPrefix": ">",
            "maxResults": 12,
            "commandSpecs": commandSpecs(),
            "recentExternalCommands": ["python -m http.server"],
            "commandCatalogAdapter": {
                "searchTerm": function () {
                    return [createItem("cmd:firefox", "firefox", "commands", 320, {
                            type: "shell.command.run",
                            command: "firefox"
                        })];
                }
            }
        });
        const items = adapter.search({
            payload: {
                query: ">cmd fire"
            }
        });

        verify(findItemById(items, "cmd:firefox") !== null);
        verify(findItemById(items, "ipc:settings.reload") === null);
    }

    function test_web_route_returns_browser_search_candidate() {
        const adapter = createAdapter();
        const items = adapter.search({
            payload: {
                query: ">web quickshell launcher"
            }
        });

        verify(items.length >= 1);
        compare(items[0].provider, "web");
        compare(items[0].action.type, "shell.command.run");
        verify(String(items[0].action.command || "").indexOf("xdg-open") === 0);
    }

    function test_windows_route_alias_maps_to_query_providers() {
        let routedQueryTerm = "";
        const adapter = SystemLauncherSearchAdapter.createSystemLauncherSearchAdapter({
            includeDefaultProviders: false,
            providers: [
                {
                    id: "custom.default",
                    order: 10,
                    routeKeys: ["default"],
                    modes: ["query"],
                    search: function () {
                        return [createItem("default:item", "Default Item", "custom", 40, {
                                type: "shell.command.run",
                                command: "echo default"
                            })];
                    }
                },
                {
                    id: "custom.windows",
                    order: 20,
                    routeKeys: ["windows"],
                    modes: ["query"],
                    search: function (context) {
                        routedQueryTerm = String(context.queryTerm || "");
                        return [createItem("windows:item", "Windows Item", "windows", 120, {
                                type: "shell.ipc.dispatch",
                                command: "window_switcher.focus",
                                args: ["0x1"]
                            })];
                    }
                }
            ]
        });
        const items = adapter.search({
            payload: {
                query: ">win fire"
            }
        });

        compare(items.length, 1);
        compare(items[0].id, "windows:item");
        compare(routedQueryTerm, "fire");
    }

    function test_math_query_returns_calculator_result() {
        const adapter = createAdapter();
        const items = adapter.search({
            payload: {
                query: "2 + 3 * 4"
            }
        });

        verify(items.length >= 1);
        compare(items[0].provider, "calculator");
        compare(items[0].title, "14");
        compare(items[0].action.type, "calculator.copy_result");
    }

    function test_app_query_returns_application_results() {
        const adapter = createAdapter();
        const items = adapter.search({
            payload: {
                query: "fire"
            }
        });

        verify(items.length >= 1);
        compare(items[0].id, "app:firefox.desktop");
        compare(items[0].action.type, "app.launch");
        verify(String(items[0].detail || "").length > 0);
        verify(String(items[0].iconName || "").length > 0);
    }

    function test_app_adapter_metadata_is_preserved_for_results() {
        const adapter = SystemLauncherSearchAdapter.createSystemLauncherSearchAdapter({
            "commandPrefix": ">",
            "maxResults": 8,
            "commandSpecs": commandSpecs(),
            "appSearchAdapter": {
                "search": function () {
                    return [
                        {
                            id: "app:custom.desktop",
                            title: "Custom App",
                            subtitle: "Custom utility",
                            detail: "Custom detail text",
                            iconName: "utilities-terminal",
                            provider: "apps",
                            score: 200,
                            action: {
                                type: "app.launch",
                                targetId: "custom.desktop"
                            }
                        }
                    ];
                }
            }
        });

        const items = adapter.search({
            payload: {
                query: "custom"
            }
        });
        const appItem = findItemById(items, "app:custom.desktop");

        verify(appItem !== null);
        compare(appItem.detail, "Custom detail text");
        compare(appItem.iconName, "utilities-terminal");
    }

    function test_provider_registry_applies_mode_routing() {
        const adapter = SystemLauncherSearchAdapter.createSystemLauncherSearchAdapter({
            includeDefaultProviders: false,
            providers: [
                {
                    id: "custom.query",
                    order: 10,
                    modes: ["query"],
                    search: function () {
                        return [createItem("custom:query", "Query Item", "custom", 50, {
                                type: "shell.command.run",
                                command: "echo query"
                            })];
                    }
                },
                {
                    id: "custom.command",
                    order: 10,
                    modes: ["command"],
                    search: function () {
                        return [createItem("custom:command", "Command Item", "custom", 60, {
                                type: "shell.ipc.dispatch",
                                command: "session.toggle",
                                args: []
                            })];
                    }
                }
            ]
        });

        const queryItems = adapter.search({
            payload: {
                query: "abc"
            }
        });
        compare(queryItems.length, 1);
        compare(queryItems[0].id, "custom:query");

        const commandItems = adapter.search({
            payload: {
                query: ">abc"
            }
        });
        compare(commandItems.length, 1);
        compare(commandItems[0].id, "custom:command");
    }

    function test_provider_registry_applies_route_alias_filtering() {
        const adapter = SystemLauncherSearchAdapter.createSystemLauncherSearchAdapter({
            includeDefaultProviders: false,
            providers: [
                {
                    id: "custom.query",
                    order: 10,
                    routeKeys: ["default"],
                    modes: ["query"],
                    search: function () {
                        return [createItem("custom:query", "Query Item", "custom", 50, {
                                type: "shell.command.run",
                                command: "echo query"
                            })];
                    }
                },
                {
                    id: "custom.emoji",
                    order: 10,
                    routeKeys: ["emoji"],
                    modes: ["query"],
                    search: function () {
                        return [createItem("custom:emoji", "Emoji Item", "emoji", 60, {
                                type: "clipboard.copy_text",
                                targetId: "😀"
                            })];
                    }
                }
            ]
        });

        const defaultQueryItems = adapter.search({
            payload: {
                query: "abc"
            }
        });
        compare(defaultQueryItems.length, 1);
        compare(defaultQueryItems[0].id, "custom:query");

        const routedItems = adapter.search({
            payload: {
                query: ">emoji grin"
            }
        });
        compare(routedItems.length, 1);
        compare(routedItems[0].id, "custom:emoji");
    }

    function test_async_provider_reports_pending_callback_and_keeps_sync_results() {
        let pending = null;
        const asyncToken = {
            then: function () {}
        };
        const adapter = SystemLauncherSearchAdapter.createSystemLauncherSearchAdapter({
            includeDefaultProviders: false,
            onAsyncProviderResult: function (event) {
                pending = event;
            },
            providers: [
                {
                    id: "sync.provider",
                    order: 20,
                    kind: "sync",
                    modes: ["query"],
                    search: function () {
                        return [createItem("sync:item", "Sync Item", "custom", 10, {
                                type: "shell.command.run",
                                command: "echo sync"
                            })];
                    }
                },
                {
                    id: "async.provider",
                    order: 10,
                    kind: "async",
                    modes: ["query"],
                    search: function () {
                        return asyncToken;
                    }
                }
            ]
        });

        const items = adapter.search({
            payload: {
                query: "abc"
            }
        });

        compare(items.length, 1);
        compare(items[0].id, "sync:item");
        verify(pending !== null);
        compare(pending.kind, "launcher.provider.async_pending");
        compare(pending.providerId, "async.provider");
        verify(pending.promise === asyncToken);
    }

    name: "LauncherSearchAdapterSlice"
}

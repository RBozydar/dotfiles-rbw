import "../system/core/application/integrations/describe-optional-integrations-health.js" as OptionalIntegrationHealthUseCases
import QtQuick 2.15
import QtTest 1.3

TestCase {
    name: "OptionalIntegrationHealthSlice"

    function findIntegration(report, integrationId) {
        const entries = report && Array.isArray(report.integrations) ? report.integrations : [];
        for (let index = 0; index < entries.length; index += 1) {
            if (entries[index].integrationId === integrationId)
                return entries[index];
        }
        return null;
    }

    function findHint(integration, code) {
        const hints = integration && Array.isArray(integration.hints) ? integration.hints : [];
        for (let index = 0; index < hints.length; index += 1) {
            if (hints[index].code === code)
                return hints[index];
        }
        return null;
    }

    function test_createOptionalIntegrationsHealthSnapshot_reports_ready_with_disabled() {
        const report = OptionalIntegrationHealthUseCases.createOptionalIntegrationsHealthSnapshot({
            integrations: [
                {
                    integrationId: "launcher.emoji",
                    kind: "adapter.search.emoji_catalog",
                    enabled: true,
                    available: true,
                    ready: true,
                    degraded: false,
                    reasonCode: "ok",
                    lastUpdatedAt: "2026-04-19T10:00:00.000Z",
                    lastError: ""
                },
                {
                    integrationId: "launcher.wallpaper",
                    kind: "adapter.search.wallpaper_catalog",
                    enabled: false,
                    available: false,
                    ready: false,
                    degraded: false,
                    reasonCode: "integration_disabled",
                    lastUpdatedAt: "2026-04-19T10:01:00.000Z",
                    lastError: ""
                }
            ]
        });

        compare(report.kind, "shell.optional_integrations.health");
        compare(report.overallStatus, "ready_with_disabled");
        compare(report.counts.total, 2);
        compare(report.counts.ready, 1);
        compare(report.counts.disabled, 1);
        compare(report.counts.degraded, 0);
    }

    function test_createOptionalIntegrationsHealthSnapshot_adds_dependency_and_refresh_hints() {
        const report = OptionalIntegrationHealthUseCases.createOptionalIntegrationsHealthSnapshot({
            integrations: [
                {
                    integrationId: "launcher.wallpaper",
                    kind: "adapter.search.wallpaper_catalog",
                    commandPath: "find",
                    applyCommandPath: "swww",
                    enabled: true,
                    available: false,
                    ready: false,
                    degraded: true,
                    reasonCode: "dependency_missing",
                    lastUpdatedAt: "2026-04-19T10:02:00.000Z",
                    lastError: "Missing required commands: find, swww"
                }
            ]
        });
        const wallpaper = findIntegration(report, "launcher.wallpaper");

        verify(wallpaper !== null);
        compare(report.overallStatus, "degraded");
        compare(wallpaper.status, "degraded");
        compare(wallpaper.severity, "error");
        compare(wallpaper.hintCount > 0, true);

        const installHint = findHint(wallpaper, "install_dependencies");
        verify(installHint !== null);
        verify(installHint.message.indexOf("find") >= 0);
        verify(installHint.message.indexOf("swww") >= 0);

        const refreshHint = findHint(wallpaper, "run_refresh");
        verify(refreshHint !== null);
        compare(refreshHint.command, "wallpaper.refresh_catalog");
    }

    function test_createOptionalIntegrationsHealthSnapshot_adds_enable_hint_for_disabled_home_assistant() {
        const report = OptionalIntegrationHealthUseCases.createOptionalIntegrationsHealthSnapshot({
            integrations: [
                {
                    integrationId: "shell.home_assistant",
                    kind: "adapter.integration.home_assistant",
                    enabled: false,
                    available: false,
                    ready: false,
                    degraded: false,
                    reasonCode: "integration_disabled",
                    lastUpdatedAt: "2026-04-19T10:03:00.000Z",
                    lastError: ""
                }
            ]
        });
        const homeAssistant = findIntegration(report, "shell.home_assistant");

        verify(homeAssistant !== null);
        compare(report.overallStatus, "disabled");
        compare(homeAssistant.status, "disabled");
        compare(homeAssistant.severity, "info");

        const enableHint = findHint(homeAssistant, "enable_integration");
        verify(enableHint !== null);
        verify(enableHint.action.indexOf("RBW_HOME_ASSISTANT_ENABLED=1") >= 0);
    }
}

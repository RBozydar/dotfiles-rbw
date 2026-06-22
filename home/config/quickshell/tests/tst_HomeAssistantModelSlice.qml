import "../system/adapters/homeassistant/homeassistant-model.js" as HomeAssistantModel
import QtQuick 2.15
import QtTest 1.3

TestCase {
    function test_parseSnapshotText_parses_valid_payload() {
        const parsed = HomeAssistantModel.parseSnapshotText("{\"configured\":true,\"available\":true,\"error\":\"\",\"lights\":[{\"entityId\":\"light.office\",\"name\":\"Office\",\"isOn\":true,\"available\":true,\"brightnessPercent\":70}],\"scenes\":[{\"entityId\":\"scene.movie_time\",\"name\":\"Movie Time\",\"available\":true}]}");

        verify(parsed.ok);
        compare(parsed.snapshot.configured, true);
        compare(parsed.snapshot.available, true);
        compare(parsed.snapshot.lights.length, 1);
        compare(parsed.snapshot.scenes.length, 1);
        compare(parsed.snapshot.lights[0].entityId, "light.office");
        compare(parsed.snapshot.lights[0].brightnessPercent, 70);
        compare(parsed.snapshot.scenes[0].entityId, "scene.movie_time");
    }

    function test_parseSnapshotText_rejects_empty_payload() {
        const parsed = HomeAssistantModel.parseSnapshotText("   ");

        compare(parsed.ok, false);
        compare(parsed.reasonCode, "empty_response");
        compare(parsed.error, "Home Assistant returned no data");
    }

    function test_summarizeSnapshot_builds_chip_and_summary_labels() {
        const summary = HomeAssistantModel.summarizeSnapshot(true, {
            configured: true,
            available: true,
            error: "",
            lights: [
                {
                    entityId: "light.office",
                    name: "Office",
                    available: true,
                    isOn: true
                },
                {
                    entityId: "light.desk",
                    name: "Desk",
                    available: true,
                    isOn: false
                }
            ]
        }, "2026-04-19T00:00:00.000Z");

        compare(summary.ready, true);
        compare(summary.reasonCode, "ok");
        compare(summary.lightCount, 2);
        compare(summary.activeLightCount, 1);
        compare(summary.sceneCount, 0);
        compare(summary.chipLabel, "1/2");
        compare(summary.summaryLabel, "1 of 2 on");
    }

    function test_summarizeSnapshot_marks_unconfigured_as_degraded() {
        const summary = HomeAssistantModel.summarizeSnapshot(true, {
            configured: false,
            available: false,
            error: "Missing HA_TOKEN",
            lights: []
        }, "2026-04-19T00:00:00.000Z");

        compare(summary.ready, false);
        compare(summary.degraded, true);
        compare(summary.reasonCode, "not_configured");
        compare(summary.summaryLabel, "Not configured");
    }

    function test_parseActionResult_handles_success_and_json_failure() {
        const okResult = HomeAssistantModel.parseActionResult("{\"success\":true}", "");
        compare(okResult.success, true);
        compare(okResult.reasonCode, "action_ok");

        const failedResult = HomeAssistantModel.parseActionResult("{\"success\":false,\"error\":\"Light is unavailable\"}", "");
        compare(failedResult.success, false);
        compare(failedResult.reasonCode, "action_failed");
        compare(failedResult.error, "Light is unavailable");
    }

    function test_parseActionResult_classifies_stderr_dependency_missing() {
        const failedResult = HomeAssistantModel.parseActionResult("", "sh: uv: not found");

        compare(failedResult.success, false);
        compare(failedResult.reasonCode, "dependency_missing");
        compare(failedResult.error, "sh: uv: not found");
    }

    name: "HomeAssistantModelSlice"
}

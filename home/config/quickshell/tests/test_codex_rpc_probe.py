from __future__ import annotations

from pathlib import Path

import pytest
from scripts import codex_rpc_probe as probe


def test_normalize_rate_window_maps_usage_and_reset_time() -> None:
    normalized = probe.normalize_rate_window(
        {
            "usedPercent": 28,
            "windowDurationMins": 300,
            "resetsAt": 1_776_060_900,
        }
    )

    assert normalized == {
        "usedPercent": 28.0,
        "remainingPercent": 72.0,
        "windowMinutes": 300,
        "resetsAt": "2026-04-13T06:15:00Z",
    }


def test_normalize_account_preserves_chatgpt_identity() -> None:
    normalized = probe.normalize_account(
        {
            "type": "chatgpt",
            "email": "user@example.com",
            "planType": "plus",
        }
    )

    assert normalized == {
        "type": "chatgpt",
        "email": "user@example.com",
        "plan": "plus",
    }


def test_build_success_payload_maps_rpc_responses() -> None:
    payload = probe.build_success_payload(
        working_directory=Path("/tmp/example"),
        account_response={
            "account": {
                "type": "chatgpt",
                "email": "user@example.com",
                "planType": "plus",
            },
            "requiresOpenaiAuth": False,
        },
        rate_limits_response={
            "rateLimits": {
                "primary": {
                    "usedPercent": 28,
                    "windowDurationMins": 300,
                    "resetsAt": 1_776_060_900,
                },
                "secondary": {
                    "usedPercent": 59,
                    "windowDurationMins": 10_080,
                    "resetsAt": 1_776_147_200,
                },
                "credits": {
                    "hasCredits": True,
                    "unlimited": False,
                    "balance": "112.4",
                },
            }
        },
    )

    assert payload["ok"] is True
    assert payload["provider"] == "codex"
    assert payload["source"] == "rpc"
    assert payload["workingDirectory"] == "/tmp/example"
    assert payload["account"] == {
        "account": {
            "type": "chatgpt",
            "email": "user@example.com",
            "plan": "plus",
        },
        "requiresOpenAIAuth": False,
    }
    assert payload["usage"] == {
        "fiveHour": {
            "usedPercent": 28.0,
            "remainingPercent": 72.0,
            "windowMinutes": 300,
            "resetsAt": "2026-04-13T06:15:00Z",
        },
        "weekly": {
            "usedPercent": 59.0,
            "remainingPercent": 41.0,
            "windowMinutes": 10080,
            "resetsAt": "2026-04-14T06:13:20Z",
        },
    }
    assert payload["credits"] == {
        "hasCredits": True,
        "unlimited": False,
        "remaining": 112.4,
    }


def test_build_success_payload_supports_api_key_account() -> None:
    payload = probe.build_success_payload(
        working_directory=Path("/tmp/example"),
        account_response={
            "account": {
                "type": "apikey",
            },
            "requiresOpenaiAuth": True,
        },
        rate_limits_response={
            "rateLimits": {
                "primary": None,
                "secondary": None,
                "credits": None,
            }
        },
    )

    assert payload["account"] == {
        "account": {
            "type": "apikey",
        },
        "requiresOpenAIAuth": True,
    }
    assert payload["usage"] == {"fiveHour": None, "weekly": None}
    assert payload["credits"] is None


def test_build_error_payload_marks_failure() -> None:
    payload = probe.build_error_payload(
        working_directory=Path("/tmp/example"),
        message="Timed out waiting for Codex RPC",
        error_type="rpc",
    )

    assert payload["ok"] is False
    assert payload["error"] == {
        "type": "rpc",
        "message": "Timed out waiting for Codex RPC",
    }


def test_extract_error_body_json_parses_embedded_usage_body() -> None:
    message = (
        "Decode error for https://chatgpt.com/backend-api/wham/usage: unknown variant `prolite`; "
        'body={"email":"user@example.com","plan_type":"prolite","rate_limit":{"primary_window":null,'
        '"secondary_window":null},"credits":{"has_credits":false,"unlimited":false,"balance":"0"}}'
    )

    payload = probe.extract_error_body_json(message)

    assert payload == {
        "email": "user@example.com",
        "plan_type": "prolite",
        "rate_limit": {
            "primary_window": None,
            "secondary_window": None,
        },
        "credits": {
            "has_credits": False,
            "unlimited": False,
            "balance": "0",
        },
    }


def test_build_success_payload_supports_raw_error_body_fallback() -> None:
    payload = probe.build_success_payload(
        working_directory=Path("/tmp/example"),
        account_response={
            "account": None,
            "requiresOpenaiAuth": False,
        },
        rate_limits_response={
            "_errorBody": {
                "email": "user@example.com",
                "plan_type": "prolite",
                "rate_limit": {
                    "primary_window": {
                        "used_percent": 24,
                        "limit_window_seconds": 18_000,
                        "reset_at": 1_776_202_233,
                    },
                    "secondary_window": {
                        "used_percent": 27,
                        "limit_window_seconds": 604_800,
                        "reset_at": 1_776_359_719,
                    },
                },
                "credits": {
                    "has_credits": False,
                    "unlimited": False,
                    "balance": "0",
                },
            }
        },
    )

    assert payload["account"] == {
        "account": {
            "type": "chatgpt",
            "email": "user@example.com",
            "plan": "prolite",
        },
        "requiresOpenAIAuth": False,
    }
    assert payload["usage"] == {
        "fiveHour": {
            "usedPercent": 24.0,
            "remainingPercent": 76.0,
            "windowMinutes": 300,
            "resetsAt": "2026-04-14T21:30:33Z",
        },
        "weekly": {
            "usedPercent": 27.0,
            "remainingPercent": 73.0,
            "windowMinutes": 10080,
            "resetsAt": "2026-04-16T17:15:19Z",
        },
    }
    assert payload["credits"] == {
        "hasCredits": False,
        "unlimited": False,
        "remaining": 0.0,
    }


def test_iso_from_unix_seconds_rejects_non_numeric_values() -> None:
    with pytest.raises(probe.CodexRpcProbeError, match="Expected numeric resetsAt"):
        probe.iso_from_unix_seconds("tomorrow")

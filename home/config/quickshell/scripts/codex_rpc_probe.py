#!/usr/bin/env python3
"""Probe Codex usage via the local JSON-RPC app-server and print normalized JSON."""

from __future__ import annotations

import argparse
import json
import os
import re
import selectors
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Final, cast

DEFAULT_TIMEOUT_SECONDS: Final[float] = 8.0
DEFAULT_CODEX_ARGS: Final[tuple[str, ...]] = (
    "-s",
    "read-only",
    "-a",
    "untrusted",
    "app-server",
)
ERROR_BODY_PATTERN: Final[re.Pattern[str]] = re.compile(r"body=(\{.*\})$", re.DOTALL)


class CodexRpcProbeError(RuntimeError):
    """Raised when the Codex RPC process or protocol fails."""


@dataclass(frozen=True, slots=True)
class NormalizedRateWindow:
    """Normalized usage window returned by Codex RPC."""

    used_percent: float
    remaining_percent: float
    window_minutes: int | None
    resets_at: str | None

    def to_payload(self) -> dict[str, object]:
        """Return a JSON-serializable mapping."""
        return {
            "usedPercent": self.used_percent,
            "remainingPercent": self.remaining_percent,
            "windowMinutes": self.window_minutes,
            "resetsAt": self.resets_at,
        }


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--cwd",
        default=str(Path.cwd()),
        help="Working directory used when launching the Codex app-server.",
    )
    parser.add_argument(
        "--codex-binary",
        default="codex",
        help="Codex executable to launch.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=DEFAULT_TIMEOUT_SECONDS,
        help="Per-request timeout in seconds.",
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print JSON output.",
    )
    return parser.parse_args()


def emit_json(payload: dict[str, Any], *, pretty: bool) -> None:
    """Emit a single JSON object followed by a newline."""
    if pretty:
        json.dump(payload, sys.stdout, indent=2, sort_keys=True)
    else:
        json.dump(payload, sys.stdout, separators=(",", ":"))
    sys.stdout.write("\n")


def utc_now_iso() -> str:
    """Return the current time as an ISO-8601 UTC string."""
    return datetime.now(UTC).isoformat().replace("+00:00", "Z")


def iso_from_unix_seconds(value: object) -> str | None:
    """Convert a Unix timestamp in seconds to ISO-8601 UTC."""
    if value is None:
        return None
    if not isinstance(value, int | float):
        raise CodexRpcProbeError(f"Expected numeric resetsAt, got {type(value).__name__}")
    return datetime.fromtimestamp(float(value), UTC).isoformat().replace("+00:00", "Z")


def optional_string(value: object) -> str | None:
    """Normalize a possibly-empty string."""
    if value is None:
        return None
    if not isinstance(value, str):
        raise CodexRpcProbeError(f"Expected string value, got {type(value).__name__}")
    trimmed = value.strip()
    return trimmed or None


def normalize_rate_window(window_payload: object) -> dict[str, object] | None:
    """Normalize a Codex RPC rate-limit window."""
    if window_payload is None:
        return None
    if not isinstance(window_payload, dict):
        raise CodexRpcProbeError(
            f"Expected rate-limit window object, got {type(window_payload).__name__}"
        )

    used_raw = window_payload.get("usedPercent")
    if not isinstance(used_raw, int | float):
        raise CodexRpcProbeError("Rate-limit window is missing numeric usedPercent")

    minutes_raw = window_payload.get("windowDurationMins")
    if minutes_raw is None:
        window_minutes = None
    elif isinstance(minutes_raw, int):
        window_minutes = minutes_raw
    else:
        raise CodexRpcProbeError("Rate-limit window has invalid windowDurationMins")

    used_percent = max(0.0, min(100.0, float(used_raw)))
    normalized = NormalizedRateWindow(
        used_percent=used_percent,
        remaining_percent=max(0.0, min(100.0, 100.0 - used_percent)),
        window_minutes=window_minutes,
        resets_at=iso_from_unix_seconds(window_payload.get("resetsAt")),
    )
    return normalized.to_payload()


def normalize_credits(credits_payload: object) -> dict[str, object] | None:
    """Normalize Codex RPC credits data."""
    if credits_payload is None:
        return None
    if not isinstance(credits_payload, dict):
        raise CodexRpcProbeError(f"Expected credits object, got {type(credits_payload).__name__}")

    has_credits_raw = credits_payload.get("hasCredits")
    unlimited_raw = credits_payload.get("unlimited")
    if not isinstance(has_credits_raw, bool) or not isinstance(unlimited_raw, bool):
        raise CodexRpcProbeError("Credits payload is missing boolean fields")

    balance_raw = credits_payload.get("balance")
    if balance_raw is None:
        remaining = None
    elif isinstance(balance_raw, str):
        try:
            remaining = float(balance_raw)
        except ValueError as exc:
            raise CodexRpcProbeError("Credits payload has non-numeric balance") from exc
    else:
        raise CodexRpcProbeError("Credits payload has invalid balance field")

    return {
        "hasCredits": has_credits_raw,
        "unlimited": unlimited_raw,
        "remaining": remaining,
    }


def normalize_credits_from_raw_usage(credits_payload: object) -> dict[str, object] | None:
    """Normalize credits from the raw OpenAI usage body embedded in a Codex error."""
    if credits_payload is None:
        return None
    if not isinstance(credits_payload, dict):
        raise CodexRpcProbeError(f"Expected raw credits object, got {type(credits_payload).__name__}")

    has_credits_raw = credits_payload.get("has_credits")
    unlimited_raw = credits_payload.get("unlimited")
    if not isinstance(has_credits_raw, bool) or not isinstance(unlimited_raw, bool):
        raise CodexRpcProbeError("Raw credits payload is missing boolean fields")

    balance_raw = credits_payload.get("balance")
    if balance_raw is None:
        remaining = None
    elif isinstance(balance_raw, str):
        try:
            remaining = float(balance_raw)
        except ValueError as exc:
            raise CodexRpcProbeError("Raw credits payload has non-numeric balance") from exc
    else:
        raise CodexRpcProbeError("Raw credits payload has invalid balance field")

    return {
        "hasCredits": has_credits_raw,
        "unlimited": unlimited_raw,
        "remaining": remaining,
    }


def normalize_account(account_payload: object) -> dict[str, object] | None:
    """Normalize the Codex RPC account payload."""
    if account_payload is None:
        return None
    if not isinstance(account_payload, dict):
        raise CodexRpcProbeError(f"Expected account object, got {type(account_payload).__name__}")

    account_type = optional_string(account_payload.get("type"))
    if account_type is None:
        raise CodexRpcProbeError("Account payload is missing type")

    payload: dict[str, object] = {"type": account_type}
    if account_type.lower() == "chatgpt":
        payload["email"] = optional_string(account_payload.get("email"))
        payload["plan"] = optional_string(account_payload.get("planType"))
    return payload


def normalize_account_from_raw_usage(usage_payload: object) -> dict[str, object] | None:
    """Normalize account metadata from the raw OpenAI usage body."""
    if not isinstance(usage_payload, dict):
        return None
    email = optional_string(usage_payload.get("email"))
    plan = optional_string(usage_payload.get("plan_type"))
    if email is None and plan is None:
        return None
    return {
        "type": "chatgpt",
        "email": email,
        "plan": plan,
    }


def normalize_rate_window_from_raw_usage(window_payload: object) -> dict[str, object] | None:
    """Normalize a raw OpenAI usage window embedded in a Codex decode error."""
    if window_payload is None:
        return None
    if not isinstance(window_payload, dict):
        raise CodexRpcProbeError(
            f"Expected raw usage window object, got {type(window_payload).__name__}"
        )

    used_raw = window_payload.get("used_percent")
    if not isinstance(used_raw, int | float):
        raise CodexRpcProbeError("Raw usage window is missing numeric used_percent")

    seconds_raw = window_payload.get("limit_window_seconds")
    if seconds_raw is None:
        window_minutes = None
    elif isinstance(seconds_raw, int):
        window_minutes = seconds_raw // 60
    else:
        raise CodexRpcProbeError("Raw usage window has invalid limit_window_seconds")

    used_percent = max(0.0, min(100.0, float(used_raw)))
    normalized = NormalizedRateWindow(
        used_percent=used_percent,
        remaining_percent=max(0.0, min(100.0, 100.0 - used_percent)),
        window_minutes=window_minutes,
        resets_at=iso_from_unix_seconds(window_payload.get("reset_at")),
    )
    return normalized.to_payload()


def build_usage_from_raw_error_body(
    usage_payload: object,
) -> tuple[dict[str, dict[str, object] | None], dict[str, object] | None]:
    """Map the raw OpenAI usage body to the normalized usage and credits payloads."""
    if not isinstance(usage_payload, dict):
        raise CodexRpcProbeError("Raw usage body is not an object")

    rate_limit_payload = usage_payload.get("rate_limit")
    if not isinstance(rate_limit_payload, dict):
        raise CodexRpcProbeError("Raw usage body is missing rate_limit")

    usage = {
        "fiveHour": normalize_rate_window_from_raw_usage(rate_limit_payload.get("primary_window")),
        "weekly": normalize_rate_window_from_raw_usage(rate_limit_payload.get("secondary_window")),
    }
    credits = normalize_credits_from_raw_usage(usage_payload.get("credits"))
    return usage, credits


def extract_error_body_json(message: str) -> dict[str, Any] | None:
    """Extract the raw JSON body embedded in a Codex decode error message."""
    match = ERROR_BODY_PATTERN.search(message)
    if match is None:
        return None

    try:
        payload = json.loads(match.group(1))
    except json.JSONDecodeError:
        return None
    if not isinstance(payload, dict):
        return None
    return cast(dict[str, Any], payload)


def build_success_payload(
    *,
    working_directory: Path,
    account_response: dict[str, Any],
    rate_limits_response: dict[str, Any],
) -> dict[str, Any]:
    """Build the normalized success payload."""
    rate_limits_payload = rate_limits_response.get("rateLimits")

    account_payload = {
        "account": normalize_account(account_response.get("account")),
        "requiresOpenAIAuth": bool(account_response.get("requiresOpenaiAuth", False)),
    }

    if isinstance(rate_limits_payload, dict):
        usage_payload: dict[str, dict[str, object] | None] = {
            "fiveHour": normalize_rate_window(rate_limits_payload.get("primary")),
            "weekly": normalize_rate_window(rate_limits_payload.get("secondary")),
        }
        credits_payload = normalize_credits(rate_limits_payload.get("credits"))
    else:
        raw_error_body = rate_limits_response.get("_errorBody")
        if raw_error_body is None:
            raise CodexRpcProbeError("Codex RPC response is missing rateLimits")
        usage_payload, credits_payload = build_usage_from_raw_error_body(raw_error_body)
        account_override = normalize_account_from_raw_usage(raw_error_body)
        if account_payload["account"] is None and account_override is not None:
            account_payload["account"] = account_override

    return {
        "ok": True,
        "provider": "codex",
        "source": "rpc",
        "workingDirectory": str(working_directory),
        "fetchedAt": utc_now_iso(),
        "account": account_payload,
        "usage": usage_payload,
        "credits": credits_payload,
    }


def build_error_payload(
    *,
    working_directory: Path,
    message: str,
    error_type: str,
) -> dict[str, Any]:
    """Build a JSON-serializable error payload."""
    return {
        "ok": False,
        "provider": "codex",
        "source": "rpc",
        "workingDirectory": str(working_directory),
        "fetchedAt": utc_now_iso(),
        "error": {
            "type": error_type,
            "message": message,
        },
    }


class CodexRpcClient:
    """Small JSON-RPC client for `codex app-server`."""

    def __init__(
        self,
        *,
        codex_binary: str,
        working_directory: Path,
        timeout_seconds: float,
    ) -> None:
        self.working_directory = working_directory
        self.timeout_seconds = timeout_seconds
        self.next_id = 1
        self.stderr_lines: list[str] = []

        resolved_binary = self._resolve_binary(codex_binary)
        environment = os.environ.copy()
        self.process = subprocess.Popen(
            [resolved_binary, *DEFAULT_CODEX_ARGS],
            cwd=self.working_directory,
            env=environment,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=False,
        )

    def close(self) -> None:
        """Terminate the child process."""
        if self.process.poll() is not None:
            return
        self.process.terminate()
        try:
            self.process.wait(timeout=1.0)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait(timeout=1.0)

    def initialize(self) -> None:
        """Run the required Codex app-server initialization sequence."""
        _ = self.request(
            "initialize",
            params={"clientInfo": {"name": "rbw-codex-rpc-probe", "version": "0.1.0"}},
        )
        self.notify("initialized")

    def fetch_account(self) -> dict[str, Any]:
        """Fetch account metadata."""
        return self.request("account/read")

    def fetch_rate_limits(self) -> dict[str, Any]:
        """Fetch rate-limit metadata."""
        return self.request("account/rateLimits/read")

    def request(self, method: str, *, params: dict[str, Any] | None = None) -> dict[str, Any]:
        """Send a request and wait for the matching response."""
        request_id = self.next_id
        self.next_id += 1
        self._send_payload({"id": request_id, "method": method, "params": params or {}})

        while True:
            message = self._read_message(timeout_seconds=self.timeout_seconds)
            message_id = message.get("id")
            if message_id is None:
                continue
            if not isinstance(message_id, int):
                raise CodexRpcProbeError("Codex RPC response id is not an integer")
            if message_id != request_id:
                continue

            error_payload = message.get("error")
            if isinstance(error_payload, dict):
                error_message = optional_string(error_payload.get("message")) or "Unknown Codex RPC error"
                raise CodexRpcProbeError(error_message)

            return message

    def notify(self, method: str, *, params: dict[str, Any] | None = None) -> None:
        """Send a JSON-RPC notification."""
        self._send_payload({"method": method, "params": params or {}})

    def _send_payload(self, payload: dict[str, Any]) -> None:
        stdin = self.process.stdin
        if stdin is None:
            raise CodexRpcProbeError("Codex RPC stdin is unavailable")

        encoded = json.dumps(payload, separators=(",", ":")).encode("utf-8") + b"\n"
        try:
            stdin.write(encoded)
            stdin.flush()
        except BrokenPipeError as exc:
            raise CodexRpcProbeError(self._process_exit_message("Codex RPC closed its stdin")) from exc

    def _read_message(self, *, timeout_seconds: float) -> dict[str, Any]:
        deadline = time.monotonic() + timeout_seconds

        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise CodexRpcProbeError(self._process_exit_message("Timed out waiting for Codex RPC"))

            stdout = self.process.stdout
            stderr = self.process.stderr
            if stdout is None or stderr is None:
                raise CodexRpcProbeError("Codex RPC pipes are unavailable")

            with selectors.DefaultSelector() as selector:
                selector.register(stdout, selectors.EVENT_READ, data="stdout")
                selector.register(stderr, selectors.EVENT_READ, data="stderr")
                events = selector.select(remaining)

            if not events:
                raise CodexRpcProbeError(self._process_exit_message("Timed out waiting for Codex RPC"))

            for key, _mask in events:
                stream_name = cast(str, key.data)
                if stream_name == "stderr":
                    self._drain_stderr_line()
                    continue
                return self._read_stdout_message()

    def _read_stdout_message(self) -> dict[str, Any]:
        stdout = self.process.stdout
        if stdout is None:
            raise CodexRpcProbeError("Codex RPC stdout is unavailable")
        line = stdout.readline()
        if not line:
            raise CodexRpcProbeError(self._process_exit_message("Codex RPC exited before replying"))
        try:
            message = json.loads(line.decode("utf-8"))
        except json.JSONDecodeError as exc:
            raise CodexRpcProbeError("Codex RPC returned invalid JSON") from exc
        if not isinstance(message, dict):
            raise CodexRpcProbeError("Codex RPC returned a non-object message")
        return cast(dict[str, Any], message)

    def _drain_stderr_line(self) -> None:
        stderr = self.process.stderr
        if stderr is None:
            return
        line = stderr.readline()
        if not line:
            return
        text = line.decode("utf-8", errors="replace").strip()
        if text:
            self.stderr_lines.append(text)

    def _process_exit_message(self, prefix: str) -> str:
        detail = self._stderr_summary()
        if detail:
            return f"{prefix}: {detail}"
        return prefix

    def _stderr_summary(self) -> str | None:
        if not self.stderr_lines:
            return None
        return " | ".join(self.stderr_lines[-5:])

    @staticmethod
    def _resolve_binary(binary: str) -> str:
        if Path(binary).is_absolute():
            if not os.access(binary, os.X_OK):
                raise CodexRpcProbeError(f"Codex binary is not executable: {binary}")
            return binary

        resolved = shutil.which(binary)
        if resolved is None:
            raise CodexRpcProbeError(f"Codex binary not found on PATH: {binary}")
        return resolved


def run_probe(args: argparse.Namespace) -> dict[str, Any]:
    """Run the Codex RPC probe and return the normalized payload."""
    working_directory = Path(args.cwd).expanduser().resolve()
    if not working_directory.is_dir():
        raise CodexRpcProbeError(f"Working directory does not exist: {working_directory}")

    client = CodexRpcClient(
        codex_binary=str(args.codex_binary),
        working_directory=working_directory,
        timeout_seconds=float(args.timeout),
    )
    try:
        client.initialize()
        account_response = client.fetch_account()
        try:
            rate_limits_response = client.fetch_rate_limits()
        except CodexRpcProbeError as exc:
            error_body = extract_error_body_json(str(exc))
            if error_body is None:
                raise
            rate_limits_response = {"_errorBody": error_body}
        return build_success_payload(
            working_directory=working_directory,
            account_response=account_response,
            rate_limits_response=rate_limits_response,
        )
    finally:
        client.close()


def main() -> int:
    """CLI entrypoint."""
    args = parse_args()
    working_directory = Path(args.cwd).expanduser().resolve()

    try:
        payload = run_probe(args)
    except CodexRpcProbeError as exc:
        emit_json(
            build_error_payload(
                working_directory=working_directory,
                message=str(exc),
                error_type="rpc",
            ),
            pretty=bool(args.pretty),
        )
        return 1

    emit_json(payload, pretty=bool(args.pretty))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

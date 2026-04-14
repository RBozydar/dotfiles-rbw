#!/usr/bin/env python3
"""Minimal Home Assistant helper for Quickshell light controls."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any
from dotenv import dotenv_values
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


DEFAULT_HASS_URL = "http://homeassistant.local:8123"
DEFAULT_TIMEOUT_SECONDS = 10.0
ENV_FILE = Path(__file__).resolve().with_name(".env")
ENTITY_ID_RE = re.compile(r"^light\.[a-z0-9_]+$")
ALLOWED_LIGHT_SERVICES = frozenset({"toggle", "turn_on", "turn_off"})
DEFAULT_ALLOWED_LIGHTS = (
    "light.living_room_lights",
    "light.bedroom_lights",
)


class HomeAssistantError(RuntimeError):
    """Raised when Home Assistant returns an unusable response."""


def parse_args() -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("lights", help="List configured light entities.")

    action_parser = subparsers.add_parser("action", help="Call a light action.")
    action_parser.add_argument("service", choices=sorted(ALLOWED_LIGHT_SERVICES))
    action_parser.add_argument("entity_id")

    brightness_parser = subparsers.add_parser("set-brightness", help="Set light brightness.")
    brightness_parser.add_argument("entity_id")
    brightness_parser.add_argument("brightness_pct", type=int)

    color_temp_parser = subparsers.add_parser("set-color-temp", help="Set light color temperature.")
    color_temp_parser.add_argument("entity_id")
    color_temp_parser.add_argument("color_temp_kelvin", type=int)

    return parser.parse_args()

def get_config() -> tuple[str, str, list[str]]:
    """Return (url, token, allowed_lights) from the repo env file."""
    env = dotenv_values(ENV_FILE)
    hass_url = (env.get("HA_URL") or env.get("HASS_URL") or DEFAULT_HASS_URL).rstrip("/")
    token = env.get("HA_TOKEN") or env.get("HASS_TOKEN") or ""
    raw_allowlist = env.get("RBW_HA_LIGHTS", "")
    allowlist = [part.strip() for part in raw_allowlist.split(",") if part.strip()]
    if not allowlist:
        allowlist = list(DEFAULT_ALLOWED_LIGHTS)
    return hass_url, token, allowlist


def print_json(payload: dict[str, Any]) -> None:
    """Emit a single JSON object."""
    json.dump(payload, sys.stdout, separators=(",", ":"))
    sys.stdout.write("\n")


def request_json(
    hass_url: str,
    token: str,
    path: str,
    *,
    method: str = "GET",
    payload: dict[str, Any] | None = None,
) -> Any:
    """Call the Home Assistant REST API and decode JSON."""
    headers = {
        "Accept": "application/json",
        "Content-Type": "application/json",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"

    body: bytes | None = None
    if payload is not None:
        body = json.dumps(payload).encode("utf-8")

    request = Request(
        url=f"{hass_url}{path}",
        headers=headers,
        data=body,
        method=method,
    )

    try:
        with urlopen(request, timeout=DEFAULT_TIMEOUT_SECONDS) as response:
            raw = response.read()
    except HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace").strip()
        message = detail or f"HTTP {exc.code}"
        raise HomeAssistantError(message) from exc
    except URLError as exc:
        raise HomeAssistantError(f"Network error: {exc.reason}") from exc

    try:
        return json.loads(raw.decode("utf-8") if raw else "null")
    except json.JSONDecodeError as exc:
        raise HomeAssistantError("Home Assistant returned invalid JSON") from exc


def ensure_entity_id(entity_id: str, allowlist: list[str]) -> None:
    """Validate that the entity ID is safe and optionally allowed."""
    if not ENTITY_ID_RE.match(entity_id):
        raise HomeAssistantError(f"Invalid light entity_id: {entity_id!r}")
    if allowlist and entity_id not in allowlist:
        raise HomeAssistantError(f"Light {entity_id!r} is not in RBW_HA_LIGHTS")


def friendly_name(entity_id: str, attributes: dict[str, Any]) -> str:
    """Return the best display name for an entity."""
    name = attributes.get("friendly_name")
    if isinstance(name, str) and name.strip():
        return name.strip()
    return entity_id.split(".", 1)[1].replace("_", " ").strip().title()


def brightness_percent(value: Any) -> int | None:
    """Convert a Home Assistant brightness value to percent."""
    if value is None:
        return None
    try:
        brightness = int(value)
    except (TypeError, ValueError):
        return None
    brightness = max(0, min(255, brightness))
    return round((brightness / 255) * 100)


def normalize_kelvin(value: Any) -> int | None:
    """Normalize a kelvin state attribute."""
    if value is None:
        return None
    try:
        kelvin = int(value)
    except (TypeError, ValueError):
        return None
    if kelvin <= 0:
        return None
    return kelvin


def kelvin_from_mired(value: Any) -> int | None:
    """Convert mired color temperature to kelvin."""
    if value is None:
        return None
    try:
        mired = int(value)
    except (TypeError, ValueError):
        return None
    if mired <= 0:
        return None
    return round(1000000 / mired)


def normalize_light(state: dict[str, Any]) -> dict[str, Any]:
    """Normalize a Home Assistant light state object for QML."""
    entity_id = str(state.get("entity_id", ""))
    attributes = state.get("attributes", {})
    if not isinstance(attributes, dict):
        attributes = {}

    supported_color_modes = attributes.get("supported_color_modes", [])
    if not isinstance(supported_color_modes, list):
        supported_color_modes = []

    raw_state = str(state.get("state", "unknown"))
    brightness = brightness_percent(attributes.get("brightness"))

    color_temp_kelvin = normalize_kelvin(attributes.get("color_temp_kelvin"))
    if color_temp_kelvin is None:
        color_temp_kelvin = kelvin_from_mired(attributes.get("color_temp"))

    min_color_temp_kelvin = normalize_kelvin(attributes.get("min_color_temp_kelvin"))
    if min_color_temp_kelvin is None:
        min_color_temp_kelvin = kelvin_from_mired(attributes.get("max_mireds"))

    max_color_temp_kelvin = normalize_kelvin(attributes.get("max_color_temp_kelvin"))
    if max_color_temp_kelvin is None:
        max_color_temp_kelvin = kelvin_from_mired(attributes.get("min_mireds"))

    supports_color_temp = (
        "color_temp" in supported_color_modes
        or color_temp_kelvin is not None
        or (min_color_temp_kelvin is not None and max_color_temp_kelvin is not None)
    )

    return {
        "entityId": entity_id,
        "name": friendly_name(entity_id, attributes),
        "state": raw_state,
        "available": raw_state != "unavailable",
        "isOn": raw_state == "on",
        "brightnessPercent": brightness,
        "colorMode": attributes.get("color_mode"),
        "supportedColorModes": supported_color_modes,
        "supportsColorTemp": supports_color_temp,
        "colorTempKelvin": color_temp_kelvin,
        "minColorTempKelvin": min_color_temp_kelvin,
        "maxColorTempKelvin": max_color_temp_kelvin,
    }


def sort_lights(lights: list[dict[str, Any]], allowlist: list[str]) -> list[dict[str, Any]]:
    """Sort lights by allowlist order or by friendly name."""
    if allowlist:
        order = {entity_id: index for index, entity_id in enumerate(allowlist)}
        return sorted(
            lights,
            key=lambda light: (
                order.get(str(light.get("entityId", "")), len(order)),
                str(light.get("name", "")).lower(),
            ),
        )

    return sorted(
        lights,
        key=lambda light: (
            str(light.get("name", "")).lower(),
            str(light.get("entityId", "")).lower(),
        ),
    )


def list_lights(hass_url: str, token: str, allowlist: list[str]) -> dict[str, Any]:
    """Fetch Home Assistant light state and return a compact summary."""
    if not token:
        return {
            "configured": False,
            "available": False,
            "error": "Missing HA_TOKEN",
            "lights": [],
            "lightCount": 0,
            "activeLightCount": 0,
        }

    states = request_json(hass_url, token, "/api/states")
    if not isinstance(states, list):
        raise HomeAssistantError("Unexpected /api/states payload")

    lights: list[dict[str, Any]] = []
    allowset = set(allowlist)
    for state in states:
        if not isinstance(state, dict):
            continue

        entity_id = str(state.get("entity_id", ""))
        if not entity_id.startswith("light."):
            continue
        if allowlist and entity_id not in allowset:
            continue

        lights.append(normalize_light(state))

    lights = sort_lights(lights, allowlist)
    active_count = sum(1 for light in lights if light.get("isOn"))
    return {
        "configured": True,
        "available": True,
        "error": "",
        "lights": lights,
        "lightCount": len(lights),
        "activeLightCount": active_count,
    }


def call_light_service(
    hass_url: str,
    token: str,
    allowlist: list[str],
    *,
    service: str,
    entity_id: str,
    brightness_pct: int | None = None,
    color_temp_kelvin: int | None = None,
) -> dict[str, Any]:
    """Call a safe light-domain service."""
    if not token:
        raise HomeAssistantError("Missing HA_TOKEN")
    ensure_entity_id(entity_id, allowlist)

    payload: dict[str, Any] = {"entity_id": entity_id}
    if brightness_pct is not None:
        payload["brightness_pct"] = max(0, min(100, brightness_pct))
        service = "turn_on"
    if color_temp_kelvin is not None:
        payload["color_temp_kelvin"] = max(1000, min(20000, color_temp_kelvin))
        service = "turn_on"

    request_json(
        hass_url,
        token,
        f"/api/services/light/{service}",
        method="POST",
        payload=payload,
    )

    return {
        "success": True,
        "service": service,
        "entityId": entity_id,
        "brightnessPercent": brightness_pct,
        "colorTempKelvin": color_temp_kelvin,
    }


def main() -> int:
    """Run the CLI."""
    args = parse_args()
    hass_url, token, allowlist = get_config()

    try:
        if args.command == "lights":
            print_json(list_lights(hass_url, token, allowlist))
            return 0

        if args.command == "action":
            print_json(
                call_light_service(
                    hass_url,
                    token,
                    allowlist,
                    service=args.service,
                    entity_id=args.entity_id,
                )
            )
            return 0

        if args.command == "set-brightness":
            print_json(
                call_light_service(
                    hass_url,
                    token,
                    allowlist,
                    service="turn_on",
                    entity_id=args.entity_id,
                    brightness_pct=args.brightness_pct,
                )
            )
            return 0

        if args.command == "set-color-temp":
            print_json(
                call_light_service(
                    hass_url,
                    token,
                    allowlist,
                    service="turn_on",
                    entity_id=args.entity_id,
                    color_temp_kelvin=args.color_temp_kelvin,
                )
            )
            return 0
    except HomeAssistantError as exc:
        configured = bool(token)
        print_json(
            {
                "configured": configured,
                "available": False,
                "success": False,
                "error": str(exc),
            }
        )
        return 1

    print_json({"success": False, "error": f"Unsupported command: {args.command}"})
    return 1


if __name__ == "__main__":
    raise SystemExit(main())

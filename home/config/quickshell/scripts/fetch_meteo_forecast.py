#!/usr/bin/env python3
"""Fetch the latest meteo.pl UM 4 km 60 h forecast and cache by run timestamp."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


DEFAULT_NAME = "Gdansk, Poland"
DEFAULT_LAT = "54.35"
DEFAULT_LON = "18.65"
MODEL_ID = "um4_60"
MODEL_LABEL = "UM 4km 60h"
AVAILABLE_RUNS_URL = "https://devmgramapi.meteo.pl/meteorograms/available"
FORECAST_URL = f"https://devmgramapi.meteo.pl/meteorograms/{MODEL_ID}"
USER_AGENT = "rbw-quickshell-weather/1.0"
DEFAULT_TIMEOUT_SECONDS = 15.0
MISSING_VALUE_SENTINEL = -327000000.0
DEFAULT_CACHE_DIR = Path.home() / ".cache" / "rbw-quickshell-weather"


class MeteoApiError(RuntimeError):
    """Raised when the meteo.pl API returns invalid or unusable data."""


@dataclass(frozen=True, slots=True)
class ForecastSeries:
    """A single hourly forecast series returned by the API."""

    name: str
    values: tuple[float | None, ...]
    first_timestamp: int
    interval_seconds: int
    unit: str
    point: dict[str, Any] | None


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description=(
            "Fetch the latest forecast from the meteo.pl UM 4 km 60 h model "
            "and print normalized JSON."
        )
    )
    parser.add_argument("--lat", default=DEFAULT_LAT, help="Latitude to query.")
    parser.add_argument("--lon", default=DEFAULT_LON, help="Longitude to query.")
    parser.add_argument(
        "--name",
        default=DEFAULT_NAME,
        help="Human-readable location name to include in the output.",
    )
    parser.add_argument(
        "--cache-dir",
        default=str(DEFAULT_CACHE_DIR),
        help="Directory where normalized forecast JSON is cached.",
    )
    parser.add_argument(
        "--pretty",
        action="store_true",
        help="Pretty-print the JSON output.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=DEFAULT_TIMEOUT_SECONDS,
        help="HTTP timeout in seconds.",
    )
    return parser.parse_args()


def fetch_json(
    url: str,
    *,
    timeout_seconds: float,
    payload: dict[str, Any] | None = None,
) -> Any:
    """Fetch and decode a JSON response."""
    headers = {
        "Accept": "application/json",
        "User-Agent": USER_AGENT,
    }
    request_body: bytes | None = None
    method = "GET"
    if payload is not None:
        request_body = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
        method = "POST"

    request = Request(url=url, data=request_body, headers=headers, method=method)
    try:
        with urlopen(request, timeout=timeout_seconds) as response:
            return json.load(response)
    except HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise MeteoApiError(f"HTTP {exc.code} while requesting {url}: {detail}") from exc
    except URLError as exc:
        raise MeteoApiError(f"Network error while requesting {url}: {exc.reason}") from exc
    except json.JSONDecodeError as exc:
        raise MeteoApiError(f"Invalid JSON returned by {url}") from exc


def unix_to_iso(timestamp: int) -> str:
    """Convert a Unix timestamp to an ISO 8601 UTC string."""
    return datetime.fromtimestamp(timestamp, UTC).isoformat().replace("+00:00", "Z")


def normalize_numeric_value(value: Any) -> float | None:
    """Convert API numeric values and map fill values to null."""
    numeric_value = float(value)
    if numeric_value <= MISSING_VALUE_SENTINEL:
        return None
    return numeric_value


def load_available_runs(timeout_seconds: float) -> tuple[int, ...]:
    """Load and sort available run timestamps for the configured model."""
    payload = fetch_json(AVAILABLE_RUNS_URL, timeout_seconds=timeout_seconds)
    runs = payload.get(MODEL_ID)
    if not isinstance(runs, list) or not runs:
        raise MeteoApiError(f"No runs returned for model {MODEL_ID}")
    return tuple(sorted({int(run) for run in runs}, reverse=True))


def extract_series(raw_payload: dict[str, Any]) -> tuple[ForecastSeries, ...]:
    """Validate and normalize series metadata from the API payload."""
    raw_data = raw_payload.get("data")
    if not isinstance(raw_data, dict) or not raw_data:
        raise MeteoApiError("Forecast payload does not contain any series")

    series_list: list[ForecastSeries] = []
    for name, raw_series in raw_data.items():
        if not isinstance(raw_series, dict):
            raise MeteoApiError(f"Series {name} is malformed")

        values_raw = raw_series.get("data")
        if not isinstance(values_raw, list) or not values_raw:
            raise MeteoApiError(f"Series {name} has no values")

        point_raw = raw_series.get("point")
        point = dict(point_raw) if isinstance(point_raw, dict) else None

        try:
            values = tuple(normalize_numeric_value(value) for value in values_raw)
            first_timestamp = int(raw_series["first_timestamp"])
            interval_seconds = int(raw_series["interval"])
        except (KeyError, TypeError, ValueError) as exc:
            raise MeteoApiError(f"Series {name} has invalid metadata") from exc

        series_list.append(
            ForecastSeries(
                name=name,
                values=values,
                first_timestamp=first_timestamp,
                interval_seconds=interval_seconds,
                unit=str(raw_series.get("unit", "")),
                point=point,
            )
        )

    return tuple(series_list)


def validate_series(series_list: tuple[ForecastSeries, ...]) -> None:
    """Ensure the hourly series align so they can be merged by timestamp."""
    reference = series_list[0]
    reference_length = len(reference.values)
    for series in series_list[1:]:
        if len(series.values) != reference_length:
            raise MeteoApiError("Forecast series lengths do not match")
        if series.first_timestamp != reference.first_timestamp:
            raise MeteoApiError("Forecast series start timestamps do not match")
        if series.interval_seconds != reference.interval_seconds:
            raise MeteoApiError("Forecast series intervals do not match")


def build_hourly_rows(series_list: tuple[ForecastSeries, ...]) -> list[dict[str, Any]]:
    """Merge all forecast series into hourly objects."""
    validate_series(series_list)
    reference = series_list[0]

    hourly_rows: list[dict[str, Any]] = []
    for index in range(len(reference.values)):
        timestamp = reference.first_timestamp + (index * reference.interval_seconds)
        row: dict[str, Any] = {
            "timestamp": timestamp,
            "timestamp_iso": unix_to_iso(timestamp),
        }
        for series in series_list:
            row[series.name] = series.values[index]
        hourly_rows.append(row)
    return hourly_rows


def fetch_latest_forecast(
    *,
    lat: str,
    lon: str,
    timeout_seconds: float,
    run_candidates: tuple[int, ...],
) -> tuple[int, dict[str, Any]]:
    """Fetch the newest usable forecast run for the configured model."""
    last_error: MeteoApiError | None = None
    for run_timestamp in run_candidates:
        try:
            payload = {
                "date": run_timestamp,
                "point": {
                    "lat": lat,
                    "lon": lon,
                },
            }
            forecast = fetch_json(
                FORECAST_URL,
                timeout_seconds=timeout_seconds,
                payload=payload,
            )
            if not isinstance(forecast, dict):
                raise MeteoApiError("Forecast response is not a JSON object")
            return run_timestamp, forecast
        except MeteoApiError as exc:
            last_error = exc

    if last_error is not None:
        raise last_error
    raise MeteoApiError("No usable forecast runs were returned")


def normalize_forecast(
    *,
    location_name: str,
    lat: str,
    lon: str,
    run_timestamp: int,
    raw_forecast: dict[str, Any],
) -> dict[str, Any]:
    """Build the JSON document emitted by the CLI."""
    series_list = extract_series(raw_forecast)
    hourly_rows = build_hourly_rows(series_list)
    reference = series_list[0]

    return {
        "available": True,
        "location": {
            "name": location_name,
            "lat": float(lat),
            "lon": float(lon),
        },
        "model": {
            "id": MODEL_ID,
            "label": MODEL_LABEL,
        },
        "run_timestamp": run_timestamp,
        "run_timestamp_iso": unix_to_iso(run_timestamp),
        "forecast_start": raw_forecast.get("fstart"),
        "series_start_timestamp": reference.first_timestamp,
        "series_start_timestamp_iso": unix_to_iso(reference.first_timestamp),
        "interval_seconds": reference.interval_seconds,
        "grid_point": reference.point,
        "units": {series.name: series.unit for series in series_list},
        "hourly": hourly_rows,
    }


def build_cache_path(cache_dir: Path, *, lat: str, lon: str) -> Path:
    """Return the cache path for the given forecast point."""
    safe_id = re.sub(r"[^a-zA-Z0-9._-]+", "_", f"{MODEL_ID}-{lat}-{lon}")
    return cache_dir / f"{safe_id}.json"


def load_cached_forecast(cache_path: Path) -> dict[str, Any] | None:
    """Load a cached normalized forecast if it exists and parses."""
    if not cache_path.exists():
        return None

    try:
        with cache_path.open("r", encoding="utf-8") as handle:
            payload = json.load(handle)
    except (OSError, json.JSONDecodeError):
        return None

    if not isinstance(payload, dict):
        return None
    return payload


def write_cached_forecast(cache_path: Path, payload: dict[str, Any]) -> None:
    """Persist a normalized forecast to disk."""
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    with cache_path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle)
        handle.write("\n")


def emit_json(payload: dict[str, Any], *, pretty: bool) -> None:
    """Write JSON to stdout."""
    json.dump(payload, sys.stdout, indent=2 if pretty else None)
    sys.stdout.write("\n")


def refresh_cached_metadata(
    payload: dict[str, Any],
    *,
    name: str,
    lat: str,
    lon: str,
    stale: bool,
) -> dict[str, Any]:
    """Return a cached payload with runtime metadata refreshed."""
    refreshed = dict(payload)
    location = dict(refreshed.get("location", {}))
    location["name"] = name
    location["lat"] = float(lat)
    location["lon"] = float(lon)
    refreshed["location"] = location
    refreshed["stale"] = stale
    return refreshed


def main() -> int:
    """Run the CLI."""
    args = parse_args()
    cache_path = build_cache_path(
        Path(args.cache_dir),
        lat=args.lat,
        lon=args.lon,
    )
    cached = load_cached_forecast(cache_path)

    try:
        available_runs = load_available_runs(args.timeout)
        latest_run = available_runs[0]
        if cached is not None and int(cached.get("run_timestamp", -1)) == latest_run:
            emit_json(
                refresh_cached_metadata(
                    cached,
                    name=args.name,
                    lat=args.lat,
                    lon=args.lon,
                    stale=False,
                ),
                pretty=args.pretty,
            )
            return 0

        run_timestamp, raw_forecast = fetch_latest_forecast(
            lat=args.lat,
            lon=args.lon,
            timeout_seconds=args.timeout,
            run_candidates=available_runs,
        )
        normalized = normalize_forecast(
            location_name=args.name,
            lat=args.lat,
            lon=args.lon,
            run_timestamp=run_timestamp,
            raw_forecast=raw_forecast,
        )
        write_cached_forecast(cache_path, normalized)
        emit_json(normalized, pretty=args.pretty)
        return 0
    except MeteoApiError as exc:
        if cached is not None:
            emit_json(
                refresh_cached_metadata(
                    cached,
                    name=args.name,
                    lat=args.lat,
                    lon=args.lon,
                    stale=True,
                ),
                pretty=args.pretty,
            )
            return 0
        print(str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

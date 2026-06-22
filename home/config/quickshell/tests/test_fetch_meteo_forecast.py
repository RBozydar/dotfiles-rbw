from __future__ import annotations

import json
from pathlib import Path

import pytest
from scripts import fetch_meteo_forecast as meteo


def _series(
    values: list[float],
    *,
    unit: str,
    first_timestamp: int = 1_776_063_600,
    interval: int = 3_600,
) -> dict[str, object]:
    return {
        "data": values,
        "first_timestamp": str(first_timestamp),
        "interval": interval,
        "unit": unit,
        "point": {
            "lat": 54.35,
            "lon": 18.65,
            "model": "um4",
            "grid": "P5",
            "row": 270,
            "col": 212,
        },
    }


def _raw_payload() -> dict[str, object]:
    return {
        "fstart": "2026-04-13T06:00:00Z",
        "data": {
            "airtmp_point": _series([6.35, 8.475, 10.475], unit="Celsius"),
            "airtmp_max": _series([7.6, 9.725, 11.1], unit="Celsius"),
            "airtmp_min": _series([4.6, 4.725, 4.85], unit="Celsius"),
            "realhum_aver": _series([70.763, 65.663, 56.043], unit="%"),
            "slpres_point": _series([102471.281, 102438.695, 102440.672], unit="Pa"),
        },
    }


def test_normalize_numeric_value_maps_missing_sentinel_to_none() -> None:
    assert meteo.normalize_numeric_value("-327276480") is None
    assert meteo.normalize_numeric_value("1.5") == 1.5


def test_extract_series_normalizes_metadata() -> None:
    series_list = meteo.extract_series(_raw_payload())

    assert len(series_list) == 5
    assert series_list[0].name == "airtmp_point"
    assert series_list[0].unit == "Celsius"
    assert series_list[0].first_timestamp == 1_776_063_600
    assert series_list[0].interval_seconds == 3_600


def test_build_hourly_rows_merges_aligned_series() -> None:
    rows = meteo.build_hourly_rows(meteo.extract_series(_raw_payload()))

    assert len(rows) == 3
    assert rows[0]["timestamp"] == 1_776_063_600
    assert rows[1]["timestamp_iso"] == "2026-04-13T08:00:00Z"
    assert rows[2]["airtmp_point"] == 10.475
    assert rows[2]["slpres_point"] == 102440.672


def test_validate_series_rejects_mismatched_lengths() -> None:
    good = meteo.ForecastSeries(
        name="airtmp_point",
        values=(1.0, 2.0),
        first_timestamp=10,
        interval_seconds=3_600,
        unit="Celsius",
        point=None,
    )
    bad = meteo.ForecastSeries(
        name="airtmp_max",
        values=(1.0,),
        first_timestamp=10,
        interval_seconds=3_600,
        unit="Celsius",
        point=None,
    )

    with pytest.raises(meteo.MeteoApiError, match="lengths do not match"):
        meteo.validate_series((good, bad))


def test_normalize_forecast_builds_expected_metadata() -> None:
    payload = meteo.normalize_forecast(
        location_name="Gdansk, Poland",
        lat="54.35",
        lon="18.65",
        run_timestamp=1_776_060_000,
        raw_forecast=_raw_payload(),
    )

    assert payload["location"] == {
        "name": "Gdansk, Poland",
        "lat": 54.35,
        "lon": 18.65,
    }
    assert payload["run_timestamp_iso"] == "2026-04-13T06:00:00Z"
    assert payload["interval_seconds"] == 3_600
    assert len(payload["hourly"]) == 3


def test_cache_roundtrip_and_refresh_metadata(tmp_path: Path) -> None:
    cache_path = meteo.build_cache_path(tmp_path, lat="54.35", lon="18.65")
    payload = meteo.normalize_forecast(
        location_name="Gdansk, Poland",
        lat="54.35",
        lon="18.65",
        run_timestamp=1_776_060_000,
        raw_forecast=_raw_payload(),
    )

    meteo.write_cached_forecast(cache_path, payload)
    loaded = meteo.load_cached_forecast(cache_path)

    assert loaded is not None
    refreshed = meteo.refresh_cached_metadata(
        loaded,
        name="Sopot, Poland",
        lat="54.44",
        lon="18.56",
        stale=True,
    )
    assert refreshed["stale"] is True
    assert refreshed["location"] == {
        "name": "Sopot, Poland",
        "lat": 54.44,
        "lon": 18.56,
    }


def test_load_cached_forecast_returns_none_for_invalid_json(tmp_path: Path) -> None:
    cache_path = tmp_path / "broken.json"
    cache_path.write_text("{not-json}\n", encoding="utf-8")

    assert meteo.load_cached_forecast(cache_path) is None


def test_emit_json_writes_trailing_newline(capsys: pytest.CaptureFixture[str]) -> None:
    meteo.emit_json({"ok": True}, pretty=False)

    captured = capsys.readouterr()
    assert captured.out == json.dumps({"ok": True}) + "\n"

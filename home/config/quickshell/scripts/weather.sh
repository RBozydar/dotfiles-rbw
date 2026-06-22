#!/bin/sh

set -eu

lat="${1:-54.35}"
lon="${2:-18.65}"
name="${3:-Gdansk, Poland}"

if ! command -v python3 >/dev/null 2>&1; then
	printf '{"available":false,"location":{"name":"%s","lat":%s,"lon":%s},"model":{"id":"um4_60","label":"UM 4km 60h"},"hourly":[]}\n' "$name" "$lat" "$lon"
	exit 0
fi

if ! python3 "$(dirname "$0")/fetch_meteo_forecast.py" --lat "$lat" --lon "$lon" --name "$name" 2>/dev/null; then
	printf '{"available":false,"location":{"name":"%s","lat":%s,"lon":%s},"model":{"id":"um4_60","label":"UM 4km 60h"},"hourly":[]}\n' "$name" "$lat" "$lon"
fi

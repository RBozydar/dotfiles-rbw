#!/bin/sh

set -eu

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

location="${1:-}"

if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    printf '{"available":false,"city":"","condition":"Weather unavailable","code":"","temperature":"--°","feelsLike":"--°","humidity":"--%%","wind":"--"}\n'
    exit 0
fi

url="https://wttr.in"
if [ -n "$location" ]; then
    url="$url/$location"
fi
url="$url?format=j1"

payload=$(curl -fsL --max-time 8 "$url" 2>/dev/null || true)

if [ -z "$payload" ]; then
    printf '{"available":false,"city":"","condition":"Weather unavailable","code":"","temperature":"--°","feelsLike":"--°","humidity":"--%%","wind":"--"}\n'
    exit 0
fi

city=$(printf '%s' "$payload" | jq -r '.nearest_area[0].areaName[0].value // ""' 2>/dev/null || printf '')
condition=$(printf '%s' "$payload" | jq -r '.current_condition[0].weatherDesc[0].value // "Unknown"' 2>/dev/null || printf 'Unknown')
code=$(printf '%s' "$payload" | jq -r '.current_condition[0].weatherCode // ""' 2>/dev/null || printf '')
temp=$(printf '%s' "$payload" | jq -r '.current_condition[0].temp_C // empty' 2>/dev/null || printf '')
feels_like=$(printf '%s' "$payload" | jq -r '.current_condition[0].FeelsLikeC // empty' 2>/dev/null || printf '')
humidity=$(printf '%s' "$payload" | jq -r '.current_condition[0].humidity // empty' 2>/dev/null || printf '')
wind=$(printf '%s' "$payload" | jq -r '.current_condition[0].windspeedKmph // empty' 2>/dev/null || printf '')

printf '{"available":true,"city":"%s","condition":"%s","code":"%s","temperature":"%s","feelsLike":"%s","humidity":"%s","wind":"%s"}\n' \
    "$(json_escape "$city")" \
    "$(json_escape "$condition")" \
    "$(json_escape "$code")" \
    "$(json_escape "${temp:-"--"}°")" \
    "$(json_escape "${feels_like:-"--"}°")" \
    "$(json_escape "${humidity:-"--"}%")" \
    "$(json_escape "${wind:-"--"} km/h")"

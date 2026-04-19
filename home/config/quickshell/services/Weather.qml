pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string locationSpec: Quickshell.env("RBW_WEATHER_LOCATION") || ""
    readonly property var locationParts: locationSpec.length > 0 ? locationSpec.split("|") : []
    readonly property string locationName: locationParts.length > 0 && locationParts[0].length > 0 ? locationParts[0] : (Quickshell.env("RBW_WEATHER_NAME") || "Gdansk, Poland")
    readonly property string latitude: locationParts.length > 1 && locationParts[1].length > 0 ? locationParts[1] : (Quickshell.env("RBW_WEATHER_LAT") || "54.35")
    readonly property string longitude: locationParts.length > 2 && locationParts[2].length > 0 ? locationParts[2] : (Quickshell.env("RBW_WEATHER_LON") || "18.65")

    property bool available: false
    property string city: ""
    property string condition: "Weather unavailable"
    property string temperature: "--°"
    property string feelsLike: "--°"
    property string humidity: "--%"
    property string wind: "--"
    property string pressure: "--"
    property string modelLabel: ""
    property string runLabel: ""
    property bool stale: false
    property double nowMs: Date.now()
    property int previewLookbackHours: 3
    property int previewLookaheadHours: 48
    property var hourly: []

    readonly property int currentHourIndex: root.findCurrentHourIndex(root.hourly, root.nowMs)
    readonly property int previewStartIndex: root.previewStartFor(root.hourly, root.nowMs, root.previewLookbackHours)
    readonly property int previewCurrentIndex: root.currentHourIndex >= 0 ? Math.max(0, root.currentHourIndex - root.previewStartIndex) : -1
    readonly property var currentHour: root.currentHourIndex >= 0 ? root.hourly[root.currentHourIndex] : null
    readonly property var hourlyPreview: root.slicePreviewHours(root.hourly, root.nowMs, root.previewLookbackHours, root.previewLookaheadHours)
    readonly property var summaryHours: root.currentHourIndex >= 0 ? root.hourly.slice(root.currentHourIndex, Math.min(root.hourly.length, root.currentHourIndex + 6)) : root.hourlyPreview.slice(0, 6)
    readonly property string summaryKind: root.classifyForecast(root.summaryHours)
    readonly property string currentKind: root.currentHour?.kind ?? root.summaryKind
    readonly property string icon: root.iconForKind(root.currentKind, root.currentHour?.night ?? false)

    function iconForKind(kind, night): string {
        switch (kind) {
        case "sunny":
            return night ? "☾" : "☀";
        case "partly-cloudy":
            return night ? "☁" : "⛅";
        case "cloudy":
            return "☁";
        case "rain":
            return "☂";
        case "snow":
            return "❄";
        case "storm":
            return "⚡";
        case "fog":
            return "〰";
        default:
            return "☁";
        }
    }

    function labelForKind(kind): string {
        switch (kind) {
        case "sunny":
            return "Clear skies";
        case "partly-cloudy":
            return "Partly cloudy";
        case "cloudy":
            return "Cloudy";
        case "rain":
            return "Rain showers";
        case "snow":
            return "Snow";
        case "storm":
            return "Storm risk";
        case "fog":
            return "Fog";
        default:
            return "Forecast unavailable";
        }
    }

    function numberOrNull(value): real {
        return value === null || value === undefined || Number.isNaN(value) ? NaN : Number(value);
    }

    function rounded(value, digits): real {
        const factor = Math.pow(10, digits);
        return Math.round(value * factor) / factor;
    }

    function percentValue(value): real {
        const numeric = root.numberOrNull(value);
        if (Number.isNaN(numeric))
            return 0;

        return numeric <= 1.01 ? numeric * 100 : numeric;
    }

    function formatTemperature(value): string {
        const numeric = root.numberOrNull(value);
        return Number.isNaN(numeric) ? "--°" : `${Math.round(numeric)}°`;
    }

    function formatHumidity(value): string {
        const numeric = root.numberOrNull(value);
        return Number.isNaN(numeric) ? "--%" : `${Math.round(root.percentValue(numeric))}%`;
    }

    function formatWind(value): string {
        const numeric = root.numberOrNull(value);
        return Number.isNaN(numeric) ? "--" : `${Math.round(numeric * 3.6)} km/h`;
    }

    function formatPressure(value): string {
        const numeric = root.numberOrNull(value);
        return Number.isNaN(numeric) ? "--" : `${Math.round(numeric / 100)} hPa`;
    }

    function formatRunLabel(value): string {
        if (!value)
            return "";

        const date = new Date(value);
        return `run ${Qt.formatDateTime(date, "yyyy-MM-dd hh:mm")}`;
    }

    function findCurrentHourIndex(hours, nowMs): int {
        const source = Array.isArray(hours) ? hours : [];
        if (source.length === 0)
            return -1;

        const nowTimestamp = Number(nowMs);
        if (!Number.isFinite(nowTimestamp))
            return 0;

        let bestIndex = 0;
        let bestDistance = Number.POSITIVE_INFINITY;

        for (let index = 0; index < source.length; index += 1) {
            const hour = source[index];
            const timestampMs = Number(hour?.timestamp ?? 0) * 1000;
            if (!Number.isFinite(timestampMs))
                continue;

            const distance = Math.abs(timestampMs - nowTimestamp);
            if (distance < bestDistance) {
                bestDistance = distance;
                bestIndex = index;
            }
        }

        return bestIndex;
    }

    function resolveCurrentHour(hours, nowMs): var {
        const index = root.findCurrentHourIndex(hours, nowMs);
        const source = Array.isArray(hours) ? hours : [];
        return index >= 0 && index < source.length ? source[index] : null;
    }

    function previewStartFor(hours, nowMs, lookbackHours): int {
        const source = Array.isArray(hours) ? hours : [];
        if (source.length === 0)
            return 0;

        const currentIndex = root.findCurrentHourIndex(source, nowMs);
        if (currentIndex < 0)
            return 0;

        const backward = Math.max(0, Math.round(Number(lookbackHours)));
        return Math.max(0, currentIndex - backward);
    }

    function slicePreviewHours(hours, nowMs, lookbackHours, lookaheadHours): var {
        const source = Array.isArray(hours) ? hours : [];
        if (source.length === 0)
            return [];

        const currentIndex = root.findCurrentHourIndex(source, nowMs);
        if (currentIndex < 0)
            return source.slice(0, Math.min(source.length, Math.max(1, Number(lookaheadHours) + 1)));

        const forward = Math.max(0, Math.round(Number(lookaheadHours)));
        const startIndex = root.previewStartFor(source, nowMs, lookbackHours);
        const endExclusive = Math.min(source.length, currentIndex + forward + 1);
        return source.slice(startIndex, endExclusive);
    }

    function classifyHour(row): string {
        const storm = root.percentValue(row.storm_max ?? 0);
        const fog = root.percentValue(row.fog_max ?? 0);
        const precipAmount = root.numberOrNull(row.pcpttl_max ?? row.pcpttl_aver ?? 0);
        const precipProb = root.percentValue(row.pcpttlprob_point ?? 0);
        const cloudCover = root.percentValue(row.cldtot_aver ?? 0);
        const temperature = root.numberOrNull(row.airtmp_point);

        if (storm >= 20)
            return "storm";
        if (fog >= 45)
            return "fog";
        if ((!Number.isNaN(precipAmount) && precipAmount >= 0.25) || precipProb >= 45) {
            if (!Number.isNaN(temperature) && temperature <= 0.5)
                return "snow";
            return "rain";
        }
        if (cloudCover >= 75)
            return "cloudy";
        if (cloudCover >= 35)
            return "partly-cloudy";
        return "sunny";
    }

    function classifyForecast(rows): string {
        const scores = {
            sunny: 0,
            "partly-cloudy": 0,
            cloudy: 0,
            rain: 0,
            snow: 0,
            storm: 0,
            fog: 0
        };

        for (let index = 0; index < rows.length; index += 1) {
            const row = rows[index];
            if (!row)
                continue;

            const weight = Math.max(1, rows.length - index);
            scores[row.kind] += weight;
        }

        let bestKind = "cloudy";
        let bestScore = -1;
        for (const [kind, score] of Object.entries(scores)) {
            if (score > bestScore) {
                bestKind = kind;
                bestScore = score;
            }
        }

        return bestKind;
    }

    function buildHour(row, index): var {
        const timestamp = Number(row.timestamp ?? 0) * 1000;
        const date = new Date(timestamp);
        const windSpeed = root.numberOrNull(row.wind10_sd_true_prev_point);
        const kind = root.classifyHour(row);
        const temp = root.numberOrNull(row.airtmp_point);
        const tempMin = root.numberOrNull(row.airtmp_min);
        const tempMax = root.numberOrNull(row.airtmp_max);
        const dewPoint = root.numberOrNull(row.dwptmp_point);
        const feelsLike = root.numberOrNull(row.wchill_point);
        const pressurePa = root.numberOrNull(row.slpres_point);
        const visibilityMeters = root.numberOrNull(row.visibl_min);
        const cloudTopMeters = root.numberOrNull(row.cldtop);
        const cloudBasesMeters = [root.numberOrNull(row.cldbse01), root.numberOrNull(row.cldbse25), root.numberOrNull(row.cldbse45), root.numberOrNull(row.cldbse65), root.numberOrNull(row.cldbse79)];
        let cloudBaseMeters = NaN;
        for (let index = 0; index < cloudBasesMeters.length; index += 1) {
            const candidate = cloudBasesMeters[index];
            if (Number.isNaN(candidate))
                continue;

            if (Number.isNaN(cloudBaseMeters) || candidate < cloudBaseMeters)
                cloudBaseMeters = candidate;
        }

        return {
            timestamp: row.timestamp ?? 0,
            hourLabel: Qt.formatDateTime(date, "hh"),
            dayLabel: Qt.formatDateTime(date, "dd.MM"),
            dayMarker: index === 0 || date.getHours() === 0,
            night: date.getHours() < 6 || date.getHours() >= 21,
            icon: root.iconForKind(kind, date.getHours() < 6 || date.getHours() >= 21),
            kind: kind,
            label: root.labelForKind(kind),
            temp: Number.isNaN(temp) ? null : root.rounded(temp, 1),
            tempMin: Number.isNaN(tempMin) ? null : root.rounded(tempMin, 1),
            tempMax: Number.isNaN(tempMax) ? null : root.rounded(tempMax, 1),
            feelsLike: Number.isNaN(feelsLike) ? null : root.rounded(feelsLike, 1),
            dewPoint: Number.isNaN(dewPoint) ? null : root.rounded(dewPoint, 1),
            humidity: root.percentValue(row.realhum_aver ?? 0),
            pressureHpa: Number.isNaN(pressurePa) ? null : root.rounded(pressurePa / 100, 1),
            precipAmount: root.numberOrNull(row.pcpttl_max ?? row.pcpttl_aver ?? 0),
            precipProbability: root.percentValue(row.pcpttlprob_point ?? 0),
            cloudCover: root.percentValue(row.cldtot_aver ?? 0),
            cloudVeryLow: root.percentValue(row.cldvlow_aver ?? 0),
            cloudLow: root.percentValue(row.cldlow_aver ?? 0),
            cloudMid: root.percentValue(row.cldmed_aver ?? 0),
            cloudHigh: root.percentValue(row.cldhigh_aver ?? 0),
            cloudBaseKm: Number.isNaN(cloudBaseMeters) ? null : root.rounded(cloudBaseMeters / 1000, 1),
            cloudTopKm: Number.isNaN(cloudTopMeters) ? null : root.rounded(cloudTopMeters / 1000, 1),
            visibilityKm: Number.isNaN(visibilityMeters) ? null : root.rounded(visibilityMeters / 1000, 1),
            fogRisk: root.percentValue(row.fog_max ?? 0),
            stormRisk: root.percentValue(row.storm_max ?? 0),
            windSpeedKmh: Number.isNaN(windSpeed) ? 0 : root.rounded(windSpeed * 3.6, 1),
            windGustKmh: root.rounded((root.numberOrNull(row.wind_gust_max) || 0) * 3.6, 1),
            windDirection: root.numberOrNull(row.wind10_dr_deg_true_prev_point) || 0
        };
    }

    function refresh(): void {
        if (!fetcher.running)
            fetcher.running = true;
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 21600000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.nowMs = Date.now()
    }

    Process {
        id: fetcher

        command: [
            "sh",
            Quickshell.shellPath("scripts/weather.sh"),
            root.latitude,
            root.longitude,
            root.locationName
        ]
        workingDirectory: Quickshell.shellDir

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (!line)
                    return;

                try {
                    const payload = JSON.parse(line);
                    const rawHourly = Array.isArray(payload.hourly) ? payload.hourly : [];
                    const builtHours = rawHourly.map((hour, index) => root.buildHour(hour, index));
                    root.nowMs = Date.now();
                    const current = root.resolveCurrentHour(builtHours, root.nowMs);

                    root.available = (payload.available ?? builtHours.length > 0) && builtHours.length > 0;
                    root.stale = payload.stale ?? false;
                    root.city = payload.location?.name ?? root.locationName;
                    root.modelLabel = payload.model?.label ?? "";
                    root.runLabel = root.formatRunLabel(payload.run_timestamp_iso ?? payload.forecast_start ?? "");
                    root.hourly = builtHours;
                    root.condition = current ? current.label : "Weather unavailable";
                    root.temperature = current ? root.formatTemperature(current.temp) : "--°";
                    root.feelsLike = current ? root.formatTemperature(current.feelsLike) : "--°";
                    root.humidity = current ? root.formatHumidity(current.humidity) : "--%";
                    root.wind = current ? `${Math.round(current.windSpeedKmh)} km/h` : "--";
                    root.pressure = current ? `${Math.round(current.pressureHpa)} hPa` : "--";
                } catch (error) {
                    console.log(`weather parse error: ${error}`);
                }
            }
        }
    }
}

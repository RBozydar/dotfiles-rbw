import QtQuick
import qs

Item {
    id: root

    property var hours: []
    property int hoveredIndex: -1

    readonly property var samples: hours ?? []
    readonly property var hoveredSample: root.sampleAt(root.hoveredIndex)
    readonly property int sampleCount: samples.length
    readonly property int leftInset: 42
    readonly property int rightInset: 42
    readonly property int chartWidth: Math.max(1, width - leftInset - rightInset)
    readonly property int tempTop: 68
    readonly property int tempHeight: 292
    readonly property int precipTop: 396
    readonly property int precipHeight: 138
    readonly property int pressureTop: 570
    readonly property int pressureHeight: 118
    readonly property int windTop: 724
    readonly property int windHeight: 112
    readonly property int cloudTop: 872
    readonly property int cloudHeight: 150
    readonly property real minTempValue: root.extremeAcross(["tempMin", "temp", "dewPoint"], false, 0) - 2
    readonly property real maxTempValue: root.extremeAcross(["tempMax", "temp"], true, 12) + 2
    readonly property real maxPrecipValue: Math.max(1, root.extremeValue("precipAmount", true, 1))
    readonly property real minPressureValue: root.extremeValue("pressureHpa", false, 1000) - 1
    readonly property real maxPressureValue: root.extremeValue("pressureHpa", true, 1025) + 1
    readonly property real maxWindValue: Math.max(20, root.extremeValue("windGustKmh", true, 24) + 4)
    readonly property real maxVisibilityValue: Math.max(4, root.extremeValue("visibilityKm", true, 8))
    readonly property int tempBottom: root.tempTop + root.tempHeight
    readonly property int precipBottom: root.precipTop + root.precipHeight
    readonly property int pressureBottom: root.pressureTop + root.pressureHeight
    readonly property int windBottom: root.windTop + root.windHeight
    readonly property int cloudBottom: root.cloudTop + root.cloudHeight
    readonly property real tempTitleCenterY: root.tempTop - 24
    readonly property real precipTitleCenterY: root.tempBottom + ((root.precipTop - root.tempBottom) / 2)
    readonly property real pressureTitleCenterY: root.precipBottom + ((root.pressureTop - root.precipBottom) / 2)
    readonly property real windTitleCenterY: root.pressureBottom + ((root.windTop - root.pressureBottom) / 2)
    readonly property real cloudTitleCenterY: root.windBottom + ((root.cloudTop - root.windBottom) / 2)
    readonly property var labelIndices: {
        const indices = [];
        for (let index = 0; index < root.sampleCount; index += 3)
            indices.push(index);

        if (root.sampleCount > 1 && indices[indices.length - 1] !== root.sampleCount - 1)
            indices.push(root.sampleCount - 1);

        return indices;
    }

    implicitWidth: 820
    implicitHeight: 1048

    function sampleAt(index): var {
        return index >= 0 && index < root.sampleCount ? root.samples[index] : null;
    }

    function xFor(index): real {
        if (root.sampleCount <= 1)
            return root.leftInset + (root.chartWidth / 2);

        return root.leftInset + ((root.chartWidth * index) / (root.sampleCount - 1));
    }

    function columnLeft(index): real {
        if (index <= 0)
            return root.leftInset;

        return (root.xFor(index - 1) + root.xFor(index)) / 2;
    }

    function columnRight(index): real {
        if (index >= root.sampleCount - 1)
            return root.leftInset + root.chartWidth;

        return (root.xFor(index) + root.xFor(index + 1)) / 2;
    }

    function indexForX(x): int {
        if (root.sampleCount <= 1)
            return root.sampleCount === 1 ? 0 : -1;

        const normalized = (x - root.leftInset) / root.chartWidth;
        return Math.max(0, Math.min(root.sampleCount - 1, Math.round(normalized * (root.sampleCount - 1))));
    }

    function valueOr(value, fallback): real {
        return value === null || value === undefined || Number.isNaN(value) ? fallback : value;
    }

    function clamp01(value): real {
        return Math.max(0, Math.min(1, value));
    }

    function extremeValue(key, takeMax, fallback): real {
        let best = null;
        for (let index = 0; index < root.sampleCount; index += 1) {
            const sample = root.sampleAt(index);
            const value = sample ? sample[key] : null;
            if (value === null || value === undefined || Number.isNaN(value))
                continue;

            if (best === null || (takeMax ? value > best : value < best))
                best = value;
        }

        return best === null ? fallback : best;
    }

    function extremeAcross(keys, takeMax, fallback): real {
        let best = null;
        for (let keyIndex = 0; keyIndex < keys.length; keyIndex += 1) {
            const candidate = root.extremeValue(keys[keyIndex], takeMax, NaN);
            if (Number.isNaN(candidate))
                continue;

            if (best === null || (takeMax ? candidate > best : candidate < best))
                best = candidate;
        }

        return best === null ? fallback : best;
    }

    function tempY(value): real {
        const normalized = (root.valueOr(value, root.minTempValue) - root.minTempValue) / Math.max(1, root.maxTempValue - root.minTempValue);
        return root.tempTop + root.tempHeight - (normalized * root.tempHeight);
    }

    function precipY(value): real {
        const normalized = root.valueOr(value, 0) / root.maxPrecipValue;
        return root.precipTop + root.precipHeight - (normalized * root.precipHeight);
    }

    function humidityY(value): real {
        const normalized = root.clamp01(root.valueOr(value, 0) / 100);
        return root.precipTop + root.precipHeight - (normalized * root.precipHeight);
    }

    function pressureY(value): real {
        const normalized = (root.valueOr(value, root.minPressureValue) - root.minPressureValue) / Math.max(1, root.maxPressureValue - root.minPressureValue);
        return root.pressureTop + root.pressureHeight - (normalized * root.pressureHeight);
    }

    function windY(value): real {
        const normalized = root.valueOr(value, 0) / root.maxWindValue;
        return root.windTop + root.windHeight - (normalized * root.windHeight);
    }

    function cloudY(value): real {
        const normalized = root.clamp01(root.valueOr(value, 0) / 100);
        return root.cloudTop + root.cloudHeight - (normalized * root.cloudHeight);
    }

    function visibilityY(value): real {
        const normalized = root.valueOr(value, 0) / root.maxVisibilityValue;
        return root.cloudTop + root.cloudHeight - (normalized * root.cloudHeight);
    }

    function rgba(color, alpha): string {
        return `rgba(${Math.round(color.r * 255)},${Math.round(color.g * 255)},${Math.round(color.b * 255)},${alpha})`;
    }

    function formatValue(value, digits, fallback): string {
        return value === null || value === undefined || Number.isNaN(value) ? fallback : Number(value).toFixed(digits);
    }

    function requestPaint(): void {
        chartCanvas.requestPaint();
    }

    onHoursChanged: {
        if (root.hoveredIndex >= root.sampleCount)
            root.hoveredIndex = -1;
        root.requestPaint();
    }
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    Connections {
        target: Theme

        function onDarkModeChanged(): void {
            root.requestPaint();
        }
    }

    Rectangle {
        visible: root.hoveredIndex >= 0
        x: root.columnLeft(root.hoveredIndex)
        y: root.tempTop - 10
        width: root.columnRight(root.hoveredIndex) - root.columnLeft(root.hoveredIndex)
        height: root.cloudTop + root.cloudHeight - y
        radius: 12
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
        border.width: 0
    }

    Rectangle {
        visible: root.hoveredIndex >= 0
        x: root.xFor(root.hoveredIndex)
        y: root.tempTop - 10
        width: 1
        height: root.cloudTop + root.cloudHeight - y
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
    }

    Canvas {
        id: chartCanvas

        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            if (root.sampleCount === 0)
                return;

            const chartRight = root.leftInset + root.chartWidth;
            function drawRoundedRect(x, y, w, h, radius, fillStyle, strokeStyle) {
                const r = Math.min(radius, w / 2, h / 2);
                ctx.beginPath();
                ctx.moveTo(x + r, y);
                ctx.arcTo(x + w, y, x + w, y + h, r);
                ctx.arcTo(x + w, y + h, x, y + h, r);
                ctx.arcTo(x, y + h, x, y, r);
                ctx.arcTo(x, y, x + w, y, r);
                ctx.closePath();
                if (fillStyle) {
                    ctx.fillStyle = fillStyle;
                    ctx.fill();
                }
                if (strokeStyle) {
                    ctx.strokeStyle = strokeStyle;
                    ctx.lineWidth = 1;
                    ctx.stroke();
                }
            }

            function strokeHorizontalGrid(top, height, steps, alpha) {
                ctx.strokeStyle = root.rgba(Theme.outline, alpha);
                ctx.lineWidth = 1;
                for (let step = 0; step <= steps; step += 1) {
                    const y = top + (height * step / steps);
                    ctx.beginPath();
                    ctx.moveTo(root.leftInset, y);
                    ctx.lineTo(chartRight, y);
                    ctx.stroke();
                }
            }

            drawRoundedRect(root.leftInset - 8, root.tempTop - 10, root.chartWidth + 16, root.tempHeight + 20, 18, root.rgba(Theme.surfaceContainerLow, Theme.darkMode ? 0.82 : 0.9), root.rgba(Theme.outline, 0.58));
            drawRoundedRect(root.leftInset - 8, root.precipTop - 8, root.chartWidth + 16, root.precipHeight + 16, 16, root.rgba(Theme.surfaceContainerLow, Theme.darkMode ? 0.42 : 0.55), root.rgba(Theme.outline, 0.5));
            drawRoundedRect(root.leftInset - 8, root.pressureTop - 8, root.chartWidth + 16, root.pressureHeight + 16, 16, root.rgba(Theme.tertiary, Theme.darkMode ? 0.08 : 0.12), root.rgba(Theme.outline, 0.5));
            drawRoundedRect(root.leftInset - 8, root.windTop - 8, root.chartWidth + 16, root.windHeight + 16, 16, root.rgba(Theme.secondary, Theme.darkMode ? 0.08 : 0.1), root.rgba(Theme.outline, 0.5));
            drawRoundedRect(root.leftInset - 8, root.cloudTop - 8, root.chartWidth + 16, root.cloudHeight + 16, 16, root.rgba(Theme.onSurface, Theme.darkMode ? 0.04 : 0.06), root.rgba(Theme.outline, 0.5));

            ctx.strokeStyle = root.rgba(Theme.outline, 0.55);
            ctx.lineWidth = 1;
            for (let index = 0; index < root.sampleCount; index += 3) {
                const x = root.xFor(index);
                const segments = [[root.tempTop, root.tempBottom], [root.precipTop, root.precipBottom], [root.pressureTop, root.pressureBottom], [root.windTop, root.windBottom], [root.cloudTop, root.cloudBottom]];
                for (let segmentIndex = 0; segmentIndex < segments.length; segmentIndex += 1) {
                    const segment = segments[segmentIndex];
                    ctx.beginPath();
                    ctx.moveTo(x, segment[0]);
                    ctx.lineTo(x, segment[1]);
                    ctx.stroke();
                }
            }

            strokeHorizontalGrid(root.tempTop, root.tempHeight, 4, 0.45);
            strokeHorizontalGrid(root.precipTop, root.precipHeight, 3, 0.35);
            strokeHorizontalGrid(root.pressureTop, root.pressureHeight, 3, 0.35);
            strokeHorizontalGrid(root.windTop, root.windHeight, 3, 0.35);
            strokeHorizontalGrid(root.cloudTop, root.cloudHeight, 3, 0.35);

            if (root.sampleCount > 1) {
                ctx.beginPath();
                for (let index = 0; index < root.sampleCount; index += 1) {
                    const sample = root.sampleAt(index);
                    const x = root.xFor(index);
                    const y = root.tempY(sample?.tempMax);
                    if (index === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }

                for (let index = root.sampleCount - 1; index >= 0; index -= 1) {
                    const sample = root.sampleAt(index);
                    ctx.lineTo(root.xFor(index), root.tempY(sample?.tempMin));
                }

                ctx.closePath();
                ctx.fillStyle = root.rgba(Theme.tertiary, 0.18);
                ctx.fill();
            }

            ctx.beginPath();
            for (let index = 0; index < root.sampleCount; index += 1) {
                const sample = root.sampleAt(index);
                const x = root.xFor(index);
                const y = root.tempY(sample?.dewPoint);
                if (index === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            ctx.lineWidth = 1.5;
            ctx.strokeStyle = root.rgba(Theme.secondary, 0.9);
            ctx.stroke();

            ctx.beginPath();
            for (let index = 0; index < root.sampleCount; index += 1) {
                const sample = root.sampleAt(index);
                const x = root.xFor(index);
                const y = root.tempY(sample?.temp);
                if (index === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            ctx.lineWidth = 2.6;
            ctx.strokeStyle = root.rgba(Theme.tertiary, 0.98);
            ctx.stroke();

            for (let index = 0; index < root.sampleCount; index += 3) {
                const sample = root.sampleAt(index);
                const x = root.xFor(index);
                const y = root.tempY(sample?.temp);
                ctx.beginPath();
                ctx.arc(x, y, 3.5, 0, Math.PI * 2);
                ctx.fillStyle = root.rgba(Theme.surfaceContainer, 0.95);
                ctx.fill();
                ctx.lineWidth = 2;
                ctx.strokeStyle = root.rgba(Theme.tertiary, 0.95);
                ctx.stroke();
            }

            for (let index = 0; index < root.sampleCount; index += 1) {
                const sample = root.sampleAt(index);
                const x = root.xFor(index);
                const barWidth = Math.max(6, root.chartWidth / Math.max(root.sampleCount, 18) * 0.58);
                const y = root.precipY(sample?.precipAmount);
                ctx.fillStyle = root.rgba(Theme.secondary, 0.82);
                ctx.fillRect(x - (barWidth / 2), y, barWidth, root.precipBottom - y);
            }

            ctx.beginPath();
            for (let index = 0; index < root.sampleCount; index += 1) {
                const sample = root.sampleAt(index);
                const x = root.xFor(index);
                const y = root.humidityY(sample?.humidity);
                if (index === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            ctx.lineWidth = 1.8;
            ctx.strokeStyle = root.rgba(Theme.tertiary, 0.9);
            ctx.stroke();

            if (root.sampleCount > 1) {
                ctx.beginPath();
                ctx.moveTo(root.xFor(0), root.pressureBottom);
                for (let index = 0; index < root.sampleCount; index += 1) {
                    const sample = root.sampleAt(index);
                    ctx.lineTo(root.xFor(index), root.pressureY(sample?.pressureHpa));
                }
                ctx.lineTo(root.xFor(root.sampleCount - 1), root.pressureBottom);
                ctx.closePath();
                ctx.fillStyle = root.rgba(Theme.tertiary, 0.26);
                ctx.fill();
            }

            ctx.beginPath();
            for (let index = 0; index < root.sampleCount; index += 1) {
                const sample = root.sampleAt(index);
                const x = root.xFor(index);
                const y = root.pressureY(sample?.pressureHpa);
                if (index === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            ctx.lineWidth = 1.8;
            ctx.strokeStyle = root.rgba(Theme.tertiary, 0.92);
            ctx.stroke();

            if (root.sampleCount > 1) {
                ctx.beginPath();
                ctx.moveTo(root.xFor(0), root.windBottom);
                for (let index = 0; index < root.sampleCount; index += 1) {
                    const sample = root.sampleAt(index);
                    ctx.lineTo(root.xFor(index), root.windY(sample?.windSpeedKmh));
                }
                ctx.lineTo(root.xFor(root.sampleCount - 1), root.windBottom);
                ctx.closePath();
                ctx.fillStyle = root.rgba(Theme.secondary, 0.24);
                ctx.fill();
            }

            ctx.beginPath();
            for (let index = 0; index < root.sampleCount; index += 1) {
                const sample = root.sampleAt(index);
                const x = root.xFor(index);
                const y = root.windY(sample?.windSpeedKmh);
                if (index === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            ctx.lineWidth = 1.8;
            ctx.strokeStyle = root.rgba(Theme.secondary, 0.95);
            ctx.stroke();

            ctx.beginPath();
            for (let index = 0; index < root.sampleCount; index += 1) {
                const sample = root.sampleAt(index);
                const x = root.xFor(index);
                const y = root.windY(sample?.windGustKmh);
                if (index === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            ctx.lineWidth = 1.4;
            ctx.strokeStyle = root.rgba(Theme.tertiary, 0.9);
            ctx.stroke();

            if (root.sampleCount > 1) {
                ctx.beginPath();
                ctx.moveTo(root.xFor(0), root.cloudBottom);
                for (let index = 0; index < root.sampleCount; index += 1) {
                    const sample = root.sampleAt(index);
                    ctx.lineTo(root.xFor(index), root.cloudY(sample?.cloudCover));
                }
                ctx.lineTo(root.xFor(root.sampleCount - 1), root.cloudBottom);
                ctx.closePath();
                ctx.fillStyle = root.rgba(Theme.onSurface, 0.2);
                ctx.fill();
            }

            const cloudLines = [["cloudLow", Theme.secondary, 0.95], ["cloudMid", Theme.primary, 0.9], ["cloudHigh", Theme.onSurfaceVariant, 0.9]];
            for (let cloudLineIndex = 0; cloudLineIndex < cloudLines.length; cloudLineIndex += 1) {
                const cloudLine = cloudLines[cloudLineIndex];
                const key = cloudLine[0];
                const color = cloudLine[1];
                const alpha = cloudLine[2];
                ctx.beginPath();
                for (let index = 0; index < root.sampleCount; index += 1) {
                    const sample = root.sampleAt(index);
                    const x = root.xFor(index);
                    const y = root.cloudY(sample ? sample[key] : null);
                    if (index === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }
                ctx.lineWidth = 1.6;
                ctx.strokeStyle = root.rgba(color, alpha);
                ctx.stroke();
            }

            ctx.beginPath();
            for (let index = 0; index < root.sampleCount; index += 1) {
                const sample = root.sampleAt(index);
                const x = root.xFor(index);
                const y = root.visibilityY(sample?.visibilityKm);
                if (index === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            ctx.lineWidth = 1.4;
            ctx.strokeStyle = root.rgba(Theme.tertiary, 0.92);
            ctx.stroke();
        }
    }

    Text {
        x: root.leftInset + (root.chartWidth - implicitWidth) / 2
        y: root.tempTitleCenterY - (implicitHeight / 2)
        text: "temp °C"
        color: Theme.tertiary
        font.family: Theme.fontMono
        font.pixelSize: 11
        font.weight: Font.DemiBold
    }

    Repeater {
        model: 5

        delegate: Text {
            required property int index

            x: 0
            y: root.tempTop + (root.tempHeight * index / 4) - (implicitHeight / 2)
            width: root.leftInset - 8
            horizontalAlignment: Text.AlignRight
            text: `${Math.round(root.maxTempValue - ((root.maxTempValue - root.minTempValue) * index / 4))}°`
            color: index === 0 ? Theme.tertiary : Theme.onSurfaceVariant
            font.family: Theme.fontMono
            font.pixelSize: 10
        }
    }

    Text {
        x: root.leftInset + (root.chartWidth * 0.25) - (implicitWidth / 2)
        y: root.precipTitleCenterY - (implicitHeight / 2)
        text: "rain mm"
        color: Theme.secondary
        font.family: Theme.fontMono
        font.pixelSize: 11
    }

    Repeater {
        model: 4

        delegate: Text {
            required property int index

            x: 0
            y: root.precipTop + (root.precipHeight * index / 3) - (implicitHeight / 2)
            width: root.leftInset - 8
            horizontalAlignment: Text.AlignRight
            text: `${root.formatValue(root.maxPrecipValue * (1 - (index / 3)), root.maxPrecipValue >= 4 ? 0 : 1, "0")} `
            color: index === 0 ? Theme.secondary : Theme.onSurfaceVariant
            font.family: Theme.fontMono
            font.pixelSize: 10
        }
    }

    Text {
        x: root.leftInset + (root.chartWidth * 0.75) - (implicitWidth / 2)
        y: root.precipTitleCenterY - (implicitHeight / 2)
        text: "humidity %"
        color: Theme.tertiary
        font.family: Theme.fontMono
        font.pixelSize: 11
    }

    Repeater {
        model: 4

        delegate: Text {
            required property int index

            x: root.width - root.rightInset + 8
            y: root.precipTop + (root.precipHeight * index / 3) - (implicitHeight / 2)
            width: root.rightInset - 8
            text: `${Math.round(100 - (index * 100 / 3))}%`
            color: index === 0 ? Theme.tertiary : Theme.onSurfaceVariant
            font.family: Theme.fontMono
            font.pixelSize: 10
        }
    }

    Text {
        x: root.leftInset + (root.chartWidth - implicitWidth) / 2
        y: root.pressureTitleCenterY - (implicitHeight / 2)
        text: "pressure hPa"
        color: Theme.tertiary
        font.family: Theme.fontMono
        font.pixelSize: 11
    }

    Repeater {
        model: 4

        delegate: Text {
            required property int index

            x: 0
            y: root.pressureTop + (root.pressureHeight * index / 3) - (implicitHeight / 2)
            width: root.leftInset - 8
            horizontalAlignment: Text.AlignRight
            text: `${Math.round(root.maxPressureValue - ((root.maxPressureValue - root.minPressureValue) * index / 3))}`
            color: index === 0 ? Theme.tertiary : Theme.onSurfaceVariant
            font.family: Theme.fontMono
            font.pixelSize: 10
        }
    }

    Text {
        x: root.leftInset + (root.chartWidth - implicitWidth) / 2
        y: root.windTitleCenterY - (implicitHeight / 2)
        text: "wind km/h"
        color: Theme.secondary
        font.family: Theme.fontMono
        font.pixelSize: 11
    }

    Repeater {
        model: 4

        delegate: Text {
            required property int index

            x: 0
            y: root.windTop + (root.windHeight * index / 3) - (implicitHeight / 2)
            width: root.leftInset - 8
            horizontalAlignment: Text.AlignRight
            text: `${Math.round(root.maxWindValue * (1 - (index / 3)))}`
            color: index === 0 ? Theme.secondary : Theme.onSurfaceVariant
            font.family: Theme.fontMono
            font.pixelSize: 10
        }
    }

    Text {
        x: root.leftInset + (root.chartWidth * 0.25) - (implicitWidth / 2)
        y: root.cloudTitleCenterY - (implicitHeight / 2)
        text: "cloud %"
        color: Theme.onSurface
        font.family: Theme.fontMono
        font.pixelSize: 11
    }

    Text {
        x: root.leftInset + (root.chartWidth * 0.75) - (implicitWidth / 2)
        y: root.cloudTitleCenterY - (implicitHeight / 2)
        text: "vis km"
        color: Theme.tertiary
        font.family: Theme.fontMono
        font.pixelSize: 11
    }

    Repeater {
        model: 4

        delegate: Text {
            required property int index

            x: 0
            y: root.cloudTop + (root.cloudHeight * index / 3) - (implicitHeight / 2)
            width: root.leftInset - 8
            horizontalAlignment: Text.AlignRight
            text: `${Math.round(100 - (index * 100 / 3))}%`
            color: index === 0 ? Theme.onSurface : Theme.onSurfaceVariant
            font.family: Theme.fontMono
            font.pixelSize: 10
        }
    }

    Repeater {
        model: 4

        delegate: Text {
            required property int index

            x: root.width - root.rightInset + 8
            y: root.cloudTop + (root.cloudHeight * index / 3) - (implicitHeight / 2)
            width: root.rightInset - 8
            text: `${root.formatValue(root.maxVisibilityValue * (1 - (index / 3)), root.maxVisibilityValue >= 10 ? 0 : 1, "0")}`
            color: index === 0 ? Theme.tertiary : Theme.onSurfaceVariant
            font.family: Theme.fontMono
            font.pixelSize: 10
        }
    }

    Repeater {
        model: root.labelIndices

        delegate: Item {
            required property int modelData

            readonly property var sample: root.sampleAt(modelData)
            readonly property real markerX: root.xFor(modelData)
            width: 48
            height: root.implicitHeight
            x: markerX - (width / 2)
            y: 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 0
                text: parent.sample?.icon ?? ""
                color: Theme.onSurface
                font.family: Theme.fontSans
                font.pixelSize: 18
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 20
                text: parent.sample?.hourLabel ?? ""
                color: Theme.onSurfaceVariant
                font.family: Theme.fontMono
                font.pixelSize: 11
            }

            Text {
                visible: parent.sample?.dayMarker ?? false
                anchors.horizontalCenter: parent.horizontalCenter
                y: 34
                text: parent.sample?.dayLabel ?? ""
                color: Theme.primary
                font.family: Theme.fontMono
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            Text {
                visible: parent.sample && parent.sample.temp !== null && parent.sample.temp !== undefined
                anchors.horizontalCenter: parent.horizontalCenter
                y: Math.max(root.tempTop - 18, root.tempY(parent.sample ? parent.sample.temp : null) - 18)
                text: parent.sample ? `${Math.round(parent.sample.temp)}` : ""
                color: Theme.onSurface
                font.family: Theme.fontMono
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.windTop + root.windHeight - 18
                text: "↑"
                rotation: parent.sample?.windDirection ?? 0
                transformOrigin: Item.Center
                color: (parent.sample?.windGustKmh ?? 0) > 30 ? Theme.tertiary : Theme.secondary
                font.family: Theme.fontSans
                font.pixelSize: 14
                font.weight: Font.Black
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: root.windTop + root.windHeight - 4
                text: parent.sample ? `${Math.round(parent.sample.windSpeedKmh)}` : ""
                color: Theme.onSurfaceVariant
                font.family: Theme.fontMono
                font.pixelSize: 10
            }
        }
    }

    Rectangle {
        visible: root.hoveredSample !== null
        z: 10
        width: 178
        height: tooltipColumn.implicitHeight + 16
        x: Math.max(8, Math.min(root.width - width - 8, root.xFor(root.hoveredIndex) - (width / 2)))
        y: 4
        radius: Theme.chipRadius
        color: Qt.rgba(Theme.surfaceContainer.r, Theme.surfaceContainer.g, Theme.surfaceContainer.b, 0.96)
        border.width: 1
        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)

        Column {
            id: tooltipColumn

            anchors.fill: parent
            anchors.margins: 8
            spacing: 2

            Text {
                text: root.hoveredSample ? `${root.hoveredSample.dayLabel} ${root.hoveredSample.hourLabel}:00` : ""
                color: Theme.onSurface
                font.family: Theme.fontMono
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }

            Text {
                text: root.hoveredSample ? `temp ${root.formatValue(root.hoveredSample.temp, 1, "--")}°  dew ${root.formatValue(root.hoveredSample.dewPoint, 1, "--")}°` : ""
                color: Theme.tertiary
                font.family: Theme.fontMono
                font.pixelSize: 10
            }

            Text {
                text: root.hoveredSample ? `rain ${root.formatValue(root.hoveredSample.precipAmount, 1, "0.0")} mm  hum ${Math.round(root.hoveredSample.humidity ?? 0)}%` : ""
                color: Theme.secondary
                font.family: Theme.fontMono
                font.pixelSize: 10
            }

            Text {
                text: root.hoveredSample ? `press ${root.formatValue(root.hoveredSample.pressureHpa, 0, "--")} hPa` : ""
                color: Theme.tertiary
                font.family: Theme.fontMono
                font.pixelSize: 10
            }

            Text {
                text: root.hoveredSample ? `wind ${Math.round(root.hoveredSample.windSpeedKmh ?? 0)} / ${Math.round(root.hoveredSample.windGustKmh ?? 0)} km/h` : ""
                color: Theme.primary
                font.family: Theme.fontMono
                font.pixelSize: 10
            }

            Text {
                text: root.hoveredSample ? `cloud ${Math.round(root.hoveredSample.cloudCover ?? 0)}%  vis ${root.formatValue(root.hoveredSample.visibilityKm, 1, "--")} km` : ""
                color: Theme.onSurfaceVariant
                font.family: Theme.fontMono
                font.pixelSize: 10
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        onPositionChanged: mouse => {
            root.hoveredIndex = root.indexForX(mouse.x);
        }
        onExited: {
            root.hoveredIndex = -1;
        }
    }
}

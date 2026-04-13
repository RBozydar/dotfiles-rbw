pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string location: Quickshell.env("RBW_WEATHER_LOCATION") || ""
    property bool available: false
    property string city: ""
    property string condition: "Weather unavailable"
    property string code: ""
    property string temperature: "--°"
    property string feelsLike: "--°"
    property string humidity: "--%"
    property string wind: "--"

    readonly property string icon: {
        switch (root.code) {
        case "113":
            return "☀";
        case "116":
            return "⛅";
        case "119":
        case "122":
        case "143":
            return "☁";
        case "176":
        case "263":
        case "266":
        case "281":
        case "284":
        case "293":
        case "296":
        case "299":
        case "302":
        case "305":
        case "308":
        case "311":
        case "314":
        case "317":
        case "353":
        case "356":
        case "359":
        case "362":
        case "365":
            return "☂";
        case "179":
        case "182":
        case "185":
        case "227":
        case "230":
        case "320":
        case "323":
        case "326":
        case "329":
        case "332":
        case "335":
        case "338":
        case "350":
        case "368":
        case "371":
        case "374":
        case "377":
        case "392":
        case "395":
            return "❄";
        case "200":
        case "386":
        case "389":
            return "⚡";
        default:
            return "☁";
        }
    }

    function refresh(): void {
        if (!fetcher.running)
            fetcher.running = true;
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 1200000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Process {
        id: fetcher

        command: ["sh", Quickshell.shellPath("scripts/weather.sh"), root.location]
        workingDirectory: Quickshell.shellDir

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (!line)
                    return;

                try {
                    const payload = JSON.parse(line);
                    root.available = payload.available ?? false;
                    root.city = payload.city ?? "";
                    root.condition = payload.condition ?? "Weather unavailable";
                    root.code = `${payload.code ?? ""}`;
                    root.temperature = payload.temperature ?? "--°";
                    root.feelsLike = payload.feelsLike ?? "--°";
                    root.humidity = payload.humidity ?? "--%";
                    root.wind = payload.wind ?? "--";
                } catch (error) {
                    console.log(`weather parse error: ${error}`);
                }
            }
        }
    }
}

import QtQuick
import Quickshell
pragma Singleton

Singleton {
    property bool darkMode: true
    readonly property string fontSans: "Fira Sans"
    readonly property string fontMono: "JetBrains Mono"
    readonly property color background: darkMode ? "#09111f" : "#edf4fb"
    readonly property color panel: darkMode ? "#d9111827" : "#eef7fbff"
    readonly property color panelSolid: darkMode ? "#111827" : "#ffffff"
    readonly property color chip: darkMode ? "#132033" : "#dfe9f4"
    readonly property color chipHover: darkMode ? "#1a2b44" : "#cedceb"
    readonly property color chipActive: darkMode ? "#1b3b36" : "#cbe7e1"
    readonly property color border: darkMode ? "#33526e" : "#9bb1c6"
    readonly property color text: darkMode ? "#c8d2e0" : "#132235"
    readonly property color textMuted: darkMode ? "#8ea4bf" : "#5d7389"
    readonly property color accent: darkMode ? "#82dccc" : "#0f9684"
    readonly property color accentStrong: darkMode ? "#01ccff" : "#0077cc"
    readonly property color warning: darkMode ? "#fb958b" : "#cf6b5d"
    readonly property color success: darkMode ? "#82dccc" : "#0f9684"
    readonly property color danger: darkMode ? "#ff857d" : "#d64f44"
    readonly property int barOuterHeight: 52
    readonly property int barInnerHeight: 40
    readonly property int barMargin: 6
    readonly property int radius: 18
    readonly property int chipRadius: 14
    readonly property int gap: 8
    readonly property int padding: 12
    readonly property int chipPadding: 10

    function toggleDarkMode(): void {
        darkMode = !darkMode;
    }
}

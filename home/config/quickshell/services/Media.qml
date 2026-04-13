pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var players: Mpris.players.values.filter(player => !player.dbusName?.startsWith("org.mpris.MediaPlayer2.playerctld"))
    property var activePlayer: null
    readonly property bool available: activePlayer !== null
    readonly property bool playing: !!activePlayer?.isPlaying
    readonly property string title: activePlayer?.trackTitle || "No media"
    readonly property string artist: activePlayer?.trackArtist || ""
    readonly property string identity: activePlayer?.identity || ""
    readonly property real progress: {
        const length = Number(activePlayer?.length ?? 0);
        const position = Number(activePlayer?.position ?? 0);
        return length > 0 ? Math.max(0, Math.min(1, position / length)) : 0;
    }

    function refresh(): void {
        const nextPlayer = root.players.find(player => player.isPlaying) ?? root.players[0] ?? null;

        if (nextPlayer !== root.activePlayer)
            root.activePlayer = nextPlayer;
    }

    function toggle(): void {
        if (root.activePlayer?.canTogglePlaying)
            root.activePlayer.togglePlaying();
    }

    function previous(): void {
        if (root.activePlayer?.canGoPrevious)
            root.activePlayer.previous();
    }

    function next(): void {
        if (root.activePlayer?.canGoNext)
            root.activePlayer.next();
    }

    function raise(): void {
        root.activePlayer?.raise();
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }
}

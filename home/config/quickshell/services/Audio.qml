pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property bool muted: !!sink?.audio?.muted
    readonly property int volumePercent: Math.round((sink?.audio?.volume ?? 0) * 100)
    readonly property real volumeLevel: Math.max(0, Math.min(1, (sink?.audio?.volume ?? 0) / 1.5))
    property bool devicesAvailable: false
    property string devicesError: ""
    property string defaultOutputId: ""
    property string defaultInputId: ""
    property var outputDevices: []
    property var inputDevices: []

    readonly property int defaultOutputIndex: root.deviceIndex(root.outputDevices, root.defaultOutputId)
    readonly property int defaultInputIndex: root.deviceIndex(root.inputDevices, root.defaultInputId)
    readonly property string currentOutputLabel: root.deviceLabel(root.outputDevices, root.defaultOutputId, "unavailable")
    readonly property string currentInputLabel: root.deviceLabel(root.inputDevices, root.defaultInputId, "unavailable")
    readonly property bool canSelectOutput: root.outputDevices.length > 1
    readonly property bool canSelectInput: root.inputDevices.length > 1

    function toggleMute(): void {
        if (sink?.ready && sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function setVolume(percent): void {
        if (sink?.ready && sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1.5, percent / 100));
        }
    }

    function deviceIdAt(devices, index): string {
        if (!Array.isArray(devices))
            return "";

        if (index < 0 || index >= devices.length)
            return "";

        return String(devices[index]?.id ?? "");
    }

    function deviceIndex(devices, id): int {
        const source = Array.isArray(devices) ? devices : [];
        const target = String(id ?? "");
        if (!target)
            return -1;

        for (let index = 0; index < source.length; index += 1) {
            if (String(source[index]?.id ?? "") === target)
                return index;
        }

        return -1;
    }

    function deviceLabel(devices, id, fallback): string {
        const source = Array.isArray(devices) ? devices : [];
        const labelFallback = String(fallback ?? "");
        const index = root.deviceIndex(source, id);
        if (index < 0)
            return labelFallback;

        return String(source[index]?.description ?? source[index]?.id ?? labelFallback);
    }

    function cycleDeviceId(devices, currentId, step): string {
        const source = Array.isArray(devices) ? devices : [];
        if (source.length === 0)
            return "";

        const normalizedStep = Number(step) >= 0 ? 1 : -1;
        const currentIndex = root.deviceIndex(source, currentId);
        let nextIndex = currentIndex >= 0 ? currentIndex + normalizedStep : 0;
        if (nextIndex < 0)
            nextIndex = source.length - 1;
        if (nextIndex >= source.length)
            nextIndex = 0;
        return root.deviceIdAt(source, nextIndex);
    }

    function runCommand(command): void {
        Quickshell.execDetached({
            command: command,
            workingDirectory: Quickshell.shellDir
        });
        refreshDevices();
        refreshLater.restart();
    }

    function setDefaultOutput(deviceId): void {
        const target = String(deviceId ?? "");
        if (target.length === 0)
            return;
        runCommand(["pactl", "set-default-sink", target]);
    }

    function setDefaultInput(deviceId): void {
        const target = String(deviceId ?? "");
        if (target.length === 0)
            return;
        runCommand(["pactl", "set-default-source", target]);
    }

    function selectPreviousOutput(): void {
        const nextId = root.cycleDeviceId(root.outputDevices, root.defaultOutputId, -1);
        if (nextId.length > 0)
            root.setDefaultOutput(nextId);
    }

    function selectNextOutput(): void {
        const nextId = root.cycleDeviceId(root.outputDevices, root.defaultOutputId, 1);
        if (nextId.length > 0)
            root.setDefaultOutput(nextId);
    }

    function selectPreviousInput(): void {
        const nextId = root.cycleDeviceId(root.inputDevices, root.defaultInputId, -1);
        if (nextId.length > 0)
            root.setDefaultInput(nextId);
    }

    function selectNextInput(): void {
        const nextId = root.cycleDeviceId(root.inputDevices, root.defaultInputId, 1);
        if (nextId.length > 0)
            root.setDefaultInput(nextId);
    }

    function refreshDevices(): void {
        if (!devicesProbe.running)
            devicesProbe.running = true;
    }

    Component.onCompleted: refreshDevices()

    Timer {
        interval: 12000
        running: true
        repeat: true
        onTriggered: root.refreshDevices()
    }

    Timer {
        id: refreshLater

        interval: 1200
        repeat: false
        onTriggered: root.refreshDevices()
    }

    Process {
        id: devicesProbe

        command: ["sh", Quickshell.shellPath("scripts/audio-status.sh")]
        workingDirectory: Quickshell.shellDir

        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                if (!line)
                    return;

                try {
                    const payload = JSON.parse(line);
                    const outputs = Array.isArray(payload.outputs) ? payload.outputs : [];
                    const inputs = Array.isArray(payload.inputs) ? payload.inputs : [];
                    const parsedDefaultOutput = String(payload.defaultOutput ?? "");
                    const parsedDefaultInput = String(payload.defaultInput ?? "");
                    root.outputDevices = outputs;
                    root.inputDevices = inputs;
                    root.defaultOutputId = parsedDefaultOutput.length > 0 ? parsedDefaultOutput : root.deviceIdAt(outputs, 0);
                    root.defaultInputId = parsedDefaultInput.length > 0 ? parsedDefaultInput : root.deviceIdAt(inputs, 0);
                    root.devicesAvailable = payload.available ?? (outputs.length > 0 || inputs.length > 0);
                    root.devicesError = String(payload.error ?? "");
                } catch (error) {
                    root.devicesAvailable = false;
                    root.devicesError = `parse error: ${error}`;
                }
            }
        }
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
}

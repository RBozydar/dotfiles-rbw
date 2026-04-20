pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "launcher-overlay-controller.js" as LauncherOverlayController
import qs

Variants {
    id: root

    required property var shell

    model: Quickshell.screens

    PanelWindow {
        id: panel

        required property var modelData

        readonly property var launcherState: root.shell && root.shell.launcherState ? root.shell.launcherState : ({
                phase: "idle",
                error: "",
                pendingProviders: []
            })
        readonly property int launcherStoreRevision: root.shell ? Number(root.shell.launcherStoreRevision) : 0
        readonly property int pendingProviderCount: launcherState && Array.isArray(launcherState.pendingProviders) ? launcherState.pendingProviders.length : 0
        property string queryText: ""
        property string pendingSearchSourceCode: "launcher.ui.input"
        property var itemGeometryByIndex: ({})
        readonly property var navigationKeyCodes: ({
                escape: Qt.Key_Escape,
                tab: Qt.Key_Tab,
                n: Qt.Key_N,
                p: Qt.Key_P,
                down: Qt.Key_Down,
                up: Qt.Key_Up,
                pageDown: Qt.Key_PageDown,
                pageUp: Qt.Key_PageUp,
                home: Qt.Key_Home,
                end: Qt.Key_End,
                space: Qt.Key_Space,
                returnKey: Qt.Key_Return,
                enter: Qt.Key_Enter
            })

        screen: modelData
        visible: root.shell.launcherOverlayOpen
        color: "transparent"
        exclusiveZone: 0
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        function setQueryText(nextQuery, sourceCode): void {
            const normalized = String(nextQuery || "");
            queryText = normalized;
            queryInput.text = normalized;
            itemGeometryByIndex = ({});
            presentationModel.resetSurfaceState();
            pendingSearchSourceCode = sourceCode === undefined ? "launcher.ui.input" : String(sourceCode);
            searchDebounce.restart();
        }

        function searchNow(sourceCode): void {
            if (!root.shell || typeof root.shell.runLauncherSearchQuery !== "function")
                return;
            root.shell.runLauncherSearchQuery(queryText, sourceCode === undefined ? "launcher.ui.search" : String(sourceCode));
        }

        function handleNavigationEvent(event): bool {
            const action = LauncherOverlayController.decideNavigationAction({
                key: event.key,
                controlPressed: (event.modifiers & Qt.ControlModifier) !== 0,
                shiftPressed: (event.modifiers & Qt.ShiftModifier) !== 0,
                hasAutocompleteCandidate: panel.canApplyCommandAutocomplete(),
                hasPreviewCandidate: panel.canPreviewHighlighted(),
                hasPinCandidate: panel.canToggleHighlightedPin(),
                canMovePinUp: panel.canMoveHighlightedPinUp(),
                canMovePinDown: panel.canMoveHighlightedPinDown(),
                totalItemCount: presentationModel.totalItemCount,
                keyCodes: panel.navigationKeyCodes
            });
            if (!action || action.kind === "noop")
                return false;

            if (action.kind === "close")
                root.shell.closeLauncherOverlay();
            else if (action.kind === "autocomplete")
                panel.applyCommandAutocomplete();
            else if (action.kind === "move")
                presentationModel.moveHighlight(Number(action.delta));
            else if (action.kind === "set_index")
                presentationModel.highlightedIndex = Number(action.index);
            else if (action.kind === "activate")
                panel.activateHighlighted();
            else if (action.kind === "preview")
                panel.previewHighlighted();
            else if (action.kind === "pin_toggle")
                panel.toggleHighlightedPin();
            else if (action.kind === "pin_move_up")
                panel.moveHighlightedPinUp();
            else if (action.kind === "pin_move_down")
                panel.moveHighlightedPinDown();

            event.accepted = true;
            return true;
        }

        function globalIndexFor(sectionIndex, itemIndex): int {
            const sections = presentationModel.sections;
            let offset = 0;
            for (let index = 0; index < sectionIndex; index += 1)
                offset += sections[index].items.length;
            return offset + itemIndex;
        }

        function itemAtGlobalIndex(globalIndex) {
            const sections = presentationModel.sections;
            let cursor = 0;

            for (let sectionIndex = 0; sectionIndex < sections.length; sectionIndex += 1) {
                const section = sections[sectionIndex];
                for (let itemIndex = 0; itemIndex < section.items.length; itemIndex += 1) {
                    if (cursor === globalIndex)
                        return section.items[itemIndex];
                    cursor += 1;
                }
            }

            return null;
        }

        function activateHighlighted(): void {
            const highlighted = itemAtGlobalIndex(presentationModel.highlightedIndex);
            if (!highlighted || !root.shell || typeof root.shell.activateLauncherItemFromUi !== "function")
                return;
            root.shell.activateLauncherItemFromUi(highlighted.id);
        }

        function canPreviewHighlighted(): bool {
            const highlighted = itemAtGlobalIndex(presentationModel.highlightedIndex);
            if (!highlighted || !highlighted.action)
                return false;
            return String(highlighted.action.type || "") === "file.open";
        }

        function previewHighlighted(): void {
            const highlighted = itemAtGlobalIndex(presentationModel.highlightedIndex);
            if (!highlighted || !root.shell || typeof root.shell.previewLauncherItemFromUi !== "function")
                return;
            root.shell.previewLauncherItemFromUi(highlighted.id);
        }

        function stablePinnedCommandName(item): string {
            const candidate = item && typeof item === "object" ? item : null;
            if (!candidate || !candidate.action)
                return "";
            if (String(candidate.action.type || "") !== "shell.ipc.dispatch")
                return "";

            const commandName = String(candidate.action.command || "").trim();
            if (!commandName)
                return "";

            if (candidate.action.args === undefined)
                return commandName;
            if (!Array.isArray(candidate.action.args))
                return "";
            if (candidate.action.args.length !== 0)
                return "";
            return commandName;
        }

        function highlightedCommandName(): string {
            return stablePinnedCommandName(itemAtGlobalIndex(presentationModel.highlightedIndex));
        }

        function canToggleHighlightedPin(): bool {
            return highlightedCommandName().length > 0;
        }

        function canMoveHighlightedPinUp(): bool {
            if (!root.shell || typeof root.shell.canMovePinnedLauncherCommand !== "function")
                return false;
            return root.shell.canMovePinnedLauncherCommand(highlightedCommandName(), -1);
        }

        function canMoveHighlightedPinDown(): bool {
            if (!root.shell || typeof root.shell.canMovePinnedLauncherCommand !== "function")
                return false;
            return root.shell.canMovePinnedLauncherCommand(highlightedCommandName(), 1);
        }

        function toggleHighlightedPin(): void {
            const commandName = highlightedCommandName();
            if (!commandName || !root.shell || typeof root.shell.toggleLauncherCommandPinFromUi !== "function")
                return;
            root.shell.toggleLauncherCommandPinFromUi(commandName);
        }

        function moveHighlightedPinUp(): void {
            const commandName = highlightedCommandName();
            if (!commandName || !root.shell || typeof root.shell.movePinnedLauncherCommandUpFromUi !== "function")
                return;
            root.shell.movePinnedLauncherCommandUpFromUi(commandName);
        }

        function moveHighlightedPinDown(): void {
            const commandName = highlightedCommandName();
            if (!commandName || !root.shell || typeof root.shell.movePinnedLauncherCommandDownFromUi !== "function")
                return;
            root.shell.movePinnedLauncherCommandDownFromUi(commandName);
        }

        function currentCommandPrefix(): string {
            const launcherSettings = root.shell && typeof root.shell.currentLauncherSettings === "function" ? root.shell.currentLauncherSettings() : null;
            return LauncherOverlayController.resolveCommandPrefix(launcherSettings, ">");
        }

        function commandAutocompleteCandidate() {
            const highlighted = itemAtGlobalIndex(presentationModel.highlightedIndex);
            return LauncherOverlayController.commandAutocompleteCandidate(queryText, currentCommandPrefix(), highlighted);
        }

        function canApplyCommandAutocomplete(): bool {
            return commandAutocompleteCandidate().length > 0;
        }

        function applyCommandAutocomplete(): bool {
            const highlighted = itemAtGlobalIndex(presentationModel.highlightedIndex);
            const completed = LauncherOverlayController.autocompleteQuery(queryText, currentCommandPrefix(), highlighted);
            if (!completed.applied)
                return false;

            setQueryText(completed.query, "launcher.ui.autocomplete");
            queryInput.cursorPosition = queryInput.text.length;
            return true;
        }

        function registerItemGeometry(globalIndex, y, height): void {
            const key = String(globalIndex);
            const next = {};
            const previous = itemGeometryByIndex && typeof itemGeometryByIndex === "object" ? itemGeometryByIndex : {};

            for (const existingKey in previous)
                next[existingKey] = previous[existingKey];

            next[key] = {
                y: Number(y),
                height: Number(height)
            };
            itemGeometryByIndex = next;
        }

        function unregisterItemGeometry(globalIndex): void {
            const key = String(globalIndex);
            const previous = itemGeometryByIndex && typeof itemGeometryByIndex === "object" ? itemGeometryByIndex : {};
            if (!previous[key])
                return;

            const next = {};
            for (const existingKey in previous) {
                if (existingKey === key)
                    continue;
                next[existingKey] = previous[existingKey];
            }
            itemGeometryByIndex = next;
        }

        function ensureHighlightVisible(): void {
            if (!panel.visible)
                return;

            const key = String(presentationModel.highlightedIndex);
            const entry = itemGeometryByIndex && typeof itemGeometryByIndex === "object" ? itemGeometryByIndex[key] : null;
            if (!entry)
                return;

            const top = Number(entry.y);
            const nextContentY = LauncherOverlayController.computeVisibleContentY(resultFlick.contentY, resultFlick.height, resultFlick.contentHeight, top, Number(entry.height), Theme.gap);
            if (nextContentY !== resultFlick.contentY)
                resultFlick.contentY = nextContentY;
        }

        onVisibleChanged: {
            if (visible) {
                const launcherSettings = root.shell && typeof root.shell.currentLauncherSettings === "function" ? root.shell.currentLauncherSettings() : ({
                        lastQuery: ""
                    });
                setQueryText(launcherSettings && launcherSettings.lastQuery ? launcherSettings.lastQuery : "", "launcher.ui.open");
                Qt.callLater(() => {
                    queryInput.forceActiveFocus();
                    queryInput.selectAll();
                });
                return;
            }

            searchDebounce.stop();
            queryText = "";
            queryInput.text = "";
            itemGeometryByIndex = ({});
            presentationModel.resetSurfaceState();
        }

        Timer {
            id: searchDebounce

            interval: 70
            repeat: false
            onTriggered: panel.searchNow(panel.pendingSearchSourceCode)
        }

        LauncherPresentationModel {
            id: presentationModel

            launcherState: panel.launcherState
            stateRevision: panel.launcherStoreRevision
        }

        Connections {
            target: presentationModel

            function onTotalItemCountChanged(): void {
                if (presentationModel.totalItemCount <= 0) {
                    panel.itemGeometryByIndex = ({});
                    presentationModel.highlightedIndex = 0;
                    return;
                }

                if (presentationModel.highlightedIndex >= presentationModel.totalItemCount)
                    presentationModel.highlightedIndex = presentationModel.totalItemCount - 1;
            }

            function onHighlightedIndexChanged(): void {
                panel.ensureHighlightVisible();
            }
        }

        Item {
            anchors.fill: parent
            focus: panel.visible

            Keys.onPressed: event => {
                panel.handleNavigationEvent(event);
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.shell.closeLauncherOverlay()
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(Theme.scrim.r, Theme.scrim.g, Theme.scrim.b, 0.66)
            }

            Rectangle {
                id: launcherCard

                width: Math.min(920, panel.width - (Theme.padding * 4))
                height: Math.min(620, panel.height - (Theme.padding * 6))
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Math.max(44, Theme.barOuterHeight + 16)
                radius: Theme.radius
                color: Theme.surface
                border.width: 1
                border.color: Theme.outline

                MouseArea {
                    anchors.fill: parent
                    onClicked: {}
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: Theme.padding + 4
                    spacing: Theme.gap

                    RowLayout {
                        width: parent.width

                        Text {
                            text: "Launcher"
                            color: Theme.roleOnSurface
                            font.family: Theme.fontSans
                            font.pixelSize: 24
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }

                        Text {
                            text: panel.pendingProviderCount > 0 ? `syncing ${panel.pendingProviderCount} providers` : panel.launcherState.phase
                            color: Theme.roleOnSurfaceVariant
                            font.family: Theme.fontMono
                            font.pixelSize: 11
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 48
                        radius: Theme.chipRadius
                        color: Theme.surfaceContainer
                        border.width: 1
                        border.color: queryInput.activeFocus ? Theme.primary : Theme.outline

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            spacing: 10

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "󰍉"
                                color: Theme.primary
                                font.family: Theme.fontSans
                                font.pixelSize: 17
                                font.weight: Font.Black
                            }

                            TextInput {
                                id: queryInput

                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 36
                                color: Theme.roleOnSurface
                                font.family: Theme.fontSans
                                font.pixelSize: 16
                                selectionColor: Theme.primary
                                selectedTextColor: Theme.surfaceContainer
                                cursorVisible: true
                                clip: true
                                Keys.priority: Keys.BeforeItem
                                Keys.onPressed: event => {
                                    panel.handleNavigationEvent(event);
                                }
                                onTextEdited: {
                                    panel.queryText = text;
                                    presentationModel.resetSurfaceState();
                                    panel.pendingSearchSourceCode = "launcher.ui.input";
                                    searchDebounce.restart();
                                }
                            }
                        }
                    }

                    Text {
                        visible: String(panel.launcherState.error || "").length > 0
                        text: panel.launcherState.error
                        color: Theme.tertiary
                        font.family: Theme.fontSans
                        font.pixelSize: 12
                    }

                    Text {
                        text: "Ctrl+Shift+P pin command  |  Ctrl+Shift+↑/↓ reorder pin  |  Ctrl+Space preview file"
                        color: Theme.roleOnSurfaceVariant
                        opacity: 0.82
                        font.family: Theme.fontMono
                        font.pixelSize: 11
                    }

                    Flickable {
                        id: resultFlick

                        width: parent.width
                        height: parent.height - (Theme.padding + 120)
                        contentWidth: width
                        contentHeight: Math.max(resultColumn.implicitHeight, height)
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height
                        maximumFlickVelocity: 5200
                        flickDeceleration: 1700

                        WheelHandler {
                            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                            onWheel: event => {
                                const maxContentY = Math.max(0, resultFlick.contentHeight - resultFlick.height);
                                if (maxContentY <= 0)
                                    return;
                                const delta = Number(event.pixelDelta.y);
                                const fallback = Number(event.angleDelta.y) * 0.45;
                                const step = Number.isFinite(delta) && delta !== 0 ? delta * 1.35 : fallback;
                                if (!Number.isFinite(step) || step === 0)
                                    return;
                                resultFlick.contentY = Math.max(0, Math.min(maxContentY, resultFlick.contentY - step));
                                event.accepted = true;
                            }
                        }

                        ScrollBar.vertical: ScrollBar {
                            id: launcherScrollBar

                            policy: ScrollBar.AsNeeded
                            width: 8
                            minimumSize: 0.08
                            visible: resultFlick.contentHeight > resultFlick.height
                            anchors.right: parent.right
                            anchors.rightMargin: 4

                            contentItem: Rectangle {
                                implicitWidth: launcherScrollBar.width
                                radius: launcherScrollBar.width / 2
                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, launcherScrollBar.pressed ? 0.72 : 0.56)
                            }

                            background: Rectangle {
                                radius: launcherScrollBar.width / 2
                                color: Qt.rgba(Theme.surfaceContainerHighest.r, Theme.surfaceContainerHighest.g, Theme.surfaceContainerHighest.b, 0.34)
                            }
                        }

                        Column {
                            id: resultColumn

                            width: resultFlick.width
                            spacing: Theme.gap

                            Rectangle {
                                visible: presentationModel.totalItemCount === 0
                                width: parent.width
                                implicitHeight: 120
                                radius: Theme.radius
                                color: Theme.surfaceContainer
                                border.width: 1
                                border.color: Theme.outline

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 8

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "No launcher results"
                                        color: Theme.roleOnSurface
                                        font.family: Theme.fontSans
                                        font.pixelSize: 18
                                        font.weight: Font.DemiBold
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "Try app names, commands with >, or math expressions."
                                        color: Theme.roleOnSurfaceVariant
                                        font.family: Theme.fontSans
                                        font.pixelSize: 13
                                    }
                                }
                            }

                            Repeater {
                                model: presentationModel.sections

                                Column {
                                    id: sectionBlock

                                    required property var modelData
                                    required property int index
                                    property int sectionIndex: index

                                    width: resultColumn.width
                                    spacing: 8

                                    Text {
                                        text: sectionBlock.modelData.title
                                        color: Theme.roleOnSurfaceVariant
                                        font.family: Theme.fontSans
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                    }

                                    Repeater {
                                        model: sectionBlock.modelData.items

                                        Rectangle {
                                            id: resultCard

                                            required property var modelData
                                            required property int index
                                            property int globalIndex: panel.globalIndexFor(sectionBlock.sectionIndex, index)
                                            readonly property bool active: presentationModel.highlightedIndex === globalIndex
                                            readonly property string subtitleText: {
                                                const subtitle = resultCard.modelData.subtitle === undefined ? "" : String(resultCard.modelData.subtitle);
                                                if (subtitle.length > 0)
                                                    return subtitle;
                                                return String(resultCard.modelData.id || "");
                                            }
                                            readonly property string detailText: resultCard.modelData.detail === undefined ? "" : String(resultCard.modelData.detail)
                                            readonly property bool hasDetailText: detailText.length > 0 && detailText !== subtitleText
                                            readonly property string iconName: resultCard.modelData.iconName === undefined ? "" : String(resultCard.modelData.iconName)
                                            readonly property string iconSource: iconName.length > 0 ? Quickshell.iconPath(iconName) : ""
                                            readonly property int pinOrder: Number(resultCard.modelData.pinOrder)
                                            readonly property bool pinned: resultCard.modelData.pinned === true || (Number.isInteger(pinOrder) && pinOrder >= 0)
                                            readonly property string pinBadgeText: (Number.isInteger(pinOrder) && pinOrder >= 0) ? "#" + String(pinOrder + 1) : "PIN"
                                            readonly property string fallbackGlyph: {
                                                const provider = String(resultCard.modelData.provider || "");
                                                if (provider === "calculator")
                                                    return "󰃬";
                                                if (provider === "commands")
                                                    return "󱓞";
                                                if (provider === "apps")
                                                    return "󰀻";
                                                if (provider === "clipboard")
                                                    return "󰅌";
                                                if (provider === "emoji")
                                                    return "󰞅";
                                                if (provider === "web")
                                                    return "󰖟";
                                                if (provider === "windows")
                                                    return "󰖲";
                                                return "󰈔";
                                            }

                                            function reportGeometry(): void {
                                                const mapped = resultCard.mapToItem(resultColumn, 0, 0);
                                                panel.registerItemGeometry(globalIndex, mapped.y, resultCard.height);
                                            }

                                            width: sectionBlock.width
                                            implicitHeight: hasDetailText ? 72 : 58
                                            radius: Theme.chipRadius
                                            color: active ? Theme.surfaceContainerHighest : Theme.surfaceContainer
                                            border.width: 1
                                            border.color: active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.65) : Theme.outline
                                            Component.onCompleted: reportGeometry()
                                            Component.onDestruction: panel.unregisterItemGeometry(globalIndex)
                                            onYChanged: reportGeometry()
                                            onHeightChanged: reportGeometry()

                                            Row {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 12

                                                Rectangle {
                                                    width: 34
                                                    height: 34
                                                    radius: 10
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: resultCard.active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.2)
                                                    border.width: 1
                                                    border.color: resultCard.active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.5) : Theme.outline

                                                    IconImage {
                                                        anchors.centerIn: parent
                                                        width: 20
                                                        height: 20
                                                        source: resultCard.iconSource
                                                        visible: resultCard.iconSource.length > 0
                                                    }

                                                    Text {
                                                        anchors.centerIn: parent
                                                        visible: resultCard.iconSource.length <= 0
                                                        text: resultCard.fallbackGlyph
                                                        color: Theme.roleOnSurfaceVariant
                                                        font.family: Theme.fontSans
                                                        font.pixelSize: 15
                                                    }
                                                }

                                                Column {
                                                    width: parent.width - 46 - (pinBadge.visible ? pinBadge.width + 8 : 0)
                                                    spacing: 2

                                                    Text {
                                                        text: resultCard.modelData.title
                                                        color: Theme.roleOnSurface
                                                        font.family: Theme.fontSans
                                                        font.pixelSize: 14
                                                        font.weight: Font.DemiBold
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        text: resultCard.subtitleText
                                                        color: Theme.roleOnSurfaceVariant
                                                        font.family: Theme.fontMono
                                                        font.pixelSize: 11
                                                        elide: Text.ElideRight
                                                    }

                                                    Text {
                                                        visible: resultCard.hasDetailText
                                                        text: resultCard.detailText
                                                        color: Qt.rgba(Theme.roleOnSurfaceVariant.r, Theme.roleOnSurfaceVariant.g, Theme.roleOnSurfaceVariant.b, 0.85)
                                                        font.family: Theme.fontSans
                                                        font.pixelSize: 11
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                Rectangle {
                                                    id: pinBadge

                                                    visible: resultCard.pinned
                                                    width: 44
                                                    height: 22
                                                    radius: 11
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
                                                    border.width: 1
                                                    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.42)

                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: resultCard.pinBadgeText
                                                        color: Theme.primary
                                                        font.family: Theme.fontMono
                                                        font.pixelSize: 10
                                                        font.weight: Font.DemiBold
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onEntered: presentationModel.highlightedIndex = resultCard.globalIndex
                                                onClicked: {
                                                    presentationModel.highlightedIndex = resultCard.globalIndex;
                                                    root.shell.activateLauncherItemFromUi(resultCard.modelData.id);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

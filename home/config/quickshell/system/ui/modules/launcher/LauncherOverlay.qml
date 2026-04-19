pragma ComponentBehavior: Bound
import QtQuick
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

        readonly property var launcherState: root.shell && root.shell.launcherStore ? root.shell.launcherStore.state : ({
                phase: "idle",
                error: "",
                pendingProviders: []
            })
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

            store: root.shell.launcherStore
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
                const action = LauncherOverlayController.decideNavigationAction({
                    key: event.key,
                    controlPressed: (event.modifiers & Qt.ControlModifier) !== 0,
                    hasAutocompleteCandidate: panel.canApplyCommandAutocomplete(),
                    totalItemCount: presentationModel.totalItemCount,
                    keyCodes: panel.navigationKeyCodes
                });
                if (!action || action.kind === "noop")
                    return;

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

                event.accepted = true;
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

                    Flickable {
                        id: resultFlick

                        width: parent.width
                        height: parent.height - (Theme.padding + 120)
                        contentWidth: width
                        contentHeight: Math.max(resultColumn.implicitHeight, height)
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: contentHeight > height

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
                                                    width: parent.width - 46
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

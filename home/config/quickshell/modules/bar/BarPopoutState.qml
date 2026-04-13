import QtQuick

QtObject {
    id: root

    property string currentName: ""
    property Item currentTarget: null
    property Component currentContent: null
    property int currentWidth: 0
    property bool popupHovered: false

    property string displayName: ""
    property Item displayTarget: null
    property Component displayContent: null
    property int displayWidth: 0

    readonly property bool open: currentName.length > 0 && currentTarget !== null && currentContent !== null
    readonly property bool visible: displayName.length > 0 && displayTarget !== null && displayContent !== null

    function show(name, target, content, width): void {
        currentName = name;
        currentTarget = target;
        currentContent = content;
        currentWidth = width;
        displayName = name;
        displayTarget = target;
        displayContent = content;
        displayWidth = width;
    }

    function hide(): void {
        currentName = "";
        currentTarget = null;
        currentContent = null;
        currentWidth = 0;
        popupHovered = false;
    }

    function clearDisplay(): void {
        if (open)
            return;

        displayName = "";
        displayTarget = null;
        displayContent = null;
        displayWidth = 0;
        popupHovered = false;
    }

    function clearAll(): void {
        hide();
        clearDisplay();
    }
}

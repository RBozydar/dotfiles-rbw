import Quickshell

Variants {
    id: root

    required property var shell

    model: Quickshell.screens

    BarScreen {
        required property var modelData

        shell: root.shell
        screen: modelData
    }
}

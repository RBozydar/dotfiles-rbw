import Quickshell
import "bar" as BarParts

Variants {
    id: root

    required property var shell

    model: Quickshell.screens

    BarParts.BarScreen {
        required property var modelData

        shell: root.shell
        screen: modelData
    }
}

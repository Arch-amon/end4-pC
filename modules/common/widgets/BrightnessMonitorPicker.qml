import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell

// Picks the monitor the brightness and gamma sliders act on.
ConfigSelectionArray {
    id: root
    property var currentScreen
    readonly property var target: Brightness.targetMonitor(root.currentScreen)

    currentValue: root.target?.name ?? ""
    onSelected: newValue => Brightness.selectedScreenName = newValue
    options: Brightness.monitors.map(monitor => ({
        displayName: Brightness.displayName(monitor),
        // gamma-only screens (no DDC/CI, no backlight) are usually TVs
        icon: monitor.hasHardwareBrightness ? "monitor" : "tv",
        value: monitor.name
    }))
}

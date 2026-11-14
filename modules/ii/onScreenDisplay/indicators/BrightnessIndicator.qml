import qs.services
import QtQuick
import Quickshell
import qs.modules.ii.onScreenDisplay

OsdValueIndicator {
    id: root
    readonly property var brightnessMonitor: Brightness.osdMonitor()

    icon: Hyprsunset.temperatureActive ? "routine" : "light_mode"
    rotateIcon: true
    scaleIcon: true
    name: Quickshell.screens.length > 1
        ? `${Translation.tr("Brightness")} · ${Brightness.displayName(root.brightnessMonitor)}`
        : Translation.tr("Brightness")
    value: root.brightnessMonitor?.brightness ?? 0.5
}

import qs.services
import QtQuick
import Quickshell
import qs.modules.ii.onScreenDisplay

OsdValueIndicator {
    id: root
    readonly property var monitor: Brightness.osdMonitor()

    icon: "wb_twilight"
    name: Quickshell.screens.length > 1
        ? `${Translation.tr("Gamma")} · ${Brightness.displayName(root.monitor)}`
        : Translation.tr("Gamma")
    from: MonitorGamma.lowerLimit / 100
    value: (root.monitor?.gamma ?? 100) / 100
}

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var layers: ({})
    // Space reserved by each monitor's bar: output name -> { edge, size }
    property var barZones: ({})
    property real dockZone: 0
    property string dockEdge: "bottom"

    function setBarZone(screenName, edge, size) {
        if (!screenName) return;
        const current = root.barZones[screenName];
        if (current && current.edge === edge && current.size === size) return;
        const zones = Object.assign({}, root.barZones);
        zones[screenName] = { edge: edge, size: size };
        root.barZones = zones;
    }

    function clearBarZone(screenName) {
        if (!(screenName in root.barZones)) return;
        const zones = Object.assign({}, root.barZones);
        delete zones[screenName];
        root.barZones = zones;
    }

    // Space reserved along `edge` ("top", "bottom", "left", "right") of a monitor
    function zoneFor(screenName, edge) {
        const bar = root.barZones[screenName];
        return (bar && bar.edge === edge ? bar.size : 0) + (root.dockEdge === edge ? root.dockZone : 0);
    }

    function refresh() {
        debounce.restart()
    }

    Timer {
        id: debounce
        interval: 40
        onTriggered: {
            collector.running = false
            collector.running = true
        }
    }

    Process {
        id: collector
        command: ["hyprctl", "layers", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.layers = JSON.parse(text)
                } catch (e) {}
            }
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Scope {
    id: root

    // Each monitor's frame follows that monitor's bar settings.
    component FrameGroup: Item {
        id: group
        required property var modelData
        readonly property var barOpts: ScreenConfig.barFor(modelData)
        readonly property bool hasBar: ScreenConfig.hasBar(modelData)
        readonly property real frameThickness: barOpts.frameThickness
        readonly property color frameColor: Appearance.getColorFromName(barOpts.frameColor)
        readonly property bool centerOnly: barOpts.layouts.leftLayout.length === 0 && barOpts.layouts.rightLayout.length === 0
        readonly property string barPosition: ScreenConfig.barEdgeFor(barOpts)

        function frameVisibleFor(side) {
            if (!group.barOpts.showFrame) return false
            // The hug bar draws its own edge, unless it has nothing to hug
            if (group.hasBar && group.barOpts.cornerStyle === 0 && side === group.barPosition) {
                return group.centerOnly || !group.barOpts.showBackground
            }
            return true
        }

        function edgeNeedsInput(side) {
            if (!frameVisibleFor(side)) return false
            const dockWants = Config.options.dock.enable && Config.options.dock.hoverToReveal && Config.options.dock.position === side
            const barWants = group.hasBar && group.barOpts.autoHide.enable && group.barPosition === side
            return dockWants || barWants
        }
    }

    component FrameHoverArea: MouseArea {
        required property string side
        required property FrameGroup group
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: group.edgeNeedsInput(side)
        onContainsMouseChanged: GlobalStates.setFrameHover(group.modelData.name, side, containsMouse)
    }

    Variants {
        model: Quickshell.screens

        FrameGroup {
            id: frameGroup

            PanelWindow { // top
                screen: frameGroup.modelData
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: frameGroup.frameVisibleFor("top") ? frameGroup.frameThickness : 0
                WlrLayershell.namespace: "quickshell:screenframe"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                color: "transparent"
                implicitHeight: frameGroup.frameThickness
                anchors { top: true; left: true; right: true }
                mask: Region { item: frameGroup.edgeNeedsInput("top") ? topRect : null }

                Rectangle { id: topRect; anchors.fill: parent; color: frameGroup.frameColor; visible: frameGroup.frameVisibleFor("top") }

                FrameHoverArea { side: "top"; group: frameGroup }
            }

            PanelWindow { // bottom
                screen: frameGroup.modelData
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: frameGroup.frameVisibleFor("bottom") ? frameGroup.frameThickness : 0
                WlrLayershell.namespace: "quickshell:screenframe"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                color: "transparent"
                implicitHeight: frameGroup.frameThickness
                anchors { bottom: true; left: true; right: true }
                mask: Region { item: frameGroup.edgeNeedsInput("bottom") ? bottomRect : null }

                Rectangle { id: bottomRect; anchors.fill: parent; color: frameGroup.frameColor; visible: frameGroup.frameVisibleFor("bottom") }

                FrameHoverArea { side: "bottom"; group: frameGroup }
            }

            PanelWindow { // left
                screen: frameGroup.modelData
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: frameGroup.frameVisibleFor("left") ? frameGroup.frameThickness : 0
                WlrLayershell.namespace: "quickshell:screenframe"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                color: "transparent"
                implicitWidth: frameGroup.frameThickness
                anchors { left: true; top: true; bottom: true }
                mask: Region { item: frameGroup.edgeNeedsInput("left") ? leftRect : null }

                Rectangle { id: leftRect; anchors.fill: parent; color: frameGroup.frameColor; visible: frameGroup.frameVisibleFor("left") }

                FrameHoverArea { side: "left"; group: frameGroup }
            }

            PanelWindow { // right
                screen: frameGroup.modelData
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: frameGroup.frameVisibleFor("right") ? frameGroup.frameThickness : 0
                WlrLayershell.namespace: "quickshell:screenframe"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                color: "transparent"
                implicitWidth: frameGroup.frameThickness
                anchors { right: true; top: true; bottom: true }
                mask: Region { item: frameGroup.edgeNeedsInput("right") ? rightRect : null }

                Rectangle { id: rightRect; anchors.fill: parent; color: frameGroup.frameColor; visible: frameGroup.frameVisibleFor("right") }

                FrameHoverArea { side: "right"; group: frameGroup }
            }
        }
    }
}
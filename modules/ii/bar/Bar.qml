pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Scope {
    id: bar

    Variants {
        // Monitors whose bar is horizontal. Waits for the monitor
        // profiles so a customized bar doesn't first appear in the global style.
        model: ScreenConfig.ready
            ? Quickshell.screens.filter(screen => ScreenConfig.hasBar(screen) && !ScreenConfig.barFor(screen).vertical)
            : []
        LazyLoader {
            id: barLoader
            active: GlobalStates.barOpen && !GlobalStates.screenLocked && !GlobalStates.startupLockPending
            required property ShellScreen modelData
            component: PanelWindow { // Bar window
                id: barRoot
                screen: barLoader.modelData
                // This monitor's bar settings (its own, or the global ones)
                readonly property var barOpts: ScreenConfig.barFor(barLoader.modelData)

                Timer {
                    id: showBarTimer
                    interval: (barRoot.barOpts.autoHide.showWhenPressingSuper.delay ?? 100)
                    repeat: false
                    onTriggered: {
                        barRoot.superShow = true
                    }
                }
                Connections {
                    target: GlobalStates
                    function onSuperDownChanged() {
                        if (!barRoot.barOpts.autoHide.showWhenPressingSuper.enable) return;
                        if (GlobalStates.superDown) showBarTimer.restart();
                        else {
                            showBarTimer.stop();
                            barRoot.superShow = false;
                        }
                    }
                }

                property bool showCorners: !barRoot.barOpts.autoHide.enable || mustShow

                Timer {
                    id: cornerRevealTimer
                    interval: 65
                    onTriggered: barRoot.showCorners = true
                }

                onMustShowChanged: {
                    if (!barRoot.barOpts.autoHide.enable) return;
                    if (mustShow) {
                        cornerRevealTimer.restart()
                    } else {
                        cornerRevealTimer.stop()
                        barRoot.showCorners = false
                    }
                }
                property bool superShow: false
                property bool mustShow: hoverRegion.containsMouse || superShow
                    || (barRoot.barOpts.autoHide.enable && GlobalStates.isFrameHovered(barRoot.screen?.name, barRoot.barOpts.bottom ? "bottom" : "top"))
                property var thisMonitorData: HyprlandData.monitors.find(m => m.name === barRoot.screen?.name)
                property bool monitorHasFullscreen: HyprlandData.workspaceById[thisMonitorData?.activeWorkspace?.id]?.hasfullscreen ?? false
                property bool monitorHasSpecialOpen: (thisMonitorData?.specialWorkspace?.name ?? "") !== ""
                exclusionMode: ExclusionMode.Ignore
                property int normalExclusiveZone: (barRoot.barOpts.autoHide.enable && (!mustShow || !barRoot.barOpts.autoHide.pushWindows))
                    ? 0
                    : Appearance.sizes.baseBarHeight
                        + (barRoot.barOpts.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0)
                        + (barRoot.barOpts.cornerStyle === 2 ? -6 : 0)

                exclusiveZone: (barContent.centerOnly && barRoot.barOpts.centerOnlyReserveFrame)
                    ? barRoot.barOpts.frameThickness
                    : (barRoot.barOpts.cornerStyle === 4 || barRoot.barOpts.cornerStyle === 5 || barRoot.barOpts.cornerStyle === 6) ? normalExclusiveZone + 4 : normalExclusiveZone
                WlrLayershell.namespace: "quickshell:bar"
                // Overlay layer only while special workspace sits on top of a fullscreen window on this monitor,
                // else Top layer so fullscreen apps cover the bar as normal (Hyprland buries Top layer under fullscreen+special).
                WlrLayershell.layer: (monitorHasFullscreen && monitorHasSpecialOpen) ? WlrLayer.Overlay : WlrLayer.Top
                implicitHeight: ScreenConfig.barHeightFor(barRoot.barOpts) + Appearance.rounding.screenRounding
                // When Overlay-layer, bar shares a layer with the screen-corner click zones (ScreenCorners.qml)
                // and same-layer overlap is resolved by stacking, not layer priority - bar was winning and
                // swallowing the tiny corner-open hit rects. Carve them out of the bar's own mask so clicks
                // reach the corners underneath. Only relevant on the edge the bar and corners share.
                property bool cutOutCornerOpenZones: (monitorHasFullscreen && monitorHasSpecialOpen) && (barRoot.barOpts.bottom === Config.options.sidebar.cornerOpen.bottom)
                property int cornerOpenCutWidth: cutOutCornerOpenZones ? Config.options.sidebar.cornerOpen.cornerRegionWidth : 0
                property int cornerOpenCutHeight: cutOutCornerOpenZones ? Config.options.sidebar.cornerOpen.cornerRegionHeight : 0
                mask: Region {
                    item: hoverMaskRegion
                    Region {
                        intersection: Intersection.Subtract
                        x: 0
                        y: barRoot.barOpts.bottom ? (barRoot.height - barRoot.cornerOpenCutHeight) : 0
                        width: barRoot.cornerOpenCutWidth
                        height: barRoot.cornerOpenCutHeight
                    }
                    Region {
                        intersection: Intersection.Subtract
                        x: barRoot.width - barRoot.cornerOpenCutWidth
                        y: barRoot.barOpts.bottom ? (barRoot.height - barRoot.cornerOpenCutHeight) : 0
                        width: barRoot.cornerOpenCutWidth
                        height: barRoot.cornerOpenCutHeight
                    }
                }
                color: "transparent"

                // Positioning
                anchors {
                    top: !barRoot.barOpts.bottom
                    bottom: barRoot.barOpts.bottom
                    left: true
                    right: true
                }

                margins {
                    top: barRoot.barOpts.cornerStyle === 3 ? 5 : 0
                    right: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.right) * -1
                    bottom: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.bottom) * -1 || barRoot.barOpts.cornerStyle === 3 ? 5 : 0
                }

                // Include in focus grab
                Component.onCompleted: {
                    GlobalFocusGrab.addPersistent(barRoot);
                }
                Component.onDestruction: {
                    GlobalFocusGrab.removePersistent(barRoot);
                }

                MouseArea  {
                    id: hoverRegion
                    readonly property string glassEdge: barRoot.barOpts.bottom ? "bottom" : "top"
                    readonly property real glassSize: Math.max(0, barRoot.exclusiveZone)
                    onGlassEdgeChanged: GlassLayers.setBarZone(barRoot.screen?.name, glassEdge, glassSize)
                    onGlassSizeChanged: GlassLayers.setBarZone(barRoot.screen?.name, glassEdge, glassSize)
                    Component.onCompleted: GlassLayers.setBarZone(barRoot.screen?.name, glassEdge, glassSize)
                    Component.onDestruction: GlassLayers.clearBarZone(barRoot.screen?.name)

                    hoverEnabled: true
                    anchors {
                        fill: parent
                        rightMargin: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.right) * 1
                        bottomMargin: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.bottom) * 1
                    }

                    Item {
                        id: hoverMaskRegion
                        anchors {
                            fill: barContent
                            topMargin: -barRoot.barOpts.autoHide.hoverRegionWidth
                            bottomMargin: -barRoot.barOpts.autoHide.hoverRegionWidth
                        }
                    }

                    BarContent {
                        id: barContent
                        barOpts: barRoot.barOpts
                        
                        implicitHeight: ScreenConfig.barHeightFor(barRoot.barOpts)
                        anchors {
                            right: parent.right
                            left: parent.left
                            top: parent.top
                            bottom: undefined
                            topMargin: (barRoot.barOpts.autoHide.enable && !mustShow) ? -ScreenConfig.barHeightFor(barRoot.barOpts) : 0
                            bottomMargin: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.bottom) * -1
                            rightMargin: (Config.options.interactions.deadPixelWorkaround.enable && barRoot.anchors.right) * -1
                        }
                        Behavior on anchors.topMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        Behavior on anchors.bottomMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }

                        states: State {
                            name: "bottom"
                            when: barRoot.barOpts.bottom
                            AnchorChanges {
                                target: barContent
                                anchors {
                                    right: parent.right
                                    left: parent.left
                                    top: undefined
                                    bottom: parent.bottom
                                }
                            }
                            PropertyChanges {
                                target: barContent
                                anchors.topMargin: 0
                                anchors.bottomMargin: (barRoot.barOpts.autoHide.enable && !mustShow) ? -ScreenConfig.barHeightFor(barRoot.barOpts) : 0
                            }
                        }
                    }
                    
                    // Round decorators
                    Loader {
                        id: roundDecorators
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: barContent.bottom
                            bottom: undefined
                        }
                        height: Appearance.rounding.screenRounding
                        active: !barContent.glassTabs && !barContent.glassHug && ((barRoot.barOpts.showBackground && barRoot.barOpts.cornerStyle === 0 && !barContent.centerOnly)
                             || (barRoot.barOpts.cornerStyle === 4 || barRoot.barOpts.cornerStyle === 6))

                        states: State {
                            name: "bottom"
                            when: barRoot.barOpts.bottom
                            AnchorChanges {
                                target: roundDecorators
                                anchors {
                                    right: parent.right
                                    left: parent.left
                                    top: undefined
                                    bottom: barContent.top
                                }
                            }
                        }

                        sourceComponent: Item {
                            implicitHeight: Appearance.rounding.screenRounding

                            readonly property color decoratorColor: (barRoot.barOpts.cornerStyle === 4 || barRoot.barOpts.cornerStyle === 6 || barRoot.barOpts.showBackground)
                                ? (barRoot.barOpts.followFrameColor && barRoot.barOpts.frameColor
                                    ? Appearance.getColorFromName(barRoot.barOpts.frameColor)
                                    : Appearance.colors.colUiBackground)
                                : "transparent"

                            RoundCorner {
                                id: leftCorner
                                glass: true
                                visible: barRoot.barOpts.cornerStyle === 0 || barContent.effectiveLeftLayout.length > 0
                                anchors {
                                    top: parent.top
                                    bottom: parent.bottom
                                    left: parent.left
                                }

                                implicitSize: Appearance.rounding.screenRounding
                                color: parent.decoratorColor

                                corner: RoundCorner.CornerEnum.TopLeft
                                states: State {
                                    name: "bottom"
                                    when: barRoot.barOpts.bottom
                                    PropertyChanges {
                                        leftCorner.corner: RoundCorner.CornerEnum.BottomLeft
                                    }
                                }
                            }
                            RoundCorner {
                                id: rightCorner
                                glass: true
                                visible: barRoot.barOpts.cornerStyle === 0 || barContent.effectiveRightLayout.length > 0
                                anchors {
                                    right: parent.right
                                    top: !barRoot.barOpts.bottom ? parent.top : undefined
                                    bottom: barRoot.barOpts.bottom ? parent.bottom : undefined
                                }
                                implicitSize: Appearance.rounding.screenRounding
                                color: parent.decoratorColor

                                corner: RoundCorner.CornerEnum.TopRight
                                states: State {
                                    name: "bottom"
                                    when: barRoot.barOpts.bottom
                                    PropertyChanges {
                                        rightCorner.corner: RoundCorner.CornerEnum.BottomRight
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "bar"

        function toggle(): void {
            GlobalStates.barOpen = !GlobalStates.barOpen
        }

        function close(): void {
            GlobalStates.barOpen = false
        }

        function open(): void {
            GlobalStates.barOpen = true
        }
    }

    CompositorGlobalShortcut {
        name: "barToggle"
        description: "Toggles bar on press"

        onPressed: {
            GlobalStates.barOpen = !GlobalStates.barOpen;
        }
    }

    CompositorGlobalShortcut {
        name: "barOpen"
        description: "Opens bar on press"

        onPressed: {
            GlobalStates.barOpen = true;
        }
    }

    CompositorGlobalShortcut {
        name: "barClose"
        description: "Closes bar on press"

        onPressed: {
            GlobalStates.barOpen = false;
        }
    }
}

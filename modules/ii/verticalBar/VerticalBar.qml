import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Scope {
    id: bar

    Variants {
        // Monitors whose bar is vertical. Waits for the monitor
        // profiles so a customized bar doesn't first appear in the global style.
        model: ScreenConfig.ready
            ? Quickshell.screens.filter(screen => ScreenConfig.hasBar(screen) && ScreenConfig.barFor(screen).vertical)
            : []
        LazyLoader {
            id: barLoader
            active: GlobalStates.barOpen && !GlobalStates.screenLocked
            required property ShellScreen modelData
            component: PanelWindow {
                id: barRoot
                screen: barLoader.modelData
                // This monitor's bar settings (its own, or the global ones)
                readonly property var barOpts: ScreenConfig.barFor(barLoader.modelData)

                property var brightnessMonitor: Brightness.getMonitorForScreen(barLoader.modelData)
                
                Timer {
                    id: showBarTimer
                    interval: (barRoot.barOpts.autoHide.showWhenPressingSuper.delay ?? 100)
                    repeat: false
                    onTriggered: { barRoot.superShow = true }
                }
                Connections {
                    target: GlobalStates
                    function onSuperDownChanged() {
                        if (!barRoot.barOpts.autoHide.showWhenPressingSuper.enable) return;
                        if (GlobalStates.superDown) showBarTimer.restart();
                        else { showBarTimer.stop(); barRoot.superShow = false; }
                    }
                }
                property bool superShow: false
                property bool mustShow: hoverRegion.containsMouse || superShow
                    || (barRoot.barOpts.autoHide.enable && GlobalStates.isFrameHovered(barRoot.screen?.name, barRoot.barOpts.bottom ? "right" : "left"))
                exclusionMode: ExclusionMode.Ignore
                property int normalExclusiveZone: (barRoot.barOpts.autoHide.enable && (!mustShow || !barRoot.barOpts.autoHide.pushWindows))
                    ? 0
                    : Appearance.sizes.baseVerticalBarWidth
                        + (barRoot.barOpts.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0)
                        + (barRoot.barOpts.cornerStyle === 3 ? (Appearance.sizes.hyprlandGapsOut || 5) : 0)

                exclusiveZone: (barContent.centerOnly && barRoot.barOpts.centerOnlyReserveFrame)
                    ? barRoot.barOpts.frameThickness
                    : normalExclusiveZone
                WlrLayershell.namespace: "quickshell:verticalBar"
                implicitWidth: ScreenConfig.verticalBarWidthFor(barRoot.barOpts) + Appearance.rounding.screenRounding
                mask: Region { item: hoverMaskRegion }
                color: "transparent"

                anchors {
                    left: !barRoot.barOpts.bottom
                    right: barRoot.barOpts.bottom
                    top: true
                    bottom: true
                }

                Component.onCompleted: { GlobalFocusGrab.addPersistent(barRoot); }
                Component.onDestruction: { GlobalFocusGrab.removePersistent(barRoot); }

                MouseArea {
                    id: hoverRegion
                    hoverEnabled: true
                    anchors.fill: parent

                    readonly property string glassEdge: barRoot.barOpts.bottom ? "right" : "left"
                    readonly property real glassSize: Math.max(0, barRoot.exclusiveZone)
                    onGlassEdgeChanged: GlassLayers.setBarZone(barRoot.screen?.name, glassEdge, glassSize)
                    onGlassSizeChanged: GlassLayers.setBarZone(barRoot.screen?.name, glassEdge, glassSize)
                    Component.onCompleted: GlassLayers.setBarZone(barRoot.screen?.name, glassEdge, glassSize)
                    Component.onDestruction: GlassLayers.clearBarZone(barRoot.screen?.name)

                    Item {
                        id: hoverMaskRegion
                        anchors {
                            fill: barContent
                            leftMargin: -barRoot.barOpts.autoHide.hoverRegionWidth
                            rightMargin: -barRoot.barOpts.autoHide.hoverRegionWidth
                        }
                    }

                    RoundCorner {
                        id: topPillCorner
                        glass: true
                        visible: barContent.centerOnly && barRoot.barOpts.showBackground && barRoot.barOpts.cornerStyle === 0 && !barContent.glassHug
                        y: barContent.centerPillY - implicitSize
                        implicitSize: Appearance.rounding.screenRounding
                        color: barRoot.barOpts.followFrameColor
                            ? Appearance.getColorFromName(barRoot.barOpts.frameColor)
                            : Appearance.colors.colUiBackground
                        corner: RoundCorner.CornerEnum.BottomLeft

                        states: State {
                            name: "right"
                            when: barRoot.barOpts.bottom
                            AnchorChanges {
                                target: topPillCorner
                                anchors.left: undefined
                                anchors.right: barContent.right
                            }
                            PropertyChanges {
                                target: topPillCorner
                                corner: RoundCorner.CornerEnum.BottomRight
                            }
                        }
                        AnchorChanges {
                            target: topPillCorner
                            anchors.left: barContent.right
                            anchors.right: undefined
                        }
                    }

                    RoundCorner {
                        id: bottomPillCorner
                        glass: true
                        visible: barContent.centerOnly && barRoot.barOpts.showBackground && barRoot.barOpts.cornerStyle === 0 && !barContent.glassHug
                        y: barContent.centerPillY + barContent.centerPillHeight
                        implicitSize: Appearance.rounding.screenRounding
                        color: barRoot.barOpts.followFrameColor
                            ? Appearance.getColorFromName(barRoot.barOpts.frameColor)
                            : Appearance.colors.colUiBackground
                        corner: RoundCorner.CornerEnum.TopLeft

                        states: State {
                            name: "right"
                            when: barRoot.barOpts.bottom
                            AnchorChanges {
                                target: bottomPillCorner
                                anchors.left: undefined
                                anchors.right: barContent.right
                            }
                            PropertyChanges {
                                target: bottomPillCorner
                                corner: RoundCorner.CornerEnum.TopRight
                            }
                        }
                        AnchorChanges {
                            target: bottomPillCorner
                            anchors.left: barContent.right
                            anchors.right: undefined
                        }
                    }

                    VerticalBarContent {
                        id: barContent

                        implicitWidth: ScreenConfig.verticalBarWidthFor(barRoot.barOpts)
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            left: parent.left
                            right: undefined
                            leftMargin: (barRoot.barOpts.autoHide.enable && !mustShow) 
                                ? -ScreenConfig.verticalBarWidthFor(barRoot.barOpts) 
                                : (barRoot.barOpts.cornerStyle === 3 ? (Appearance.sizes.hyprlandGapsOut || 5) : 0)
                        }
                        Behavior on anchors.leftMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        Behavior on anchors.rightMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }

                        states: State {
                            name: "right"
                            when: barRoot.barOpts.bottom
                            AnchorChanges {
                                target: barContent
                                anchors {
                                    top: parent.top
                                    bottom: parent.bottom
                                    left: undefined
                                    right: parent.right
                                }
                            }
                            PropertyChanges {
                                target: barContent
                                anchors.topMargin: 0
                                anchors.rightMargin: (barRoot.barOpts.autoHide.enable && !mustShow)
                                    ? -ScreenConfig.barHeightFor(barRoot.barOpts)
                                    : (barRoot.barOpts.cornerStyle === 3 ? (Appearance.sizes.hyprlandGapsOut || 5) : 0)
                            }
                        }
                    }

                    // Round decorators
                    Loader {
                        id: roundDecorators
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            left: barContent.right
                            right: undefined
                        }
                        width: Appearance.rounding.screenRounding
                        active: !barContent.glassTabs && !barContent.glassHug && ((barRoot.barOpts.showBackground && barRoot.barOpts.cornerStyle === 0 && !barContent.centerOnly)
                             || (barRoot.barOpts.cornerStyle === 4 || barRoot.barOpts.cornerStyle === 6))

                        states: State {
                            name: "right"
                            when: barRoot.barOpts.bottom
                            AnchorChanges {
                                target: roundDecorators
                                anchors {
                                    top: parent.top
                                    bottom: parent.bottom
                                    left: undefined
                                    right: barContent.left
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
                                id: topCorner
                                glass: true
                                visible: barRoot.barOpts.cornerStyle === 0 || barContent.effectiveLeftLayout.length > 0
                                anchors { left: parent.left; right: parent.right; top: parent.top }
                                implicitSize: Appearance.rounding.screenRounding
                                width: implicitSize
                                height: implicitSize
                                color: parent.decoratorColor
                                corner: RoundCorner.CornerEnum.TopLeft
                                states: State {
                                    name: "bottom"
                                    when: barRoot.barOpts.bottom
                                    PropertyChanges { topCorner.corner: RoundCorner.CornerEnum.TopRight }
                                }
                            }
                            RoundCorner {
                                id: bottomCorner
                                glass: true
                                visible: barRoot.barOpts.cornerStyle === 0 || barContent.effectiveRightLayout.length > 0
                                anchors {
                                    bottom: parent.bottom
                                    left: parent.left
                                    right: parent.right
                                }
                                implicitSize: Appearance.rounding.screenRounding
                                width: implicitSize
                                height: implicitSize
                                color: parent.decoratorColor
                                corner: RoundCorner.CornerEnum.BottomLeft
                                states: State {
                                    name: "bottom"
                                    when: barRoot.barOpts.bottom
                                    PropertyChanges { bottomCorner.corner: RoundCorner.CornerEnum.BottomRight }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // The "bar" IPC target and the bar shortcuts live in Bar.qml, which is
    // always loaded alongside this file and toggles both kinds of bars.
}

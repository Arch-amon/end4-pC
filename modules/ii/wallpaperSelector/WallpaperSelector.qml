import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    property bool reallyOpen: false

    Connections {
        target: GlobalStates
        function onWallpaperSelectorOpenChanged() {
            if (GlobalStates.wallpaperSelectorOpen) {
                closeAnimTimer.stop();
                root.reallyOpen = true;
            } else {
                closeAnimTimer.restart();
            }
        }
    }

    Timer {
        id: closeAnimTimer
        interval: Appearance.animation.sidebarSlideExit.duration
        onTriggered: root.reallyOpen = false
    }

    Loader {
        id: wallpaperSelectorLoader
        active: root.reallyOpen

        sourceComponent: PanelWindow {
            id: panelWindow
            readonly property var monitor: WM.monitorFor(panelWindow.screen)
            readonly property var barOpts: ScreenConfig.barFor(panelWindow.screen)
            property bool monitorIsFocused: WM.compositor === "hyprland"
                ? (Hyprland.focusedMonitor?.name == monitor?.name)
                : (WM.focusedMonitor?.name == monitor?.name)

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:wallpaperSelector"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            color: "transparent"

            anchors.top: true
            margins {
                top: panelWindow.barOpts.vertical ? Appearance.sizes.hyprlandGapsOut : ScreenConfig.barHeightFor(panelWindow.barOpts) + Appearance.sizes.hyprlandGapsOut
            }

            mask: Region {
                item: content
            }

            implicitHeight: Appearance.sizes.wallpaperSelectorHeight
            implicitWidth: Appearance.sizes.wallpaperSelectorWidth

            Component.onCompleted: {
                GlobalFocusGrab.addDismissable(panelWindow);
                content.slideIn();
            }
            Component.onDestruction: {
                GlobalFocusGrab.removeDismissable(panelWindow);
            }
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    GlobalStates.wallpaperSelectorOpen = false;
                }
            }

            WallpaperSelectorContent {
                id: content
                width: parent.width
                height: parent.height
                x: 0
                y: 0

                function slideIn() {
                    content.y = -content.height;
                    if (WM.compositor === "niri") {
                        Qt.callLater(() => { Qt.callLater(() => { content.y = 0; }); });
                    } else {
                        Qt.callLater(() => { content.y = 0; });
                    }
                }

                Connections {
                    target: GlobalStates
                    function onWallpaperSelectorOpenChanged() {
                        if (!GlobalStates.wallpaperSelectorOpen) {
                            content.y = -content.height;
                        }
                    }
                }

                Behavior on y {
                    NumberAnimation {
                        duration: WM.compositor === "niri"
                            ? Appearance.animation.sidebarSlideEnter.duration
                            : Appearance.animation.sidebarSlideExit.duration
                        easing.type: GlobalStates.wallpaperSelectorOpen
                            ? Appearance.animation.sidebarSlideEnter.type
                            : Appearance.animation.sidebarSlideExit.type
                        easing.bezierCurve: GlobalStates.wallpaperSelectorOpen
                            ? Appearance.animation.sidebarSlideEnter.bezierCurve
                            : Appearance.animation.sidebarSlideExit.bezierCurve
                    }
                }
            }
        }
    }

    // The focused monitor if it has its own wallpaper, else the global one
    function defaultTarget() {
        const focused = WM.focusedMonitor?.name ?? "";
        return ScreenConfig.hasOwnWallpaper(focused) ? focused : "";
    }

    function toggleWallpaperSelector() {
        if (Config.options.wallpaperSelector.useSystemFileDialog) {
            Wallpapers.openFallbackPicker(Appearance.m3colors.darkmode, "", root.defaultTarget());
            return;
        }
        if (!GlobalStates.wallpaperSelectorOpen) {
            GlobalStates.wallpaperSelectorTarget = "wallpaper";
            GlobalStates.wallpaperSelectorScreen = root.defaultTarget();
        }
        GlobalStates.wallpaperSelectorOpen = !GlobalStates.wallpaperSelectorOpen
    }

    IpcHandler {
        target: "wallpaperSelector"

        function toggle(): void {
            root.toggleWallpaperSelector();
        }

        function random(): void {
            Wallpapers.randomFromCurrentFolder(Appearance.m3colors.darkmode, root.defaultTarget());
        }
    }

    CompositorGlobalShortcut {
        name: "wallpaperSelectorToggle"
        description: "Toggle wallpaper selector"
        onPressed: {
            root.toggleWallpaperSelector();
        }
    }

    CompositorGlobalShortcut {
        name: "wallpaperSelectorRandom"
        description: "Select random wallpaper in current folder"
        onPressed: {
            Wallpapers.randomFromCurrentFolder(Appearance.m3colors.darkmode, root.defaultTarget());
        }
    }
}
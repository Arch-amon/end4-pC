import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower

Rectangle {
    id: root
    WindowGlass {
        anchors.fill: parent
        glassEnabled: (parent?.color.a ?? 0) > 0
        cardRadius: parent?.radius ?? 0
        tint: parent?.color ?? 'transparent'
    }

    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.targetMonitor(screen)

    implicitWidth: contentItem.implicitWidth + root.horizontalPadding * 2
    implicitHeight: contentItem.implicitHeight + root.verticalPadding * 2
    radius: Appearance.rounding.normal
    color: Appearance.colors.colLayer1
    property real verticalPadding: 4
    property real horizontalPadding: 12

    Column {
        id: contentItem
        anchors {
            fill: parent
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
        }

        Loader {
            anchors {
                left: parent.left
                right: parent.right
            }
            visible: active
            active: Config.options.sidebar.quickSliders.showBrightness && Brightness.monitors.length > 1
            sourceComponent: BrightnessMonitorPicker {
                currentScreen: root.screen
            }
        }

        Loader {
            anchors {
                left: parent.left
                right: parent.right
            }
            visible: active
            active: Config.options.sidebar.quickSliders.showBrightness
            sourceComponent: QuickSlider {
                readonly property var monitor: root.brightnessMonitor
                readonly property bool hardware: monitor?.hasHardwareBrightness ?? true
                materialSymbol: hardware ? "brightness_medium" : "wb_twilight"
                secondaryMaterialSymbol: hardware ? "wb_twilight" : ""
                stopIndicatorValues: hardware && monitor?.gamma !== 100 && monitor?.brightness !== 0
                    ? [Brightness.gammaShare + monitor.brightness * (1 - Brightness.gammaShare)] : []
                value: monitor?.combinedLevel ?? 1
                tooltipContent: !hardware || monitor?.gamma !== 100
                    ? `${Translation.tr("Gamma")} ${monitor?.gamma ?? 100}%`
                    : `${Math.round((monitor?.brightness ?? 1) * 100)}%`
                onMoved: monitor?.setCombinedLevel(value)
            }
        }

        Loader {
            anchors { left: parent.left; right: parent.right }
            visible: active
            active: Config.options.sidebar.quickSliders.showVolume
            sourceComponent: QuickSlider {
                materialSymbol: "volume_up"
                value: Audio.sink?.audio?.volume ?? 0
                onMoved: {
                    if (Audio.sink?.audio)
                        Audio.sink.audio.volume = value
                }
            }
        }

        Loader {
            anchors { left: parent.left; right: parent.right }
            visible: active
            active: Config.options.sidebar.quickSliders.showMic
            sourceComponent: QuickSlider {
                materialSymbol: "mic"
                value: Audio.source?.audio?.volume ?? 0
                onMoved: {
                    if (Audio.source?.audio)
                        Audio.source.audio.volume = value
                }
            }
        }
    }

    component QuickSlider: StyledSlider { 
        id: quickSlider
        required property string materialSymbol
        property string secondaryMaterialSymbol
        configuration: StyledSlider.Configuration.M
        stopIndicatorValues: []
        dividerValues: secondaryMaterialSymbol.length > 0 ? [secondaryIcon.iconLocation] : []
        
        MaterialSymbol {
            id: icon
            property bool nearFull: quickSlider.value >= 0.9
            anchors {
                verticalCenter: quickSlider.verticalCenter
                right: nearFull ? quickSlider.handle.right : quickSlider.right
                rightMargin: nearFull ? 14 : 8
            }
            iconSize: 20
            color: nearFull ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
            text: quickSlider.materialSymbol

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
            Behavior on anchors.rightMargin {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }

        MaterialSymbol {
            id: secondaryIcon
            visible: secondaryMaterialSymbol.length > 0
            property real iconLocation: 0.3
            property bool nearIcon: iconLocation - quickSlider.value <= 0.1 && iconLocation - quickSlider.value > (quickSlider.handleWidth + 8 - 14) / quickSlider.effectiveDraggingWidth
            anchors {
                verticalCenter: quickSlider.verticalCenter
                right: nearIcon ? quickSlider.handle.right : quickSlider.right
                rightMargin: nearIcon ? 14 : (1 - iconLocation) * quickSlider.effectiveDraggingWidth + quickSlider.rightPadding + 8
            }
            iconSize: 20
            color: quickSlider.value >= iconLocation - 0.1 ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
            text: secondaryMaterialSymbol

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
    }
}

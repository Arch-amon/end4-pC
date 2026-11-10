import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick

MouseArea {
    id: root
    // Bar settings of the monitor this widget is on
    readonly property var barOpts: ScreenConfig.barOf(root)
    property color contentColor: Appearance.colors.colOnSecondaryContainer
    property bool contentColorOverridden: false
    property bool vertical: false
    property bool borderless: root.barOpts.borderless
    property bool isMaterial: root.barOpts.cornerStyle === 3 || root.barOpts.cornerStyle === 4
    readonly property var chargeState: Battery.chargeState
    readonly property bool isCharging: Battery.isCharging
    readonly property bool isPluggedIn: Battery.isPluggedIn
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: percentage <= Config.options.battery.low / 100

    implicitWidth: vertical ? ScreenConfig.verticalBarWidthFor(root.barOpts) : glyph.implicitWidth + 8
    implicitHeight: vertical ? glyph.implicitHeight + 8 : ScreenConfig.barHeightFor(root.barOpts)

    hoverEnabled: !root.barOpts.tooltips.clickToShow

    BatteryGlyph {
        id: glyph
        anchors.centerIn: parent
        style: root.barOpts.battery.style
        percentage: root.percentage
        isCharging: root.isCharging
        isLow: root.isLow
        showPercentage: root.barOpts.battery.showPercentage
        showCharging: root.barOpts.battery.showCharging
        vertical: root.vertical
        contentColor: root.contentColor
    }

    BatteryPopup {
        id: batteryPopup
        hoverTarget: root
    }
}

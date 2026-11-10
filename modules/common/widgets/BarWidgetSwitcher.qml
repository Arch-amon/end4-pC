import qs.modules.common
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    // Bar settings of the monitor this widget is on
    readonly property var barOpts: ScreenConfig.barOf(root)
    property bool vertical: false
    property bool isMaterial: root.barOpts.cornerStyle === 3 || root.barOpts.cornerStyle === 4
    property real horizontalExtraPadding: 12

    property Component colDefault
    property Component colMaterial
    property Component rowDefault
    property Component rowMaterial

    implicitWidth: root.vertical
        ? ScreenConfig.verticalBarWidthFor(root.barOpts)
        : (rowLoader.item?.implicitWidth ?? 0) + (root.isMaterial ? 0 : root.horizontalExtraPadding)
    implicitHeight: root.vertical
        ? (colLoader.item?.implicitHeight ?? 0)
        : ScreenConfig.barHeightFor(root.barOpts)

    Loader {
        id: colLoader
        active: root.vertical
        visible: active
        anchors.centerIn: parent
        sourceComponent: root.isMaterial ? root.colMaterial : root.colDefault
    }

    Loader {
        id: rowLoader
        active: !root.vertical
        visible: active
        anchors.centerIn: parent
        sourceComponent: root.isMaterial ? root.rowMaterial : root.rowDefault
    }
}
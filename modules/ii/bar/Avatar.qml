import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell

Item {
    id: root
    // Bar settings of the monitor this widget is on
    readonly property var barOpts: ScreenConfig.barOf(root)
    property bool vertical: false
    readonly property bool isMaterial: root.barOpts.cornerStyle === 3 || root.barOpts.cornerStyle === 4

    implicitWidth: vertical ? ScreenConfig.verticalBarWidthFor(root.barOpts) : avatar.width + (root.isMaterial ? 0 : 8)
    implicitHeight: vertical ? avatar.height + 8 : ScreenConfig.barHeightFor(root.barOpts)

    UserAvatar {
        id: avatar
        anchors.centerIn: parent
        width: root.isMaterial ? 32 : 24
        height: root.isMaterial ? 32 : 24
        iconSize: Appearance.font.pixelSize.larger
        scale: clickArea.pressed ? 0.92 : (clickArea.containsMouse ? 1.1 : 1)

        Behavior on scale {
            NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2 }
        }
    }

    MouseArea {
        id: clickArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (popup.active && popup.item) popup.item.close()
            else popup.active = true
        }
    }

    Loader {
        id: popup
        active: false
        sourceComponent: AvatarPopup {
            anchor {
                window: root.QsWindow.window
                item: root
                gravity: root.barOpts.vertical
                    ? (root.barOpts.bottom ? Edges.Left : Edges.Right)
                    : (root.barOpts.bottom ? Edges.Top : Edges.Bottom)
                edges: root.barOpts.vertical
                    ? (root.barOpts.bottom ? Edges.Left : Edges.Right)
                    : (root.barOpts.bottom ? Edges.Top : Edges.Bottom)
            }
            onPopupClosed: popup.active = false
        }
    }
}

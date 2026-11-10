import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Search field for the settings window. Results come from
 * SettingsSearchIndex (the labels of every page); picking one emits
 * resultChosen so the window can open that page and highlight the option.
 *
 * Keys: Up/Down move through results, Enter opens one, Esc clears the field
 * (and leaves it when already empty).
 */
Item {
    id: root

    signal resultChosen(var result)

    readonly property string query: field.text.trim()
    readonly property var results: query.length > 0 ? SettingsSearchIndex.search(query, 12) : []
    property int currentIndex: 0
    // Kept open while the pointer is over the list, so clicking a result
    // still works after the field loses focus.
    readonly property bool showingResults: query.length > 0 && (field.activeFocus || listHover.hovered)

    implicitHeight: 40
    z: 10 // Results drop over the page below

    function focusSearch() {
        field.forceActiveFocus();
        field.selectAll();
    }

    function choose(index) {
        const result = root.results[index];
        if (!result) return;
        field.text = "";
        field.focus = false;
        root.resultChosen(result);
    }

    function breadcrumb(result) {
        const parts = [result.pageName];
        if (result.kind !== "page" && result.section && result.section !== result.label) parts.push(result.section);
        if (result.subsection && result.subsection !== result.label) parts.push(result.subsection);
        return parts.join("  ›  ");
    }

    onResultsChanged: root.currentIndex = 0

    ToolbarTextField {
        id: field
        anchors.fill: parent
        leftPadding: 42
        rightPadding: clearButton.visible ? 42 : 14
        placeholderText: Translation.tr("Search settings  (Ctrl+F)")
        colBackground: Appearance.colors.colLayer1

        onAccepted: root.choose(root.currentIndex)

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Down && root.results.length > 0) {
                root.currentIndex = Math.min(root.currentIndex + 1, root.results.length - 1);
                resultsList.positionViewAtIndex(root.currentIndex, ListView.Contain);
                event.accepted = true;
            } else if (event.key === Qt.Key_Up && root.results.length > 0) {
                root.currentIndex = Math.max(root.currentIndex - 1, 0);
                resultsList.positionViewAtIndex(root.currentIndex, ListView.Contain);
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                // Empty field: let Esc reach the window (closes settings)
                if (field.text.length === 0) return;
                field.text = "";
                event.accepted = true;
            }
        }

        MaterialSymbol {
            anchors {
                left: parent.left
                leftMargin: 14
                verticalCenter: parent.verticalCenter
            }
            text: "search"
            iconSize: Appearance.font.pixelSize.larger
            color: field.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
        }

        RippleButton {
            id: clearButton
            visible: field.text.length > 0
            focusPolicy: Qt.NoFocus
            anchors {
                right: parent.right
                rightMargin: 6
                verticalCenter: parent.verticalCenter
            }
            implicitWidth: 28
            implicitHeight: 28
            buttonRadius: Appearance.rounding.full
            onClicked: field.text = ""
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "close"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colSubtext
            }
        }
    }

    Rectangle {
        id: resultsPopup
        visible: root.showingResults
        anchors {
            top: field.bottom
            topMargin: 6
            left: parent.left
            right: parent.right
        }
        implicitHeight: root.results.length === 0 ? 44 : Math.min(resultsList.contentHeight, 360) + 12
        radius: Appearance.rounding.normal
        color: Appearance.colors.colLayer2
        border.width: 1
        border.color: Appearance.colors.colLayer0Border

        HoverHandler {
            id: listHover
        }

        StyledText {
            visible: root.results.length === 0
            anchors.centerIn: parent
            text: Translation.tr("No settings match \"%1\"").arg(root.query)
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.small
        }

        StyledListView {
            id: resultsList
            anchors {
                fill: parent
                margins: 6
            }
            clip: true
            spacing: 2
            model: root.results
            popin: false
            animateAppearance: false

            delegate: RippleButton {
                id: resultButton
                required property var modelData
                required property int index
                width: resultsList.width
                focusPolicy: Qt.NoFocus
                buttonRadius: Appearance.rounding.small
                toggled: root.currentIndex === index
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colBackgroundToggled: Appearance.colors.colSecondaryContainer
                colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                onHoveredChanged: if (hovered) root.currentIndex = index
                onClicked: root.choose(index)

                leftPadding: 10
                rightPadding: 10
                topPadding: 7
                bottomPadding: 7

                contentItem: RowLayout {
                    id: resultRow
                    spacing: 10

                    MaterialSymbol {
                        text: resultButton.modelData.kind === "page" ? resultButton.modelData.icon
                            : resultButton.modelData.kind === "section" ? "segment" : "tune"
                        iconSize: Appearance.font.pixelSize.larger
                        color: resultButton.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: resultButton.modelData.label
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: resultButton.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer2
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.breadcrumb(resultButton.modelData)
                            elide: Text.ElideRight
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }
    }
}

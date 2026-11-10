import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

/**
 * Manages the local folders the wallpaper selector offers as quick access
 * (Config.options.wallpaperSelector.folders). The first folder is the one
 * the selector opens by default.
 */
WindowDialog {
    id: root
    backgroundWidth: 560

    property string errorText: ""

    function expandHome(path) {
        const home = FileUtils.trimFileProtocol(Directories.home);
        return path.startsWith("~") ? home + path.slice(1) : path;
    }

    // Only add folders that exist
    function tryAdd(path) {
        const clean = root.expandHome(path.trim());
        if (clean.length === 0) return;
        if (!clean.startsWith("/")) {
            root.errorText = Translation.tr("Use an absolute path (or one starting with ~)");
            return;
        }
        checkProc.candidate = clean;
        checkProc.exec(["test", "-d", clean]);
    }

    Process {
        id: checkProc
        property string candidate: ""
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                Wallpapers.addFolder(checkProc.candidate);
                pathField.text = "";
                root.errorText = "";
            } else {
                root.errorText = Translation.tr("\"%1\" is not a folder").arg(checkProc.candidate);
            }
        }
    }

    Process {
        id: browseProc
        command: ["bash", "-c", "kdialog --getexistingdirectory \"$1\" 2>/dev/null || zenity --file-selection --directory --filename=\"$1/\" 2>/dev/null",
            "_", FileUtils.trimFileProtocol(Wallpapers.effectiveDirectory || Directories.home)]
        stdout: StdioCollector {
            onStreamFinished: {
                const picked = text.trim();
                if (picked.length > 0) root.tryAdd(picked);
            }
        }
    }

    WindowDialogTitle {
        text: Translation.tr("Wallpaper folders")
    }

    WindowDialogParagraph {
        Layout.fillWidth: true
        text: Translation.tr("Folders shown as quick access at the top of the selector. The first one opens by default.")
    }

    WindowDialogSeparator {}

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        Repeater {
            model: Wallpapers.folders
            delegate: Rectangle {
                id: folderRow
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: rowLayout.implicitHeight + 12
                radius: Appearance.rounding.small
                color: Appearance.colors.colLayer2

                RowLayout {
                    id: rowLayout
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 6
                    }
                    spacing: 10

                    MaterialSymbol {
                        text: folderRow.index === 0 ? "folder_special" : folderRow.modelData.icon
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer2
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        StyledText {
                            Layout.fillWidth: true
                            text: folderRow.modelData.name + (folderRow.index === 0 ? "  · " + Translation.tr("default") : "")
                            elide: Text.ElideRight
                            color: Appearance.colors.colOnLayer2
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: FileUtils.trimFileProtocol(folderRow.modelData.path)
                            elide: Text.ElideMiddle
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }

                    FolderButton {
                        symbol: "arrow_upward"
                        tip: Translation.tr("Move up (the first folder opens by default)")
                        enabled: folderRow.index > 0
                        onClicked: Wallpapers.moveFolder(folderRow.index, -1)
                    }
                    FolderButton {
                        symbol: "arrow_downward"
                        tip: Translation.tr("Move down")
                        enabled: folderRow.index < Wallpapers.folders.length - 1
                        onClicked: Wallpapers.moveFolder(folderRow.index, 1)
                    }
                    FolderButton {
                        symbol: "delete"
                        tip: Translation.tr("Remove from the list (the folder itself is kept)")
                        onClicked: Wallpapers.removeFolder(folderRow.index)
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        TextField {
            id: pathField
            ContextMenu.menu: StyledTextEditMenu { editor: pathField }
            Layout.fillWidth: true
            placeholderText: Translation.tr("Folder path, e.g. ~/Pictures/Wallpapers")
            placeholderTextColor: Appearance.colors.colSubtext
            color: Appearance.colors.colOnLayer1
            font {
                family: Appearance.font.family.main
                pixelSize: Appearance.font.pixelSize.small
                hintingPreference: Font.PreferFullHinting
            }
            renderType: Text.NativeRendering
            background: Rectangle {
                color: Appearance.colors.colLayer1
                radius: Appearance.rounding.small
                border.width: 1
                border.color: pathField.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
            }
            onTextEdited: root.errorText = ""
            onAccepted: root.tryAdd(text)
        }

        FolderButton {
            symbol: "add"
            tip: Translation.tr("Add this path")
            enabled: pathField.text.trim().length > 0
            onClicked: root.tryAdd(pathField.text)
        }
        FolderButton {
            symbol: "folder_open"
            tip: Translation.tr("Browse for a folder")
            enabled: !browseProc.running
            onClicked: browseProc.running = true
        }
        FolderButton {
            symbol: "create_new_folder"
            tip: Translation.tr("Add the folder currently shown in the selector")
            onClicked: root.tryAdd(FileUtils.trimFileProtocol(Wallpapers.effectiveDirectory))
        }
    }

    StyledText {
        visible: root.errorText.length > 0
        Layout.fillWidth: true
        text: root.errorText
        color: Appearance.m3colors.m3error
        font.pixelSize: Appearance.font.pixelSize.small
    }

    WindowDialogSeparator {}

    WindowDialogButtonRow {
        Layout.fillWidth: true

        ConfigSwitch {
            buttonIcon: "home"
            text: Translation.tr("Show home folder")
            checked: Config.options.wallpaperSelector.showHomePath
            onCheckedChanged: Config.options.wallpaperSelector.showHomePath = checked
        }

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            visible: Wallpapers.hasCustomFolders
            buttonText: Translation.tr("Reset")
            onClicked: Wallpapers.resetFolders()
        }
        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }

    component FolderButton: RippleButton {
        id: folderButton
        property string symbol
        property string tip
        implicitWidth: 32
        implicitHeight: 32
        buttonRadius: Appearance.rounding.full
        colBackground: "transparent"
        opacity: enabled ? 1 : 0.4
        contentItem: MaterialSymbol {
            anchors.centerIn: parent
            text: folderButton.symbol
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnLayer2
        }
        StyledToolTip {
            text: folderButton.tip
        }
    }
}

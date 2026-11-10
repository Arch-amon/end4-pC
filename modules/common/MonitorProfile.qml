import QtQuick
import Quickshell
import Quickshell.Io

// Settings that belong to a single monitor, stored as
// <shell config>/monitors/<output name>.json.
//
// A monitor without a file simply follows the global settings: the file is
// only written once one of its values changes. Use ScreenConfig rather than
// reading this directly, it knows how to fall back to the global values.
Scope {
    id: root

    required property string screenName
    readonly property alias settings: adapter
    // True once the file was read (or found missing), so consumers can wait
    // for it instead of briefly showing the global bar on a customized monitor.
    property bool settled: false

    FileView {
        id: file
        path: `${Directories.monitorProfilesDir}/${root.screenName}.json`
        watchChanges: true
        printErrors: false

        onFileChanged: reloadTimer.restart()
        onAdapterUpdated: writeTimer.restart()
        onLoaded: root.settled = true
        onLoadFailed: root.settled = true

        JsonAdapter {
            id: adapter

            // Whether the bar on this monitor is shown at all.
            property bool barEnabled: true
            // When false the monitor uses Config.options.bar and `bar` below is
            // ignored. When true, `bar` is this monitor's own copy, made from the
            // global (or another monitor's) bar when it was customized.
            property bool customBar: false
            property JsonObject bar: BarOptions {}

            // Empty means "use the global wallpaper".
            property string wallpaperPath: ""
            property string thumbnailPath: "" // Still frame for video wallpapers
        }
    }

    Timer {
        id: reloadTimer
        interval: 50
        onTriggered: file.reload()
    }

    Timer {
        id: writeTimer
        interval: 50
        onTriggered: file.writeAdapter()
    }
}

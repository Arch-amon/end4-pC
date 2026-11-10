import QtQuick
import Quickshell.Io

// Schema of the bar settings. The global bar lives at Config.options.bar;
// every monitor with its own bar gets another instance of this object in its
// monitor profile (see ScreenConfig). Keep the two in sync by only adding
// bar settings here.
JsonObject {
    property JsonObject autoHide: JsonObject {
        property bool enable: false
        property int hoverRegionWidth: 2
        property bool pushWindows: false
        property JsonObject showWhenPressingSuper: JsonObject {
            property bool enable: true
            property int delay: 140
        }
    }
    property bool showFrame: false
    property real frameThickness: 4
    property string frameColor: "black"
    property bool followFrameColor: false
    property bool centerOnlyReserveFrame: false
    property bool bottom: false // Instead of top
    property int cornerStyle: 0 // 0: Hug | 1: Float | 2: Plain rectangle | 3: M3 | 4: M3 Hug | 5: Panel | 6: Split Hug
    property string groupColor: "layer1"
    property bool floatStyleShadow: true // Show shadow behind bar when cornerStyle == 1 (Float)
    property string borderless: "pills"
    property list<var> widgetStyles: []
    property string topLeftIcon: "spark" // Options: "distro" or any icon name in ~/.config/quickshell/ii/assets/icons
    property bool showBackground: true
    property bool verbose: true
    property bool vertical: false
    property JsonObject resources: JsonObject {
        property string style: "filled"
        property bool showValue: false
        property bool alwaysShowSwap: false
        property bool alwaysShowCpu: true
        property bool alwaysShowCpuTemp: false
        property bool alwaysShowDisk: false
        property bool alwaysShowRam: true
        property int memoryWarningThreshold: 95
        property int swapWarningThreshold: 85
        property int cpuWarningThreshold: 90
    }

    property JsonObject aiUsage: JsonObject {
        property bool claudeEnabled: true
        property bool codexEnabled: true
        property int tokenLimit: 1000000
        property int updateInterval: 60
    }

    property JsonObject dynamicIsland: JsonObject {
        property string visualizerStyle: "dots" // "dots", "wave", "none"
        property bool showMediaControls: false
        property string leftWidget: "none"
        property string rightWidget: "none"
    }
    property JsonObject divider: JsonObject {
        property string style: "rect" // rect - dot - space
        property int spacing: 20
    }

    property JsonObject layouts: JsonObject {
        property list<string> leftLayout: ["launcherButton", "workspaces", "activeWindow"]
        property list<string> middleLayout: ["clockWidget"]
        property list<string> rightLayout: ["sysTray", "utilButtons", "systemIcons", "powerButton"]
    }
    
    property list<string> screenList: [] // List of names, like "eDP-1", find out with 'hyprctl monitors' command
    property JsonObject battery: JsonObject {
        property string style: "bar"
        property bool showPercentage: true
        property bool showCharging: true
    }
    property JsonObject utilButtons: JsonObject {
        property bool showScreenSnip: true
        property bool showColorPicker: true
        property bool showMicToggle: false
        property bool showKeyboardToggle: false
        property bool showWallpaperToggle: true
        property bool showDarkModeToggle: false
        property bool showPerformanceProfileToggle: false
        property bool showScreenRecord: false       
        property bool isRecording: false
    }

    property JsonObject workspaces: JsonObject {
        property bool monochromeIcons: true
        property int shown: 10
        property bool showAppIcons: false
        property string indicatorStyle: "dot" // "dot" or "icon"
        property string style: "default" // "default", "gnome", "dots", "ticks"
        property bool alwaysShowNumbers: true
        property int showNumberDelay: 300 // milliseconds
        property list<string> numberMap: ["1", "2"] // Characters to show instead of numbers on workspace indicator
        property bool useNerdFont: false
    }
    property JsonObject weather: JsonObject {
        property bool enable: false
        property bool enableGPS: true // gps based location
        property string city: "" // When 'enableGPS' is false
        property bool useUSCS: false // Instead of metric (SI) units
        property int fetchInterval: 10 // minutes
    }
    property JsonObject indicators: JsonObject {
        property JsonObject notifications: JsonObject {
            property bool showUnreadCount: false
        }
    }
    property JsonObject tooltips: JsonObject {
        property bool enable: true
        property bool clickToShow: false
        property string style: "default"
    }
    property JsonObject media: JsonObject {
        property string preferredPlayer: ""
        property bool alwaysVisible: false
        property bool onlyTitle: false
        property int maxWidth: 280
        property int minWidth: 100
        property bool showLyrics: false
    }
}

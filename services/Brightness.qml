pragma Singleton
pragma ComponentBehavior: Bound

// From https://github.com/caelestia-dots/shell with modifications.
// License: GPLv3

import qs.modules.common
import qs.modules.common.functions
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

/**
 * For managing brightness of monitors. Supports both brightnessctl and ddcutil.
 */
Singleton {
    id: root
    signal brightnessChanged()

    property var ddcMonitors: []
    readonly property list<BrightnessMonitor> monitors: Quickshell.screens.map(screen => monitorComp.createObject(root, {
        screen
    }))

    // Monitor the brightness sliders act on; empty = the screen the slider is on.
    property string selectedScreenName: ""
    // Monitor whose brightness or gamma changed last, for the OSD.
    property string lastChangedScreenName: ""
    // Share of a combined slider below which it drives gamma instead of hardware brightness.
    readonly property real gammaShare: 0.3

    function getMonitorForScreen(screen: ShellScreen): var {
        return monitors.find(m => m.screen === screen);
    }

    function monitorByName(name: string): var {
        return monitors.find(m => m.screen?.name === name);
    }

    function targetMonitor(screen: ShellScreen): var {
        return monitorByName(root.selectedScreenName) ?? getMonitorForScreen(screen);
    }

    function focusedMonitor(): var {
        const focusedName = WM.compositor === "hyprland" ? Hyprland.focusedMonitor?.name : WM.focusedMonitor?.name;
        return monitorByName(focusedName);
    }

    // Monitor the OSD should describe: the one that just changed, else the focused one.
    function osdMonitor(): var {
        return monitorByName(root.lastChangedScreenName) ?? focusedMonitor();
    }

    function displayName(monitor: var): string {
        return monitor?.screen?.model || monitor?.screen?.name || "";
    }

    function increaseBrightness(): void {
        const monitor = focusedMonitor();
        if (!monitor) return;
        // if gamma is not yet 100, first increase gamma
        if (monitor.gamma !== 100 || !monitor.hasHardwareBrightness) {
            monitor.setGamma(monitor.gamma + 5);
            return;
        }
        monitor.setBrightness(monitor.brightness + 0.05);
    }

    function decreaseBrightness(): void {
        const monitor = focusedMonitor();
        if (!monitor) return;
        if (monitor.hasHardwareBrightness && monitor.brightness > 0)
            monitor.setBrightness(monitor.brightness - 0.05);
        // if brightness is 0 (or the monitor has none), then decrease gamma
        else
            monitor.setGamma(monitor.gamma - 5);
    }

    reloadableId: "brightness"

    onMonitorsChanged: {
        ddcMonitors = [];
        ddcProc.running = true;
    }

    function initializeMonitor(i: int): void {
        if (i >= monitors.length)
            return;
        monitors[i].initialize();
    }

    function ddcDetectFinished(): void {
        initializeMonitor(0);
    }

    Process {
        id: ddcProc

        command: ["ddcutil", "detect", "--brief"]
        stdout: SplitParser {
            splitMarker: "\n\n"
            onRead: data => {
                if (data.startsWith("Display ")) {
                    const lines = data.split("\n").map(l => l.trim());
                    root.ddcMonitors.push({
                        name: lines.find(l => l.startsWith("DRM connector:")).split("-").slice(1).join('-'),
                        busNum: lines.find(l => l.startsWith("I2C bus:")).split("/dev/i2c-")[1]
                    });
                }
            }
        }
        onExited: root.ddcDetectFinished()
    }

    Process {
        id: setProc
    }

    component BrightnessMonitor: QtObject {
        id: monitor

        required property ShellScreen screen
        readonly property string name: screen?.name ?? ""
        property bool isDdc
        // False for screens with neither DDC/CI nor a backlight (most TVs): gamma only.
        property bool hasHardwareBrightness: true
        readonly property int gamma: MonitorGamma.gammaOf(monitor.name)
        // One 0..1 value for the sliders: gamma in [0, gammaShare), hardware brightness above.
        readonly property real combinedLevel: {
            const gammaLevel = (monitor.gamma - MonitorGamma.lowerLimit) / (100 - MonitorGamma.lowerLimit);
            if (!monitor.hasHardwareBrightness) return gammaLevel;
            if (monitor.gamma !== 100) return gammaLevel * root.gammaShare;
            return root.gammaShare + monitor.brightness * (1 - root.gammaShare);
        }
        property string busNum
        property int rawMaxBrightness: 100
        property real brightness
        property real brightnessMultiplier: 1.0
        property real multipliedBrightness: Math.max(0, Math.min(1, brightness * (Config.options.light.antiFlashbang.enable ? brightnessMultiplier : 1)))
        property bool ready: false
        property bool animateChanges: !monitor.isDdc

        onBrightnessChanged: {
            if (!monitor.ready) return;
            root.lastChangedScreenName = monitor.name;
            root.brightnessChanged();
        }

        Behavior on multipliedBrightness {
            enabled: monitor.animateChanges
            NumberAnimation {
                duration: 200
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveEffects
            }
        }
        onMultipliedBrightnessChanged: {
            if (monitor.animationEnabled) syncBrightness();
            else setTimer.restart();
        }

        function initialize() {
            monitor.ready = false;
            const match = root.ddcMonitors.find(m => m.name === screen.name && !root.monitors.slice(0, root.monitors.indexOf(this)).some(mon => mon.busNum === m.busNum));
            isDdc = !!match;
            busNum = match?.busNum ?? "";
            // A backlight belongs to the built-in panel only, never to an external screen.
            const internal = /^(eDP|LVDS|DSI)/.test(monitor.name);
            hasHardwareBrightness = isDdc || internal;
            if (!hasHardwareBrightness) {
                monitor.brightness = 1;
                monitor.ready = true;
                initializeMonitor(root.monitors.indexOf(monitor) + 1);
                return;
            }
            initProc.command = isDdc ? ["ddcutil", "-b", busNum, "getvcp", "10", "--brief"] : ["sh", "-c", `echo "a b c $(brightnessctl --class backlight g) $(brightnessctl --class backlight m)"`];
            initProc.running = true;
        }

        readonly property Process initProc: Process {
            stdout: SplitParser {
                onRead: data => {
                    const [, , , current, max] = data.split(" ");
                    if (isNaN(parseInt(current)) || !(parseInt(max) > 0)) {
                        // getvcp/brightnessctl failed: treat it like a screen without hardware brightness
                        monitor.hasHardwareBrightness = false;
                        monitor.brightness = 1;
                        monitor.ready = true;
                        return;
                    }
                    monitor.rawMaxBrightness = parseInt(max);
                    monitor.brightness = parseInt(current) / monitor.rawMaxBrightness;
                    monitor.ready = true;
                }
            }
            onExited: (exitCode, exitStatus) => {
                initializeMonitor(root.monitors.indexOf(monitor) + 1);
            }
        }

        // We need a delay for DDC monitors because they can be quite slow and might act weird with rapid changes
        property var setTimer: Timer {
            id: setTimer
            interval: monitor.isDdc ? 300 : 0
            onTriggered: {
                syncBrightness();
            }
        }

        function syncBrightness() {
            if (!monitor.hasHardwareBrightness || !monitor.ready) return;
            const brightnessValue = Math.max(monitor.multipliedBrightness, 0);
            if (isDdc) {
                const rawValueRounded = Math.max(Math.floor(brightnessValue * monitor.rawMaxBrightness), 1);
                setProc.exec(["ddcutil", "-b", busNum, "setvcp", "10", rawValueRounded]);
            } else {
                const valuePercentNumber = Math.floor(brightnessValue * 100);
                let valuePercent = `${valuePercentNumber}%`;
                if (valuePercentNumber == 0) valuePercent = "1"; // Prevent fully black
                setProc.exec(["brightnessctl", "--class", "backlight", "s", valuePercent, "--quiet"])
            }
        }

        function setBrightness(value: real): void {
            value = Math.max(0, Math.min(1, value));
            monitor.brightness = value;
        }

        function setGamma(value: real): void {
            root.lastChangedScreenName = monitor.name;
            MonitorGamma.setGamma(monitor.name, value);
        }

        function setCombinedLevel(value: real): void {
            value = Math.max(0, Math.min(1, value));
            const toGamma = level => MonitorGamma.lowerLimit + level * (100 - MonitorGamma.lowerLimit);
            if (!monitor.hasHardwareBrightness) {
                monitor.setGamma(toGamma(value));
            } else if (value >= root.gammaShare) {
                monitor.setBrightness((value - root.gammaShare) / (1 - root.gammaShare));
                if (monitor.gamma !== 100) monitor.setGamma(100);
            } else {
                if (monitor.brightness !== 0) monitor.setBrightness(0);
                monitor.setGamma(toGamma(value / root.gammaShare));
            }
        }

        function setBrightnessMultiplier(value: real): void {
            monitor.brightnessMultiplier = value;
        }
    }

    Component {
        id: monitorComp

        BrightnessMonitor {}
    }

    // Anti-flashbang
    property int workspaceAnimationDelay: 500
    property int contentSwitchDelay: 30
    property string screenshotDir: "/tmp/quickshell/brightness/antiflashbang"
    function brightnessMultiplierForLightness(x: real): real {
        // I hand picked some values and fitted an exponential curve for this
        // 6.600135 + 216.360356 * e^(-0.0811129189x)
        // Division by 100 is to normalize to [0, 1]
        return (6.600135 + 216.360356 * Math.pow(Math.E, -0.0811129189 * x)) / 100.0;
    }
    Variants {
        model: Quickshell.screens
        Scope {
            id: screenScope
            required property var modelData
            property string screenName: modelData.name
            property string screenshotPath: `${root.screenshotDir}/screenshot-${screenName}.png`
            Connections {
                enabled: Config.options.light.antiFlashbang.enable && Appearance.m3colors.darkmode
                target: Hyprland
                function onRawEvent(event) {
                    if (["activewindowv2", "windowtitlev2"].includes(event.name)) {
                        screenshotTimer.interval = root.contentSwitchDelay;
                        screenshotTimer.restart();
                    } else if (["workspacev2"].includes(event.name)) {
                        screenshotTimer.interval = root.workspaceAnimationDelay;
                        screenshotTimer.restart();
                    }
                }
            }

            Timer {
                id: screenshotTimer
                interval: 700 // This is what I have for a Hyprland ws anim
                onTriggered: {
                    screenshotProc.running = false;
                    screenshotProc.running = true;
                }
            }

            Process {
                id: screenshotProc
                command: ["bash", "-c",
                    `mkdir -p '${StringUtils.shellSingleQuoteEscape(root.screenshotDir)}'`
                    + ` && grim -o '${StringUtils.shellSingleQuoteEscape(screenScope.screenName)}' -`
                    + ` | magick png:- -colorspace Gray -format "%[fx:mean*100]" info:`
                ]
                stdout: StdioCollector {
                    id: lightnessCollector
                    onStreamFinished: {
                        Quickshell.execDetached(["rm", screenScope.screenshotPath]); // Cleanup
                        const lightness = lightnessCollector.text
                        const newMultiplier = root.brightnessMultiplierForLightness(parseFloat(lightness))
                        Brightness.getMonitorForScreen(screenScope.modelData).setBrightnessMultiplier(newMultiplier)
                    }
                }
            }
        }
    }

    // External trigger points

    IpcHandler {
        target: "brightness"

        function increment() {
            onPressed: root.increaseBrightness()
        }

        function decrement() {
            onPressed: root.decreaseBrightness()
        }
    }

    CompositorGlobalShortcut {
        name: "brightnessIncrease"
        description: "Increase brightness"
        onPressed: root.increaseBrightness()
    }

    CompositorGlobalShortcut {
        name: "brightnessDecrease"
        description: "Decrease brightness"
        onPressed: root.decreaseBrightness()
    }
}

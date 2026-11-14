pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

/**
 * Per-monitor gamma (software dimming). scripts/gamma/qs-gamma holds a
 * wlr-gamma-control ramp for each output that isn't at 100%, so this costs no
 * GPU time and leaves night light (hyprsunset's color matrix) alone. When the
 * helper can't run, it falls back to hyprsunset's gamma, which hits every monitor.
 */
Singleton {
    id: root
    signal gammaChangeAttempt(string screenName)

    readonly property int lowerLimit: 25
    property bool available: false
    property var failedOutputs: ({})
    property int restarts: 0

    // Survives shell reloads so a reload doesn't flash the screens back to 100%.
    PersistentProperties {
        id: persist
        reloadableId: "monitorGamma"
        property var values: ({})
    }

    function gammaOf(screenName: string): int {
        return persist.values[screenName] ?? 100;
    }

    function setGamma(screenName: string, value: real): void {
        if (!screenName) return;
        const v = Math.round(Math.max(root.lowerLimit, Math.min(100, value)));
        const values = Object.assign({}, persist.values);
        values[screenName] = v;
        persist.values = values;
        root.gammaChangeAttempt(screenName);
        root.push(screenName, v);
    }

    function push(screenName: string, value: int): void {
        if (root.available && !root.failedOutputs[screenName]) {
            helper.write(`set ${screenName} ${value}\n`);
        } else if (WM.compositor !== "niri") {
            // Global fallback: hyprsunset can only dim every monitor at once.
            Hyprsunset.startHyprsunset();
            Quickshell.execDetached(["hyprctl", "hyprsunset", "gamma", `${value}`]);
        }
    }

    function reapplyAll(): void {
        for (const name in persist.values) {
            if (persist.values[name] !== 100) root.push(name, persist.values[name]);
        }
    }

    Process {
        id: helper
        running: WM.compositor !== "niri"
        stdinEnabled: true
        command: ["bash", `${Directories.scriptPath}/gamma/run.sh`]
        stdout: SplitParser {
            onRead: line => {
                const [kind, name] = line.trim().split(" ");
                if (kind === "ready") {
                    root.available = true;
                    root.restarts = 0;
                    // Clear a global gamma left over from before per-monitor gamma.
                    Quickshell.execDetached(["bash", "-c", "pidof hyprsunset >/dev/null && hyprctl hyprsunset gamma 100"]);
                    root.reapplyAll();
                } else if (kind === "failed") {
                    const failed = Object.assign({}, root.failedOutputs);
                    failed[name] = true;
                    root.failedOutputs = failed;
                    console.warn(`[MonitorGamma] compositor refused gamma for ${name}; using hyprsunset`);
                    root.push(name, root.gammaOf(name));
                } else if (kind === "error") {
                    console.warn(`[MonitorGamma] ${line}`);
                }
            }
        }
        stderr: SplitParser {
            onRead: line => console.warn(`[MonitorGamma] ${line}`)
        }
        onExited: (exitCode, exitStatus) => {
            root.available = false;
            if (root.restarts < 3) {
                root.restarts++;
                restartTimer.start();
            } else {
                console.warn("[MonitorGamma] qs-gamma keeps exiting; per-monitor gamma is off");
                root.reapplyAll(); // through the hyprsunset fallback
            }
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: helper.running = true
    }
}

pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

/**
 * Per-monitor settings on top of the global config.
 *
 * Every connected monitor has a MonitorProfile. A monitor either follows the
 * global bar (Config.options.bar) or has its own full copy of it ("custom
 * bar"), and either shows the global wallpaper or its own.
 *
 * Functions taking a `screen` accept a ShellScreen or an output name. An
 * unknown or empty screen always resolves to the global settings, so callers
 * that don't know their monitor keep the old behaviour.
 */
Singleton {
    id: root

    // Output name -> MonitorProfile, for the connected monitors.
    readonly property var profiles: {
        const map = {};
        const instances = profileVariants.instances;
        for (let i = 0; i < instances.length; i++)
            map[instances[i].screenName] = instances[i];
        return map;
    }

    // All profiles have been read, so bars can be created in their final style.
    readonly property bool ready: {
        const instances = profileVariants.instances;
        for (let i = 0; i < instances.length; i++)
            if (!instances[i].settled) return false;
        return true;
    }

    readonly property string primaryScreenName: Quickshell.screens[0]?.name ?? ""

    Variants {
        id: profileVariants
        model: Quickshell.screens.map(screen => screen.name)
        MonitorProfile {
            required property string modelData
            screenName: modelData
        }
    }

    function nameOf(screen) {
        if (!screen) return "";
        return typeof screen === "string" ? screen : (screen.name ?? "");
    }

    function profile(screen) {
        return root.profiles[root.nameOf(screen)] ?? null;
    }

    // ---------------------------------------------------------------- Bar

    function hasCustomBar(screen) {
        return root.profile(screen)?.settings.customBar ?? false;
    }

    // The bar settings object in effect on a monitor. It is a real config
    // object, so bindings on its properties update individually, and writing
    // to it changes that monitor (or the global bar) directly.
    function barFor(screen) {
        const settings = root.profile(screen)?.settings;
        return (settings && settings.customBar) ? settings.bar : Config.options.bar;
    }

    // Same as barFor(), for the monitor whose window contains `item`.
    function barOf(item) {
        return root.barFor(item?.QsWindow?.window?.screen);
    }

    function isBarEnabled(screen) {
        return root.profile(screen)?.settings.barEnabled ?? true;
    }

    function setBarEnabled(screen, enabled) {
        const p = root.profile(screen);
        if (p) p.settings.barEnabled = enabled;
    }

    // Whether a bar is meant to be on this monitor at all (global screen
    // list + the per-monitor switch), regardless of its orientation.
    function hasBar(screen) {
        const name = root.nameOf(screen);
        const list = Config.options.bar.screenList;
        const listed = !list || list.length === 0 || list.includes(name);
        return listed && root.isBarEnabled(name);
    }

    function barScreens() {
        return Quickshell.screens.filter(screen => root.hasBar(screen));
    }

    // True if `predicate(barSettings, screen)` holds for any shown bar.
    function anyBar(predicate) {
        return root.barScreens().some(screen => predicate(root.barFor(screen), screen));
    }

    function barHasWidget(bar, widgetName) {
        const layouts = bar?.layouts;
        if (!layouts) return false;
        return [layouts.leftLayout, layouts.middleLayout, layouts.rightLayout]
            .some(layout => Array.from(layout ?? []).includes(widgetName));
    }

    // Give `screen` its own bar, starting as a copy of `from` (another
    // monitor, or the global bar when empty).
    function customizeBar(screen, from = "") {
        const p = root.profile(screen);
        if (!p || root.nameOf(from) === p.screenName) return;
        root.copyJson(root.barFor(from), p.settings.bar);
        p.settings.customBar = true;
    }

    // Make `screen` follow the global bar again.
    function resetBar(screen) {
        const p = root.profile(screen);
        if (p) p.settings.customBar = false;
    }

    // Copy a monitor's bar to the global one, e.g. to make it the default.
    function applyBarToGlobal(screen) {
        if (!root.hasCustomBar(screen)) return;
        root.copyJson(root.barFor(screen), Config.options.bar, ["screenList"]);
    }

    // Bar thickness depends on the bar style, so it differs per monitor.
    function barHeightFor(bar) {
        const base = Appearance.sizes.baseBarHeight;
        const style = bar?.cornerStyle ?? 0;
        if (style === 1) return base + Appearance.sizes.hyprlandGapsOut * 2;
        if (style === 4 || style === 5 || style === 6) return base + 4;
        return base;
    }

    function verticalBarWidthFor(bar) {
        const base = Appearance.sizes.baseVerticalBarWidth;
        return (bar?.cornerStyle ?? 0) === 1 ? base + Appearance.sizes.hyprlandGapsOut * 2 : base;
    }

    function barThicknessFor(bar) {
        return bar?.vertical ? root.verticalBarWidthFor(bar) : root.barHeightFor(bar);
    }

    // ---------------------------------------------------------- Wallpaper

    function hasOwnWallpaper(screen) {
        return (root.profile(screen)?.settings.wallpaperPath ?? "") !== "";
    }

    function wallpaperFor(screen) {
        const own = root.profile(screen)?.settings.wallpaperPath ?? "";
        return own !== "" ? own : Config.options.background.wallpaperPath;
    }

    // Still image for a video wallpaper (used for colors and previews).
    function thumbnailFor(screen) {
        const settings = root.profile(screen)?.settings;
        if (settings && settings.wallpaperPath !== "") return settings.thumbnailPath;
        return Config.options.background.thumbnailPath;
    }

    // The monitor whose wallpaper the color theme follows. Until one is
    // chosen that is the primary monitor, which shows the global wallpaper
    // unless it got its own.
    readonly property string themeSourceScreen: Config.options.background.themeSourceScreen || root.primaryScreenName

    function isThemeSource(screen) {
        return root.nameOf(screen) === root.themeSourceScreen;
    }

    // ------------------------------------------------------------ Helpers

    // Deep-copy the values of one config object into another of the same
    // shape. Only keys the target knows about are touched.
    function copyJson(source, target, skipKeys = []) {
        root.assignInto(target, JSON.parse(JSON.stringify(source)), skipKeys);
    }

    function assignInto(target, plain, skipKeys = []) {
        for (const key of Object.keys(plain)) {
            if (key === "objectName" || skipKeys.includes(key) || !(key in target)) continue;
            const value = plain[key];
            const current = target[key];
            const isNested = value !== null && typeof value === "object" && !Array.isArray(value)
                && current !== null && typeof current === "object";
            if (isNested) root.assignInto(current, value);
            else target[key] = value;
        }
    }
}

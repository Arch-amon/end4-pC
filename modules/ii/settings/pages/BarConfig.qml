import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Quickshell
import Quickshell.Hyprland

ContentPage {
    id: page

    // The bar this page edits: the global one, or the own bar of the monitor
    // picked in "Monitors". A monitor following the global bar can't be
    // edited until it is customized.
    readonly property string editScreen: Quickshell.screens.some(screen => screen.name === GlobalStates.barSettingsScreen)
        ? GlobalStates.barSettingsScreen : ""
    readonly property bool editingMonitor: editScreen !== ""
    readonly property bool editable: !editingMonitor || ScreenConfig.hasCustomBar(editScreen)
    readonly property var bar: ScreenConfig.barFor(editScreen)

    // Show/hide the bar on a monitor. The old global screen list is folded
    // into the per-monitor switches the first time this is used.
    function setBarShown(screenName, shown) {
        const list = Array.from(Config.options.bar.screenList ?? [])
        if (list.length > 0) {
            for (const screen of Quickshell.screens)
                ScreenConfig.setBarEnabled(screen, list.includes(screen.name) && ScreenConfig.isBarEnabled(screen))
            Config.options.bar.screenList = []
        }
        ScreenConfig.setBarEnabled(screenName, shown)
    }
    readonly property bool defaultWorkspacesDesign: (page.bar.workspaces.style ?? "default") === "default"
    forceWidth: true

    readonly property color leftIconColor: {
        const name = Config.options.custom.iconColor || "onLayer0"
        return Appearance.colors[`col${name.charAt(0).toUpperCase()}${name.slice(1)}`] ?? Appearance.colors.colOnLayer0
    }

    property var allWidgets: [
        { id: "leftSidebarButton", name: Translation.tr("Left Sidebar Button"),  icon: "left_panel_open" },
        { id: "workspaces",        name: Translation.tr("Workspaces"),           icon: "steppers" },
        { id: "weatherBar",        name: Translation.tr("Weather"),              icon: "flare" },
        { id: "liveWallpaper",     name: Translation.tr("Live wallpaper"),        icon: "play_pause" },
        { id: "media",             name: Translation.tr("Media"),                icon: "music_note" },
        { id: "resources",         name: Translation.tr("Resources"),            icon: "empty_dashboard" },
        { id: "systemIcons",       name: Translation.tr("System Icons"),         icon: "info" },
        { id: "networkSpeed",      name: Translation.tr("Network Speed"),        icon: "network_check" },
        { id: "clockWidget",       name: Translation.tr("Clock"),                icon: "schedule" },
        { id: "utilButtons",       name: Translation.tr("Util Buttons"),         icon: "toggle_on" },
        { id: "sysTray",           name: Translation.tr("Tray"),                 icon: "inbox" },
        { id: "batteryIndicator",  name: Translation.tr("Battery"),              icon: "battery_android_frame_full" },
        { id: "bluetooth",         name: Translation.tr("Bluetooth"),            icon: "bluetooth" },
        { id: "activeWindow",      name: Translation.tr("Active Window"),        icon: "subtitles" },
        { id: "powerButton",       name: Translation.tr("Power Button"),         icon: "power_settings_new" },
        { id: "updatesCount",      name: Translation.tr("Updates"),              icon: "deployed_code_update" },
        { id: "docktoPanel",       name: Translation.tr("Dock to Panel"),        icon: "apps" },
        { id: "visualizer",        name: Translation.tr("Visualizer"),           icon: "graphic_eq" },
        { id: "hyprlandXkbIndicator",   name: Translation.tr("Keyboard Layout"), icon: "keyboard" },
        { id: "divisor",            name: Translation.tr("Divider"),             icon: "horizontal_distribute" },
        { id: "launcherButton",     name: Translation.tr("Launcher Button"),     icon: "search" },
        { id: "dynamicIsland",     name: Translation.tr("Dynamic Island"),     icon: "nest_wifi_pro" },
        { id: "aiUsage",           name: Translation.tr("AI Usage"),           icon: "neurology" },
        { id: "avatar",            name: Translation.tr("Avatar"),             icon: "account_circle" },
    ]

    function availableFor(section) {
        let used = [
            ...page.bar.layouts.leftLayout,
            ...page.bar.layouts.middleLayout,
            ...page.bar.layouts.rightLayout
        ]
        if (section === "middle" && page.bar.layouts.middleLayout.length > 0) {
            return page.bar.layouts.middleLayout.includes("dynamicIsland") ? [] : allWidgets.filter(w => {
                if (w.id === "dynamicIsland") return false
                if (w.id === "divisor" && page.bar.borderless !== "transparent") return false
                const multipleAllowed = ["visualizer", "divisor"]
                return !used.includes(w.id) || multipleAllowed.includes(w.id)
            })
        }
        const multipleAllowed = ["visualizer", "divisor"]
        return allWidgets.filter(w => {
            if (w.id === "divisor" && page.bar.borderless !== "transparent") return false
            if (w.id === "dynamicIsland" && (page.bar.vertical || section !== "middle")) return false
            return !used.includes(w.id) || multipleAllowed.includes(w.id)
        })
    }

    readonly property var usedWidgets: {
        const layouts = page.bar.layouts
        const used = [...layouts.leftLayout, ...layouts.middleLayout, ...layouts.rightLayout]
        if (used.includes("dynamicIsland")) {
            used.push(page.bar.dynamicIsland.leftWidget, page.bar.dynamicIsland.rightWidget)
        }
        return used
    }

    function isUsed(id) {
        return page.usedWidgets.includes(id)
    }

    readonly property var widgetSections: ({
        dynamicIsland: Translation.tr("Dynamic Island"),
        sysTray: Translation.tr("Tray"),
        leftSidebarButton: Translation.tr("Left sidebar button"),
        divisor: Translation.tr("Divider"),
        utilButtons: Translation.tr("Utility buttons"),
        workspaces: Translation.tr("Workspaces"),
        resources: Translation.tr("Resources"),
        media: Translation.tr("Media"),
        aiUsage: Translation.tr("AI Usage")
    })

    function openWidgetSettings(id) {
        const title = page.widgetSections[id]
        if (title) page.goTo(title, title)
    }

    function getWidgetName(id) {
        const w = allWidgets.find(w => w.id === id)
        return w ? w.name : id
    }

    ColumnLayout {
        id: mainLayout 
        Layout.fillWidth: true   
        Layout.fillHeight: true
        spacing: 20

        ContentSection {
            icon: "monitor"
            shape: MaterialShape.Shape.ClamShell
            visible: Quickshell.screens.length > 1
            title: Translation.tr("Monitors")
            hint: Translation.tr("Every monitor follows the global bar unless you customize it")
            hintIcon: "info"

            ContentSubsection {
                title: Translation.tr("Settings on this page apply to")

                ConfigSelectionArray {
                    currentValue: page.editScreen
                    onSelected: newValue => GlobalStates.barSettingsScreen = newValue
                    options: [
                        { displayName: Translation.tr("Global bar"), icon: "tv_displays", value: "" },
                        ...Quickshell.screens.map(screen => ({
                            displayName: screen.name,
                            icon: ScreenConfig.hasCustomBar(screen) ? "tune" : "monitor",
                            value: screen.name
                        }))
                    ]
                }
            }

            ContentSubsection {
                visible: !page.editingMonitor
                title: Translation.tr("Show bar on")

                Repeater {
                    model: Quickshell.screens
                    delegate: ConfigSwitch {
                        id: shownSwitch
                        required property var modelData
                        Layout.fillWidth: true
                        buttonIcon: ScreenConfig.hasCustomBar(modelData) ? "tune" : "monitor"
                        text: ScreenConfig.hasCustomBar(modelData)
                            ? Translation.tr("%1 (own bar)").arg(modelData.name)
                            : modelData.name
                        onCheckedChanged: {
                            if (checked !== ScreenConfig.hasBar(modelData)) page.setBarShown(modelData.name, checked)
                        }
                        Binding {
                            target: shownSwitch
                            property: "checked"
                            value: ScreenConfig.hasBar(shownSwitch.modelData)
                            restoreMode: Binding.RestoreBinding
                        }
                    }
                }
            }

            ContentSubsection {
                visible: page.editingMonitor
                title: page.editScreen

                ConfigSwitch {
                    id: thisMonitorSwitch
                    Layout.fillWidth: true
                    buttonIcon: "toast"
                    text: Translation.tr("Show a bar on this monitor")
                    onCheckedChanged: {
                        if (page.editingMonitor && checked !== ScreenConfig.hasBar(page.editScreen))
                            page.setBarShown(page.editScreen, checked)
                    }
                    Binding {
                        target: thisMonitorSwitch
                        property: "checked"
                        value: ScreenConfig.hasBar(page.editScreen)
                        restoreMode: Binding.RestoreBinding
                    }
                }

                NoticeBox {
                    Layout.fillWidth: true
                    materialIcon: page.editable ? "tune" : "link"
                    text: page.editable
                        ? Translation.tr("%1 has its own bar: the settings below only change this monitor.").arg(page.editScreen)
                        : Translation.tr("%1 uses the global bar. Customize it to give this monitor its own settings, starting from a copy of the global bar.").arg(page.editScreen)

                    Item { Layout.fillWidth: true }

                    MonitorBarButton {
                        visible: !page.editable
                        materialIcon: "edit"
                        mainText: Translation.tr("Customize")
                        onClicked: ScreenConfig.customizeBar(page.editScreen)
                    }
                    MonitorBarButton {
                        visible: page.editable
                        materialIcon: "publish"
                        mainText: Translation.tr("Make global")
                        onClicked: ScreenConfig.applyBarToGlobal(page.editScreen)
                    }
                    MonitorBarButton {
                        visible: page.editable
                        materialIcon: "restart_alt"
                        mainText: Translation.tr("Use global")
                        onClicked: ScreenConfig.resetBar(page.editScreen)
                    }
                }

                ConfigSelectionArray {
                    id: copyFrom
                    // Another monitor's own bar (or the global one, to start over)
                    readonly property var sources: [
                        ...(page.editable ? [{ displayName: Translation.tr("Global bar"), icon: "tv_displays", value: "" }] : []),
                        ...Quickshell.screens
                            .filter(screen => screen.name !== page.editScreen && ScreenConfig.hasCustomBar(screen))
                            .map(screen => ({ displayName: screen.name, icon: "tune", value: screen.name }))
                    ]
                    visible: sources.length > 0
                    text: Translation.tr("Copy bar from")
                    icon: "content_copy"
                    currentValue: null
                    options: sources
                    onSelected: newValue => ScreenConfig.customizeBar(page.editScreen, newValue)
                }
            }
        }

        ContentSection {
            enabled: page.editable
            icon: "splitscreen_add"
            shape: MaterialShape.Shape.Cookie6Sided
            title: Translation.tr("Bar layout")
            hint: Translation.tr("Right-click a widget to open its settings (not every widget has settings here)")
            hintIcon: "info"

            GroupedList {
                LayoutSection {
                    sectionTitle: page.bar.vertical ? Translation.tr("Top") : Translation.tr("Left")
                    layout: page.bar.layouts.leftLayout
                    availableWidgets: page.availableFor("left")
                    getWidgetName: page.getWidgetName
                    onUpdate: list => page.bar.layouts.leftLayout = list
                    onWidgetContextRequested: id => page.openWidgetSettings(id)
                }

                LayoutSection {
                    sectionTitle: Translation.tr("Center")
                    layout: page.bar.layouts.middleLayout
                    availableWidgets: page.availableFor("middle")
                    getWidgetName: page.getWidgetName
                    onUpdate: list => page.bar.layouts.middleLayout = list
                    onWidgetContextRequested: id => page.openWidgetSettings(id)
                }

                LayoutSection {
                    sectionTitle: page.bar.vertical ? Translation.tr("Bottom") : Translation.tr("Right")
                    layout: page.bar.layouts.rightLayout
                    availableWidgets: page.availableFor("right")
                    getWidgetName: page.getWidgetName
                    onUpdate: list => page.bar.layouts.rightLayout = list
                    onWidgetContextRequested: id => page.openWidgetSettings(id)
                }
            }
        }

        ContentSection {
            enabled: page.editable
            icon: "pivot_table_chart"
            shape: MaterialShape.Shape.Gem
            title: Translation.tr("Positioning & Styles")
            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Bar position")
                    icon: "swap_vert"
                    currentValue: (page.bar.bottom ? 1 : 0) | (page.bar.vertical ? 2 : 0)
                    onSelected: newValue => {
                        page.bar.bottom = (newValue & 1) !== 0;
                        page.bar.vertical = (newValue & 2) !== 0;
                    }
                    options: [
                        { displayName: Translation.tr("Top"),    icon: "arrow_upward",   value: 0 },
                        { displayName: Translation.tr("Left"),   icon: "arrow_back",     value: 2 },
                        { displayName: Translation.tr("Bottom"), icon: "arrow_downward", value: 1 },
                        { displayName: Translation.tr("Right"),  icon: "arrow_forward",  value: 3 }
                    ]
                }
                ConfigSelectionArray {
                    text: Translation.tr("Bar style")
                    icon: "style"
                    textOnlyWhenActive: true
                    currentValue: page.bar.cornerStyle
                    onSelected: newValue => { page.bar.cornerStyle = newValue; }
                    options: [
                        { displayName: Translation.tr("Hug"),     icon: "line_curve", value: 0 },
                        { displayName: Translation.tr("Split Hug"), icon: "splitscreen", value: 6 },
                        { displayName: Translation.tr("Float"),   icon: "view_day",   value: 1 },
                        { displayName: Translation.tr("Islands"), icon: "crop_3_2",   value: 2 },
                        { displayName: Translation.tr("M3"), icon: "interests",   value: 3 },
                        { displayName: Translation.tr("M3 Hug"), icon: "category", value: 4 },
                        { displayName: Translation.tr("Panel"), icon: "toolbar",   value: 5 }
                    ]
                }
                ConfigSelectionArray {
                    text: Translation.tr("Group style")
                    icon: "tab_group"
                    currentValue: page.bar.borderless
                    onSelected: newValue => { page.bar.borderless = newValue; }
                    options: [
                        { displayName: Translation.tr(""),          icon: "block",          value: "transparent" },
                        { displayName: Translation.tr("Pills"),     icon: "pill",           value: "pills" },
                        { displayName: Translation.tr("Separated"), icon: "view_column_2",  value: "separated" },
                        { displayName: Translation.tr("Segmented"), icon: "tablet",           value: "segmented" },
                    ]
                }
                ColorSelectionArray {
                    icon: "brush"
                    text: Translation.tr("Group Color")
                    options: ["primaryContainer", "secondaryContainer", "tertiaryContainer", "layer1", "layer0"]
                    currentValue: page.bar.groupColor
                    onSelected: newValue => {
                        page.bar.groupColor = newValue
                    }
                }
                ConfigRow{
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "variable_insert"
                        text: Translation.tr("Show Background")
                        enabled: page.bar.cornerStyle === 0 || page.bar.cornerStyle === 1
                        checked: page.bar.showBackground
                        onCheckedChanged: { page.bar.showBackground = checked; }
                    }
                    ConfigSelectionArray {
                        text: Translation.tr("Autohide")
                        icon: "preview_off"
                        currentValue: page.bar.autoHide.enable
                        onSelected: newValue => { page.bar.autoHide.enable = newValue; }
                        options: [
                            { displayName: Translation.tr("No"),  icon: "close", value: false },
                            { displayName: Translation.tr("Yes"), icon: "check", value: true }
                        ]
                    }
                }
                ConfigSwitch {
                    buttonIcon: "expand"
                    enabled: page.bar.showFrame
                    text: Translation.tr("Overlap windows when center-only")
                    checked: page.bar.centerOnlyReserveFrame
                    onCheckedChanged: { page.bar.centerOnlyReserveFrame = checked; }
                }
                ConfigRow {
                    ConfigSwitch {
                        buttonIcon: "panorama_wide_angle"
                        text: Translation.tr("Show Frame")
                        checked: page.bar.showFrame

                        property bool switchReady: false
                        Component.onCompleted: Qt.callLater(() => switchReady = true)

                        onCheckedChanged: {
                            if (switchReady && checked) {
                                GlobalStates.refreshBar();
                            }
                            page.bar.showFrame = checked;
                        }
                    }
                    ConfigSwitch {
                        buttonIcon: "colors"
                        enabled: page.bar.showFrame
                        text: Translation.tr("Follow Frame Color")
                        checked: page.bar.followFrameColor
                        onCheckedChanged: { page.bar.followFrameColor = checked; }
                    }
                }
                ConfigSpinBox {
                    icon: "eraser_size_1"
                    text: Translation.tr("Frame thickness")
                    value: page.bar.frameThickness
                    from: 2
                    to: 10
                    stepSize: 1
                    onValueChanged: {
                        page.bar.frameThickness = value;
                    }
                }
                ColorSelectionArray {
                    icon: "imagesearch_roller"
                    text: Translation.tr("Frame Color")
                    options: ["primaryContainer", "secondaryContainer", "tertiaryContainer", "layer0", "black"] // sorry only solid colors transparency looks bad
                    currentValue: page.bar.frameColor
                    onSelected: newValue => {
                        page.bar.frameColor = newValue
                    }
                }
            }
        }

        ContentSection {
            enabled: page.editable
            icon: "nest_wifi_pro"
            shape: MaterialShape.Shape.Cookie4Sided
            title: Translation.tr("Dynamic Island")
            visible: page.isUsed("dynamicIsland")

            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Left widget")
                    icon: "right_panel_open"
                    currentValue: page.bar.dynamicIsland.leftWidget
                    onSelected: newValue => { page.bar.dynamicIsland.leftWidget = newValue; }
                    options: [
                        { displayName: Translation.tr(""),    icon: "block",        value: "none" },
                        { displayName: Translation.tr("Clock"),   icon: "schedule",     value: "clockWidget" },
                        { displayName: Translation.tr("Weather"), icon: "partly_cloudy_day", value: "weatherBar" },
                        { displayName: Translation.tr("Updates"), icon: "update",       value: "updatesCount" }
                    ]
                }
                ConfigSelectionArray {
                    text: Translation.tr("Right widget")
                    icon: "left_panel_open"
                    currentValue: page.bar.dynamicIsland.rightWidget
                    onSelected: newValue => { page.bar.dynamicIsland.rightWidget = newValue; }
                    options: [
                        { displayName: Translation.tr(""),         icon: "block",        value: "none" },
                        { displayName: Translation.tr("System icons"), icon: "settings",     value: "systemIcons" },
                        { displayName: Translation.tr("Tray"),  icon: "apps",         value: "sysTray" },
                        { displayName: Translation.tr("Util buttons"), icon: "widgets",   value: "utilButtons" }
                    ]
                }
            }

            ContentSubsection {
                Layout.topMargin: 10
                title: Translation.tr("Media")
                GroupedList {
                    ConfigSelectionArray {
                        text: Translation.tr("Visualizer style")
                        icon: "graphic_eq"
                        currentValue: page.bar.dynamicIsland.visualizerStyle
                        onSelected: newValue => { page.bar.dynamicIsland.visualizerStyle = newValue; }
                        options: [
                            { displayName: Translation.tr(""),      icon: "block",       value: "none" },
                            { displayName: Translation.tr("Dots"),  icon: "steppers",     value: "dots" },
                            { displayName: Translation.tr("Wave"),  icon: "ssid_chart",   value: "wave" }
                        ]
                    }
                    ConfigSwitch {
                        buttonIcon: "play_circle"
                        text: Translation.tr("Show media controls")
                        checked: page.bar.dynamicIsland.showMediaControls
                        onCheckedChanged: { page.bar.dynamicIsland.showMediaControls = checked; }
                    }
                }
            }
        }

        ContentSection {
            enabled: page.editable
            icon: "notifications"
            shape: MaterialShape.Shape.Bun
            title: Translation.tr("Notifications")
            
            GroupedList {
                ConfigComboBox { // too much items for configselectionarray - I know it's not the best place to put this but I can change it later
                    text: Translation.tr("Popup position")
                    buttonIcon: "my_location" 
                    currentValue: Config.options.notifications.position
                    fieldWidth: 50
                    onSelected: newValue => {
                        Config.options.notifications.position = newValue;
                    }
                    model: [
                        {
                            displayName: Translation.tr("Top left"),
                            value: "top_left"
                        },
                        {
                            displayName: Translation.tr("Top center"),
                            value: "top_center"
                        },
                        {
                            displayName: Translation.tr("Top right"),
                            value: "top_right"
                        },
                        {
                            displayName: Translation.tr("Bottom left"),
                            value: "bottom_left"
                        },
                        {
                            displayName: Translation.tr("Bottom center"),
                            value: "bottom_center"
                        },
                        {
                            displayName: Translation.tr("Bottom right"),
                            value: "bottom_right"
                        }
                    ]
                }
                ConfigSwitch {
                    buttonIcon: "counter_2"
                    text: Translation.tr("Unread indicator: show count")
                    checked: page.bar.indicators.notifications.showUnreadCount
                    onCheckedChanged: { page.bar.indicators.notifications.showUnreadCount = checked; }
                }
                ConfigSpinBox {
                    icon: "av_timer"
                    text: Translation.tr("Timeout duration (if not defined by notification) (ms)")
                    value: Config.options.notifications.timeout
                    from: 1000
                    to: 60000
                    stepSize: 1000
                    onValueChanged: {
                        Config.options.notifications.timeout = value;
                    }
                }
            }
        }

        ContentSection {
            enabled: page.editable
            shape: MaterialShape.Shape.Square
            icon: "inbox_customize"
            title: Translation.tr("Tray")
            visible: page.isUsed("sysTray")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "keep"; text: Translation.tr("Make icons pinned by default")
                    checked: Config.options.tray.invertPinnedItems
                    onCheckedChanged: { Config.options.tray.invertPinnedItems = checked; }
                }
                ConfigSwitch {
                    buttonIcon: "colors"; text: Translation.tr("Tint icons")
                    checked: Config.options.tray.monochromeIcons
                    onCheckedChanged: { Config.options.tray.monochromeIcons = checked; }
                }
            }
        }

        ContentSection {
            enabled: page.editable
            icon: "right_panel_open"
            shape: MaterialShape.Shape.Pentagon
            title: Translation.tr("Left sidebar button")
            visible: page.isUsed("leftSidebarButton")

            GroupedList {
                ConfigRow {
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                    spacing: 10

                    CustomIcon {
                        source: Config.options.custom.distroIcon || SystemInfo.distroIcon
                        colorize: Config.options.custom.colorizeIcon
                        color: page.leftIconColor
                        customFolder: Config.options.custom.iconsPath
                        width: Appearance.font.pixelSize.larger
                        height: Appearance.font.pixelSize.larger
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Icon")
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    StyledText {
                        text: (Config.options.custom.distroIcon || SystemInfo.distroIcon).replace("-symbolic", "")
                        color: Appearance.colors.colSubtext
                    }
                }
                IconPickerGrid {
                    customFolder: Config.options.custom.iconsPath
                    currentValue: Config.options.custom.distroIcon
                    colorize: Config.options.custom.colorizeIcon
                    iconColor: page.leftIconColor
                    onSelected: name => { Config.options.custom.distroIcon = name }
                }
                ConfigTextArea {
                    id: iconsPathField
                    Layout.fillWidth: true
                    buttonIcon: "folder_open"
                    text: Translation.tr("Custom icons folder")
                    placeholderText: Translation.tr("Leave empty to use the built-in icons, e.g. ~/Pictures/icons")
                    value: Config.options.custom.iconsPath
                    onValueChanged: iconsPathDebounce.restart()

                    Timer {
                        id: iconsPathDebounce
                        interval: 600
                        onTriggered: Config.options.custom.iconsPath = iconsPathField.value
                    }
                }
                ConfigSwitch {
                    buttonIcon: "colors"
                    text: Translation.tr("Colorize icon")
                    checked: Config.options.custom.colorizeIcon
                    onCheckedChanged: { Config.options.custom.colorizeIcon = checked }
                }
                ColorSelectionArray {
                    enabled: Config.options.custom.colorizeIcon
                    opacity: enabled ? 1 : 0.4
                    icon: "palette"
                    text: Translation.tr("Icon color")
                    options: ["onLayer0", "primary", "secondary", "tertiary", "onPrimaryContainer", "onSecondaryContainer", "onTertiaryContainer"]
                    currentValue: Config.options.custom.iconColor
                    onSelected: newValue => { Config.options.custom.iconColor = newValue }
                }
            }
        }

        ContentSection {
            enabled: page.editable
            icon: "vertical_align_center"
            shape: MaterialShape.Shape.Diamond
            title: Translation.tr("Divider")
            visible: page.isUsed("divisor")

            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Style")
                    icon: "style"
                    currentValue: page.bar.divider.style
                    onSelected: newValue => { page.bar.divider.style = newValue; }
                    options: [
                        { displayName: Translation.tr("Line"),  icon: "more_vert",       value: "rect" },
                        { displayName: Translation.tr("Dot"),   icon: "fiber_manual_record", value: "dot" },
                        { displayName: Translation.tr("Space"), icon: "space_bar",       value: "space" }
                    ]
                }
                ConfigSpinBox {
                    icon: "width"
                    enabled: page.bar.divider.style === "space"
                    text: Translation.tr("Space width (px)")
                    value: page.bar.divider.spacing
                    from: 4
                    to: 400
                    stepSize: 2
                    onValueChanged: {
                        page.bar.divider.spacing = value;
                    }
                }
            }
        }

        ContentSection {
            enabled: page.editable
            icon: "buttons_alt"
            shape: MaterialShape.Shape.SoftBurst
            title: Translation.tr("Utility buttons")
            visible: page.isUsed("utilButtons")

            GroupedList {
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "screenshot_region"
                        text: Translation.tr("Screen snip")
                        checked: page.bar.utilButtons.showScreenSnip
                        onCheckedChanged: { page.bar.utilButtons.showScreenSnip = checked }
                    }
                    ConfigSwitch {
                        buttonIcon: "colorize"
                        text: Translation.tr("Color picker")
                        checked: page.bar.utilButtons.showColorPicker
                        onCheckedChanged: { page.bar.utilButtons.showColorPicker = checked }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "keyboard"
                        text: Translation.tr("Keyboard toggle")
                        checked: page.bar.utilButtons.showKeyboardToggle
                        onCheckedChanged: { page.bar.utilButtons.showKeyboardToggle = checked }
                    }
                    ConfigSwitch {
                        buttonIcon: "mic"
                        text: Translation.tr("Mic toggle")
                        checked: page.bar.utilButtons.showMicToggle
                        onCheckedChanged: { page.bar.utilButtons.showMicToggle = checked }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "dark_mode"
                        text: Translation.tr("Dark/Light toggle")
                        checked: page.bar.utilButtons.showDarkModeToggle
                        onCheckedChanged: { page.bar.utilButtons.showDarkModeToggle = checked }
                    }
                    ConfigSwitch {
                        buttonIcon: "speed"
                        text: Translation.tr("Performance Profile")
                        checked: page.bar.utilButtons.showPerformanceProfileToggle
                        onCheckedChanged: { page.bar.utilButtons.showPerformanceProfileToggle = checked }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "screen_record"
                        text: Translation.tr("Record Screen")
                        checked: page.bar.utilButtons.showScreenRecord
                        onCheckedChanged: { page.bar.utilButtons.showScreenRecord = checked }
                    }
                    ConfigSwitch {
                        buttonIcon: "imagesmode"
                        text: Translation.tr("Wallpapers Toggle")
                        checked: page.bar.utilButtons.showWallpaperToggle
                        onCheckedChanged: { page.bar.utilButtons.showWallpaperToggle = checked }
                    }
                }
            }
        }

        ContentSection {
            enabled: page.editable
            shape: MaterialShape.Shape.Cookie12Sided
            icon: "steppers"; title: Translation.tr("Workspaces")
            visible: page.isUsed("workspaces")
            GroupedList {
                ConfigSelectionArray {
                    text: Translation.tr("Style")
                    icon: "style"
                    currentValue: page.bar.workspaces.style ?? "default"
                    onSelected: newValue => {
                        page.bar.workspaces.style = newValue
                    }
                    options: [
                        { displayName: Translation.tr("Default"), icon: "view_carousel",         value: "default" },
                        { displayName: Translation.tr("GNOME"),   icon: "more_horiz",            value: "gnome" },
                        { displayName: Translation.tr("Dots"),    icon: "hdr_weak",               value: "dots" },
                        { displayName: Translation.tr("Ticks"),   icon: "more_vert",             value: "ticks" }
                    ]
                }
                ConfigSpinBox {
                    icon: "view_column"; text: Translation.tr("Workspaces shown")
                    value: page.bar.workspaces.shown
                    from: 1; to: 30
                    onValueChanged: { page.bar.workspaces.shown = value; }
                }
                ConfigSwitch {
                    enabled: page.defaultWorkspacesDesign
                    buttonIcon: "counter_1"; text: Translation.tr("Always show numbers")
                    checked: page.bar.workspaces.alwaysShowNumbers
                    onCheckedChanged: { page.bar.workspaces.alwaysShowNumbers = checked; }
                }
                ConfigSelectionArray {
                    enabled: page.defaultWorkspacesDesign
                    opacity: page.defaultWorkspacesDesign ? 1 : 0.5
                    text: Translation.tr("Numbers style")
                    icon: "looks_3"
                    currentValue: JSON.stringify(page.bar.workspaces.numberMap)
                    onSelected: newValue => {
                        page.bar.workspaces.numberMap = JSON.parse(newValue)
                    }
                    options: [
                        { displayName: Translation.tr("Normal"),    icon: "timer_10",        value: '[]' },
                        { displayName: Translation.tr("Han chars"), icon: "glyphs",          value: '["一","二","三","四","五","六","七","八","九","十","十一","十二","十三","十四","十五","十六","十七","十八","十九","二十"]' },
                        { displayName: Translation.tr("Roman"),     icon: "account_balance", value: '["I","II","III","IV","V","VI","VII","VIII","IX","X","XI","XII","XIII","XIV","XV","XVI","XVII","XVIII","XIX","XX"]' }
                    ]
                }
                ConfigSwitch {
                    enabled: page.defaultWorkspacesDesign
                    buttonIcon: "award_star"; text: Translation.tr("Show app icons")
                    checked: page.bar.workspaces.showAppIcons
                    onCheckedChanged: { page.bar.workspaces.showAppIcons = checked; }
                }
                ConfigSelectionArray {
                    enabled: page.defaultWorkspacesDesign
                    opacity: page.defaultWorkspacesDesign ? 1 : 0.5
                    text: Translation.tr("Indicator style")
                    icon: "page_control"
                    currentValue: page.bar.workspaces.indicatorStyle ?? "icon"
                    onSelected: newValue => {
                        page.bar.workspaces.indicatorStyle = newValue
                    }
                    options: [
                        { displayName: Translation.tr("Dots"),  icon: "radio_button_checked",   value: "dot" },
                        { displayName: Translation.tr("Icons"), icon: "interests",              value: "icon" },
                    ]
                }
            }
        }

        ContentSection {
            enabled: page.editable
            icon: "battery_android_full"
            title: Translation.tr("Battery")
            visible: page.isUsed("batteryIndicator")

            GroupedList {
                ConfigComboBox {
                    Layout.fillWidth: true
                    buttonIcon: "style"
                    text: Translation.tr("Battery style")
                    fieldWidth: 220
                    fixedWidth: true
                    currentValue: page.bar.battery.style
                    onSelected: newValue => { page.bar.battery.style = newValue }
                    model: [
                        { displayName: "Android", value: "bar" },
                        { displayName: "iOS", value: "ios" },
                        { displayName: "macOS", value: "macos" },
                        { displayName: "Windows", value: "windows" },
                        { displayName: Translation.tr("Ring"), value: "ring" },
                        { displayName: Translation.tr("Icon"), value: "icon" },
                        { displayName: Translation.tr("Number"), value: "number" }
                    ]
                }
                ConfigSwitch {
                    buttonIcon: "percent"
                    text: Translation.tr("Show percentage")
                    checked: page.bar.battery.showPercentage
                    onCheckedChanged: { page.bar.battery.showPercentage = checked }
                }
                ConfigSwitch {
                    buttonIcon: "bolt"
                    text: Translation.tr("Charging bolt")
                    checked: page.bar.battery.showCharging
                    onCheckedChanged: { page.bar.battery.showCharging = checked }
                }
            }
        }

        ContentSection {
            enabled: page.editable
            icon: "empty_dashboard"
            shape: MaterialShape.Shape.Burst
            title: Translation.tr("Resources")
            visible: page.isUsed("resources")

            GroupedList {
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "planner_review"
                        text: Translation.tr("CPU")
                        checked: page.bar.resources.alwaysShowCpu
                        onCheckedChanged: { page.bar.resources.alwaysShowCpu = checked }
                    }
                    ConfigSwitch {
                        buttonIcon: "thermostat"
                        text: Translation.tr("CPU Temperature")
                        checked: page.bar.resources.alwaysShowCpuTemp
                        onCheckedChanged: { page.bar.resources.alwaysShowCpuTemp = checked }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "memory"
                        text: Translation.tr("RAM")
                        checked: page.bar.resources.alwaysShowRam
                        onCheckedChanged: { page.bar.resources.alwaysShowRam = checked }
                    }
                    ConfigSwitch {
                        buttonIcon: "storage"
                        text: Translation.tr("Disk")
                        checked: page.bar.resources.alwaysShowDisk
                        onCheckedChanged: { page.bar.resources.alwaysShowDisk = checked }
                    }
                }
                ConfigRow {
                    uniform: true
                    ConfigSwitch {
                        buttonIcon: "swap_horiz"
                        text: Translation.tr("Swap")
                        checked: page.bar.resources.alwaysShowSwap
                        onCheckedChanged: { page.bar.resources.alwaysShowSwap = checked }
                    }
                }
                ConfigSelectionArray {
                    text: Translation.tr("Style")
                    icon: "style"
                    currentValue: page.bar.resources.style
                    onSelected: newValue => { page.bar.resources.style = newValue; }
                    options: [
                        { displayName: Translation.tr("Filled"),    icon: "incomplete_circle",  value: "filled" },
                        { displayName: Translation.tr("Outline"),   icon: "circles",            value: "outline" },
                        { displayName: Translation.tr("Text"),      icon: "text_fields",        value: "text" }
                    ]
                }
                ConfigSwitch {
                    buttonIcon: "decimal_increase"; text: Translation.tr("Show Percentage")
                    checked: page.bar.resources.showValue
                    onCheckedChanged: { page.bar.resources.showValue = checked; }
                }
                ConfigSpinBox {
                    icon: "av_timer"
                    text: Translation.tr("Polling interval (ms)")
                    value: Config.options.resources.updateInterval
                    from: 100
                    to: 10000
                    stepSize: 100
                    onValueChanged: {
                        Config.options.resources.updateInterval = value;
                    }
                }
            }
        }

        ContentSection {
            icon: "neurology"
            title: Translation.tr("AI Usage")

            GroupedList {
                ConfigSwitch {
                    buttonIcon: "terminal"
                    text: Translation.tr("Claude Code")
                    checked: Config.options.bar.aiUsage.claudeEnabled
                    onCheckedChanged: Config.options.bar.aiUsage.claudeEnabled = checked
                }
                ConfigSwitch {
                    buttonIcon: "code"
                    text: Translation.tr("Codex")
                    checked: Config.options.bar.aiUsage.codexEnabled
                    onCheckedChanged: Config.options.bar.aiUsage.codexEnabled = checked
                }
            }
        }

        ContentSection {
            enabled: page.editable
            icon: "music_note"
            shape: MaterialShape.Shape.Sunny
            title: Translation.tr("Media")
            visible: page.isUsed("media")

            GroupedList {
                ConfigTextArea {
                    id: preferredPlayerField
                    Layout.fillWidth: true
                    buttonIcon: "play_circle"
                    text: Translation.tr("Preferred Player")
                    placeholderText: Translation.tr("e.g. spotify, firefox")
                    value: Config.options.bar.media.preferredPlayer
                    onValueChanged: {
                        mediaDebounceTimer.restart();
                    }

                    Timer {
                        id: mediaDebounceTimer
                        interval: 600
                        repeat: false
                        onTriggered: {
                            Config.options.bar.media.preferredPlayer = preferredPlayerField.value;
                        }
                    }
                }
                ConfigSwitch {
                    buttonIcon: "keep"; text: Translation.tr("Pin media controls")
                    checked: page.bar.media.alwaysVisible
                    onCheckedChanged: { page.bar.media.alwaysVisible = checked; }
                }
                ConfigSwitch {
                    buttonIcon: "titlecase"; text: Translation.tr("Show only title")
                    checked: page.bar.media.onlyTitle
                    onCheckedChanged: { page.bar.media.onlyTitle = checked; }
                }
                ConfigSpinBox {
                    icon: "width"
                    text: Translation.tr("Max media width")
                    value: page.bar.media.maxWidth
                    from: 100
                    to: 500
                    stepSize: 10
                    onValueChanged: {
                        page.bar.media.maxWidth = value;
                    }
                }
            }
        }

        ContentSection {
            enabled: page.editable
            shape: MaterialShape.Shape.Puffy
            icon: "tooltip"; title: Translation.tr("Tooltips")
            GroupedList {
                ConfigSwitch {
                    buttonIcon: "visibility"; text: Translation.tr("Enable")
                    checked: page.bar.tooltips.enable
                    onCheckedChanged: { page.bar.tooltips.enable = checked; }
                }
                ConfigSwitch {
                    buttonIcon: "ads_click"; text: Translation.tr("Click to show")
                    checked: page.bar.tooltips.clickToShow
                    onCheckedChanged: { page.bar.tooltips.clickToShow = checked; }
                    enabled: page.bar.tooltips.enable
                }
                ConfigSelectionArray {
                    text: Translation.tr("Style")
                    icon: "tooltip"
                    enabled: page.bar.tooltips.enable
                    currentValue: page.bar.tooltips.style
                    onSelected: newValue => { page.bar.tooltips.style = newValue }
                    options: [
                        { displayName: Translation.tr("Default"), icon: "tooltip", value: "default" },
                        { displayName: Translation.tr("Morph"), icon: "join_inner", value: "morph" }
                    ]
                }
            }
        }
    }

    component MonitorBarButton: RippleButtonWithIcon {
        Layout.fillWidth: false
        buttonRadius: Appearance.rounding.small
        colBackground: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer)
        colBackgroundHover: Appearance.colors.colPrimaryContainerHover
        colRipple: Appearance.colors.colPrimaryContainerActive
    }
}

pragma Singleton

import qs
import QtQuick
import Quickshell

Singleton {
    id: root

    function runSystemUpdate() {
        Quickshell.execDetached([
            "kitty", "--hold",
            "fish", "-i", "-l", "-c",
            "if type -q yay; yay -Syu --combinedupgrade=false; else if type -q paru; paru -Syu; else; sudo pacman -Syu; end"
        ])
        Qt.callLater(() => GlobalStates.settingsOpen = false)
    }

    function runUpdateDots() {
        const updateScript = `
            set -e
            DIR="$HOME/.config/quickshell"

            rm -rf "$DIR/end4-pC-tmp"
            git clone https://github.com/pctrade/end4-pC.git "$DIR/end4-pC-tmp"

            rm -rf "$DIR/end4-pC-old"
            [ -d "$DIR/end4-pC" ] && mv "$DIR/end4-pC" "$DIR/end4-pC-old"
            mv "$DIR/end4-pC-tmp" "$DIR/end4-pC"

            # Restart under the config name Hyprland uses ($qsConfig), so the
            # keybinds that check "qs -c $qsConfig" still find the shell.
            # A hardcoded name made them fall back to fuzzel and co.
            SHELL_CONFIG="\${qsConfig:-end4-pC}"
            if [ "$SHELL_CONFIG" != "end4-pC" ]; then
                echo
                echo "Note: Hyprland runs the '$SHELL_CONFIG' config, not end4-pC."
                echo "end4-pC was updated, but '$SHELL_CONFIG' is restarted as it is."
            fi

            killall qs 2>/dev/null || true
            sleep 0.5
            setsid qs -c "$SHELL_CONFIG" >/tmp/qs.log 2>&1 < /dev/null &
            disown

            rm -rf "$DIR/end4-pC-old"
        `

        Quickshell.execDetached(["kitty", "--hold", "bash", "-c", updateScript])
        Qt.callLater(() => GlobalStates.settingsOpen = false)
    }
}

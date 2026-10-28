local defaults = require("machine").defaults
local saved = require("settings")
local boot = saved.boot or defaults.boot
local cursor = saved.cursor or defaults.cursor

hl.on("hyprland.start", function()
    if boot.enabled ~= false then
        hl.exec_cmd("BOOT_BLACK_MS=" .. (boot.black_ms or defaults.boot.black_ms) .. " qs -p ~/.config/hypr/utilities/boot.qml --daemonize")
    end
    hl.exec_cmd("hyprctl setcursor " .. (cursor.theme or defaults.cursor.theme) .. " " .. (cursor.size or defaults.cursor.size))
    -- portal doesn't survive a relog, restart it
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        .. "; systemctl --user reset-failed xdg-desktop-portal-hyprland xdg-desktop-portal"
        .. "; systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("~/.config/hypr/utilities/shells.sh start")
    hl.exec_cmd("~/.config/hypr/utilities/bar.sh boot")
    hl.exec_cmd("~/.config/hypr/utilities/pypr.sh")
    hl.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ 0")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("sleep .5 && swww restore")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd([[sh -c '
        command -v hyprpm >/dev/null 2>&1 || exit 0
        hyprpm list 2>/dev/null | grep -qi hyprglass || exit 0
        hyprpm reload -n >/dev/null 2>&1
        sleep 1
        hyprctl plugin list 2>/dev/null | grep -qi hyprglass && hyprctl reload
    ']])
end)

hl.env("ELECTRON_OZONE_PLATFORM_HINT", "wayland")
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("XCURSOR_THEME", cursor.theme or defaults.cursor.theme)
hl.env("XCURSOR_SIZE", tostring(cursor.size or defaults.cursor.size))
hl.device({ name = "epic-mouse-v1", sensitivity = 0 })

return { defaults = defaults }

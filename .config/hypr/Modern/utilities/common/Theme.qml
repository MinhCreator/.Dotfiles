pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property string sans: "CodeNewRoman Nerd Font Propo"
    readonly property int pad: 14

    property real rounding: 10
    property bool glass: false
    property bool hyprAnimates: true
    property real hyprPace: 1
    property var hyprSettle: own
    property var hyprLeave: own
    readonly property bool ownMotion: /\["utilities"\]\s*=\s*\{[^}]*\["animations"\]\s*=\s*true/.test(settingsFile.text())

    readonly property var own: [0.2, 0.9, 0.3, 1, 1, 1]
    readonly property bool animates: ownMotion || hyprAnimates
    readonly property real pace: ownMotion ? 1 : hyprPace
    readonly property var settle: ownMotion ? own : hyprSettle
    readonly property var leave: ownMotion ? own : hyprLeave
    readonly property int fast: ms(160)
    readonly property int move: ms(280)

    // corner radius scaled to hyprland's rounding
    function r(px) {
        return px * rounding / 10
    }

    function ms(d) {
        return animates ? Math.round(d * pace) : 0
    }

    function refresh() {
        optionProc.running = true
        curveProc.running = true
        glassProc.running = true
    }
    Component.onCompleted: refresh()

    Process {
        id: optionProc
        command: ["sh", "-c", "hyprctl -j getoption decoration:rounding; hyprctl -j getoption animations:enabled"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const [r, a] = text.trim().split(/\n(?=\{)/).map(s => JSON.parse(s))
                    if (typeof r.int === "number") root.rounding = r.int
                    root.hyprAnimates = a.bool ?? a.int !== 0
                } catch (e) {}
            }
        }
    }

    // hyprctl errors instead of JSON without the plugin
    Process {
        id: glassProc
        command: ["sh", "-c", "for o in enabled namespaces exclude_namespaces; do hyprctl -j getoption plugin:hyprglass:layers:$o; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const [on, only, except] = text.trim().split(/\n(?=\{)/).map(s => JSON.parse(s))
                    const ns = "quickshell-bar"
                    const has = o => (o.str || "").split(",").includes(ns)
                    root.glass = on.int === 1 && (!only.str || only.str === "[[EMPTY]]" || has(only)) && !has(except)
                } catch (e) { root.glass = false }
            }
        }
    }

    Process {
        id: curveProc
        command: ["hyprctl", "-j", "animations"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const [leaves, beziers] = JSON.parse(text)
                    const parent = { windowsIn: "windows", windowsOut: "windows", windows: "global" }
                    const leaf = (name, has) => {
                        for (let n = name; n; n = parent[n]) {
                            const l = leaves.find(a => a.name === n)
                            if (l && has(l)) return l
                        }
                        return null
                    }
                    const curve = name => {
                        const l = leaf(name, l => !!l.bezier && beziers.some(b => b.name === l.bezier))
                        const b = l ? beziers.find(b => b.name === l.bezier) : null
                        return b ? [b.X0, b.Y0, b.X1, b.Y1, 1, 1] : null
                    }
                    root.hyprSettle = curve("windowsIn") ?? root.own
                    root.hyprLeave = curve("windowsOut") ?? root.hyprSettle
                    // speed is in deciseconds, 3 is what everything was tuned at
                    const w = leaf("windowsIn", l => l.speed > 0)
                    root.hyprPace = w ? Math.max(0.2, Math.min(3, w.speed / 3)) : 1
                } catch (e) {}
            }
        }
    }

    // file is written right before hyprland applies it, so retry a few times
    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.config/hypr/settings.lua"
        watchChanges: true
        printErrors: false
        onFileChanged: { reload(); settleTimer.n = 0; settleTimer.restart() }
    }
    Timer {
        id: settleTimer
        property int n: 0
        interval: 250
        repeat: true
        onTriggered: { root.refresh(); if (++n >= 3) stop() }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) { if (event.name === "configreloaded") root.refresh() }
    }

    // lua dispatch if hyprland.lua is in use
    FileView {
        id: luaFile
        path: Quickshell.env("HOME") + "/.config/hypr/hyprland.lua"
        blockLoading: true
        printErrors: false
    }
    readonly property bool lua: luaFile.text() !== ""

    function dispatch(lua, classic) {
        Hyprland.dispatch(root.lua ? lua : classic)
    }

    function run(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd])
    }

    // skip playerctld, it keeps the last track after players stop
    readonly property var players: Mpris.players.values.filter(p => !(p.dbusName || "").includes("playerctld"))

    // pinned one, then spotify cause that's what i use, then whatever's playing, then whatever
    function pickPlayer(pinned) {
        const ps = players
        return ps.find(p => pinned && p.dbusName === pinned) ?? ps.find(isSpotify) ?? ps.find(p => p.isPlaying) ?? ps[0] ?? null
    }

    function isSpotify(x) {
        return !!x && [x.identity, x.dbusName, x.id, x.title, x.tooltipTitle].some(s => (s || "").toLowerCase().includes("spotify"))
    }

    function openSpotify() {
        Quickshell.execDetached([Quickshell.shellDir + "/common/spotify.sh"])
    }

    // focusedMonitor can be stale at startup, so ask for the cursor position
    function locate(done) {
        located.push(done)
        cursorQuery.running = true
    }
    function screenAt(x, y) {
        return Quickshell.screens.find(s => x >= s.x && x < s.x + s.width && y >= s.y && y < s.y + s.height) ?? focusedScreen()
    }
    function focusedScreen() {
        return Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
    }
    // ui scale for the popups, i tuned everything at 1080p
    function scaleFor(s) {
        return s ? Math.max(0.8, Math.min(1.35, Math.min(s.width / 1920, s.height / 1080))) : 1
    }
    property var located: []
    function found(c) {
        const scr = c ? screenAt(c.x, c.y) : screenAt(-1, -1)
        const done = located
        located = []
        done.forEach(f => f(scr))
    }
    Process {
        id: cursorQuery
        command: ["hyprctl", "-j", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                let c = null
                try { c = JSON.parse(text) } catch (e) {}
                root.found(c)
            }
        }
        onExited: code => { if (code !== 0) root.found(null) }
    }

    // keeps the last good palette, wal rewrites the file in pieces and a half-written read used to flash the defaults
    Watched {
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        onLoaded: { try { root.saved = JSON.parse(text()) } catch (e) {} }
    }

    property var saved: null
    // wallpaper picker preview palette, null when not previewing
    property var preview: null
    readonly property var wal: preview ? {
        colors: preview.reduce((o, c, i) => (o["color" + i] = c, o), {}),
        special: { background: preview[0], foreground: preview[15] }
    } : saved
    // the bright half (9-14) reads best on the dark panels. on the nvim schemes that's real red/green/yellow/blue/magenta/cyan,
    // on pywal it's just six different wallpaper tones, which is still way better than color9 on everything
    function c(i, fallback) { return wal ? wal.colors["color" + i] : fallback }
    readonly property color red: c(9, "#e06c75")
    readonly property color green: c(10, "#98c379")
    readonly property color yellow: c(11, "#e5c07b")
    readonly property color blue: c(12, "#8fd3ff")
    readonly property color magenta: c(13, "#c3a6ff")
    readonly property color cyan: c(14, "#9fe0d0")

    // what stuff actually uses, so it isn't color9 on everything
    // settings > colors can point any of these at another slot, saved as { role: slot }
    Watched { id: rolesFile; path: Quickshell.env("HOME") + "/.config/hypr/.color-roles.json" }
    readonly property var roles: { try { return JSON.parse(rolesFile.text()) } catch (e) { return {} } }
    readonly property var roleSlots: ({ accent: 9, accent2: 13, ok: 10, caution: 11, info: 14, warn: 1 })
    function slotOf(role) { return roles[role] ?? roleSlots[role] }
    // picks stick to the scheme you're on, call it empty to undo them
    function setRole(role, slot) {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.config/hypr/utilities/color-roles.sh"].concat(role ? ["set", role, String(slot)] : ["reset"]))
    }
    readonly property color accent: c(slotOf("accent"), "#8fd3ff")
    readonly property color accent2: c(slotOf("accent2"), magenta)
    readonly property color ok: c(slotOf("ok"), green)
    readonly property color caution: c(slotOf("caution"), yellow)
    readonly property color info: c(slotOf("info"), cyan)
    readonly property color warn: c(slotOf("warn"), "#e06c75")
    // some schemes have text basically the same color as the bg. why
    readonly property color fg: readable(c(7, "#c7c6c2"))
    readonly property color bright: readable(c(15, "#ffffff"))
    // based on the text color, color8 is too dark on some schemes
    readonly property color dim: alpha(fg, 0.5)
    readonly property color bg: wal ? wal.special.background : "#101418"

    // "black" and "white" are the darkest and lightest colors the scheme has, not pure ones
    readonly property var shades: [bg].concat(Array.from({ length: 16 }, (_, i) => Qt.color(c(i, i < 8 ? "#101418" : "#ffffff"))))
    readonly property color darkest: shades.reduce((a, b) => lum(b) < lum(a) ? b : a)
    readonly property color lightest: shades.reduce((a, b) => lum(b) > lum(a) ? b : a)
    function lum(c) {
        const f = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
        return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b)
    }
    function contrast(a, b) {
        const x = lum(a), y = lum(b)
        return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)
    }
    function against(fill) { return contrast(fill, darkest) >= contrast(fill, lightest) ? darkest : lightest }
    function readable(c) { c = Qt.color(c); return contrast(c, bg) >= 3 ? c : against(bg) }

    // used to mix bg in for glass but pills came out muddier than the sliders. same color everywhere now
    function soft(c, hot) { return hot ? Qt.lighter(c, 1.12) : Qt.color(c) }
    function on(fill) { return against(soft(fill)) }
    readonly property color ink: on(accent)
    readonly property var spectrum: [blue, cyan, green, yellow, magenta]

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function along(stops, f) {
        if (!stops || stops.length === 0) return accent
        if (stops.length === 1) return stops[0]
        const x = Math.max(0, Math.min(1, f)) * (stops.length - 1)
        const i = Math.min(stops.length - 2, Math.floor(x))
        const a = Qt.color(stops[i]), b = Qt.color(stops[i + 1]), m = x - i
        return Qt.rgba(a.r + (b.r - a.r) * m, a.g + (b.g - a.g) * m, a.b + (b.b - a.b) * m, 1)
    }
}

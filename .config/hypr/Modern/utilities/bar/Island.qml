import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Services.Mpris
import "../common"

Item {
    id: page

    property var ctx
    property var pill

    readonly property var tabs: [
        { id: "media", glyph: "󰝚" },
        { id: "timer", glyph: "󰔛" },
        { id: "color", glyph: "󰈊" },
        { id: "capture", glyph: "󰄀" },
        { id: "weather", glyph: ctx.weather.ready ? ctx.weather.glyph(ctx.weather.code, ctx.weather.night) : "󰖕" }
    ]
    readonly property string current: pill.tab !== "" ? pill.tab : "media"
    // keeps the menu up while an app waits on me to pick a share
    readonly property bool holdOpen: captureTab.sharing && current === "capture"
    onCurrentChanged: if (current === "weather") ctx.weather.refresh(false)

    implicitHeight: 196

    Item {
        anchors.fill: parent

        Item {
            x: 50
            width: parent.width - 50
            height: parent.height

            // tabs keep the 440 they were laid out for, centred. media takes the whole width
            component Fade: Item {
                property bool on: false
                property real maxW: 440
                width: Math.min(maxW, parent.width)
                height: parent.height
                x: (parent.width - width) / 2
                opacity: on ? 1 : 0
                visible: opacity > 0
                transform: Translate { y: (1 - opacity) * 6 }
                Behavior on opacity { Settle { duration: Theme.move } }
            }

            Fade {
                on: page.current === "media"
                maxW: Infinity
                MediaTab {
                    anchors.fill: parent
                    active: page.pill.open && parent.visible
                    player: page.ctx.player
                    playerCount: page.ctx.players.length
                    playing: page.ctx.playing
                    musicOut: page.ctx.mediaAway(page.pill)
                    canPopOut: !page.ctx.standalone
                    onCyclePlayer: page.ctx.cyclePlayer()
                    onPopOut: { page.pill.close(); if (!page.ctx.musicOut) page.ctx.musicCall("open") }
                    onBringBack: { page.pill.close(); page.ctx.musicCall("close") }
                }
            }
            Fade {
                on: page.current === "timer"
                TimerTab {
                    anchors.fill: parent
                    timer: page.ctx.timer
                }
            }
            Fade {
                on: page.current === "color"
                ColorTab {
                    anchors.fill: parent
                    onPick: { page.pill.close(); page.ctx.pickColor() }
                    onCopy: c => page.ctx.run("printf %s '" + c + "' | wl-copy")
                }
            }
            Fade {
                on: page.current === "capture"
                CaptureTab {
                    id: captureTab
                    anchors.fill: parent
                    active: page.pill.open && parent.visible
                    open: page.pill.open
                    onCapture: (kind, mode) => {
                        page.pill.close()
                        page.ctx.run("sleep 0.35; '" + Quickshell.shellDir + "/bar/" + (kind === "share" ? "share.sh' pick " : "capture.sh' " + kind + " ") + mode)
                    }
                    onCancelShare: page.ctx.run("'" + Quickshell.shellDir + "/bar/share.sh' cancel")
                    onCast: (tv, mode) => {
                        page.pill.close()
                        Quickshell.execDetached(["sh", "-c", 'sleep 0.35; exec "$0" start "$1" "$2" "$3" "$4"',
                            Quickshell.shellDir + "/bar/cast.py", tv.kind, tv.target, tv.name, mode])
                    }
                    onStopCast: Quickshell.execDetached([Quickshell.shellDir + "/bar/cast.py", "stop"])
                    onMore: { page.pill.close(); page.ctx.run("gnome-network-displays") }
                    onStop: page.ctx.run("'" + Quickshell.shellDir + "/bar/capture.sh' stop")
                }
            }
            Fade {
                on: page.current === "weather"
                WeatherTab {
                    anchors.fill: parent
                    weather: page.ctx.weather
                }
            }
        }

        Column {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: page.tabs

                Rectangle {
                    id: tab
                    required property var modelData
                    readonly property bool on: page.current === modelData.id
                    width: 32
                    height: 32
                    radius: Math.min(Theme.rounding, 10)
                    color: on ? Theme.soft(Theme.accent) : Theme.alpha(Theme.fg, tabArea.containsMouse ? 0.1 : 0.04)
                    Behavior on color { ColorAnimation { duration: Theme.fast } }

                    Label {
                        anchors.centerIn: parent
                        text: tab.modelData.glyph
                        font.pixelSize: 14
                        color: tab.on ? Theme.ink : tabArea.containsMouse ? Theme.bright : Theme.fg
                    }

                    Hover {
                        id: tabArea
                        anchors.fill: parent
                        onContainsMouseChanged: if (containsMouse) page.pill.tab = tab.modelData.id
                        onClicked: page.pill.tab = tab.modelData.id
                    }
                }
            }

            WheelHandler {
                onWheel: e => {
                    const i = page.tabs.findIndex(t => t.id === page.current)
                    page.pill.tab = page.tabs[(i + (e.angleDelta.y > 0 ? -1 : 1) + page.tabs.length) % page.tabs.length].id
                }
            }
        }
    }

    component MediaTab: Item {
        id: page

        property var player: null
        property int playerCount: 0
        property bool playing: false
        property bool active: false
        signal cyclePlayer()
        signal popOut()
        signal bringBack()
        property bool musicOut: false
        property bool canPopOut: true

        function mmss(s) {
            if (!isFinite(s) || s < 0) s = 0
            const m = Math.floor(s / 60), r = Math.floor(s % 60)
            return m + ":" + (r < 10 ? "0" : "") + r
        }

        function openApp() {
            if (!player || Theme.isSpotify(player)) Theme.openSpotify()
            else if (player.canRaise) player.raise()
        }

        Timer {
            running: page.active && page.playing
            interval: 1000
            repeat: true
            triggeredOnStart: true
            onTriggered: if (page.player) page.player.positionChanged()
        }

        Notice {
            visible: page.musicOut
            glyph: "󰏌"
            text: "Playing in the music player"
            action: "\uf066  Bring it back"
            onPressed: page.bringBack()
        }

        Notice {
            visible: !page.player && !page.musicOut
            glyph: "󰝚"
            text: "Nothing playing"
            action: "\uf1bc  Open Spotify"
            onPressed: Theme.openSpotify()
        }

        Item {
            anchors.fill: parent
            visible: !!page.player && !page.musicOut

            ClippingRectangle {
                id: art
                width: parent.height
                height: width
                radius: Math.min(Theme.rounding, 16)
                color: Theme.alpha(Theme.fg, 0.1)
                scale: artArea.containsMouse ? 1.03 : 1
                Behavior on scale { NumberAnimation { duration: Theme.fast } }

                Image {
                    anchors.fill: parent
                    source: page.player ? page.player.trackArtUrl : ""
                    sourceSize.width: 512
                    sourceSize.height: 512
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Rectangle {
                    anchors.fill: parent
                    color: Theme.alpha(Theme.bg, 0.45)
                    opacity: artArea.containsMouse ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.fast } }
                    Label {
                        anchors.centerIn: parent
                        text: "󰏌"
                        font.pixelSize: 20
                        color: Theme.bright
                    }
                }

                MouseArea { id: artArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.openApp() }
            }

            Item {
                id: info
                anchors.left: art.right
                anchors.leftMargin: 20
                anchors.right: parent.right
                height: parent.height

                Rectangle {
                    id: chip
                    height: 20
                    width: chipRow.implicitWidth + 16
                    radius: Math.min(Theme.rounding, 10)
                    color: Theme.alpha(Theme.fg, chipArea.containsMouse && page.playerCount > 1 ? 0.14 : 0.07)

                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 6
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Theme.isSpotify(page.player) ? "" : "󰝚"
                            font.pixelSize: 11
                            color: Theme.ok
                        }
                        Label {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (page.player ? page.player.identity : "") + (page.playerCount > 1 ? "  " : "")
                            font.pixelSize: 10
                            color: Theme.fg
                        }
                    }
                    MouseArea {
                        id: chipArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: page.playerCount > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: page.cyclePlayer()
                    }
                }

                Column {
                    anchors.top: chip.bottom
                    anchors.topMargin: 8
                    width: parent.width
                    spacing: 2

                    Label {
                        width: parent.width
                        text: page.player ? (page.player.trackTitle || "Unknown title") : ""
                        elide: Text.ElideRight
                        font.pixelSize: 17
                        font.bold: true
                        color: Theme.bright
                    }
                    Label {
                        width: parent.width
                        text: page.player ? (page.player.trackArtist || "") : ""
                        elide: Text.ElideRight
                        font.pixelSize: 12
                        color: Theme.fg
                    }
                    Label {
                        width: parent.width
                        visible: text !== ""
                        text: page.player ? (page.player.trackAlbum || "") : ""
                        elide: Text.ElideRight
                        font.pixelSize: 11
                        color: Theme.dim
                    }
                }

                Item {
                    id: progress
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 50
                    width: parent.width
                    height: 14
                    visible: !!page.player && page.player.lengthSupported && page.player.length > 0
                    readonly property real frac: visible ? Math.max(0, Math.min(1, page.player.position / page.player.length)) : 0

                    Label {
                        id: elapsed
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: page.player ? page.mmss(page.player.position) : ""
                        font.pixelSize: 10
                        color: Theme.dim
                    }
                    Label {
                        id: total
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: page.player ? page.mmss(page.player.length) : ""
                        font.pixelSize: 10
                        color: Theme.dim
                    }
                    Slider {
                        anchors.left: elapsed.right
                        anchors.leftMargin: 10
                        anchors.right: total.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        value: progress.frac
                        onMoved: v => { if (page.player && page.player.canSeek) page.player.position = v * page.player.length }
                    }
                }
            }

            Rectangle {
                visible: page.canPopOut
                anchors.right: parent.right
                anchors.top: parent.top
                width: 26
                height: 26
                radius: Math.min(Theme.rounding, 8)
                color: Theme.alpha(Theme.fg, popArea.containsMouse ? 0.14 : 0.06)
                Behavior on color { ColorAnimation { duration: Theme.fast } }
                Label {
                    anchors.centerIn: parent
                    text: "󰏌"
                    font.pixelSize: 13
                    color: popArea.containsMouse ? Theme.accent : Theme.fg
                }
                MouseArea { id: popArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.popOut() }
            }

            Row {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: info.horizontalCenter
                spacing: 22

                MediaButton {
                    text: ""
                    ok: !!page.player && page.player.shuffleSupported
                    on: ok && page.player.shuffle
                    onPressed: page.player.shuffle = !page.player.shuffle
                }
                MediaButton {
                    text: ""
                    ok: !!page.player && page.player.canGoPrevious
                    onPressed: page.player.previous()
                }

                Rectangle {
                    width: 40
                    height: 40
                    radius: 20
                    color: Theme.soft(Theme.accent, playArea.containsMouse)
                    scale: playArea.pressed ? 0.9 : 1
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                    Behavior on scale { NumberAnimation { duration: Theme.ms(120) } }
                    PlayPause {
                        anchors.centerIn: parent
                        width: 14
                        height: 14
                        color: Theme.ink
                        m: page.playing ? 1 : 0
                        Behavior on m { Settle { duration: Theme.move } }
                    }
                    Hover {
                        id: playArea
                        anchors.fill: parent
                        onClicked: if (page.player && page.player.canTogglePlaying) page.player.togglePlaying()
                    }
                }

                MediaButton {
                    text: ""
                    ok: !!page.player && page.player.canGoNext
                    onPressed: page.player.next()
                }
                MediaButton {
                    text: page.player && page.player.loopState === MprisLoopState.Track ? "󰑘" : "󰑖"
                    ok: !!page.player && page.player.loopSupported
                    on: ok && page.player.loopState !== MprisLoopState.None
                    onPressed: page.player.loopState = page.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                        : page.player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None
                }
            }
        }
    }

    component Notice: Column {
        id: n
        property string glyph
        property string text
        property string action
        signal pressed()
        anchors.centerIn: parent
        spacing: 10

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: n.glyph
            font.pixelSize: 38
            color: Theme.alpha(Theme.fg, 0.35)
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: n.text
            font.pixelSize: 14
            color: Theme.dim
        }
        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            primary: true
            label: n.action
            onPressed: n.pressed()
        }
    }

    component MediaButton: Text {
        id: b
        property bool ok: true
        property bool on: false
        signal pressed()
        anchors.verticalCenter: parent.verticalCenter
        font.family: Theme.sans
        font.pixelSize: 15
        color: !ok ? Theme.alpha(Theme.fg, 0.2) : on ? Theme.accent : bArea.containsMouse ? Theme.bright : Theme.fg
        Behavior on color { ColorAnimation { duration: Theme.fast } }
        Hover {
            id: bArea
            anchors.fill: parent
            anchors.margins: -8
            onClicked: if (b.ok) b.pressed()
        }
    }

    component TimerTab: Item {
        id: page

        property var timer

        Item {
            id: dial
            width: 150
            height: 150
            anchors.verticalCenter: parent.verticalCenter

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: Theme.alpha(Theme.fg, 0.1)
                    strokeWidth: 7
                    fillColor: "transparent"
                    PathAngleArc { centerX: 75; centerY: 75; radiusX: 68; radiusY: 68; startAngle: 0; sweepAngle: 360 }
                }
                ShapePath {
                    strokeColor: page.timer.running ? Theme.accent2 : Theme.alpha(Theme.caution, 0.7)
                    strokeWidth: 7
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    PathAngleArc {
                        centerX: 75
                        centerY: 75
                        radiusX: 68
                        radiusY: 68
                        startAngle: -90
                        sweepAngle: 360 * page.timer.frac
                        Behavior on sweepAngle { NumberAnimation { duration: Theme.ms(300) } }
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 2
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: page.timer.format(page.timer.remaining)
                    font.pixelSize: 30
                    font.bold: true
                    color: Theme.bright
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: page.timer.running ? "Focusing" : page.timer.active ? "Paused" : "Ready"
                    font.pixelSize: 11
                    color: page.timer.running ? Theme.accent2 : page.timer.active ? Theme.caution : Theme.dim
                }
            }
        }

        Column {
            anchors.left: dial.right
            anchors.leftMargin: 24
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Label {
                x: 2
                text: "START A SESSION"
                font.pixelSize: 10
                font.letterSpacing: 1.6
                color: Theme.dim
            }

            Grid {
                id: presets
                columns: 3
                spacing: 6
                readonly property real cell: (parent.width - spacing * 2) / 3

                Repeater {
                    model: [5, 15, 25, 30, 45, 60]
                    Rectangle {
                        required property int modelData
                        readonly property bool current: page.timer.total === modelData * 60
                        width: presets.cell
                        height: 30
                        radius: Math.min(Theme.rounding, 10)
                        color: current && page.timer.active ? Theme.soft(Theme.accent2)
                            : Theme.alpha(Theme.fg, presetArea.containsMouse ? 0.12 : 0.055)
                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                        Label {
                            anchors.centerIn: parent
                            text: parent.modelData + " min"
                            font.pixelSize: 12
                            color: parent.current && page.timer.active ? Theme.on(Theme.accent2) : Theme.fg
                        }
                        Hover {
                            id: presetArea
                            anchors.fill: parent
                            onClicked: page.timer.start(parent.modelData)
                        }
                    }
                }
            }

            Row {
                spacing: 6

                Button {
                    primary: true
                    label: page.timer.running ? "  Pause" : page.timer.active ? "  Resume" : "  Start"
                    onPressed: page.timer.toggle()
                }
                Button {
                    label: "  Reset"
                    onPressed: page.timer.reset()
                }
                Button {
                    label: "+5"
                    onPressed: page.timer.add(5)
                }
            }
        }
    }

    // shares waybar's history in ~/.cache/colorpicker/colors
    component ColorTab: Item {
        id: page

        signal pick()
        signal copy(string color)

        Watched {
            id: history
            path: Quickshell.env("HOME") + "/.cache/colorpicker/colors"
        }
        readonly property var colors: history.text().split("\n").map(s => s.trim()).filter(s => /^#[0-9a-fA-F]{6}$/.test(s))
        readonly property string last: colors.length > 0 ? colors[0] : ""
        property string copied: ""
        Timer { id: unmark; interval: 1400; onTriggered: page.copied = "" }

        function copyColor(c) {
            copy(c)
            copied = c
            unmark.restart()
        }

        function rgb(c) {
            const v = parseInt(c.slice(1), 16)
            return [(v >> 16) & 255, (v >> 8) & 255, v & 255].join("  ")
        }

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 18

            Rectangle {
                width: 118
                height: 118
                radius: Math.min(Theme.rounding, 14)
                color: page.last !== "" ? page.last : Theme.alpha(Theme.fg, 0.06)
                border.width: 1
                border.color: Theme.alpha(Theme.fg, 0.1)

                Label {
                    anchors.centerIn: parent
                    visible: page.last === ""
                    text: "󰈊"
                    font.pixelSize: 26
                    color: Theme.dim
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: page.last !== ""
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.copyColor(page.last)
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Label {
                    text: page.last !== "" ? page.last.toUpperCase() : "No colors yet"
                    font.pixelSize: 22
                    font.bold: page.last !== ""
                    color: Theme.bright
                }
                Label {
                    text: page.copied !== "" ? "Copied " + page.copied.toUpperCase()
                        : page.last !== "" ? "RGB  " + page.rgb(page.last) : "Pick one from anywhere on screen"
                    font.pixelSize: 11
                    color: page.copied !== "" ? Theme.ok : Theme.dim
                }

                Item { width: 1; height: 6 }

                Button {
                    primary: true
                    label: "󰈊  Pick"
                    onPressed: page.pick()
                }

                Item { width: 1; height: 4 }

                Row {
                    spacing: 7

                    Repeater {
                        model: page.colors.slice(1, 9)

                        Rectangle {
                            required property string modelData
                            width: 22
                            height: 22
                            radius: 11
                            color: modelData
                            border.width: 1
                            border.color: Theme.alpha(Theme.fg, swatchArea.containsMouse ? 0.5 : 0.1)
                            scale: swatchArea.containsMouse ? 1.12 : 1
                            Behavior on scale { Settle { duration: Theme.fast } }
                            MouseArea { id: swatchArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.copyColor(parent.modelData) }
                        }
                    }
                }
            }
        }

    }

    component CaptureTab: Item {
        id: page

        property bool active: false
        property bool open: false
        property string kind: "shot"
        property int elapsed: 0
        signal capture(string kind, string mode)
        signal stop()
        signal cancelShare()
        signal cast(var tv, string mode)
        signal stopCast()
        signal more()

        property var tvs: []
        property var tv: null
        property bool scanned: false
        onKindChanged: { tv = null; if (kind !== "cast") { tvs = []; scanned = false } }
        Process {
            id: scanner
            command: [Quickshell.shellDir + "/bar/cast.py", "scan"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try { page.tvs = JSON.parse(text) } catch (e) {}
                    page.scanned = true
                }
            }
        }
        Timer {
            running: page.kind === "cast" && !page.tv && page.active && !page.casting
            interval: 6000
            repeat: true
            triggeredOnStart: true
            onTriggered: if (!scanner.running) scanner.running = true
        }

        Watched {
            id: castFile
            path: Quickshell.env("XDG_RUNTIME_DIR") + "/cast-state"
        }
        readonly property var castState: { try { return JSON.parse(castFile.text()) } catch (e) { return null } }
        readonly property bool casting: !!castState
        readonly property int castStarted: casting ? castState.started : 0

        // share.sh writes this when an app wants my screen
        Watched {
            id: shareReq
            path: Quickshell.env("XDG_RUNTIME_DIR") + "/share-request"
        }
        readonly property bool sharing: shareReq.text() !== ""
        property bool picked: false
        onSharingChanged: { picked = false; kind = sharing ? "share" : kind === "share" ? "shot" : kind }
        onOpenChanged: if (!open && sharing && !picked) cancelShare()

        Watched {
            id: state
            path: Quickshell.env("XDG_RUNTIME_DIR") + "/capture-rec"
        }
        readonly property int started: parseInt(state.text()) || 0
        readonly property bool recording: started > 0

        readonly property int since: recording ? started : castStarted
        function tick() { elapsed = Math.max(0, Math.floor(Date.now() / 1000) - since) }
        onSinceChanged: tick()
        Timer { running: page.since > 0 && page.active; interval: 1000; repeat: true; triggeredOnStart: true; onTriggered: page.tick() }

        function clock(s) {
            const p = n => String(n).padStart(2, "0")
            return p(Math.floor(s / 60)) + ":" + p(s % 60)
        }

        Column {
            width: parent.width
            anchors.centerIn: parent
            spacing: 14
            visible: !page.recording && !page.casting

            Row {
                visible: !page.tv
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6

                Repeater {
                    model: [{ id: "shot", label: "󰄀  Photo" }, { id: "rec", label: "󰻃  Video" }, { id: "cast", label: "󰄘  Cast" }]
                        .concat(page.sharing ? [{ id: "share", label: "󰹑  Share" }] : [])

                    Button {
                        required property var modelData
                        primary: page.kind === modelData.id
                        label: modelData.label
                        // hitting cast again stops looking for tvs
                        onPressed: page.kind = modelData.id === "cast" && page.kind === "cast" ? "shot" : modelData.id
                    }
                }
            }

            Item {
                visible: !!page.tv
                width: parent.width
                height: 32

                Button {
                    id: backBtn
                    label: "\uf053"
                    onPressed: page.tv = null
                }
                Label {
                    anchors.left: backBtn.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: page.tv ? "󰄘  " + page.tv.name : ""
                    elide: Text.ElideRight
                    font.pixelSize: 14
                    color: Theme.bright
                }
            }

            ClippingRectangle {
                visible: page.kind === "cast" && !page.tv
                width: parent.width
                height: 108
                radius: Math.min(Theme.rounding, 12)
                color: Theme.alpha(Theme.fg, 0.055)

                Flickable {
                    anchors.fill: parent
                    contentHeight: tvList.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: tvList
                        width: parent.width

                        Repeater {
                            // miracast needs wifi direct, not dealing with that. gnome-network-displays can
                            model: page.tvs.concat([{ kind: "more", name: "Miracast" }])

                            Rectangle {
                                id: tvRow
                                required property var modelData
                                width: tvList.width
                                height: 34
                                color: Theme.alpha(Theme.fg, tvArea.containsMouse ? 0.1 : 0)
                                Behavior on color { ColorAnimation { duration: Theme.fast } }

                                Label {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 16
                                    anchors.right: parent.right
                                    anchors.rightMargin: 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (tvRow.modelData.kind === "cast" ? "󰄘" : tvRow.modelData.kind === "dlna" ? "󰔂" : "󰖩") + "   " + tvRow.modelData.name
                                    elide: Text.ElideRight
                                    font.pixelSize: 12
                                    color: tvArea.containsMouse ? Theme.bright : tvRow.modelData.kind === "more" ? Theme.dim : Theme.fg
                                }

                                Hover {
                                    id: tvArea
                                    anchors.fill: parent
                                    onClicked: tvRow.modelData.kind === "more" ? page.more() : page.tv = tvRow.modelData
                                }
                            }
                        }
                    }
                }

                Label {
                    id: searching
                    visible: page.tvs.length === 0
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.top: parent.top
                    anchors.topMargin: 13
                    text: scanner.running || !page.scanned ? "Searching…" : "No TVs"
                    font.pixelSize: 11
                    color: Theme.dim
                    SequentialAnimation on opacity {
                        running: scanner.running && page.active
                        loops: Animation.Infinite
                        onRunningChanged: if (!running) searching.opacity = 1
                        NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                    }
                }
            }

            Row {
                id: tiles
                visible: page.kind !== "cast" || !!page.tv
                width: parent.width
                spacing: 8

                Repeater {
                    model: [{ id: "region", glyph: "󰆞", label: "Region" }, { id: "window", glyph: "󱂬", label: "Window" }, { id: "screen", glyph: "󰍹", label: "Screen" }]

                    Rectangle {
                        id: tile
                        required property var modelData
                        width: (tiles.width - tiles.spacing * 2) / 3
                        height: 72
                        radius: Math.min(Theme.rounding, 12)
                        color: Theme.alpha(Theme.fg, tileArea.containsMouse ? 0.12 : 0.055)
                        scale: tileArea.pressed ? 0.95 : 1
                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                        Behavior on scale { NumberAnimation { duration: Theme.ms(120) } }

                        Column {
                            anchors.centerIn: parent
                            spacing: 5
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.glyph
                                font.pixelSize: 20
                                color: tileArea.containsMouse ? Theme.accent : Theme.fg
                            }
                            Label {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: tile.modelData.label
                                font.pixelSize: 10
                                color: Theme.dim
                            }
                        }

                        Hover {
                            id: tileArea
                            anchors.fill: parent
                            onClicked: {
                                if (page.kind === "cast") { page.cast(page.tv, tile.modelData.id); page.tv = null; return }
                                if (page.kind === "share") page.picked = true
                                page.capture(page.kind, tile.modelData.id)
                            }
                        }
                    }
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 10
            visible: page.recording || page.casting

            Label {
                visible: !page.recording
                anchors.horizontalCenter: parent.horizontalCenter
                text: "󰄘  " + (page.castState ? page.castState.name : "")
                font.pixelSize: 13
                color: Theme.fg
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Rectangle {
                    visible: page.recording
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10
                    height: 10
                    radius: 5
                    color: Theme.warn
                    SequentialAnimation on opacity {
                        running: page.recording && page.active
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 700 }
                        NumberAnimation { to: 1; duration: 700 }
                    }
                }
                Label {
                    text: page.since > 0 ? page.clock(page.elapsed) : "Connecting…"
                    font.pixelSize: page.since > 0 ? 28 : 18
                    font.bold: true
                    color: Theme.bright
                }
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                primary: true
                label: "󰓛  Stop"
                onPressed: page.recording ? page.stop() : page.stopCast()
            }
        }
    }

    component WeatherTab: Item {
        id: wt

        property var weather

        Column {
            id: now
            anchors.verticalCenter: parent.verticalCenter
            width: 150
            spacing: 4

            Row {
                spacing: 10
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: wt.weather.ready ? wt.weather.glyph(wt.weather.code, wt.weather.night) : "󰖕"
                    font.pixelSize: 38
                    color: wt.weather.night ? Theme.accent2 : Theme.caution
                }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    text: wt.weather.ready ? wt.weather.temp + "°" : "--"
                    font.pixelSize: 34
                    font.bold: true
                    color: Theme.bright
                }
            }
            Label {
                width: parent.width
                text: wt.weather.ready ? wt.weather.desc : wt.weather.failed ? "Weather unavailable" : "Loading weather..."
                elide: Text.ElideRight
                font.pixelSize: 13
                color: Theme.fg
            }
            Label {
                visible: wt.weather.ready
                text: "Feels " + wt.weather.feels + "°  ·  H " + wt.weather.high + "°  L " + wt.weather.low + "°"
                font.pixelSize: 10
                color: Theme.dim
            }
            Row {
                visible: wt.weather.ready
                spacing: 10
                Text { text: "󰖎 " + wt.weather.humidity + "%"; font.family: Theme.sans; font.pixelSize: 10; color: Theme.dim }
                Text { text: "󰖝 " + wt.weather.wind + " mph"; font.family: Theme.sans; font.pixelSize: 10; color: Theme.dim }
            }
            Label {
                width: parent.width
                visible: wt.weather.ready
                text: wt.weather.area
                elide: Text.ElideRight
                font.pixelSize: 10
                color: Theme.alpha(Theme.fg, 0.35)
            }
        }

        Item {
            id: graph
            anchors.left: now.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            height: parent.height
            visible: wt.weather.ready

            readonly property var hours: wt.weather.hours
            readonly property real lo: Math.min(...hours.map(h => h.temp))
            readonly property real hi: Math.max(...hours.map(h => h.temp))
            readonly property real step: hours.length > 1 ? (width - 24) / (hours.length - 1) : 0
            function px(i) { return 12 + i * step }
            function py(t) { return 100 - (hi > lo ? (t - lo) / (hi - lo) : 0.5) * 50 }

            Canvas {
                anchors.fill: parent
                property var points: graph.hours.map((h, i) => [graph.px(i), graph.py(h.temp)])
                onPointsChanged: requestPaint()
                onWidthChanged: requestPaint()
                // canvas doesn't notice palette changes on its own
                property color tint: Theme.caution
                onTintChanged: requestPaint()
                onPaint: {
                    const c = getContext("2d")
                    c.reset()
                    const p = points
                    if (p.length < 2) return
                    const trace = () => {
                        c.beginPath()
                        c.moveTo(p[0][0], p[0][1])
                        for (let i = 1; i < p.length; i++) {
                            const mx = (p[i - 1][0] + p[i][0]) / 2
                            c.bezierCurveTo(mx, p[i - 1][1], mx, p[i][1], p[i][0], p[i][1])
                        }
                    }
                    trace()
                    c.lineTo(p[p.length - 1][0], 118)
                    c.lineTo(p[0][0], 118)
                    c.closePath()
                    const g = c.createLinearGradient(0, 40, 0, 118)
                    g.addColorStop(0, Theme.alpha(Theme.caution, 0.28))
                    g.addColorStop(1, Theme.alpha(Theme.info, 0))
                    c.fillStyle = g
                    c.fill()
                    trace()
                    c.lineWidth = 2
                    c.strokeStyle = Theme.caution
                    c.stroke()
                }
            }

            Repeater {
                model: graph.hours

                Item {
                    required property var modelData
                    required property int index
                    x: graph.px(index) - 20
                    width: 40
                    height: graph.height

                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 2
                        text: wt.weather.glyph(modelData.code, modelData.night)
                        font.pixelSize: 14
                        color: Theme.fg
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: graph.py(modelData.temp) - 3
                        width: 6
                        height: 6
                        radius: 3
                        color: index === 0 ? Theme.bright : Theme.caution
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: graph.py(modelData.temp) - 20
                        text: modelData.temp + "°"
                        font.pixelSize: 10
                        color: index === 0 ? Theme.bright : Theme.fg
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 128
                        text: index === 0 ? "Now" : modelData.label
                        font.pixelSize: 10
                        color: Theme.dim
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            z: -1
            onClicked: wt.weather.refresh(true)
        }
    }

    // wttr.in by IP, shared by all monitors, refreshed every 30 min
    component Forecast: Item {
        id: fc

        property bool ready: false
        property bool failed: false
        property int temp: 0
        property int feels: 0
        property int high: 0
        property int low: 0
        property int humidity: 0
        property int wind: 0
        property int code: 113
        property bool night: false
        property string desc: ""
        property string area: ""
        property var hours: []
        property real fetchedAt: 0

        function refresh(force) {
            if (!force && Date.now() - fetchedAt < 10 * 60 * 1000) return
            if (!proc.running) proc.running = true
        }

        // fold wttr.in codes into a few icons. probably missed some
        function glyph(c, dark) {
            if (c === 113) return dark ? "󰖔" : "󰖙"
            if (c === 116) return "󰖕"
            if ([119, 122].includes(c)) return "󰖐"
            if ([143, 248, 260].includes(c)) return "󰖑"
            if ([200, 386, 389, 392, 395].includes(c)) return "󰖓"
            if ([299, 302, 305, 308, 356, 359].includes(c)) return "󰖖"
            if ([179, 182, 185, 227, 230, 311, 314, 317, 320, 323, 326, 329, 332, 335, 338, 350, 362, 365, 368, 371, 374, 377].includes(c)) return "󰖘"
            return "󰖗"
        }

        Timer { interval: 30 * 60 * 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: fc.refresh(true) }

        Process {
            id: proc
            command: ["curl", "-sf", "--max-time", "10", "https://wttr.in/?format=j1"]
            stdout: StdioCollector {
                onStreamFinished: {
                    try {
                        const d = JSON.parse(text)
                        const c = d.current_condition[0], a = d.nearest_area[0], today = d.weather[0]
                        const hour = new Date().getHours()
                        fc.temp = +c.temp_F
                        fc.feels = +c.FeelsLikeF
                        fc.humidity = +c.humidity
                        fc.wind = +c.windspeedMiles
                        fc.code = +c.weatherCode
                        fc.desc = (c.weatherDesc[0].value || "").trim()
                        fc.area = [a.areaName[0].value, a.region[0].value].filter(s => !!s).join(", ")
                        fc.high = +today.maxtempF
                        fc.low = +today.mintempF
                        fc.night = hour < 6 || hour >= 20
                        // 3-hour slots through tomorrow, idk what else to show
                        const now = Date.now(), list = []
                        for (let day = 0; day < 2; day++) {
                            const date = d.weather[day].date
                            for (const h of d.weather[day].hourly) {
                                const hh = Math.floor(+h.time / 100)
                                const at = new Date(date + "T" + String(hh).padStart(2, "0") + ":00:00").getTime()
                                if (at < now - 90 * 60 * 1000) continue
                                list.push({ temp: +h.tempF, code: +h.weatherCode, night: hh < 6 || hh >= 20,
                                            label: (hh % 12 || 12) + (hh < 12 ? "a" : "p") })
                            }
                        }
                        fc.hours = list.slice(0, 7)
                        fc.ready = true
                        fc.failed = false
                        fc.fetchedAt = Date.now()
                    } catch (e) {
                        fc.failed = true
                    }
                }
            }
            onExited: code => { if (code !== 0) fc.failed = true }
        }
    }

    // lives in the shell so it keeps running with the island closed, i think that's why
    component Countdown: Item {
        id: ft

        property int total: 25 * 60
        property int remaining: total
        property bool running: false
        property real endsAt: 0
        readonly property bool active: running || remaining < total
        readonly property real frac: total > 0 ? remaining / total : 0
        signal finished()

        function start(minutes) {
            total = Math.round(minutes * 60)
            remaining = total
            resume()
        }

        function resume() {
            if (remaining <= 0) remaining = total
            endsAt = Date.now() + remaining * 1000
            running = true
        }

        function pause() {
            tick()
            running = false
        }

        function toggle() {
            running ? pause() : resume()
        }

        function reset() {
            running = false
            remaining = total
        }

        function add(minutes) {
            total += minutes * 60
            if (running) endsAt += minutes * 60000
            remaining += minutes * 60
        }

        function tick() {
            remaining = Math.max(0, Math.ceil((endsAt - Date.now()) / 1000))
            if (remaining === 0 && running) {
                running = false
                finished()
            }
        }

        function format(s) {
            const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), r = s % 60
            const mm = (h > 0 && m < 10 ? "0" : "") + m
            return (h > 0 ? h + ":" : "") + mm + ":" + (r < 10 ? "0" : "") + r
        }

        Timer {
            interval: 250
            running: ft.running
            repeat: true
            onTriggered: ft.tick()
        }
    }
}

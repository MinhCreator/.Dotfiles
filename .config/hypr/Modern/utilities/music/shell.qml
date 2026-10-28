import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import "../common"

ShellRoot {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string uiPath: home + "/.local/state/music-player/ui.json"

    property bool active: false
    property bool leaving: false
    property bool tucked: false
    property real t: 0
    property var targetScreen: null


    readonly property real u: Theme.scaleFor(win.screen)
    readonly property real screenH: win.screen ? win.screen.height : 1080
    readonly property real defaultSide: Math.round(380 * u)
    readonly property real minSide: Math.round(300 * u)
    readonly property real maxSide: Math.max(minSide, Math.round(Math.min(720 * u, screenH * 0.55)))
    property real side: defaultSide
    property real dragSide: defaultSide
    property bool dragging: false
    readonly property real shown: Math.max(minSide, Math.min(maxSide, dragging ? dragSide : side))
    Behavior on side { enabled: !root.dragging; Settle { duration: Theme.move } }

    // laid out for 380px and scaled
    readonly property real k: shown / 380
    function px(v) { return Math.round(v * k) }
    readonly property real pad: px(30)

    readonly property real rounding: Theme.rounding
    property real gapsOut: 8
    readonly property real topGap: Math.max(8, gapsOut)
    readonly property real radius: Math.min(rounding, shown / 4)

    FileView {
        id: uiFile
        path: root.uiPath
        blockLoading: true
        printErrors: false
    }


    property real offX: 0
    property real offY: 0
    property bool moving: false
    Behavior on offX { enabled: !root.moving; Settle { duration: Theme.move } }
    Behavior on offY { enabled: !root.moving; Settle { duration: Theme.move } }
    readonly property real homeX: (win.width - shown) / 2
    readonly property real baseX: Math.max(8, Math.min(win.width - shown - 8, homeX + offX))
    readonly property real baseY: Math.max(topGap, Math.min(win.height - shown - 8, topGap + offY))

    function resetPosition() {
        moving = true
        offX = 0
        offY = 0
        moving = false
    }

    readonly property string placement: JSON.stringify({
        open: active && !leaving, tucked: tucked, screen: targetScreen?.name ?? "", side: Math.round(shown), top: topGap,
        x: Math.round(baseX), y: Math.round(baseY)
    })
    onPlacementChanged: placementWrite.restart()
    Timer { id: placementWrite; interval: 30; onTriggered: placementFile.setText(root.placement) }
    FileView {
        id: placementFile
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/music-player.json"
        atomicWrites: false
        printErrors: false
    }

    function saveSide(v) {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1"', "sh",
                                 uiPath, JSON.stringify({ side: v / u })])
    }

    Process {
        id: gapsProc
        command: ["hyprctl", "-j", "getoption", "general:gaps_out"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    const n = parseInt(String(d.custom ?? d.css ?? d.int ?? "").trim().split(/\s+/)[0])
                    if (!isNaN(n)) root.gapsOut = n
                } catch (e) {}
            }
        }
    }


    readonly property var players: Theme.players
    property string pinned: ""
    readonly property var player: Theme.pickPlayer(pinned)
    readonly property bool spotify: Theme.isSpotify(player)
    readonly property bool playing: !!player && player.isPlaying

    function cyclePlayer() {
        const ps = players
        if (!ps || ps.length < 2) return
        const i = ps.indexOf(player)
        pinned = ps[(i + 1) % ps.length].dbusName
    }

    FrameAnimation {
        running: root.active && root.playing
        onTriggered: if (root.player) root.player.positionChanged()
    }

    property int dir: 1
    function next() { if (player && player.canGoNext) { dir = 1; player.next() } }
    function previous() { if (player && player.canGoPrevious) { dir = -1; player.previous() } }
    function toggle() { if (player && player.canTogglePlaying) player.togglePlaying() }
    function seekBy(s) {
        if (!player || !player.canSeek) return
        player.position = Math.max(0, Math.min(player.length, player.position + s))
    }

    function openSpotify() {
        Theme.openSpotify()
        close()
    }


    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    // dim is see-through so it lied about its color, this is what it really looks like
    readonly property color volTint: muted ? Theme.along([Theme.bg, Theme.fg], 0.5) : Theme.info
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    function setVolume(v) {
        if (!sink || !sink.audio) return
        sink.audio.volume = Math.max(0, Math.min(1, v))
        if (v > 0 && sink.audio.muted) sink.audio.muted = false
    }
    function toggleMute() { if (sink && sink.audio) sink.audio.muted = !muted }

    function clock(s) {
        if (!(s > 0)) return "0:00"
        s = Math.floor(s)
        const m = Math.floor(s / 60), r = s % 60
        return m >= 60 ? Math.floor(m / 60) + ":" + String(m % 60).padStart(2, "0") + ":" + String(r).padStart(2, "0")
                       : m + ":" + String(r).padStart(2, "0")
    }


    property real vizIntro: 0

    Component.onCompleted: {
        try {
            const ui = JSON.parse(uiFile.text())
            if (typeof ui.side === "number") side = Math.round(ui.side * u)
        } catch (e) {}
        targetScreen = Theme.focusedScreen()
        placementWrite.restart()
        Theme.refresh()
        gapsProc.running = true
    }


    function show() {
        if (tucked) { untuck(); return }
        if (active && !leaving) return
        Theme.refresh()
        gapsProc.running = true
        const scr = Theme.focusedScreen()
        if (!active && scr !== targetScreen) {
            targetScreen = scr
            resetPosition()
            moveDelay.restart()
            return
        }
        begin()
    }

    function begin() {
        if (!active) resetPosition()
        leaving = false
        active = true
        animateTo(1)
        vizAnim.restart()
        warp.restart()
    }

    Timer {
        id: warp
        interval: 30
        onTriggered: {
            const s = win.screen
            if (!s) return
            const x = Math.round(s.x + root.baseX + root.shown / 2)
            const y = Math.round(s.y + s.height - win.height + root.baseY + root.shown / 2)
            Theme.dispatch("hl.dsp.cursor.move({ x = " + x + ", y = " + y + " })", "movecursor " + x + " " + y)
        }
    }

    function close() {
        if (!active || leaving) return
        tucked = false
        leaving = true
        animateTo(0)
    }

    function tuck() {
        if (!active || leaving || tucked) return
        tucked = true
        animateTo(0)
    }

    function untuck() {
        if (!tucked) return
        tucked = false
        if (!active || leaving) return
        animateTo(1)
        vizAnim.restart()
    }

    function toggleOpen() {
        if (active && !leaving) close()
        else show()
    }

    function animateTo(target) {
        tween.stop()
        tween.from = t
        tween.to = target
        tween.duration = Theme.ms(target === 1 ? 400 : 320)
        tween.easing.bezierCurve = Theme.settle
        tween.start()
    }

    function stage(from) {
        if (leaving) return Math.max(0, Math.min(1, (t - 0.7) / 0.3))
        return Math.max(0, Math.min(1, (t - from) / (1 - from)))
    }

    Timer { id: moveDelay; interval: 90; onTriggered: root.begin() }

    NumberAnimation {
        id: tween
        target: root
        property: "t"
        easing.type: Easing.BezierSpline
        onFinished: {
            if (!root.leaving) return
            root.active = false
            root.leaving = false
            root.vizIntro = 0
        }
    }

    SequentialAnimation {
        id: vizAnim
        PropertyAction { target: root; property: "vizIntro"; value: 0 }
        PauseAnimation { duration: Theme.ms(220) }
        NumberAnimation { target: root; property: "vizIntro"; to: 1; duration: Theme.ms(820); easing.type: Easing.OutQuad }
    }

    IpcHandler {
        target: "music"
        function toggle(): void { root.toggleOpen() }
        function open(): void { root.show() }
        function close(): void { root.close() }
        function tuck(): void { root.tuck() }
        function untuck(): void { root.untuck() }
    }


    // i think this frees the textures once it closes, saves some memory
    property bool warm: false
    onActiveChanged: {
        if (active) { warm = true; cool.stop() }
        else cool.restart()
    }
    Timer { id: cool; interval: 120000; onTriggered: root.warm = false }

    PanelWindow {
        id: win
        screen: root.targetScreen ?? Quickshell.screens[0]
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Normal
        color: "transparent"
        mask: Region { item: root.active && !root.leaving && !root.tucked ? ld.item : null }
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "music-player"
        WlrLayershell.keyboardFocus: root.active && !root.leaving && !root.tucked
            ? (ld.item && ld.item.hovered ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand) : WlrKeyboardFocus.None

        // no fill, a sized Loader stretches the card across the window. no clue why
        Loader {
            id: ld
            active: root.active || root.warm
            focus: true
            sourceComponent: Component {
                Item {
                    id: card
                property alias hovered: hover.hovered
                    width: root.shown
                    height: root.shown * Math.max(0, Math.min(1, root.t))
                    x: root.baseX + (root.shown - width) / 2
                    y: root.baseY
                    opacity: root.active ? Math.min(1, root.t * 8) : 0
                    focus: true

                    // hovering is enough for keys, clicking used to be the only thing that grabbed focus
                    HoverHandler { id: hover; onHoveredChanged: if (hovered) card.forceActiveFocus() }

                    Keys.onPressed: event => {
                        const k = event.key
                        if (k === Qt.Key_Escape || k === Qt.Key_Q) root.close()
                        else if (k === Qt.Key_Space || k === Qt.Key_K) { playButton.bump(); root.toggle() }
                        else if (k === Qt.Key_Left || k === Qt.Key_H) root.seekBy(-5)
                        else if (k === Qt.Key_Right || k === Qt.Key_L) root.seekBy(5)
                        else if (k === Qt.Key_Up) root.setVolume(root.volume + 0.05)
                        else if (k === Qt.Key_Down) root.setVolume(root.volume - 0.05)
                        else if (k === Qt.Key_M) root.toggleMute()
                        else if (k === Qt.Key_N || k === Qt.Key_Period) { nextButton.bump(); root.next() }
                        else if (k === Qt.Key_P || k === Qt.Key_Comma) { prevButton.bump(); root.previous() }
                        else { event.accepted = false; return }
                        event.accepted = true
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: pressed && root.moving ? Qt.ClosedHandCursor : Qt.ArrowCursor
                        property point start
                        property real sx: 0
                        property real sy: 0

                        function at(mouse) {
                            return mapToItem(win.contentItem, mouse.x, mouse.y)
                        }

                        onPressed: mouse => {
                            card.forceActiveFocus()
                            start = at(mouse)
                            sx = root.baseX - root.homeX
                            sy = root.baseY - root.topGap
                        }
                        onPositionChanged: mouse => {
                            if (!pressed || !root.active || root.leaving) return
                            const p = at(mouse)
                            if (!root.moving && Math.hypot(p.x - start.x, p.y - start.y) < 4) return
                            root.moving = true
                            root.offX = sx + p.x - start.x
                            root.offY = sy + p.y - start.y
                        }
                        onReleased: {
                            if (!root.moving) return
                            root.offX = root.baseX - root.homeX
                            root.offY = root.baseY - root.topGap
                            root.moving = false
                        }
                        onDoubleClicked: { root.offX = 0; root.offY = 0 }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Math.min(card.height / 2, root.radius)
                        color: Theme.alpha(Theme.bg, 0.6)
                        border.width: 1
                        border.color: Theme.alpha(Theme.fg, 0.07)
                    }

                    Item {
                        anchors.fill: parent
                        clip: true

                        Item {
                            width: root.shown - root.pad * 2
                            height: root.shown - root.pad * 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: root.pad


                            Item {
                                id: topRow
                                width: parent.width
                                height: root.px(26)
                                opacity: root.stage(0.55)
                                transform: Translate { y: -8 * (1 - root.stage(0.5)) }

                                Rectangle {
                                    visible: !!root.player
                                    height: parent.height
                                    width: chipRow.implicitWidth + root.px(20)
                                    radius: height / 2
                                    color: Theme.alpha(Theme.fg, chipArea.containsMouse && root.players.length > 1 ? 0.12 : 0.06)
                                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                                    Behavior on width { Settle { duration: Theme.move } }

                                    Row {
                                        id: chipRow
                                        anchors.centerIn: parent
                                        spacing: root.px(7)

                                        Rectangle {
                                            id: liveDot
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: root.px(6)
                                            height: width
                                            radius: width / 2
                                            color: root.playing ? Theme.ok : Theme.dim
                                            Behavior on color { ColorAnimation { duration: Theme.move } }
                                            SequentialAnimation on opacity {
                                                running: root.active && root.playing
                                                loops: Animation.Infinite
                                                onRunningChanged: if (!running) liveDot.opacity = 1
                                                NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                                                NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                                            }
                                        }
                                        Label {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: root.player ? (root.player.identity || "Player") : ""
                                            font.pixelSize: root.px(11)
                                            color: Theme.fg
                                        }
                                        Label {
                                            visible: root.players.length > 1
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: ""
                                            font.pixelSize: root.px(9)
                                            color: Theme.dim
                                        }
                                    }

                                    MouseArea {
                                        id: chipArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: root.players.length > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: root.cyclePlayer()
                                    }
                                }

                                Glyph {
                                    id: spotifyButton
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    size: root.px(30)
                                    glyph: ""
                                    glyphSize: root.px(19)
                                    tint: root.spotify ? Theme.accent : Theme.fg
                                    onClicked: root.openSpotify()
                                }

                                Volume {
                                    anchors.right: spotifyButton.left
                                    anchors.rightMargin: root.px(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: root.px(116)
                                }
                            }


                            Item {
                                anchors.top: topRow.bottom
                                anchors.topMargin: root.px(22)
                                width: parent.width
                                height: root.px(100)
                                opacity: root.stage(0.6)
                                transform: Translate { y: 10 * (1 - root.stage(0.55)) }

                                Art {
                                    id: art
                                    width: parent.height
                                    height: parent.height
                                    url: root.player ? (root.player.trackArtUrl || "") : ""
                                }

                                Item {
                                    id: info
                                    anchors.left: art.right
                                    anchors.leftMargin: root.px(18)
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    height: infoCol.implicitHeight

                                    readonly property string key: root.player ? root.player.trackTitle + "\u0001" + root.player.trackArtist : ""
                                    property string title: ""
                                    property string artist: ""
                                    property string album: ""
                                    property real shift: 0

                                    function take() {
                                        title = root.player ? (root.player.trackTitle || "Unknown track") : ""
                                        artist = root.player ? (root.player.trackArtist || "") : ""
                                        album = root.player ? (root.player.trackAlbum || "") : ""
                                    }
                                    Component.onCompleted: take()
                                    onKeyChanged: {
                                        if (!root.active || title === "") { take(); return }
                                        swap.restart()
                                    }

                                    SequentialAnimation {
                                        id: swap
                                        ParallelAnimation {
                                            NumberAnimation { target: infoCol; property: "opacity"; to: 0; duration: Theme.ms(130); easing.type: Easing.InQuad }
                                            NumberAnimation { target: info; property: "shift"; to: -root.dir * 18; duration: Theme.ms(130); easing.type: Easing.InQuad }
                                        }
                                        ScriptAction { script: { info.take(); info.shift = root.dir * 18; root.dir = 1 } }
                                        ParallelAnimation {
                                            NumberAnimation { target: infoCol; property: "opacity"; to: 1; duration: Theme.ms(300); easing.type: Easing.OutCubic }
                                            Settle { target: info; property: "shift"; to: 0; duration: Theme.ms(340) }
                                        }
                                    }

                                    Column {
                                        id: infoCol
                                        width: parent.width
                                        spacing: root.px(4)
                                        transform: Translate { x: info.shift }

                                        Label {
                                            width: parent.width
                                            text: root.player ? info.title : "Nothing playing"
                                            elide: Text.ElideRight
                                            font.pixelSize: root.px(17)
                                            color: Theme.bright
                                        }
                                        Label {
                                            width: parent.width
                                            visible: text !== ""
                                            text: root.player ? info.artist : "Open Spotify to start"
                                            elide: Text.ElideRight
                                            font.pixelSize: root.px(13)
                                            color: Theme.fg
                                        }
                                        Label {
                                            width: parent.width
                                            visible: text !== ""
                                            text: root.player ? info.album : ""
                                            elide: Text.ElideRight
                                            font.pixelSize: root.px(11)
                                            color: Theme.dim
                                        }
                                    }
                                }
                            }


                            Visualizer {
                                id: viz
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: root.px(34)
                                running: root.active || moveDelay.running
                                intro: root.vizIntro
                                opacity: root.stage(0.7)
                            }

                            Item {
                                id: controls
                                anchors.bottom: viz.top
                                anchors.bottomMargin: root.px(18)
                                width: parent.width
                                height: root.px(56)
                                opacity: root.stage(0.66)
                                transform: Translate { y: 8 * (1 - root.stage(0.62)) }
                                enabled: !!root.player

                                Glyph {
                                    id: prevButton
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.right: playButton.left
                                    anchors.rightMargin: root.px(26)
                                    size: root.px(44)
                                    glyph: ""
                                    glyphSize: root.px(16)
                                    nudge: -1
                                    dimmed: !root.player || !root.player.canGoPrevious
                                    onClicked: root.previous()
                                }

                                PlayButton {
                                    id: playButton
                                    anchors.centerIn: parent
                                    size: root.px(56)
                                }

                                Glyph {
                                    id: nextButton
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: playButton.right
                                    anchors.leftMargin: root.px(26)
                                    size: root.px(44)
                                    glyph: ""
                                    glyphSize: root.px(16)
                                    nudge: 1
                                    dimmed: !root.player || !root.player.canGoNext
                                    onClicked: root.next()
                                }
                            }

                            Seek {
                                anchors.bottom: controls.top
                                anchors.bottomMargin: root.px(10)
                                width: parent.width
                                opacity: root.stage(0.63)
                                transform: Translate { y: 8 * (1 - root.stage(0.6)) }
                            }
                        }
                    }

                    Item {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: root.px(90)
                        height: root.px(16)
                        opacity: root.stage(0.75)

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: root.px(7)
                            height: 4
                            width: grabArea.containsMouse || grabArea.pressed ? root.px(64) : root.px(36)
                            radius: 2
                            color: Theme.alpha(grabArea.containsMouse || grabArea.pressed ? Theme.accent : Theme.fg, grabArea.containsMouse || grabArea.pressed ? 0.85 : 0.18)
                            Behavior on width { NumberAnimation { duration: Theme.ms(200); easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                        }

                        MouseArea {
                            id: grabArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.SizeVerCursor
                            preventStealing: true

                            property real startY: 0
                            property real startSide: 0

                            function windowY(mouse) {
                                return mapToItem(win.contentItem, mouse.x, mouse.y).y
                            }

                            onPressed: mouse => {
                                startY = windowY(mouse)
                                startSide = root.shown
                                root.dragSide = root.shown
                                root.dragging = true
                            }
                            onPositionChanged: mouse => {
                                if (!pressed) return
                                const want = startSide + (windowY(mouse) - startY)
                                const lo = root.minSide, hi = root.maxSide
                                root.dragSide = want < lo ? lo - Math.sqrt(lo - want) * 2
                                              : want > hi ? hi + Math.sqrt(want - hi) * 2 : want
                            }
                            onReleased: {
                                root.side = Math.max(root.minSide, Math.min(root.maxSide, root.dragSide))
                                root.dragging = false
                                let next = root.side
                                if (Math.abs(next - root.defaultSide) < 14) next = root.defaultSide
                                root.side = next
                                root.saveSide(next)
                            }
                        }
                    }
                }
            }
        }
    }

    component Glyph: Item {
        id: btn
        property real size: 40
        property string glyph: ""
        property real glyphSize: 16
        property color tint: Theme.fg
        property int nudge: 0
        property bool dimmed: false
        property real kick: 0
        signal clicked()

        width: size
        height: size

        function bump() { kickAnim.restart() }

        SequentialAnimation {
            id: kickAnim
            NumberAnimation { target: btn; property: "kick"; to: 1; duration: Theme.ms(90); easing.type: Easing.OutQuad }
            NumberAnimation { target: btn; property: "kick"; to: 0; duration: Theme.ms(380); easing.type: Easing.OutBack; easing.overshoot: 2.2 }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.alpha(Theme.fg, area.pressed ? 0.16 : 0.09)
            opacity: area.containsMouse && !btn.dimmed ? 1 : 0
            scale: area.containsMouse ? 1 : 0.7
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }
            Behavior on scale { Settle { duration: Theme.move } }
        }

        Label {
            anchors.centerIn: parent
            text: btn.glyph
            font.pixelSize: btn.glyphSize
            color: btn.dimmed ? Theme.dim : (area.containsMouse ? Theme.bright : btn.tint)
            opacity: btn.dimmed ? 0.5 : 1
            scale: (area.pressed ? 0.84 : 1) * (1 + 0.08 * btn.kick * (btn.nudge === 0 ? 1 : 0))
            transform: Translate { x: btn.nudge * btn.kick * root.px(6) }
            Behavior on color { ColorAnimation { duration: Theme.fast } }
            Behavior on scale { NumberAnimation { duration: Theme.ms(180); easing.type: Easing.OutBack; easing.overshoot: 2 } }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: btn.dimmed ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: {
                if (btn.dimmed) return
                btn.bump()
                btn.clicked()
            }
        }
    }

    component Volume: Item {
        id: vb
        height: root.px(24)
        readonly property real level: root.muted ? 0 : root.volume

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Theme.alpha(Theme.fg, volDrag.containsMouse || volDrag.pressed ? 0.14 : 0.08)
            clip: true
            Behavior on color { ColorAnimation { duration: Theme.fast } }

            Rectangle {
                height: parent.height
                width: Math.max(parent.height, parent.width * vb.level)
                radius: height / 2
                color: Theme.soft(root.volTint)
                Behavior on width { enabled: !volDrag.pressed; NumberAnimation { duration: Theme.ms(120); easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Theme.fast } }
            }
        }

        Label {
            x: root.px(8)
            anchors.verticalCenter: parent.verticalCenter
            text: root.muted || root.volume === 0 ? "\uf026" : "\uf028"
            font.pixelSize: root.px(12)
            color: Theme.on(root.volTint)
        }

        Label {
            anchors.right: parent.right
            anchors.rightMargin: root.px(9)
            anchors.verticalCenter: parent.verticalCenter
            text: root.muted ? "Muted" : Math.round(root.volume * 100) + "%"
            font.pixelSize: root.px(10)
            color: vb.level > 0.8 ? Theme.on(root.volTint) : Theme.fg
        }

        Hover {
            id: volDrag
            anchors.fill: parent
            preventStealing: true
            onPressed: mouse => root.setVolume(mouse.x / width)
            onPositionChanged: mouse => { if (pressed) root.setVolume(mouse.x / width) }
            onWheel: wheel => root.setVolume(root.volume + wheel.angleDelta.y / 120 * 0.03)
        }
        MouseArea {
            width: parent.height
            height: parent.height
            cursorShape: Qt.PointingHandCursor
            onClicked: root.toggleMute()
        }
    }

    component PlayButton: Item {
        id: pb
        property real size: 56
        width: size
        height: size

        function bump() {}

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: Theme.soft(Theme.accent, pbArea.containsMouse)
            scale: pbArea.pressed ? 0.9 : (pbArea.containsMouse ? 1.05 : 1)
            Behavior on scale { NumberAnimation { duration: Theme.ms(260); easing.type: Easing.OutBack; easing.overshoot: 2.4 } }

            PlayPause {
                anchors.centerIn: parent
                width: Math.round(pb.size * 0.34)
                height: width
                color: Theme.ink
                m: root.playing ? 1 : 0
                Behavior on m { NumberAnimation { duration: Theme.ms(340); easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
            }
        }

        Hover {
            id: pbArea
            anchors.fill: parent
            onClicked: {
                pb.bump()
                root.toggle()
            }
        }
    }

    component Seek: Item {
        id: sk
        height: root.px(36)

        readonly property real length: root.player && root.player.lengthSupported ? root.player.length : 0
        readonly property real position: root.player && root.player.positionSupported ? root.player.position : 0
        readonly property bool live: sk.length > 0 && !!root.player && root.player.canSeek
        property bool seeking: false
        property real seekFrac: 0
        readonly property real frac: seeking ? seekFrac : (length > 0 ? Math.max(0, Math.min(1, position / length)) : 0)
        readonly property bool hot: bar.containsMouse || bar.pressed

        Item {
            id: track
            width: parent.width
            height: root.px(14)

            Rectangle {
                id: groove
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: sk.hot ? root.px(6) : root.px(4)
                radius: height / 2
                color: Theme.alpha(Theme.fg, 0.14)
                Behavior on height { NumberAnimation { duration: Theme.ms(200); easing.type: Easing.OutCubic } }

                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    width: Math.max(height, parent.width * sk.frac)
                    color: Theme.accent2
                    // animating this restarts every frame and it stutters like hell
                    Behavior on width {
                        enabled: !sk.seeking && !root.playing
                        NumberAnimation { duration: Theme.ms(160); easing.type: Easing.OutCubic }
                    }
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                x: groove.width * sk.frac - width / 2
                width: root.px(14)
                height: width
                radius: width / 2
                color: Theme.bright
                scale: sk.hot && sk.live ? (bar.pressed ? 1.15 : 1) : 0
                Behavior on scale { NumberAnimation { duration: Theme.ms(240); easing.type: Easing.OutBack; easing.overshoot: 2 } }
            }

            Hover {
                id: bar
                anchors.fill: parent
                anchors.margins: -root.px(6)
                enabled: sk.live
                preventStealing: true

                function fracAt(mouse) {
                    return Math.max(0, Math.min(1, (mouse.x - root.px(6)) / groove.width))
                }
                onPressed: mouse => { sk.seekFrac = fracAt(mouse); sk.seeking = true }
                onPositionChanged: mouse => { if (pressed) sk.seekFrac = fracAt(mouse) }
                onReleased: {
                    if (root.player && root.player.canSeek) root.player.position = sk.seekFrac * sk.length
                    sk.seeking = false
                }
            }
        }

        Label {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            text: root.clock(sk.frac * sk.length)
            font.pixelSize: root.px(11)
            color: sk.seeking ? Theme.bright : Theme.dim
            Behavior on color { ColorAnimation { duration: Theme.fast } }
        }
        Label {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: sk.length > 0 ? root.clock(sk.length) : "--:--"
            font.pixelSize: root.px(11)
            color: Theme.dim
        }
    }

    component Art: Item {
        id: art
        property string url: ""
        property bool useA: true

        // setting the same source doesn't fire onStatusChanged, found out the hard way
        onUrlChanged: {
            const front = useA ? imgA : imgB
            const back = useA ? imgB : imgA
            if (url !== "" && front.source == url) return
            if (url !== "" && back.source == url && back.status !== Image.Loading) { swapTo(back); return }
            back.source = url
            if (url === "") swapTo(back)
        }

        function swapTo(img) {
            useA = img === imgA
        }
        function settled(img) {
            if (img.source != url) return
            if (img.status === Image.Ready || img.status === Image.Error) swapTo(img)
        }

        Rectangle {
            anchors.fill: parent
            radius: root.px(12)
            color: Theme.alpha(Theme.fg, 0.07)

            Label {
                anchors.centerIn: parent
                text: ""
                font.pixelSize: root.px(30)
                color: Theme.dim
            }
        }

        ClippingRectangle {
            anchors.fill: parent
            radius: root.px(12)
            color: "transparent"

            Image {
                id: imgA
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                mipmap: true
                sourceSize: Qt.size(256, 256)
                opacity: art.useA && status === Image.Ready ? 1 : 0
                scale: art.useA ? 1 : 1.04
                onStatusChanged: art.settled(imgA)
                Behavior on opacity { NumberAnimation { duration: Theme.ms(380); easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: Theme.ms(520); easing.type: Easing.OutCubic } }
            }
            Image {
                id: imgB
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                mipmap: true
                sourceSize: Qt.size(256, 256)
                opacity: !art.useA && status === Image.Ready ? 1 : 0
                scale: !art.useA ? 1 : 1.04
                onStatusChanged: art.settled(imgB)
                Behavior on opacity { NumberAnimation { duration: Theme.ms(380); easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: Theme.ms(520); easing.type: Easing.OutCubic } }
            }
        }
    }
}

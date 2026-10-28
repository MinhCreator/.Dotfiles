import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import "Schema.js" as Schema
import "../common"

ShellRoot {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property real defaultFrac: 1 / 3
    readonly property real minFrac: 0.2
    readonly property real maxFrac: 0.6

    property bool active: false
    property bool leaving: false
    property real t: 0
    property var targetScreen: null

    property real frac: defaultFrac
    property real dragFrac: defaultFrac
    property bool dragging: false
    property string page: "profile"
    readonly property var current: Schema.PAGES.find(p => p.id === page) || Schema.PAGES[0]
    readonly property real screenW: (win.screen ? win.screen.width : 1600)

    FileView {
        id: uiFile
        path: root.home + "/.local/state/hypr-settings/ui.json"
        blockLoading: true
    }

    Component.onCompleted: {
        try {
            const ui = JSON.parse(uiFile.text())
            if (typeof ui.wfrac === "number") frac = Math.max(minFrac, Math.min(maxFrac, ui.wfrac))
            if (ui.page && Schema.PAGES.some(p => p.id === ui.page)) page = ui.page
        } catch (e) {}
        dragFrac = frac
        targetScreen = usableScreen(Theme.focusedScreen())
        Store.refresh()
    }


    function screenNamed(name) {
        return Quickshell.screens.find(s => s.name === name) ?? Theme.focusedScreen()
    }

    function show(name) {
        showOn(name ? screenNamed(name) : Theme.focusedScreen())
    }

    function landscape(scr) {
        return !!scr && scr.width >= scr.height
    }

    function usableScreen(scr) {
        if (landscape(scr)) return scr
        if (landscape(targetScreen)) return targetScreen
        return Quickshell.screens.find(s => landscape(s)) ?? scr
    }

    function showOn(scr) {
        scr = usableScreen(scr)
        if (active && !leaving && scr === targetScreen) return
        if (scr !== targetScreen) {
            tween.stop()
            active = false
            leaving = false
            t = 0
            targetScreen = scr
            moveDelay.restart()
            return
        }
        begin()
    }

    function followCursor(scr) {
        if (!active || leaving || dragging) return
        if (landscape(scr) && scr !== targetScreen) showOn(scr)
    }

    Timer {
        interval: 200
        repeat: true
        running: root.active && !root.leaving
        // skip a tick if the last lookup hasn't come back
        onTriggered: if (Theme.located.length === 0) Theme.locate(root.followCursor)
    }

    function begin() {
        leaving = false
        active = true
        Store.opened++
        ld.item?.forceActiveFocus()
        animateTo(1)
    }

    function close() {
        if (!active || leaving) return
        leaving = true
        animateTo(0)
    }

    function toggle(name) {
        const scr = usableScreen(name ? screenNamed(name) : Theme.focusedScreen())
        if (active && !leaving && scr === targetScreen) close()
        else show(name)
    }

    function stepPage(d) {
        const i = Schema.PAGES.findIndex(p => p.id === page)
        selectPage(Schema.PAGES[(i + d + Schema.PAGES.length) % Schema.PAGES.length].id)
    }

    function moveSelection(d) {
        if (Store.picker) { Store.picker.step(d); return }
        if (!ld.item) return
        const s = ld.item.pScrollAnim, scroller = ld.item.pScroller
        s.stop()
        s.from = scroller.contentY
        s.to = Math.max(0, Math.min(scroller.contentHeight - scroller.height, scroller.contentY + d * 90))
        s.start()
    }

    property int pageDir: 1

    function selectPage(id) {
        if (id === page) return
        const from = Schema.PAGES.findIndex(p => p.id === page)
        const to = Schema.PAGES.findIndex(p => p.id === id)
        pageDir = to >= from ? 1 : -1
        page = id
        Store.saveUi("page", id)
        ld.item?.forceActiveFocus()
    }

    function animateTo(target) {
        tween.stop()
        tween.from = t
        tween.to = target
        tween.duration = Theme.ms(target === 1 ? 380 : 240)
        tween.easing.type = Easing.BezierSpline
        tween.easing.bezierCurve = target === 1 ? Theme.settle : Theme.leave
        tween.start()
    }

    Timer { id: moveDelay; interval: 90; onTriggered: root.begin() }

    NumberAnimation {
        id: tween
        target: root
        property: "t"
        onFinished: {
            if (root.leaving) { root.active = false; root.leaving = false }
            else Store.refresh()
        }
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { root.toggle("") }
        function open(): void { root.show("") }
        function toggleOn(screen: string): void { root.toggle(screen) }
        function openOn(screen: string): void { root.show(screen) }
        function close(): void { root.close() }
        function page(id: string): void { root.selectPage(id); root.show("") }
    }

    function controlShown(c, values, caps, waybar) {
        if (c.type === "waybar" && ((Store.bar === "quickshell" ? Store.quickshell : waybar).styles || []).length === 0) return false
        return Schema.shown(c, values, caps)
    }

    function sectionVisible(sec, values, caps, waybar) {
        return sec.controls.some(c => controlShown(c, values, caps, waybar))
    }

    function firstShown(controls, values, caps, waybar) {
        return controls.findIndex(c => controlShown(c, values, caps, waybar))
    }

    function source(type) {
        return "Setting" + type.charAt(0).toUpperCase() + type.slice(1) + ".qml"
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData
            screen: modelData
            visible: root.active && !root.leaving && modelData !== root.targetScreen
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "settings-panel-outside"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            MouseArea {
                anchors.fill: parent
                onPressed: root.close()
            }
        }
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
        color: "transparent"
        exclusionMode: ExclusionMode.Normal
        mask: Region { item: root.active && !root.leaving ? ld.item : null }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "settings-panel"
        WlrLayershell.keyboardFocus: root.active && !root.leaving ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Loader {
            id: ld
            anchors.fill: parent
            active: root.active || root.warm
            sourceComponent: Component {
                Item {
                    id: keyRoot
                    objectName: "keyRoot"
                    property alias pScroller: scroller
                    property alias pScrollAnim: scrollAnim
                    anchors.fill: parent
                    focus: true
                    Keys.onEscapePressed: root.close()
                    Keys.onPressed: event => {
                        const k = event.key
                        if (k === Qt.Key_Left || k === Qt.Key_H || k === Qt.Key_Backtab) root.stepPage(-1)
                        else if (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_Tab) root.stepPage(1)
                        else if (k === Qt.Key_Down || k === Qt.Key_J) root.moveSelection(1)
                        else if (k === Qt.Key_Up || k === Qt.Key_K) root.moveSelection(-1)
                        else if ((k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) && Store.picker) Store.picker.pick()
                        else { event.accepted = false; return }
                        event.accepted = true
                    }

                    MouseArea {
                        anchors.fill: parent
                        onPressed: root.close()
                    }

                    Item {
                        id: card
                        visible: root.active
                        width: Math.round(root.screenW * (root.dragging ? root.dragFrac : root.frac))
                        height: parent.height
                        x: (root.t - 1) * width

                        MouseArea { anchors.fill: parent }

                        Rectangle {
                            readonly property real rounding: Store.values["config.decoration.rounding"] ?? 10
                            x: -(rounding + 2)
                            width: parent.width + rounding + 2
                            height: parent.height
                            radius: rounding
                            color: Theme.alpha(Theme.bg, 0.64)
                            border.width: 1
                            border.color: Theme.alpha(Theme.fg, 0.07)
                        }

                        Item {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 18

                            Label {
                                id: title
                                y: 16
                                text: root.current.label
                                font.pixelSize: 20
                                color: Theme.bright

                                transform: Translate { id: titleShift }

                                Connections {
                                    target: root
                                    function onPageChanged() { titleAnim.restart() }
                                }

                                ParallelAnimation {
                                    id: titleAnim
                                    NumberAnimation { target: title; property: "opacity"; from: 0; to: 1; duration: Theme.ms(320); easing.type: Easing.OutCubic }
                                    NumberAnimation { target: titleShift; property: "x"; from: 14 * root.pageDir; to: 0; duration: Theme.ms(380); easing.type: Easing.OutCubic }
                                }
                            }

                            Label {
                                anchors.right: parent.right
                                anchors.verticalCenter: title.verticalCenter
                                text: "Hyprland · Alt+S"
                                font.pixelSize: 11
                                color: Theme.dim
                            }

                            Item {
                                id: tabs
                                y: title.y + title.height + 14
                                width: parent.width
                                height: 34
                                readonly property real gap: 6
                                readonly property real cell: (width - gap * (Schema.PAGES.length - 1)) / Schema.PAGES.length
                                readonly property int index: Math.max(0, Schema.PAGES.findIndex(p => p.id === root.page))

                                Rectangle {
                                    width: tabs.cell
                                    height: parent.height
                                    radius: Theme.r(9)
                                    x: tabs.index * (tabs.cell + tabs.gap)
                                    color: Theme.alpha(Theme.accent, 0.42)
                                    Behavior on x { NumberAnimation { duration: Theme.ms(340); easing.type: Easing.OutCubic } }
                                }

                                Repeater {
                                    model: Schema.PAGES

                                    Item {
                                        id: tab
                                        required property var modelData
                                        required property int index
                                        readonly property bool on: root.page === modelData.id
                                        x: index * (tabs.cell + tabs.gap)
                                        width: tabs.cell
                                        height: tabs.height

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: Theme.r(9)
                                            color: Theme.alpha(Theme.fg, tab.on ? 0 : (tabArea.containsMouse ? 0.12 : 0.05))
                                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                                        }

                                        Label {
                                            anchors.centerIn: parent
                                            text: tab.modelData.icon
                                            font.pixelSize: 15
                                            scale: tab.on ? 1.12 : 1
                                            color: tab.on || tabArea.containsMouse ? Theme.bright : Theme.fg
                                            Behavior on scale { NumberAnimation { duration: Theme.ms(260); easing.type: Easing.OutBack } }
                                            Behavior on color { ColorAnimation { duration: Theme.fast } }
                                        }

                                        Hover {
                                            id: tabArea
                                            anchors.fill: parent
                                            onClicked: root.selectPage(tab.modelData.id)
                                        }
                                    }
                                }
                            }

                            Flickable {
                                id: scroller
                                anchors.top: tabs.bottom
                                anchors.topMargin: 14
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 10
                                width: parent.width
                                contentHeight: body.height + 14
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                flickableDirection: Flickable.VerticalFlick

                                visible: !root.current.themes

                                Connections {
                                    target: root
                                    function onPageChanged() { scroller.contentY = 0 }
                                }

                                NumberAnimation { id: scrollAnim; target: scroller; property: "contentY"; duration: Theme.ms(140); easing.type: Easing.OutCubic }

                                Column {
                                    id: body
                                    width: scroller.width
                                    spacing: 16

                                    Repeater {
                                        model: root.current.sections

                                        Column {
                                            id: sec
                                            required property var modelData
                                            required property int index
                                            visible: root.sectionVisible(modelData, Store.values, Store.caps, Store.waybar)
                                            width: body.width
                                            spacing: 6

                                            Rise { target: sec; index: sec.index; replay: Store.opened }

                                            Label {
                                                x: 4
                                                text: sec.modelData.label.toUpperCase()
                                                font.pixelSize: 10
                                                font.letterSpacing: 1.6
                                                color: Theme.dim
                                            }

                                            Rectangle {
                                                width: sec.width
                                                height: rows.height
                                                radius: Theme.r(12)
                                                color: Theme.alpha(Theme.fg, 0.055)

                                                Column {
                                                    id: rows
                                                    width: parent.width

                                                    Repeater {
                                                        model: sec.modelData.controls

                                                        Item {
                                                            id: row
                                                            required property var modelData
                                                            required property int index
                                                            readonly property bool on: root.controlShown(modelData, Store.values, Store.caps, Store.waybar)
                                                            readonly property int lead: root.firstShown(sec.modelData.controls, Store.values, Store.caps, Store.waybar)
                                                            // animate an amount not the height, otherwise live resizing lags. i think
                                                            property real reveal: on ? 1 : 0
                                                            Behavior on reveal { NumberAnimation { duration: Theme.ms(220); easing.type: Easing.OutCubic } }


                                                            width: rows.width
                                                            height: inner.height * reveal
                                                            opacity: reveal
                                                            visible: reveal > 0.001
                                                            clip: reveal < 1

                                                            Column {
                                                                id: inner
                                                                width: row.width

                                                                Rectangle {
                                                                    visible: row.index > row.lead
                                                                    x: Theme.pad
                                                                    width: parent.width - Theme.pad * 2
                                                                    height: 1
                                                                    color: Theme.alpha(Theme.fg, 0.07)
                                                                }

                                                                Loader {
                                                                    width: row.width
                                                                    height: item ? item.implicitHeight : 0
                                                                    Component.onCompleted: setSource(root.source(row.modelData.type), { def: row.modelData })
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Loader {
                                id: themesHost
                                anchors.top: tabs.bottom
                                anchors.topMargin: 6
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 8
                                width: parent.width
                                active: root.current.themes === true
                                source: "Themes.qml"
                            }
                        }

                        Item {
                            anchors.right: parent.right
                            width: 16
                            height: parent.height

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                x: 6
                                width: 4
                                height: grabArea.containsMouse || grabArea.pressed ? 64 : 40
                                radius: 2
                                color: Theme.alpha(grabArea.containsMouse || grabArea.pressed ? Theme.accent : Theme.fg, grabArea.containsMouse || grabArea.pressed ? 0.85 : 0.25)
                                Behavior on height { NumberAnimation { duration: Theme.ms(200); easing.type: Easing.OutCubic } }
                                Behavior on color { ColorAnimation { duration: Theme.fast } }
                            }

                            MouseArea {
                                id: grabArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.SizeHorCursor

                                property real startX: 0
                                property real startWidth: 0

                                function windowX(mouse) {
                                    return mapToItem(win.contentItem, mouse.x, mouse.y).x
                                }

                                onPressed: mouse => {
                                    startX = windowX(mouse)
                                    startWidth = card.width
                                    root.dragFrac = card.width / root.screenW
                                    root.dragging = true
                                }

                                onPositionChanged: mouse => {
                                    if (!pressed) return
                                    const w = startWidth + (windowX(mouse) - startX)
                                    root.dragFrac = Math.max(0.08, Math.min(root.maxFrac, w / root.screenW))
                                }

                                onReleased: {
                                    root.dragging = false
                                    const f = root.dragFrac
                                    if (f < root.minFrac * 0.75) {
                                        root.close()
                                        return
                                    }
                                    let next = Math.max(root.minFrac, f)
                                    if (Math.abs(next - root.defaultFrac) * root.screenW < 14) next = root.defaultFrac
                                    root.frac = next
                                    Store.saveUi("wfrac", next)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

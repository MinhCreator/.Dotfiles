import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import "../common"

ShellRoot {
    id: root

    readonly property string home: Quickshell.env("HOME")

    property bool active: false
    property bool leaving: false
    property real t: 0
    property real pulse: 0
    property real wiggle: 0
    property int fillDuration: 110

    property string kind: "volume"
    property bool flag: false
    property string label: ""
    property real shownValue: 0

    readonly property real dotSize: 52
    readonly property real fullWidth: 300
    readonly property real w: Math.max(0, (t - 0.2) / 0.8)

    readonly property color accent: kind === "volume" ? Theme.info : kind === "brightness" ? Theme.caution : hasBar ? Theme.accent : Theme.accent2

    readonly property bool hasBar: kind === "volume" || kind === "brightness"
    readonly property bool off: kind === "volume" ? flag : false
    readonly property string glyph: {
        switch (kind) {
        case "volume": return flag || shownValue < 0.005 ? "\uf026" : (shownValue < 0.45 ? "\uf027" : "\uf028")
        case "brightness": return "\uf185"
        case "mic": return flag ? "\uf131" : "\uf130"
        case "caps": return flag ? "\uf023" : "\uf09c"
        case "play": return "\uf04b"
        case "pause": return "\uf04c"
        case "next": return "\uf051"
        case "prev": return "\uf048"
        }
        return ""
    }
    readonly property string title: {
        switch (kind) {
        case "caps": return "Caps Lock"
        case "mic": return "Microphone"
        case "play": case "pause": case "next": case "prev": return label !== "" ? label : (kind === "pause" ? "Paused" : "Playing")
        }
        return ""
    }
    readonly property string readout: {
        if (hasBar) return flag ? "MUTE" : Math.round(shownValue * 100) + "%"
        if (kind === "caps") return flag ? "ON" : "OFF"
        if (kind === "mic") return flag ? "OFF" : "ON"
        return ""
    }
    readonly property bool readoutLit: kind === "caps" ? flag : (kind === "mic" ? !flag : !off)

    function stage(from) {
        return Math.max(0, Math.min(1, (t - from) / (1 - from)))
    }

    function present(k, v, f, text) {
        const fresh = !active || leaving || kind !== k
        const toggled = !fresh && flag !== f

        kind = k
        flag = f
        label = text

        if (fresh) {
            barBehavior.enabled = false
            shownValue = 0
            fillDuration = 420
            barBehavior.enabled = true
            shownValue = v
        } else {
            fillDuration = 120
            shownValue = v
        }

        hideTimer.restart()
        if (!active) {
            active = true
            leaving = false
            t = 0
            animateTo(1)
        } else if (leaving) {
            leaving = false
            animateTo(1)
        } else {
            pulseAnim.restart()
        }

        if (toggled) wiggleAnim.restart()
    }

    function animateTo(target) {
        tween.stop()
        tween.from = t
        tween.to = target
        tween.duration = Theme.ms(target === 1 ? 480 : 340)
        tween.easing.type = Easing.BezierSpline
        tween.easing.bezierCurve = target === 1 ? Theme.settle : Theme.leave
        tween.start()
    }

    function hide() {
        if (!active || leaving) return
        leaving = true
        animateTo(0)
    }

    NumberAnimation {
        id: tween
        target: root
        property: "t"
        onFinished: if (root.leaving) { root.active = false; root.leaving = false; root.t = 0 }
    }

    Timer { id: hideTimer; interval: 1400; onTriggered: root.hide() }

    SequentialAnimation {
        id: pulseAnim
        NumberAnimation { target: root; property: "pulse"; to: 1; duration: Theme.ms(70); easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "pulse"; to: 0; duration: Theme.ms(220); easing.type: Easing.OutBack }
    }

    SequentialAnimation {
        id: wiggleAnim
        NumberAnimation { target: root; property: "wiggle"; to: -14; duration: Theme.ms(60); easing.type: Easing.OutQuad }
        NumberAnimation { target: root; property: "wiggle"; to: 11; duration: Theme.ms(90); easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "wiggle"; to: -6; duration: Theme.ms(80); easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "wiggle"; to: 0; duration: Theme.ms(100); easing.type: Easing.OutQuad }
    }

    IpcHandler {
        target: "osd"
        function notify(kind: string, value: real, flag: bool, text: string): void { root.present(kind, value, flag, text) }
    }

    PanelWindow {
        visible: root.active
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        anchors.bottom: true
        // sits on the edge so the card can slide fully off
        margins.bottom: 0
        implicitWidth: 340
        implicitHeight: 156
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "osd"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Item {
            id: card
            width: root.dotSize + (root.fullWidth - root.dotSize) * root.w
            height: root.dotSize
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 76 - 132 * (1 - root.t)
            opacity: Math.min(1, root.t * 8)
            scale: 1 + 0.015 * root.pulse

            Rectangle {
                anchors.fill: parent
                radius: Math.max(10, root.dotSize / 2 - (root.dotSize / 2 - 10) * Math.min(1, root.w))
                color: Theme.alpha(Theme.bg, 0.45)
            }

            Label {
                id: icon
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 22
                horizontalAlignment: Text.AlignHCenter
                text: root.glyph
                font.pixelSize: 18
                color: root.off ? Theme.dim : root.accent
                rotation: root.wiggle
                scale: (0.75 + 0.25 * root.stage(0.1)) * (1 + 0.18 * root.pulse)
                Behavior on color { ColorAnimation { duration: Theme.ms(120) } }
            }

            Label {
                id: readout
                visible: root.stage(0.55) > 0
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                horizontalAlignment: Text.AlignRight
                text: root.readout
                font.pixelSize: 14
                color: root.readoutLit ? Theme.fg : Theme.dim
                opacity: root.stage(0.55)
                transform: Translate { x: 6 * (1 - root.stage(0.55)) }
                Behavior on color { ColorAnimation { duration: Theme.ms(120) } }
            }

            Rectangle {
                visible: root.hasBar && root.stage(0.5) > 0
                anchors.left: icon.right
                anchors.leftMargin: 14
                anchors.right: readout.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                height: 4
                radius: 2
                color: Theme.alpha(Theme.fg, 0.16)
                opacity: root.stage(0.5)

                Rectangle {
                    id: fill
                    height: parent.height
                    radius: 2
                    width: parent.width * Math.max(0, Math.min(1, root.shownValue))
                    color: root.off ? Theme.dim : root.accent
                    Behavior on color { ColorAnimation { duration: Theme.ms(90) } }

                    Rectangle {
                        visible: root.shownValue > 0.01 && !root.off
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10 + 6 * root.pulse
                        height: width
                        radius: width / 2
                        x: parent.width - width / 2
                        color: root.accent
                    }
                }
            }

            Label {
                visible: !root.hasBar && root.stage(0.5) > 0
                anchors.left: icon.right
                anchors.leftMargin: 14
                anchors.right: readout.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: root.title
                elide: Text.ElideRight
                font.pixelSize: 15
                color: Theme.fg
                opacity: root.stage(0.5)
                transform: Translate { x: -6 * (1 - root.stage(0.5)) }
            }
        }
    }

    Behavior on shownValue { id: barBehavior; NumberAnimation { duration: Theme.ms(root.fillDuration); easing.type: Easing.OutCubic } }
}
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../common"

QtObject {
    component Entry: Rectangle {
        id: row

        property string glyph: ""
        property string iconSource: ""
        property string label: ""
        property string sub: ""
        property string trailing: ""
        property bool active: false
        property bool busy: false
        property bool enabledRow: true
        property bool gear: false
        readonly property bool hot: area.containsMouse || cogArea.containsMouse
        signal clicked()
        signal rightClicked()
        signal settingsClicked()

        // wiggles while connecting, does a little spin when it works. i like it
        property real triedAt: 0
        function cheer() {
            triedAt = 0
            wiggle.stop()
            settle.stop()
            party.restart()
        }
        onBusyChanged: {
            triedAt = Date.now()
            if (busy) { party.stop(); settle.stop(); wiggle.restart(); return }
            wiggle.stop()
            if (active) cheer()
            else settle.restart()
        }
        onActiveChanged: if (active && !busy && Date.now() - triedAt < 2500) cheer()
        Component.onCompleted: if (busy) { triedAt = Date.now(); wiggle.start() }

        width: parent ? parent.width : 0
        height: sub !== "" ? 46 : 36
        color: active ? Theme.alpha(Theme.accent, area.containsMouse ? 0.34 : 0.26)
            : Theme.alpha(Theme.fg, area.containsMouse && enabledRow ? 0.1 : 0)
        opacity: enabledRow ? 1 : 0.45
        Behavior on color { ColorAnimation { duration: Theme.ms(120) } }

        Item {
            id: lead
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20
            visible: row.glyph !== "" || row.iconSource !== ""

            Label {
                anchors.centerIn: parent
                visible: row.iconSource === ""
                text: row.glyph
                font.pixelSize: 15
                color: row.active || row.busy ? Theme.accent : Theme.fg
                Behavior on color { ColorAnimation { duration: Theme.ms(200) } }
            }

            IconImage {
                anchors.centerIn: parent
                visible: row.iconSource !== ""
                implicitSize: 18
                source: row.iconSource
            }
        }

        // hardcoded on purpose, Theme.ms can hit 0 and a 0ms infinite loop maxed my cpu
        SequentialAnimation {
            id: wiggle
            loops: Animation.Infinite
            NumberAnimation { target: lead; property: "rotation"; to: -16; duration: 200; easing.type: Easing.InOutSine }
            NumberAnimation { target: lead; property: "rotation"; to: 14; duration: 320; easing.type: Easing.InOutSine }
            NumberAnimation { target: lead; property: "rotation"; to: -9; duration: 280; easing.type: Easing.InOutSine }
            NumberAnimation { target: lead; property: "rotation"; to: 0; duration: 220; easing.type: Easing.InOutSine }
            NumberAnimation { target: lead; property: "scale"; to: 1.2; duration: 240; easing.type: Easing.InOutSine }
            NumberAnimation { target: lead; property: "scale"; to: 1; duration: 360; easing.type: Easing.InOutSine }
            PauseAnimation { duration: 100 }
        }

        ParallelAnimation {
            id: settle
            NumberAnimation { target: lead; property: "rotation"; to: 0; duration: Theme.ms(300); easing.type: Easing.OutCubic }
            NumberAnimation { target: lead; property: "scale"; to: 1; duration: Theme.ms(300); easing.type: Easing.OutCubic }
        }

        SequentialAnimation {
            id: party
            ParallelAnimation {
                NumberAnimation { target: lead; property: "rotation"; to: 360; duration: Theme.ms(760); easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                SequentialAnimation {
                    NumberAnimation { target: lead; property: "scale"; to: 1.4; duration: Theme.ms(260); easing.type: Easing.OutQuad }
                    NumberAnimation { target: lead; property: "scale"; to: 1; duration: Theme.ms(500); easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                }
            }
            PropertyAction { target: lead; property: "rotation"; value: 0 }
        }

        Column {
            anchors.left: lead.visible ? lead.right : parent.left
            anchors.leftMargin: lead.visible ? 10 : 16
            anchors.right: cog.visible ? cog.left : tail.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Label {
                width: parent.width
                text: row.label
                elide: Text.ElideRight
                font.pixelSize: 13
                color: row.active || row.hot ? Theme.bright : Theme.fg
            }
            Label {
                width: parent.width
                visible: row.sub !== ""
                text: row.sub
                elide: Text.ElideRight
                font.pixelSize: 10
                color: Theme.dim
            }
        }

        Label {
            id: tail
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: row.trailing
            font.pixelSize: 11
            color: row.active ? Theme.accent : Theme.dim
        }

        Hover {
            id: area
            anchors.fill: parent
            enabled: row.enabledRow
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => m.button === Qt.RightButton ? row.rightClicked() : row.clicked()
        }

        Item {
            id: cog
            visible: row.gear
            anchors.right: tail.left
            anchors.rightMargin: tail.text !== "" ? 4 : -4
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: row.hot ? 26 : 0
            Behavior on width { NumberAnimation { duration: Theme.ms(180); easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                radius: Math.min(Theme.rounding, height / 2)
                color: Theme.alpha(Theme.fg, cogArea.containsMouse ? 0.14 : 0)
                opacity: row.hot ? 1 : 0
                scale: row.hot ? 1 : 0.6
                Behavior on color { ColorAnimation { duration: Theme.ms(120) } }
                Behavior on opacity { NumberAnimation { duration: Theme.ms(160) } }
                Behavior on scale { NumberAnimation { duration: Theme.ms(180); easing.type: Easing.OutBack } }

                Label {
                    anchors.centerIn: parent
                    text: "\uf013"
                    font.pixelSize: 12
                    color: cogArea.containsMouse ? Theme.bright : Theme.dim
                }

                Hover {
                    id: cogArea
                    anchors.fill: parent
                    anchors.margins: -2
                    enabled: row.gear
                    onClicked: row.settingsClicked()
                }
            }
        }
    }

    component Round: Rectangle {
        id: rb
        property string glyph
        signal clicked()
        width: 26
        height: 26
        radius: Math.min(Theme.rounding, height / 2)
        color: Theme.alpha(Theme.fg, rbArea.containsMouse ? 0.14 : 0.07)
        Behavior on color { ColorAnimation { duration: Theme.ms(120) } }

        Label {
            anchors.centerIn: parent
            text: rb.glyph
            font.pixelSize: 12
            color: rbArea.containsMouse ? Theme.bright : Theme.fg
        }

        Hover {
            id: rbArea
            anchors.fill: parent
            onClicked: rb.clicked()
        }
    }

    component Toggle: Item {
        id: tg
        property string label
        property bool checked: false
        signal toggled()
        width: parent ? parent.width : 0
        height: 26

        Label {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: tg.label
            font.pixelSize: 12
            color: Theme.fg
        }
        Switch {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: tg.checked
            onToggled: { tg.checked = !tg.checked; tg.toggled() }
        }
    }

    component Header: Item {
        id: h
        property string title
        property string note
        property string icon
        default property alias trailing: tail.data
        width: parent ? parent.width : 0
        height: 26

        IconImage {
            id: appIcon
            anchors.verticalCenter: parent.verticalCenter
            visible: h.icon !== ""
            implicitSize: 18
            source: h.icon
        }
        Label {
            anchors.left: appIcon.visible ? appIcon.right : parent.left
            anchors.leftMargin: appIcon.visible ? 10 : 0
            anchors.right: noteText.left
            anchors.verticalCenter: parent.verticalCenter
            text: h.title
            elide: Text.ElideRight
            font.pixelSize: 16
            color: Theme.bright
        }
        Label {
            id: noteText
            anchors.right: tail.left
            anchors.rightMargin: tail.width > 0 ? 10 : 0
            anchors.verticalCenter: parent.verticalCenter
            text: h.note
            font.pixelSize: 10
            color: Theme.dim
        }
        Row {
            id: tail
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
        }
    }

    component Group: Column {
        id: sec

        property string title: ""
        property int maxHeight: 240
        property string empty: ""
        default property alias rows: list.data

        width: parent ? parent.width : 0
        spacing: 6

        Label {
            x: 4
            visible: sec.title !== ""
            text: sec.title.toUpperCase()
            font.pixelSize: 10
            font.letterSpacing: 1.6
            color: Theme.dim
        }

        // rows go edge to edge and get clipped to the corners so a highlight isn't a box in a box
        ClippingRectangle {
            width: parent.width
            height: Math.min(sec.maxHeight, Math.max(sec.empty !== "" && list.implicitHeight < 4 ? 40 : 0, list.implicitHeight))
            radius: Math.min(Theme.rounding, 12)
            color: Theme.alpha(Theme.fg, 0.055)

            Flickable {
                anchors.fill: parent
                contentHeight: list.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height

                Column {
                    id: list
                    width: parent.width
                }
            }

            Label {
                anchors.centerIn: parent
                visible: sec.empty !== "" && list.implicitHeight < 4
                text: sec.empty
                font.pixelSize: 12
                color: Theme.dim
            }
        }
    }

    component Caption: Text {
        x: 4
        font.family: Theme.sans
        font.pixelSize: 10
        font.letterSpacing: 1.6
        color: Theme.dim
    }

    component Field: Rectangle {
        id: field

        property alias text: input.text
        property string placeholder: ""
        property bool secret: false
        property bool readOnly: false
        property bool shown: false
        signal accepted()

        function grab() { input.forceActiveFocus() }

        width: parent ? parent.width : 0
        height: 34
        radius: Math.min(Theme.rounding, 8)
        color: Theme.alpha(Theme.fg, input.activeFocus ? 0.1 : 0.07)
        border.width: 1
        border.color: input.activeFocus ? Theme.alpha(Theme.accent, 0.6) : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.ms(120) } }
        Behavior on border.color { ColorAnimation { duration: Theme.ms(120) } }

        TextInput {
            id: input
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: eye.visible ? eye.left : parent.right
            anchors.rightMargin: eye.visible ? 8 : 12
            anchors.verticalCenter: parent.verticalCenter
            readOnly: field.readOnly
            echoMode: field.secret && !field.shown ? TextInput.Password : TextInput.Normal
            font.family: Theme.sans
            font.pixelSize: 13
            color: Theme.bright
            selectionColor: Theme.alpha(Theme.accent, 0.5)
            selectByMouse: true
            clip: true
            onAccepted: field.accepted()

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                visible: input.text === ""
                text: field.placeholder
                elide: Text.ElideRight
                font: input.font
                color: Theme.dim
            }
        }

        Label {
            id: eye
            visible: field.secret
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: field.shown ? "\uf070" : "\uf06e"
            font.pixelSize: 12
            color: eyeArea.containsMouse ? Theme.fg : Theme.dim
            MouseArea { id: eyeArea; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: field.shown = !field.shown }
        }
    }

    component Oops: Text {
        visible: text !== ""
        x: 4
        width: parent.width - 8
        wrapMode: Text.Wrap
        font.family: Theme.sans
        font.pixelSize: 11
        color: Theme.warn
    }

    component Addr: Row {
        property alias addr: a
        property alias gw: g
        width: parent ? parent.width : 0
        spacing: 6
        Field { id: a; width: (parent.width - 6) / 2; placeholder: "Address"; onAccepted: g.grab() }
        Field { id: g; width: (parent.width - 6) / 2; placeholder: "Gateway" }
    }

    component Chips: Flow {
        id: chips

        property var options: []
        property string value: ""
        signal picked(string v)

        width: parent ? parent.width : 0
        spacing: 6

        Repeater {
            model: chips.options

            Rectangle {
                id: chip
                required property var modelData
                readonly property bool on: chips.value === modelData[0]
                width: label.implicitWidth + 22
                height: 26
                radius: Math.min(Theme.rounding, height / 2)
                color: on ? Theme.alpha(Theme.accent, chipArea.containsMouse ? 0.95 : 0.8)
                    : Theme.alpha(Theme.fg, chipArea.containsMouse ? 0.14 : 0.07)
                Behavior on color { ColorAnimation { duration: Theme.ms(140) } }

                Label {
                    id: label
                    anchors.centerIn: parent
                    text: chip.modelData[1]
                    font.pixelSize: 11
                    color: chip.on ? Theme.bg : Theme.fg
                }

                Hover {
                    id: chipArea
                    anchors.fill: parent
                    onClicked: { chips.value = chip.modelData[0]; chips.picked(chips.value) }
                }
            }
        }
    }

    component Card: Rectangle {
        default property alias content: inner.data
        property alias spacing: inner.spacing
        width: parent ? parent.width : 0
        height: inner.implicitHeight + 20
        radius: Math.min(Theme.rounding, 12)
        color: Theme.alpha(Theme.fg, 0.055)

        Column {
            id: inner
            x: 10
            y: 10
            width: parent.width - 20
            spacing: 8
        }
    }

    component Network: Grid {
        id: menu

        property bool open: false
        signal run(string cmd)

        readonly property bool holdOpen: wifi.holdOpen
        readonly property real colW: columns === 2 ? (width - columnSpacing) / 2 : width

        columns: width >= 600 ? 2 : 1
        columnSpacing: 22
        rowSpacing: 18

        Wifi {
            id: wifi
            width: menu.colW
            open: menu.open
            onRun: c => menu.run(c)
        }

        Bluetooth {
            width: menu.colW
            open: menu.open
        }
    }

    component Wifi: Column {
        id: menu

        property bool open: false
        signal run(string cmd)

        spacing: 10

        readonly property var wifiDev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
        readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired && d.connected) ?? null
        readonly property var networks: wifiDev
            ? wifiDev.networks.values.filter(n => n.name !== "").slice().sort((a, b) =>
                (b.connected - a.connected) || (b.known - a.known) || (strength(b) - strength(a)))
            : []
        property string asking: ""
        property bool askingEap: false
        property bool hidden: false
        property string editing: ""
        readonly property bool joining: joiner.running
        readonly property bool listing: editing === ""
        readonly property bool holdOpen: asking !== "" || hidden || !listing || joining || saver.running
        property var failed: ({})
        property var vpns: []
        property string vpnBusy: ""

        // stop scanning while i type or the list jumps around
        Binding {
            target: menu.wifiDev
            property: "scannerEnabled"
            value: true
            when: menu.open && !menu.holdOpen && !!menu.wifiDev && Networking.wifiEnabled
            restoreMode: Binding.RestoreBindingOrValue
        }

        onOpenChanged: if (open) vpnList.running = true; else { asking = ""; hidden = false; editing = "" }
        Component.onCompleted: if (open) vpnList.running = true

        function strength(n) {
            const s = n.signalStrength ?? 0
            return s > 1 ? s / 100 : s
        }

        function glyph(n) {
            const f = strength(n)
            return f > 0.75 ? "󰤨" : f > 0.5 ? "󰤥" : f > 0.25 ? "󰤢" : "󰤟"
        }

        function secured(n) {
            return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Owe
        }

        function enterprise(n) {
            return n.security === WifiSecurityType.Wpa2Eap || n.security === WifiSecurityType.WpaEap
                || n.security === WifiSecurityType.Wpa3SuiteB192
        }

        function ask(n) {
            hidden = false
            askingEap = enterprise(n)
            asking = n.name
        }

        function askHidden() {
            asking = ""
            askingEap = false
            hidden = !hidden
        }

        function setFailed(name, why) {
            failed = Object.assign({}, failed, { [name]: why })
        }

        function pick(n) {
            if (joining) return
            setFailed(n.name, "")
            if (n.connected) n.disconnect()
            else if (n.known || !secured(n)) n.connect()
            else if (asking === n.name) asking = ""
            else ask(n)
        }

        // null means ethernet
        function edit(n) {
            asking = ""
            hidden = false
            editor.load(n ? "wifi" : "ethernet", n ? n.name : wired.name, n)
            editing = editor.name
        }

        // new networks go through nmcli since it actually tells me when the password is wrong
        // 802.1x is peap/mschapv2 because that's what UC_Secure wants, deleted again if it fails
        function join(ssid, user, psk) {
            if (joining || ssid === "" || (!hidden && psk.length === 0) || (askingEap && user === "")) return
            setFailed(ssid, "")
            joiner.ssid = ssid
            joiner.hidden = hidden
            joiner.command = askingEap
                ? ["sh", "-c", `nmcli connection delete id "$1" >/dev/null 2>&1
nmcli connection add type wifi con-name "$1" ssid "$1" wifi-sec.key-mgmt wpa-eap \\
  802-1x.eap peap 802-1x.phase2-auth mschapv2 802-1x.identity "$2" 802-1x.password "$3" >/dev/null || exit 1
nmcli --wait 30 connection up id "$1" >/dev/null && exit 0
nmcli connection delete id "$1" >/dev/null 2>&1
exit 1`, "sh", ssid, user, psk]
                : ["nmcli", "--wait", "30", "device", "wifi", "connect", ssid]
                    .concat(psk !== "" ? ["password", psk] : []).concat(hidden ? ["hidden", "yes"] : [])
            joiner.running = true
        }

        function lastLine(text) {
            return text.trim().replace(/^Error:\s*/, "").split("\n").pop()
        }

        Process {
            id: joiner
            property string ssid: ""
            property bool hidden: false
            stderr: StdioCollector { id: joinErr }
            onExited: code => {
                if (code === 0) {
                    if (menu.asking === joiner.ssid) menu.asking = ""
                    if (joiner.hidden) menu.hidden = false
                    return
                }
                const msg = menu.lastLine(joinErr.text)
                menu.setFailed(joiner.ssid, /secret|password|802-11-wireless-security/i.test(msg) ? "Wrong password" : (msg || "Error " + code))
                if (!joiner.hidden) menu.asking = joiner.ssid
                prompt.reset()
            }
        }

        function toggleVpn(v) {
            if (vpnBusy !== "") return
            vpnBusy = v.uuid
            vpnToggle.command = ["nmcli", "connection", v.active ? "down" : "up", "uuid", v.uuid]
            vpnToggle.running = true
        }

        Process {
            id: vpnList
            property bool clear: false
            command: ["nmcli", "-t", "-f", "UUID,TYPE,ACTIVE,NAME", "connection", "show"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const out = []
                    for (const line of text.split("\n")) {
                        const m = line.match(/^([^:]*):([^:]*):([^:]*):(.*)$/)
                        if (m && (m[2] === "vpn" || m[2] === "wireguard"))
                            out.push({ uuid: m[1], name: m[4].replace(/\\(.)/g, "$1"), active: m[3] === "yes" })
                    }
                    // only swap if it changed or the rows restart their animations
                    if (JSON.stringify(out) !== JSON.stringify(menu.vpns)) menu.vpns = out
                    if (vpnList.clear) { vpnList.clear = false; menu.vpnBusy = "" }
                }
            }
        }
        Process {
            id: vpnToggle
            onExited: { vpnList.clear = true; if (!vpnList.running) vpnList.running = true }
        }

        Header {
            visible: menu.listing
            title: "Wi-Fi"
            Round {
                visible: Networking.wifiEnabled && !!menu.wifiDev
                anchors.verticalCenter: parent.verticalCenter
                glyph: menu.hidden ? "" : ""
                onClicked: menu.askHidden()
            }
            Switch {
                anchors.verticalCenter: parent.verticalCenter
                checked: Networking.wifiEnabled
                onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
            }
        }

        Group {
            visible: !!menu.wired && menu.listing

            Entry {
                glyph: "󰈀"
                label: "Ethernet"
                active: true
                gear: true
                onClicked: menu.edit(null)
                onSettingsClicked: menu.edit(null)
            }
        }

        Group {
            visible: menu.listing
            maxHeight: 248
            empty: !menu.wifiDev ? "No adapter" : !Networking.wifiEnabled ? "Off" : "Searching…"

            // rows slide around instead of the whole list rebuilding
            Item {
                id: stack
                readonly property int rowH: 40
                readonly property int gapH: 0
                readonly property int count: Networking.wifiEnabled ? menu.networks.length : 0
                width: parent.width
                height: count > 0 ? count * (rowH + gapH) - gapH : 0
                Behavior on height { Settle { duration: Theme.move } }

                Repeater {
                    model: Networking.wifiEnabled && menu.wifiDev ? menu.wifiDev.networks : null

                    Entry {
                        id: net
                        required property var modelData
                        readonly property int rank: menu.networks.indexOf(modelData)
                        readonly property bool joiningThis: menu.joining && joiner.ssid === modelData.name
                        readonly property bool connecting: joiningThis || modelData.state === ConnectionState.Connecting || modelData.stateChanging

                        visible: rank >= 0
                        y: Math.max(0, rank) * (stack.rowH + stack.gapH)
                        height: stack.rowH
                        Behavior on y { Settle { duration: Theme.ms(420) } }

                        Connections {
                            target: net.modelData
                            function onConnectionFailed(reason) {
                                if (net.joiningThis) return
                                menu.setFailed(net.modelData.name, ConnectionFailReason.toString(reason))
                                if (!net.modelData.known && menu.secured(net.modelData)) menu.ask(net.modelData)
                            }
                            function onConnectedChanged() { if (net.modelData.connected && menu.asking === net.modelData.name && !menu.joining) menu.asking = "" }
                        }

                        glyph: menu.glyph(modelData)
                        label: modelData.name
                        sub: net.connecting ? "Connecting" : (menu.failed[modelData.name] || "")
                        trailing: menu.secured(modelData) ? "" : ""
                        active: modelData.connected || menu.asking === modelData.name
                        busy: net.connecting
                        gear: true
                        onClicked: menu.pick(modelData)
                        onRightClicked: if (modelData.known) modelData.forget()
                        onSettingsClicked: menu.edit(modelData)
                    }
                }
            }
        }

        // outside the repeater so a rescan can't eat what i'm typing
        Column {
            id: prompt
            visible: (menu.asking !== "" || menu.hidden) && menu.listing
            width: parent.width
            spacing: 6
            opacity: menu.joining ? 0.6 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }

            readonly property string target: menu.hidden ? ssid.text.trim() : menu.asking

            function reset() {
                pass.text = ""
                if (menu.hidden && ssid.text === "") ssid.grab()
                else if (menu.askingEap && user.text === "") user.grab()
                else pass.grab()
            }
            function submit() {
                if (menu.hidden && ssid.text.trim() === "") { ssid.grab(); return }
                if (menu.askingEap && user.text === "") { user.grab(); return }
                menu.join(prompt.target, user.text.trim(), pass.text)
            }
            function cancel() { menu.asking = ""; menu.hidden = false }
            Keys.onEscapePressed: cancel()

            onVisibleChanged: if (visible) reset()
            Connections {
                target: menu
                function onAskingChanged() { if (menu.asking !== "") prompt.reset() }
                function onHiddenChanged() { if (menu.hidden) { ssid.text = ""; prompt.reset() } }
            }

            Field {
                id: ssid
                visible: menu.hidden
                readOnly: menu.joining
                placeholder: "Name"
                onAccepted: pass.grab()
            }

            Field {
                id: user
                visible: menu.askingEap
                readOnly: menu.joining
                placeholder: "Username"
                onAccepted: pass.grab()
            }

            Item {
                width: parent.width
                height: 34

                Field {
                    id: pass
                    anchors.left: parent.left
                    anchors.right: go.left
                    anchors.rightMargin: 6
                    secret: true
                    readOnly: menu.joining
                    placeholder: "Password"
                    onAccepted: prompt.submit()
                }

                Button {
                    id: go
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: 34
                    primary: true
                    label: menu.joining ? "…" : "Join"
                    onPressed: prompt.submit()
                }
            }

            Oops { text: menu.hidden ? (menu.failed[prompt.target] || "") : "" }
        }

        Group {
            visible: menu.vpns.length > 0 && menu.listing
            maxHeight: 130

            Repeater {
                model: menu.vpns

                Entry {
                    required property var modelData
                    glyph: "󰖂"
                    label: modelData.name
                    active: modelData.active
                    busy: menu.vpnBusy === modelData.uuid
                    onClicked: menu.toggleVpn(modelData)
                }
            }
        }

        Column {
            id: editor
            visible: !menu.listing
            width: parent.width
            spacing: 10

            property string kind: "wifi"
            property string name: ""
            property alias tab: tabs.value
            property string uuid: ""
            property alias sec: secChips.value
            property alias eap: eapChips.value
            property alias phase2: phase2Chips.value
            property alias auto: autoT.checked
            property bool more: false
            property alias ip4: ip4Chips.value
            property string ip4Was: "auto"
            property alias ip6: ip6Chips.value
            property string ip6Was: "auto"
            property alias ignoreDns: ignoreDnsT.checked
            property alias allUsers: allUsersT.checked
            property bool allUsersWas: true
            property alias metered: meteredT.checked
            property alias ssidHidden: hiddenT.checked
            property alias band: bandChips.value
            property alias mac: macChips.value
            property string error: ""
            readonly property bool wifi: kind === "wifi"
            readonly property string hw: wifi ? "802-11-wireless" : "802-3-ethernet"
            readonly property bool saved: uuid !== ""
            readonly property bool busy: saver.running || loader.running
            Keys.onEscapePressed: menu.editing = ""

            function load(k, nm, n) {
                Object.assign(editor, { kind: k, name: nm, tab: k === "wifi" ? "sec" : "ip", uuid: "", error: "", more: false,
                    sec: !n ? "none" : menu.enterprise(n) ? "wpa-eap" : n.security === WifiSecurityType.Sae ? "sae" : menu.secured(n) ? "wpa-psk" : "none",
                    eap: "peap", phase2: "mschapv2", ip4: "auto", ip4Was: "auto", ip6: "auto", ip6Was: "auto", band: "", mac: "",
                    auto: true, allUsers: true, allUsersWas: true, metered: false, ssidHidden: false, ignoreDns: false })
                for (const f of [psk, identity, eapPass, anon, ca, domain, v4.addr, v4.gw, v6.addr, v6.gw, dns, mtu]) f.text = ""
                refresh()
            }

            // never reads the password back
            function refresh() {
                const f = ["connection.uuid", "connection.autoconnect", "connection.metered", "connection.permissions",
                    "ipv4.method", "ipv4.addresses", "ipv4.gateway", "ipv4.dns", "ipv4.ignore-auto-dns",
                    "ipv6.method", "ipv6.addresses", "ipv6.gateway", "ipv6.dns", hw + ".cloned-mac-address", hw + ".mtu"]
                if (wifi) f.push("802-11-wireless.hidden", "802-11-wireless.band", "802-11-wireless-security.key-mgmt",
                    "802-1x.eap", "802-1x.phase2-auth", "802-1x.identity", "802-1x.anonymous-identity", "802-1x.ca-cert", "802-1x.domain-suffix-match")
                loader.command = ["sh", "-c", `f=$1 kind=$2 name=$3
if [ "$kind" = ethernet ]; then
  u=$(nmcli -g UUID,DEVICE connection show --active | sed -n "s/:$name\\$//p" | head -n1)
  [ -n "$u" ] && exec nmcli -t -f "$f" connection show uuid "$u"
  exit 0
fi
for u in $(nmcli -g UUID,TYPE connection show | sed -n 's/:802-11-wireless$//p'); do
  [ "$(nmcli -g 802-11-wireless.ssid connection show uuid "$u")" = "$name" ] || continue
  exec nmcli -t -f "$f" connection show uuid "$u"
done`, "sh", f.join(","), kind, name]
                loader.running = true
            }

            function apply(f) {
                const get = k => (f[k] ?? "") === "--" ? "" : (f[k] ?? "")
                uuid = get("connection.uuid")
                auto = get("connection.autoconnect") !== "no"
                metered = get("connection.metered") === "yes"
                allUsers = allUsersWas = get("connection.permissions") === ""
                const m4 = get("ipv4.method")
                ip4 = ip4Was = ["manual", "shared", "disabled"].includes(m4) ? m4 : "auto"
                const m6 = get("ipv6.method")
                ip6 = ip6Was = m6 === "manual" ? "manual" : m6 === "disabled" || m6 === "ignore" ? "disabled" : "auto"
                v4.addr.text = get("ipv4.addresses")
                v4.gw.text = get("ipv4.gateway")
                v6.addr.text = get("ipv6.addresses")
                v6.gw.text = get("ipv6.gateway")
                dns.text = [get("ipv4.dns"), get("ipv6.dns")].filter(s => s).join(", ")
                ignoreDns = get("ipv4.ignore-auto-dns") === "yes"
                mac = get(hw + ".cloned-mac-address")
                const m = get(hw + ".mtu")
                mtu.text = m === "auto" || m === "0" ? "" : m
                if (!wifi) return
                ssidHidden = get("802-11-wireless.hidden") === "yes"
                band = get("802-11-wireless.band")
                const km = get("802-11-wireless-security.key-mgmt")
                sec = km === "" || km === "owe" ? "none" : km.startsWith("wpa-eap") ? "wpa-eap" : km === "sae" ? "sae" : "wpa-psk"
                if (get("802-1x.eap")) eap = get("802-1x.eap").split(",")[0]
                if (get("802-1x.phase2-auth")) phase2 = get("802-1x.phase2-auth")
                identity.text = get("802-1x.identity")
                anon.text = get("802-1x.anonymous-identity")
                ca.text = get("802-1x.ca-cert").replace(/^file:\/\//, "")
                domain.text = get("802-1x.domain-suffix-match")
                if (anon.text || ca.text || domain.text) more = true
            }

            function fail(msg, field, where) {
                error = msg
                if (where) tab = where
                if (field) field.grab()
            }

            function save(up) {
                if (busy) return
                error = ""
                const kv = ["connection.autoconnect", auto ? "yes" : "no"]
                const opt = (key, val) => { if (val !== "" || saved) kv.push(key, val) }
                const cidr = (s, p) => s.split(/[\s,]+/).filter(a => a).map(a => a.includes("/") ? a : a + "/" + p).join(",")

                if (wifi) {
                    if (sec === "wpa-psk" || sec === "sae") {
                        if (!saved && psk.text === "") return fail("Password needed", psk, "sec")
                        kv.push("802-11-wireless-security.key-mgmt", sec)
                        if (psk.text !== "") kv.push("802-11-wireless-security.psk", psk.text)
                    } else if (sec === "wpa-eap") {
                        if (identity.text.trim() === "") return fail("Username needed", identity, "sec")
                        if (!saved && eapPass.text === "") return fail("Password needed", eapPass, "sec")
                        kv.push("802-11-wireless-security.key-mgmt", "wpa-eap", "802-1x.eap", eap,
                            "802-1x.phase2-auth", phase2, "802-1x.identity", identity.text.trim())
                        if (eapPass.text !== "") kv.push("802-1x.password", eapPass.text)
                        opt("802-1x.anonymous-identity", anon.text.trim())
                        opt("802-1x.ca-cert", ca.text.trim().replace(/^~(?=\/)/, Quickshell.env("HOME")))
                        opt("802-1x.domain-suffix-match", domain.text.trim())
                    }
                }

                // only touch the method if i changed it, otherwise stuff like link-local gets wiped
                if (ip4 !== ip4Was || ip4 === "manual") kv.push("ipv4.method", ip4)
                if (ip4 === "manual") {
                    if (v4.addr.text.trim() === "") return fail("Address needed", v4.addr, "ip")
                    kv.push("ipv4.addresses", cidr(v4.addr.text, 24), "ipv4.gateway", v4.gw.text.trim())
                } else if (ip4 !== ip4Was) kv.push("ipv4.addresses", "", "ipv4.gateway", "")
                if (ip6 !== ip6Was || ip6 === "manual") kv.push("ipv6.method", ip6)
                if (ip6 === "manual") {
                    if (v6.addr.text.trim() === "") return fail("Address needed", v6.addr, "ip")
                    kv.push("ipv6.addresses", cidr(v6.addr.text, 64), "ipv6.gateway", v6.gw.text.trim())
                } else if (ip6 !== ip6Was) kv.push("ipv6.addresses", "", "ipv6.gateway", "")

                const ds = dns.text.split(/[\s,]+/).filter(a => a)
                if (ip4 !== "disabled") {
                    opt("ipv4.dns", ds.filter(a => !a.includes(":")).join(","))
                    kv.push("ipv4.ignore-auto-dns", ignoreDns ? "yes" : "no")
                }
                if (ip6 !== "disabled") {
                    opt("ipv6.dns", ds.filter(a => a.includes(":")).join(","))
                    kv.push("ipv6.ignore-auto-dns", ignoreDns ? "yes" : "no")
                }

                kv.push("connection.metered", metered ? "yes" : "unknown")
                if (allUsers !== allUsersWas || (!saved && !allUsers))
                    kv.push("connection.permissions", allUsers ? "" : "user:" + Quickshell.env("USER"))
                opt(hw + ".cloned-mac-address", mac)
                const mt = mtu.text.trim()
                if (mt !== "" && !/^\d+$/.test(mt)) return fail("Bad MTU", mtu, "adv")
                if (mt !== "" || saved) kv.push(hw + ".mtu", mt || "0")
                if (wifi) {
                    if (ssidHidden || saved) kv.push("802-11-wireless.hidden", ssidHidden ? "yes" : "no")
                    opt("802-11-wireless.band", band)
                }

                saver.forgetting = false
                saver.command = ["sh", "-c", `mode=$1 uuid=$2 name=$3 sec=$4 kind=$5
shift 5
if [ -z "$uuid" ]; then
  if [ "$kind" = ethernet ]; then
    out=$(nmcli connection add type ethernet con-name "$name" ifname "$name" "$@") || exit 1
  else
    out=$(nmcli connection add type wifi con-name "$name" ssid "$name" "$@") || exit 1
  fi
  uuid=$(printf '%s' "$out" | grep -oE '[0-9a-f]{8}-[0-9a-f-]{27}') || exit 1
else
  if [ "$kind" = wifi ]; then
    [ "$sec" = wpa-eap ] || nmcli connection modify uuid "$uuid" remove 802-1x >/dev/null 2>&1
    [ "$sec" = none ] && nmcli connection modify uuid "$uuid" remove 802-11-wireless-security >/dev/null 2>&1
  fi
  nmcli connection modify uuid "$uuid" "$@" || exit 1
fi
[ "$mode" = up ] && exec nmcli --wait 30 connection up uuid "$uuid" >/dev/null
exit 0`, "sh", up ? "up" : "save", uuid, name, sec, kind].concat(kv)
                saver.running = true
            }

            function forget() {
                if (busy || !saved) return
                error = ""
                saver.forgetting = true
                saver.command = ["nmcli", "connection", "delete", "uuid", uuid]
                saver.running = true
            }

            Process {
                id: loader
                stdout: StdioCollector {
                    onStreamFinished: {
                        const f = {}
                        for (const line of text.split("\n")) {
                            const i = line.indexOf(":")
                            if (i > 0) f[line.slice(0, i)] = line.slice(i + 1).replace(/\\(.)/g, "$1")
                        }
                        if (f["connection.uuid"]) editor.apply(f)
                    }
                }
            }

            Process {
                id: saver
                property bool forgetting: false
                stderr: StdioCollector { id: saveErr }
                onExited: code => {
                    if (code === 0) {
                        menu.setFailed(editor.name, "")
                        menu.editing = ""
                        return
                    }
                    editor.error = menu.lastLine(saveErr.text) || "Error " + code
                    // the profile might exist even if connecting failed
                    if (!saver.forgetting) editor.refresh()
                }
            }

            Item {
                width: parent.width
                height: 26

                Round {
                    id: back
                    glyph: ""
                    onClicked: menu.editing = ""
                }

                Label {
                    anchors.left: back.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: editor.wifi ? editor.name : "Ethernet"
                    elide: Text.ElideRight
                    font.pixelSize: 16
                    color: Theme.bright
                }
            }

            Chips {
                options: editor.wifi ? [["sec", "Security"], ["ip", "IP"], ["adv", "More"]] : [["ip", "IP"], ["adv", "More"]]
                id: tabs
            }

            Card {
                visible: editor.tab === "sec" && editor.wifi

                Chips {
                    options: [["none", "Open"], ["wpa-psk", "WPA2"], ["sae", "WPA3"], ["wpa-eap", "802.1X"]]
                    id: secChips
                }

                Field {
                    id: psk
                    visible: editor.sec === "wpa-psk" || editor.sec === "sae"
                    secret: true
                    placeholder: editor.saved ? "••••••••" : "Password"
                    onAccepted: editor.save(true)
                }

                Column {
                    visible: editor.sec === "wpa-eap"
                    width: parent.width
                    spacing: 8

                    Field {
                        id: identity
                        placeholder: "Username"
                        onAccepted: eapPass.grab()
                    }
                    Field {
                        id: eapPass
                        secret: true
                        placeholder: editor.saved ? "••••••••" : "Password"
                        onAccepted: editor.save(true)
                    }

                    Caption { text: "EAP" }
                    Chips {
                        options: [["peap", "PEAP"], ["ttls", "TTLS"]]
                        id: eapChips
                    }

                    Caption { text: "PHASE 2" }
                    Chips {
                        options: [["mschapv2", "MSCHAPv2"], ["pap", "PAP"], ["gtc", "GTC"], ["mschap", "MSCHAP"]]
                        id: phase2Chips
                    }

                    Label {
                        x: 4
                        text: (editor.more ? "" : "") + "  More"
                        font.pixelSize: 11
                        color: moreArea.containsMouse ? Theme.fg : Theme.dim
                        MouseArea { id: moreArea; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: editor.more = !editor.more }
                    }

                    Field {
                        id: anon
                        visible: editor.more
                        placeholder: "Anonymous identity"
                    }
                    Field {
                        id: ca
                        visible: editor.more
                        placeholder: "CA certificate"
                    }
                    Field {
                        id: domain
                        visible: editor.more
                        placeholder: "Domain"
                    }
                }
            }

            Card {
                visible: editor.tab === "ip"

                Caption { text: "IPV4" }
                Chips {
                    options: [["auto", "Auto"], ["manual", "Manual"], ["shared", "Shared"], ["disabled", "Off"]]
                    id: ip4Chips
                }
                Addr { id: v4; visible: editor.ip4 === "manual" }

                Caption { text: "IPV6" }
                Chips {
                    options: [["auto", "Auto"], ["manual", "Manual"], ["disabled", "Off"]]
                    id: ip6Chips
                }
                Addr { id: v6; visible: editor.ip6 === "manual" }

                Field { id: dns; placeholder: "DNS" }
                Toggle { id: ignoreDnsT; label: "Ignore auto DNS" }
            }

            Card {
                visible: editor.tab === "adv"

                Toggle { id: autoT; label: "Auto-connect" }
                Toggle { id: allUsersT; label: "All users" }
                Toggle { id: meteredT; label: "Metered" }
                Toggle { id: hiddenT; visible: editor.wifi; label: "Hidden" }

                Caption { visible: editor.wifi; text: "BAND" }
                Chips {
                    visible: editor.wifi
                    options: [["", "Auto"], ["bg", "2.4 GHz"], ["a", "5 GHz"]]
                    id: bandChips
                }

                Caption { text: "MAC" }
                Chips {
                    options: [["", "Default"], ["permanent", "Real"], ["random", "Random"], ["stable", "Stable"]]
                    id: macChips
                }

                Field { id: mtu; placeholder: "MTU" }
            }

            Oops { text: editor.error }

            Item {
                width: parent.width
                height: 32
                opacity: editor.busy ? 0.6 : 1

                Button {
                    visible: editor.saved
                    anchors.left: parent.left
                    label: "Forget"
                    onPressed: editor.forget()
                }

                Row {
                    anchors.right: parent.right
                    spacing: 6

                    Button {
                        label: "Save"
                        onPressed: editor.save(false)
                    }
                    Button {
                        primary: true
                        label: saver.running && !saver.forgetting ? "…" : "Connect"
                        onPressed: editor.save(true)
                    }
                }
            }
        }
    }

    component Bluetooth: Column {
        id: menu

        property bool open: false

        spacing: 12

        readonly property var adapter: Bluetooth.defaultAdapter
        readonly property bool on: !!adapter && adapter.enabled
        readonly property var all: adapter ? adapter.devices.values : []
        readonly property var paired: all.filter(d => d.paired || d.connected)
            .sort((a, b) => (b.connected - a.connected) || label(a).localeCompare(label(b)))
        readonly property var nearby: all.filter(d => !d.paired && !d.connected && d.name && d.name !== d.address.replace(/:/g, "-"))
            .sort((a, b) => label(a).localeCompare(label(b)))
        property var pending: ({})
        // rows get rebuilt when a device moves lists, this lets the new one still do the spin
        property var trying: ({})
        function mark(d) { trying[d.address] = Date.now() }
        function fresh(d) {
            const t = trying[d.address] ?? 0
            delete trying[d.address]
            return Date.now() - t < 4000
        }

        Binding {
            target: menu.adapter
            property: "discovering"
            value: true
            when: menu.open && menu.on
            restoreMode: Binding.RestoreBindingOrValue
        }

        function label(d) {
            return d.name || d.deviceName || d.address
        }

        function glyph(d) {
            const i = (d.icon || "").toLowerCase()
            if (i.includes("headset") || i.includes("headphone")) return "󰋋"
            if (i.includes("audio") || i.includes("speaker")) return "󰓃"
            if (i.includes("keyboard")) return "󰌌"
            if (i.includes("mouse")) return "󰍽"
            if (i.includes("phone")) return "󰄜"
            if (i.includes("gaming") || i.includes("joystick")) return "󰊴"
            if (i.includes("computer")) return "󰌢"
            return "󰂯"
        }

        function status(d) {
            if (d.pairing) return "Pairing"
            if (d.state === BluetoothDeviceState.Connecting) return "Connecting"
            if (d.state === BluetoothDeviceState.Disconnecting) return "Disconnecting"
            return ""
        }

        function pick(d) {
            if (d.connected) d.disconnect()
            else if (d.paired) d.connect()
            else {
                pending = Object.assign({}, pending, { [d.address]: true })
                d.trusted = true
                d.pair()
            }
        }

        Header {
            title: "Bluetooth"
            Switch {
                checked: menu.on
                onToggled: if (menu.adapter) menu.adapter.enabled = !menu.adapter.enabled
            }
        }

        Group {
            maxHeight: 166
            empty: !menu.adapter ? "No adapter" : !menu.on ? "Off" : "No devices"

            Repeater {
                model: menu.on ? menu.paired : []
                DeviceRow { owner: menu }
            }
        }

        Group {
            maxHeight: 130
            visible: menu.on
            empty: "Searching…"

            Repeater {
                model: menu.on ? menu.nearby : []
                DeviceRow { owner: menu }
            }
        }
    }

    component DeviceRow: Entry {
        id: dr
        property var owner
        required property var modelData
        glyph: owner.glyph(modelData)
        label: owner.label(modelData)
        sub: owner.status(modelData)
        height: 40
        trailing: modelData.batteryAvailable ? Math.round((modelData.battery > 1 ? modelData.battery : modelData.battery * 100)) + "%" : ""
        active: modelData.connected
        busy: modelData.pairing || modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
        onClicked: owner.pick(modelData)
        onRightClicked: if (modelData.paired) modelData.forget()

        Component.onCompleted: {
            if (busy) owner.mark(modelData)
            else if (modelData.connected && owner.fresh(modelData)) cheer()
        }
        Connections {
            target: dr
            function onBusyChanged() { if (dr.busy) dr.owner.mark(dr.modelData) }
        }
        Connections {
            target: dr.modelData
            function onPairedChanged() {
                if (dr.modelData.paired && owner.pending[dr.modelData.address]) {
                    owner.pending = Object.assign({}, owner.pending, { [dr.modelData.address]: false })
                    dr.modelData.connect()
                }
            }
        }
    }

    component Audio: Grid {
        id: menu

        property bool open: false
        signal run(string cmd)
        signal done()

        readonly property real colW: columns === 2 ? (width - columnSpacing) / 2 : width
        columns: width >= 600 ? 2 : 1
        columnSpacing: 22
        rowSpacing: 12

        readonly property var sink: Pipewire.defaultAudioSink
        readonly property var source: Pipewire.defaultAudioSource
        readonly property var devices: Pipewire.nodes.values.filter(n => n.audio && !n.isStream)
        readonly property var outputs: devices.filter(n => n.isSink)
        readonly property var inputs: devices.filter(n => !n.isSink && !(n.name || "").endsWith(".monitor"))

        PwObjectTracker { objects: menu.open ? menu.devices : [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }

        function name(n) {
            return n.nickname || n.description || n.name
        }

        function volGlyph(v) {
            return v > 0.66 ? "󰕾" : v > 0.33 ? "󰖀" : "󰕿"
        }

        Column {
            width: menu.colW
            spacing: 12

            Header { title: "Sound" }

            Level {
                node: menu.sink
                device: menu.sink ? menu.name(menu.sink) : ""
                title: "Output"
                glyph: menu.volGlyph(menu.sink && menu.sink.audio ? menu.sink.audio.volume : 0)
                mutedGlyph: "󰝟"
            }

            Level {
                node: menu.source
                device: menu.source ? menu.name(menu.source) : ""
                title: "Microphone"
                glyph: "󰍬"
                mutedGlyph: "󰍭"
            }
        }

        Column {
            width: menu.colW
            spacing: 12

            Group {
                title: "Output device"
                maxHeight: 170
                empty: "No outputs"
                Repeater {
                    model: menu.outputs
                    Entry {
                        required property var modelData
                        glyph: "󰓃"
                        label: menu.name(modelData)
                        active: menu.sink === modelData
                        trailing: active ? "" : ""
                        onClicked: Pipewire.preferredDefaultAudioSink = modelData
                    }
                }
            }

            Group {
                title: "Input device"
                maxHeight: 130
                visible: menu.inputs.length > 0
                Repeater {
                    model: menu.inputs
                    Entry {
                        required property var modelData
                        glyph: "󰍬"
                        label: menu.name(modelData)
                        active: menu.source === modelData
                        trailing: active ? "" : ""
                        onClicked: Pipewire.preferredDefaultAudioSource = modelData
                    }
                }
            }

            Group {
                Entry {
                    glyph: "󰕾"
                    label: "Mixer"
                    sub: "Per-app volume"
                    onClicked: { menu.run("pypr toggle music 2>/dev/null || pavucontrol"); menu.done() }
                }
            }
        }
    }

    component Level: Column {
        id: lv
        property var node
        property string title
        property string glyph
        property string mutedGlyph
        property string device
        readonly property bool ok: !!node && !!node.audio
        readonly property real vol: ok ? node.audio.volume : 0
        readonly property bool muted: ok && node.audio.muted
        width: parent.width
        spacing: 6

        Item {
            width: parent.width
            height: 16
            Label {
                x: 4
                anchors.verticalCenter: parent.verticalCenter
                text: lv.title.toUpperCase()
                font.pixelSize: 10
                font.letterSpacing: 1.6
                color: Theme.dim
            }
            Label {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.left: parent.horizontalCenter
                horizontalAlignment: Text.AlignRight
                anchors.verticalCenter: parent.verticalCenter
                text: lv.ok ? lv.device : "None"
                elide: Text.ElideRight
                font.pixelSize: 10
                color: Theme.dim
            }
        }

        Tile {
            width: parent.width
            height: 44
            opacity: lv.ok ? 1 : 0.45

            Label {
                id: muteBtn
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                text: lv.muted ? lv.mutedGlyph : lv.glyph
                font.pixelSize: 16
                color: lv.muted ? Theme.dim : muteArea.containsMouse ? Theme.accent : Theme.bright
                Hover {
                    id: muteArea
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: if (lv.ok) lv.node.audio.muted = !lv.node.audio.muted
                }
            }

            Slider {
                anchors.left: muteBtn.right
                anchors.leftMargin: 12
                anchors.right: pct.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                value: lv.vol
                dimmed: lv.muted
                step: 0.02
                onMoved: v => { if (lv.ok) { lv.node.audio.volume = v; if (v > 0) lv.node.audio.muted = false } }
            }

            Label {
                id: pct
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                horizontalAlignment: Text.AlignRight
                text: Math.round(lv.vol * 100) + "%"
                font.pixelSize: 12
                color: Theme.fg
            }
        }
    }

    // lock and suspend are instant, the rest need a second press
    component Session: Column {
        id: menu

        property bool open: false
        signal run(string cmd)
        signal done()

        spacing: 12

        property bool standalone: false
        property string armed: ""
        property string uptime: ""
        property real light: 1
        property bool hasLight: false
        onOpenChanged: { armed = ""; if (open) { up.running = true; probe.running = true } }

        Process {
            id: probe
            command: ["sh", "-c", "brightnessctl -m 2>/dev/null | head -n1 | cut -d, -f4 | tr -d %"]
            stdout: StdioCollector {
                onStreamFinished: {
                    const v = parseInt(text)
                    menu.hasLight = !isNaN(v)
                    if (menu.hasLight) menu.light = v / 100
                }
            }
        }
        Timer {
            id: apply
            interval: 50
            onTriggered: Quickshell.execDetached(["brightnessctl", "-q", "set", Math.max(1, Math.round(menu.light * 100)) + "%"])
        }
        Watched {
            id: dndFile
            path: Quickshell.env("XDG_RUNTIME_DIR") + "/home-dnd"
        }
        readonly property bool dnd: dndFile.text().trim() === "1"

        Process {
            id: up
            command: ["uptime", "-p"]
            stdout: StdioCollector { onStreamFinished: menu.uptime = text.trim().replace(/^up /, "") }
        }
        Timer { id: disarm; interval: 3000; onTriggered: menu.armed = "" }

        readonly property var actions: [
            { id: "lock", glyph: "", label: "Lock" },
            { id: "suspend", glyph: "󰒲", label: "Suspend" },
            { id: "logout", glyph: "󰍃", label: "Log out" },
            { id: "reboot", glyph: "󰜉", label: "Reboot" },
            { id: "poweroff", glyph: "󰐥", label: "Shut down" }
        ]

        function press(a) {
            if (Power.confirm(a.id) && armed !== a.id) { armed = a.id; disarm.restart(); return }
            armed = ""
            done()
            Power.act(a.id)
        }

        Header {
            title: "Session"
            note: menu.uptime !== "" ? "Up " + menu.uptime : ""
        }

        Row {
            id: grid
            spacing: 6
            readonly property real cell: (menu.width - spacing * (menu.actions.length - 1)) / menu.actions.length

            Repeater {
                model: menu.actions

                Rectangle {
                    id: btn
                    required property var modelData
                    readonly property bool armed: menu.armed === modelData.id
                    width: grid.cell
                    height: grid.cell + 14
                    radius: Math.min(Theme.rounding, 12)
                    color: armed ? Theme.alpha(Theme.warn, 0.4)
                        : Theme.alpha(Theme.fg, area.containsMouse ? 0.12 : 0.055)
                    scale: area.pressed ? 0.95 : 1
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                    Behavior on scale { NumberAnimation { duration: Theme.ms(120) } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 6
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: btn.modelData.glyph
                            font.pixelSize: 20
                            color: btn.armed ? Theme.bright : area.containsMouse ? Theme.accent : Theme.fg
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: btn.armed ? "Again" : btn.modelData.label
                            font.pixelSize: 10
                            color: btn.armed ? Theme.bright : Theme.dim
                        }
                    }

                    Hover {
                        id: area
                        anchors.fill: parent
                        onClicked: menu.press(btn.modelData)
                    }
                }
            }
        }

        Tile {
            id: bat
            readonly property var dev: Power.battery
            readonly property bool present: Power.hasBattery
            readonly property real charge: Power.charge
            readonly property bool charging: Power.charging
            readonly property bool full: Power.full
            readonly property bool low: !charging && !full && charge < 0.2
            readonly property real secs: !present ? 0 : charging ? dev.timeToFull : dev.timeToEmpty

            function span(s) {
                const m = Math.round(s / 60)
                return m < 60 ? m + "m" : Math.floor(m / 60) + "h " + (m % 60) + "m"
            }

            visible: present
            width: parent.width
            height: 44

            Label {
                id: batGlyph
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                text: bat.charging || bat.full ? "󰂄" : ["󰁻", "󰁼", "󰁾", "󰂀", "󰂂", "󰁹"][Math.min(5, Math.floor(bat.charge * 6))]
                font.pixelSize: 16
                color: bat.low ? Theme.warn : Theme.bright
            }

            Rectangle {
                anchors.left: batGlyph.right
                anchors.leftMargin: 12
                anchors.right: batTime.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                height: 4
                radius: 2
                color: Theme.alpha(Theme.fg, 0.16)

                Rectangle {
                    width: Math.max(parent.height, parent.width * bat.charge)
                    height: parent.height
                    radius: parent.radius
                    color: bat.low ? Theme.warn : Theme.ok
                    Behavior on width { NumberAnimation { duration: Theme.move; easing.type: Easing.OutCubic } }
                }
            }

            Label {
                id: batTime
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(bat.charge * 100) + "%" + (bat.full || bat.secs <= 0 ? "" : "  ·  " + bat.span(bat.secs) + (bat.charging ? " to full" : " left"))
                font.pixelSize: 12
                color: Theme.fg
            }
        }

        Tile {
            visible: menu.hasLight
            width: parent.width
            height: 44

            Label {
                id: sun
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 18
                text: "󰃠"
                font.pixelSize: 16
                color: Theme.bright
            }
            Slider {
                anchors.left: sun.right
                anchors.leftMargin: 12
                anchors.right: sunPct.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                value: menu.light
                onMoved: v => { menu.light = Math.max(0.01, v); apply.restart() }
            }
            Label {
                id: sunPct
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 32
                horizontalAlignment: Text.AlignRight
                text: Math.round(menu.light * 100) + "%"
                font.pixelSize: 12
                color: Theme.fg
            }
        }

        Tile {
            visible: !menu.standalone
            width: parent.width
            height: 44

            Label {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: (menu.dnd ? "󰂛" : "󰂚") + "  Do not disturb"
                font.pixelSize: 12
                color: menu.dnd ? Theme.accent2 : Theme.fg
            }
            Switch {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                checked: menu.dnd
                onToggled: menu.run("~/.config/hypr/utilities/shells.sh home toggleDnd")
            }
        }
    }

    component Tray: Column {
        id: menu

        property bool open: false
        property var item: null
        signal run(string cmd)
        signal done()

        spacing: 10

        property var stack: []
        readonly property var current: stack.length > 0 ? stack[stack.length - 1] : (item ? item.menu : null)
        onItemChanged: stack = []
        onOpenChanged: if (!open) stack = []

        QsMenuOpener {
            id: opener
            menu: menu.current
        }

        Header {
            icon: menu.item ? menu.item.icon : ""
            title: menu.item ? (menu.item.tooltipTitle || menu.item.title || menu.item.id) : ""
        }

        Group {
            maxHeight: 380
            empty: "No menu"

            Entry {
                visible: menu.stack.length > 0
                glyph: ""
                label: "Back"
                onClicked: menu.stack = menu.stack.slice(0, -1)
            }

            Repeater {
                model: opener.children

                Item {
                    id: entry
                    required property var modelData
                    width: parent.width
                    height: modelData.isSeparator ? 9 : row.height

                    Rectangle {
                        visible: entry.modelData.isSeparator
                        anchors.centerIn: parent
                        width: parent.width - 20
                        height: 1
                        color: Theme.alpha(Theme.fg, 0.08)
                    }

                    Entry {
                        id: row
                        visible: !entry.modelData.isSeparator
                        readonly property bool check: entry.modelData.buttonType !== QsMenuButtonType.None
                        readonly property bool checked: entry.modelData.checkState === Qt.Checked
                        // some apps put underscores in labels for accelerators, strip them
                        label: (entry.modelData.text || "").replace(/_(?=[^_])/g, "")
                        iconSource: entry.modelData.icon || ""
                        glyph: check ? (checked ? (entry.modelData.buttonType === QsMenuButtonType.RadioButton ? "" : "") : (entry.modelData.buttonType === QsMenuButtonType.RadioButton ? "" : "")) : ""
                        trailing: entry.modelData.hasChildren ? "" : ""
                        enabledRow: entry.modelData.enabled
                        onClicked: {
                            if (entry.modelData.hasChildren) {
                                menu.stack = menu.stack.concat([entry.modelData])
                            } else {
                                entry.modelData.triggered()
                                menu.done()
                            }
                        }
                    }
                }
            }
        }
    }
}

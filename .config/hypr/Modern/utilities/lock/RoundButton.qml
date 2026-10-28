import QtQuick
import "../common"

Item {
    id: b

    property string glyph
    property real u: 1
    property real size: 44 * u
    property color tint: "#ffffff"
    property bool filled: false
    property bool armed: false
    signal clicked()

    width: size
    height: size
    scale: area.pressed ? 0.9 : area.containsMouse ? 1.06 : 1
    Behavior on scale { Settle { duration: Theme.ms(220) } }

    Card {
        anchors.fill: parent
        radius: Lock.corner(b.size, b.u)
        opacity: b.filled || b.armed ? 0 : 1
    }
    Rectangle {
        anchors.fill: parent
        radius: Lock.corner(b.size, b.u)
        color: Theme.soft(b.armed ? Theme.warn : Theme.accent, area.containsMouse)
        opacity: b.filled || b.armed ? 1 : area.containsMouse ? 0.12 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.ms(160) } }
        Behavior on color { ColorAnimation { duration: Theme.ms(160) } }
    }

    Label {
        anchors.centerIn: parent
        text: b.glyph
        font.pixelSize: b.size * 0.4
        color: b.filled || b.armed ? Theme.on(b.armed ? Theme.warn : Theme.accent) : b.tint
        Behavior on color { ColorAnimation { duration: Theme.ms(160) } }
    }

    Hover {
        id: area
        anchors.fill: parent
        onClicked: b.clicked()
    }
}

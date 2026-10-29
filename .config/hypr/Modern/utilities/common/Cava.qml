pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// one cava for every visualizer, each monitor's bar used to spawn its own
Singleton {
    id: root

    property int users: 0
    readonly property int bars: 36
    property var levels: []

    Process {
        running: root.users > 0
        command: ["cava", "-p", Quickshell.shellPath("music/cava.conf")]
        stdout: SplitParser {
            onRead: line => {
                const parts = line.split(";")
                const out = new Array(root.bars)
                for (let i = 0; i < root.bars; i++) out[i] = Math.max(0, Math.min(1, (parseInt(parts[i]) || 0) / 1000))
                root.levels = out
            }
        }
        onRunningChanged: if (!running) root.levels = []
    }
}

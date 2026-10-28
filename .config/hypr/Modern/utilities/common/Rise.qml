import QtQuick

// fade + lil popin for stuff loading in, staggered by index. same curve and pace as hyprland's window-in.
// plays on load, when target shows up (loaders), and whenever replay changes
SequentialAnimation {
    id: rise
    property Item target
    property int index
    property int replay
    function play() { if (target) restart() }
    Component.onCompleted: play()
    onTargetChanged: play()
    onReplayChanged: play()

    PropertyAction { target: rise.target; property: "opacity"; value: 0 }
    PropertyAction { target: rise.target; property: "scale"; value: 0.97 }
    PauseAnimation { duration: Theme.ms(Math.min(rise.index, 8) * 30) }
    ParallelAnimation {
        Settle { target: rise.target; property: "opacity"; to: 1; duration: Theme.move }
        Settle { target: rise.target; property: "scale"; to: 1; duration: Theme.move }
    }
}

/*
 * Pomodoro Timer Plasmoid
 * Author: David A
 * License: GNU General Public License v2.0
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // ── config bindings ────────────────────────────────────────────────────
    property string presetsJson:        Plasmoid.configuration.presetsJson
    property int    defaultPresetIndex: Plasmoid.configuration.defaultPresetIndex

    // ── session state ──────────────────────────────────────────────────────
    property var  sessions:          []
    property int  currentIndex:      0
    property int  timeLeft:          0
    property bool running:           false
    property bool finished:          false
    property var  startTime:         null
    property var  endTime:           null
    // track which preset is currently loaded (-1 = none yet)
    property int  loadedPresetIndex: -1

    // ── derived ────────────────────────────────────────────────────────────
    property bool currentIsWork: sessions.length > 0
                                 && sessions[currentIndex] !== undefined
                                 && sessions[currentIndex].type === "work"

    property int elapsedInSession: (sessions.length > 0 && sessions[currentIndex] !== undefined)
                                   ? sessions[currentIndex].duration - timeLeft : 0

    property real fillFraction: (sessions.length > 0
                                 && sessions[currentIndex] !== undefined
                                 && sessions[currentIndex].duration > 0)
                                ? Math.min(1.0, elapsedInSession / sessions[currentIndex].duration) : 0.0

    // ── built-in presets ───────────────────────────────────────────────────
    function builtinPresets() {
        return [
            { name: "25+5",  sessions: buildRepeating(25, 5,  4) },
            { name: "50+10", sessions: buildRepeating(50, 10, 3) }
        ]
    }

    function buildRepeating(workMin, breakMin, reps) {
        var arr = []
        for (var i = 0; i < reps; i++) {
            arr.push({ type: "work",  duration: workMin  * 60 })
            arr.push({ type: "break", duration: breakMin * 60 })
        }
        arr.push({ type: "work", duration: workMin * 60 })
        return arr
    }

    function allPresets() {
        var user = []
        try { user = JSON.parse(root.presetsJson) } catch(e) {}
        return builtinPresets().concat(user)
    }

    // ── session management ─────────────────────────────────────────────────
    function loadSessions(arr, presetIdx) {
        sessions          = arr.slice()
        currentIndex      = 0
        timeLeft          = arr.length > 0 ? arr[0].duration : 0
        running           = false
        finished          = false
        startTime         = null
        endTime           = null
        loadedPresetIndex = (presetIdx !== undefined) ? presetIdx : -1
        Qt.callLater(function() { timelineFlickable.centerOnCurrent() })
    }

    function loadDefault() {
        var presets = allPresets()
        var idx     = defaultPresetIndex
        if (idx >= 0 && idx < presets.length)
            loadSessions(presets[idx].sessions, idx)
        else
            loadSessions(builtinPresets()[0].sessions, 0)
    }

    function startTimer() {
        if (sessions.length === 0) return
        startTime = new Date()
        var total = 0
        for (var i = 0; i < sessions.length; i++) total += sessions[i].duration
        endTime  = new Date(startTime.getTime() + total * 1000)
        running  = true
        finished = false
    }

    function skipBlock() {
        if (finished) return
        if (currentIndex + 1 < sessions.length) {
            currentIndex++
            timeLeft = sessions[currentIndex].duration
        } else {
            running  = false
            finished = true
            timeLeft = 0
        }
        Qt.callLater(function() { timelineFlickable.centerOnCurrent() })
    }

    Component.onCompleted: loadDefault()

    // Only reload if timer isn't running — don't clobber an active session
    onDefaultPresetIndexChanged: { if (!running && !finished) loadDefault() }
    onPresetsJsonChanged:        { if (!running && !finished) loadDefault() }

    // (centering is handled inside fullRepresentation via Connections)

    // ── ticker ─────────────────────────────────────────────────────────────
    Timer {
        id: ticker
        interval: 1000
        repeat:   true
        running:  root.running
        onTriggered: {
            if (root.timeLeft > 1) {
                root.timeLeft--
            } else {
                if (root.currentIndex + 1 < root.sessions.length) {
                    root.currentIndex++
                    root.timeLeft = root.sessions[root.currentIndex].duration
                } else {
                    root.running  = false
                    root.finished = true
                    root.timeLeft = 0
                }
            }
        }
    }

    // ── helpers ────────────────────────────────────────────────────────────
    function fmt(secs) {
        var m = Math.floor(secs / 60), s = secs % 60
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
    }
    function fmtClock(date) {
        if (!date) return "--:--"
        var h = date.getHours(), m = date.getMinutes()
        return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m
    }
    function blockWidth(dur) { return Math.max(52, dur / 60 * 3.2) }
    function blockX(idx) {
        var x = 0
        for (var i = 0; i < idx; i++)
            x += blockWidth(sessions[i] ? sessions[i].duration : 0) + 4
        return x
    }

    // ══════════════════════════════════════════════════════════════════════
    // COMPACT (taskbar)
    // ══════════════════════════════════════════════════════════════════════
    compactRepresentation: Item {
        Layout.minimumWidth:  compactRow.implicitWidth + 16
        Layout.preferredWidth: compactRow.implicitWidth + 16
        Layout.fillHeight:    true

        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: parent.width * root.fillFraction
            color: root.currentIsWork ? Qt.rgba(1, 0.38, 0.22, 0.30)
                                      : Qt.rgba(0.22, 0.85, 0.50, 0.25)
            Behavior on width { NumberAnimation { duration: 900; easing.type: Easing.Linear } }
        }

        RowLayout {
            id: compactRow
            anchors.centerIn: parent
            spacing: 5

            Kirigami.Icon {
                source: root.finished ? "dialog-ok-apply"
                      : root.running  ? "media-playback-start" : "clock"
                Layout.preferredWidth:  Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                color: root.finished      ? "#5fffaa"
                     : root.currentIsWork ? "#ff6644" : "#44cc88"
            }

            Text {
                text:           root.finished ? "Done!" : root.fmt(root.timeLeft)
                font.pixelSize: 13
                font.family:    "monospace"
                font.weight:    Font.Medium
                color:          Kirigami.Theme.textColor
                Layout.minimumWidth: 44
            }
        }

        MouseArea { anchors.fill: parent; onClicked: root.expanded = !root.expanded }
    }

    // ══════════════════════════════════════════════════════════════════════
    // FULL POPUP
    // ══════════════════════════════════════════════════════════════════════
    fullRepresentation: Item {
        implicitWidth:  440
        implicitHeight: mainCol.implicitHeight + 28

        Column {
            id: mainCol
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.margins: 14
            spacing: 12

            // ── title ─────────────────────────────────────────────────────
            Text {
                text: "🍅  Pomodoro Timer"
                font.pixelSize: 16; font.weight: Font.Bold
                color: Kirigami.Theme.textColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // ── big countdown ─────────────────────────────────────────────
            Rectangle {
                width: parent.width; height: 76; radius: 10
                color: root.finished      ? Qt.rgba(0.2, 1, 0.5, 0.12)
                     : root.currentIsWork ? Qt.rgba(1, 0.38, 0.22, 0.14)
                                          : Qt.rgba(0.22, 0.85, 0.50, 0.12)
                Text {
                    anchors.centerIn: parent
                    text: root.finished ? "✓  All done!" : root.fmt(root.timeLeft)
                    font.pixelSize: 40; font.family: "monospace"; font.weight: Font.Bold
                    color: root.finished      ? "#5fffaa"
                         : root.currentIsWork ? "#ff6644" : "#44cc88"
                }
            }

            Text {
                text: root.finished      ? "Session complete!"
                    : root.currentIsWork ? "🍅  Working — stay focused!"
                                        : "☕  Break time — relax!"
                font.pixelSize: 11; color: Kirigami.Theme.disabledTextColor
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // ── CENTERED TIMELINE ─────────────────────────────────────────
            // Half-viewport padding on each side lets block 0 and last block
            // be truly centered, not just flush-left/right.
            Item {
                id: timelineContainer
                width: parent.width; height: 60; clip: true

                Flickable {
                    id: timelineFlickable
                    anchors.fill: parent
                    contentWidth:  timelineContainer.width / 2 + timelineRow.implicitWidth + timelineContainer.width / 2
                    contentHeight: 60
                    flickableDirection: Flickable.HorizontalFlick
                    interactive: false

                    function centerOnCurrent() {
                        if (root.sessions.length === 0) return
                        var dur = root.sessions[root.currentIndex]
                                  ? root.sessions[root.currentIndex].duration : 0
                        var bx  = root.blockX(root.currentIndex)
                        var bw  = root.blockWidth(dur)
                        // offset by left padding (half viewport)
                        var cx  = timelineContainer.width / 2 + bx + bw / 2
                        contentX = cx - timelineContainer.width / 2
                    }

                    Behavior on contentX { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        // Left spacer — half viewport width
                        Item { width: timelineContainer.width / 2; height: 60 }

                        Row {
                            id: timelineRow
                            spacing: 4

                            Repeater {
                                model: root.sessions.length
                                delegate: Item {
                                    property bool isCurrent: index === root.currentIndex
                                    property bool isPast:    index  < root.currentIndex
                                    property bool isWork:    root.sessions[index] !== undefined
                                                             && root.sessions[index].type === "work"
                                    property int  dur:       root.sessions[index] !== undefined
                                                             ? root.sessions[index].duration : 0
                                    width:  root.blockWidth(dur)
                                    height: 60

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width:  parent.width
                                        height: isCurrent ? 52 : 38; radius: 7
                                        color:  isPast
                                                ? Qt.rgba(0.5, 0.5, 0.5, 0.13)
                                                : isCurrent
                                                    ? (isWork ? Qt.rgba(1, 0.38, 0.22, 0.52)
                                                              : Qt.rgba(0.22, 0.85, 0.50, 0.44))
                                                    : (isWork ? Qt.rgba(1, 0.38, 0.22, 0.18)
                                                              : Qt.rgba(0.22, 0.85, 0.50, 0.15))
                                        border.color: isCurrent ? (isWork ? "#ff6644" : "#44cc88") : "transparent"
                                        border.width: isCurrent ? 2 : 0
                                        Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

                                        Column {
                                            anchors.centerIn: parent; spacing: 2
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: isWork ? "🍅" : "☕"
                                                font.pixelSize: isCurrent ? 16 : 12
                                            }
                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: Math.round(dur / 60) + "m"
                                                font.pixelSize: 8; font.family: "monospace"
                                                color: Kirigami.Theme.disabledTextColor
                                            }
                                        }
                                    }
                                }
                            }
                        } // end timelineRow

                        // Right spacer — half viewport width
                        Item { width: timelineContainer.width / 2; height: 60 }
                    } // end outer Row

                    Component.onCompleted: Qt.callLater(centerOnCurrent)

                    // Watch currentIndex changes from inside the Flickable's scope
                    // so timelineFlickable is always in scope
                    Connections {
                        target: root
                        function onCurrentIndexChanged() {
                            Qt.callLater(timelineFlickable.centerOnCurrent)
                        }
                        function onSessionsChanged() {
                            Qt.callLater(timelineFlickable.centerOnCurrent)
                        }
                    }
                }
            }

            // ── stats row ─────────────────────────────────────────────────
            Row {
                spacing: 20; anchors.horizontalCenter: parent.horizontalCenter
                Repeater {
                    model: [
                        { label: "Start",       val: root.fmtClock(root.startTime) },
                        { label: "End",         val: root.fmtClock(root.endTime)   },
                        { label: "Blocks left", val: root.sessions.length > 0
                                                     ? String(root.sessions.length - root.currentIndex - (root.finished ? 0 : 1))
                                                     : "0" }
                    ]
                    delegate: Column {
                        spacing: 2
                        Text { text: modelData.label; font.pixelSize: 10; color: Kirigami.Theme.disabledTextColor; anchors.horizontalCenter: parent.horizontalCenter }
                        Text { text: modelData.val;   font.pixelSize: 15; font.family: "monospace"; color: Kirigami.Theme.textColor; anchors.horizontalCenter: parent.horizontalCenter }
                    }
                }
            }

            // ── controls ──────────────────────────────────────────────────
            Row {
                spacing: 8; anchors.horizontalCenter: parent.horizontalCenter

                PlasmaComponents.Button {
                    text: root.finished   ? "Restart"
                        : !root.startTime ? "Start"
                        : root.running    ? "Pause" : "Resume"
                    onClicked: {
                        if (root.finished || !root.startTime) {
                            // restart with whatever is currently loaded, don't re-load default
                            if (root.finished) root.loadSessions(root.sessions.slice(), root.loadedPresetIndex)
                            root.startTimer()
                        } else if (root.running) {
                            root.running = false
                        } else {
                            root.running = true
                        }
                    }
                }

                PlasmaComponents.Button {
                    text: "Skip ⏭"
                    enabled: !root.finished && root.startTime !== null
                    onClicked: root.skipBlock()
                }

                PlasmaComponents.Button {
                    text: "Reset"
                    onClicked: root.loadDefault()
                }
            }

            // ── preset selector + add button ──────────────────────────────
            Flow {
                width: parent.width; spacing: 6

                Text {
                    text: "Preset:"; font.pixelSize: 11
                    color: Kirigami.Theme.disabledTextColor
                    height: 28; verticalAlignment: Text.AlignVCenter
                }

                Repeater {
                    model: root.allPresets().length
                    delegate: PlasmaComponents.Button {
                        // capture index at creation time to avoid closure issue
                        property int myIndex: index
                        property var myPreset: root.allPresets()[myIndex]
                        text:        myPreset ? myPreset.name : ""
                        highlighted: myIndex === root.loadedPresetIndex
                        onClicked: {
                            root.loadSessions(myPreset.sessions, myIndex)
                        }
                    }
                }

                // Plain "+" — no icon, no extra label
                PlasmaComponents.Button {
                    text: "+"
                    implicitWidth: 28
                    onClicked: {
                        root.expanded = false
                        Plasmoid.internalAction("configure").trigger()
                    }
                }
            }

            Item { height: 2; width: 1 }
        }
    }
}

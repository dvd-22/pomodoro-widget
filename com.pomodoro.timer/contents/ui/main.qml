/*
 * Pomodoro Timer Plasmoid
 * Author: David A
 * License: GNU General Public License v2.0
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.notification
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
    property int  focusMinutes:      60
    property int  longBreakMinutes:  15
    property bool suppressAutoApply: false
    property string appIconPath: Qt.resolvedUrl("../../logo.png")

    Notification {
        id: blockTransitionNotification
        componentName: "plasma_workspace"
        eventId: "notification"
        iconName: "com.pomodoro.timer"
        title: "Pomodoro Timer"
        text: ""
    }

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
            { name: "25+5",  workMin: 25, breakMin: 5 },
            { name: "50+10", workMin: 50, breakMin: 10 }
        ]
    }

    function normalizePreset(p) {
        if (!p) return null

        if (p.workMin !== undefined && p.breakMin !== undefined) {
            return {
                name: p.name ? String(p.name) : (Math.round(p.workMin) + "+" + Math.round(p.breakMin)),
                workMin: Math.max(1, Math.round(p.workMin)),
                breakMin: Math.max(1, Math.round(p.breakMin))
            }
        }

        if (p.sessions && p.sessions.length > 0) {
            var workMin = 25
            var breakMin = 5
            for (var i = 0; i < p.sessions.length; i++) {
                if (p.sessions[i].type === "work") {
                    workMin = Math.max(1, Math.round(p.sessions[i].duration / 60))
                    break
                }
            }
            for (var j = 0; j < p.sessions.length; j++) {
                if (p.sessions[j].type === "break") {
                    breakMin = Math.max(1, Math.round(p.sessions[j].duration / 60))
                    break
                }
            }
            return {
                name: p.name ? String(p.name) : (workMin + "+" + breakMin),
                workMin: workMin,
                breakMin: breakMin
            }
        }

        return null
    }

    function allPresets() {
        var userRaw = []
        try { userRaw = JSON.parse(root.presetsJson) } catch(e) {}
        var user = []
        for (var i = 0; i < userRaw.length; i++) {
            var p = normalizePreset(userRaw[i])
            if (p) user.push(p)
        }
        return builtinPresets().concat(user)
    }

    function suggestedLongBreakMinutes(totalMin) {
        if (totalMin >= 240) return 30
        if (totalMin >= 180) return 20
        return 15
    }

    // Build alternating work/break blocks from a total duration.
    // Every 4th break is a long break.
    // If remaining time can't fit a full break, fold it into the last work block.
    function buildAlternatingByTotal(workMin, breakMin, totalMin, longBreakMin) {
        var workSec = Math.max(1, workMin) * 60
        var shortBreakSec = Math.max(1, breakMin) * 60
        var longBreakSec = Math.max(1, longBreakMin) * 60
        var remaining = Math.max(1, totalMin) * 60
        var workBlocksDone = 0
        var arr = []
        var adjustedTail = false

        while (remaining > 0) {
            var workDur = Math.min(workSec, remaining)
            arr.push({ type: "work", duration: workDur })
            workBlocksDone++
            remaining -= workDur
            if (remaining <= 0)
                break

            var thisBreakSec = shortBreakSec
            if (workBlocksDone % 4 === 0)
                thisBreakSec = longBreakSec

            if (remaining >= thisBreakSec) {
                arr.push({ type: "break", duration: thisBreakSec })
                remaining -= thisBreakSec
            } else {
                arr[arr.length - 1].duration += remaining
                remaining = 0
                adjustedTail = true
            }
        }

        return { blocks: arr, adjustedTail: adjustedTail }
    }

    function sessionsForPreset(preset, totalMin) {
        var built = buildAlternatingByTotal(preset.workMin, preset.breakMin, totalMin, longBreakMinutes)
        return built.blocks
    }

    function loadPresetByIndex(idx) {
        var presets = allPresets()
        var target = idx
        if (target < 0 || target >= presets.length) target = 0
        var preset = presets[target]
        loadSessions(sessionsForPreset(preset, focusMinutes), target)
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
        var idx     = defaultPresetIndex
        loadPresetByIndex(idx)
    }

    function startTimer() {
        if (sessions.length === 0) return
        startTime = new Date()
        refreshEndTimeFromNow()
        running  = true
        finished = false
    }

    function skipBlock() {
        if (finished) return
        var oldType = sessions[currentIndex] ? sessions[currentIndex].type : undefined
        if (currentIndex + 1 < sessions.length) {
            currentIndex++
            timeLeft = sessions[currentIndex].duration
            var newType = sessions[currentIndex] ? sessions[currentIndex].type : undefined
            notifyBlockTransition(oldType, newType)
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
                root.refreshEndTimeFromNow()
            } else {
                if (root.currentIndex + 1 < root.sessions.length) {
                    var oldType = root.sessions[root.currentIndex] ? root.sessions[root.currentIndex].type : undefined
                    root.currentIndex++
                    root.timeLeft = root.sessions[root.currentIndex].duration
                    root.refreshEndTimeFromNow()
                    var newType = root.sessions[root.currentIndex] ? root.sessions[root.currentIndex].type : undefined
                    root.notifyBlockTransition(oldType, newType)
                } else {
                    root.running  = false
                    root.finished = true
                    root.timeLeft = 0
                    root.endTime  = new Date()
                }
            }
        }
    }

    // Keep end-time moving forward while paused.
    Timer {
        interval: 1000
        repeat: true
        running: root.startTime !== null && !root.running && !root.finished
        onTriggered: root.refreshEndTimeFromNow()
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

    function blockLabel(blockType) {
        return blockType === "work" ? "Work" : "Break"
    }

    function notifyBlockTransition(fromType, toType) {
        if (fromType === undefined || toType === undefined || fromType === toType)
            return

        var message = toType === "work" ? "Time to work 🍅" : "Break time ☕"
        if (blockTransitionNotification) {
            blockTransitionNotification.title = "Pomodoro Timer"
            blockTransitionNotification.text = message
            blockTransitionNotification.iconName = "com.pomodoro.timer"
            blockTransitionNotification.sendEvent()
            return
        }

        if (!showDesktopNotification(message))
            console.warn("Pomodoro notification API not available")
    }

    function showDesktopNotification(message) {
        if (typeof root.showPassiveNotification === "function") {
            root.showPassiveNotification(message, root.appIconPath)
            return true
        }
        if (Plasmoid && typeof Plasmoid.showPassiveNotification === "function") {
            Plasmoid.showPassiveNotification(message, root.appIconPath)
            return true
        }
        if (Plasmoid && Plasmoid.nativeInterface
            && typeof Plasmoid.nativeInterface.showPassiveNotification === "function") {
            Plasmoid.nativeInterface.showPassiveNotification(message, root.appIconPath)
            return true
        }
        return false
    }

    function remainingTotalSeconds() {
        if (sessions.length === 0 || currentIndex < 0 || currentIndex >= sessions.length)
            return 0

        var remaining = Math.max(0, timeLeft)
        for (var i = currentIndex + 1; i < sessions.length; i++)
            remaining += sessions[i].duration
        return remaining
    }

    function refreshEndTimeFromNow() {
        if (startTime === null || finished || sessions.length === 0) {
            endTime = null
            return
        }
        endTime = new Date(new Date().getTime() + remainingTotalSeconds() * 1000)
    }

    function applySessionSettings() {
        if (suppressAutoApply)
            return
        loadPresetByIndex(loadedPresetIndex)
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
                            root.refreshEndTimeFromNow()
                        } else {
                            root.running = true
                            root.refreshEndTimeFromNow()
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

            // ── focus duration for selected preset ───────────────────────
            Column {
                width: parent.width
                spacing: 6

                Text {
                    text: "Amount of time to concentrate (minutes)"
                    font.pixelSize: 11
                    color: Kirigami.Theme.disabledTextColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Row {
                    spacing: 8
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        text: "Focus:"
                        color: Kirigami.Theme.textColor
                        height: 32
                        verticalAlignment: Text.AlignVCenter
                    }

                    QQC2.SpinBox {
                        id: focusMinutesInput
                        from: 1
                        to: 1440
                        value: root.focusMinutes
                        implicitWidth: 86
                        onValueModified: {
                            root.suppressAutoApply = true
                            root.focusMinutes = value
                            root.longBreakMinutes = root.suggestedLongBreakMinutes(value)
                            longBreakInput.value = root.longBreakMinutes
                            root.suppressAutoApply = false
                            root.applySessionSettings()
                        }
                    }

                    Text {
                        text: "min"
                        color: Kirigami.Theme.textColor
                        height: 32
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Row {
                    spacing: 8
                    anchors.horizontalCenter: parent.horizontalCenter

                    Text {
                        text: "Long break:"
                        color: Kirigami.Theme.textColor
                        height: 32
                        verticalAlignment: Text.AlignVCenter
                    }

                    QQC2.SpinBox {
                        id: longBreakInput
                        from: 1
                        to: 120
                        value: root.longBreakMinutes
                        implicitWidth: 86
                        onValueModified: {
                            root.longBreakMinutes = value
                            root.applySessionSettings()
                        }
                    }

                    Text {
                        text: "min"
                        color: Kirigami.Theme.textColor
                        height: 32
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Text {
                    width: parent.width
                    text: "Used every 4th break for sessions of 2 hours or more."
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    color: Kirigami.Theme.disabledTextColor
                    font.pixelSize: 10
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
                            root.loadSessions(root.sessionsForPreset(myPreset, root.focusMinutes), myIndex)
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

/*
 * Pomodoro Timer — Configuration Page
 * Author: David A — GNU GPL v2.0
 */

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Item {
    id: cfgRoot
    implicitWidth:  560
    implicitHeight: scroll.contentHeight + 24

    // cfg_ via alias to a backing TextInput/SpinBox so Plasma can read/write them
    property alias cfg_presetsJson:        presetsJsonBacking.text
    property alias cfg_defaultPresetIndex: defaultIndexBacking.value

    // Hidden backing elements that hold the actual values
    TextInput { id: presetsJsonBacking;  visible: false; text: "[]" }
    QQC2.SpinBox { id: defaultIndexBacking; visible: false; from: 0; to: 999; value: 0 }

    // ── internal ────────────────────────────────────────────────────────────
    property var userPresets: []

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

    function parsePresets() {
        var parsed = []
        try { parsed = JSON.parse(presetsJsonBacking.text) }
        catch(e) { parsed = [] }

        var normalized = []
        for (var i = 0; i < parsed.length; i++) {
            var p = normalizePreset(parsed[i])
            if (p) normalized.push(p)
        }
        userPresets = normalized
        userModel.rebuild()
        defaultCombo.refreshModel()
    }

    function savePresets() {
        presetsJsonBacking.text = JSON.stringify(userPresets)
        defaultCombo.refreshModel()
    }

    readonly property var builtinNames: ["25+5", "50+10"]

    function allNames() {
        var n = builtinNames.slice()
        for (var i = 0; i < userPresets.length; i++) n.push(userPresets[i].name)
        return n
    }

    Component.onCompleted:              parsePresets()
    onCfg_presetsJsonChanged:           parsePresets()

    // ── scroll container ────────────────────────────────────────────────────
    QQC2.ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: scroll.availableWidth
            spacing: 14

            // ══ DEFAULT PRESET ═══════════════════════════════════════════
            Kirigami.Heading { text: "Default Preset"; level: 3; Layout.topMargin: 10 }

            RowLayout {
                Layout.fillWidth: true; spacing: 10
                QQC2.Label { text: "Load on start:" }
                QQC2.ComboBox {
                    id: defaultCombo
                    Layout.fillWidth: true
                    function refreshModel() {
                        var names = cfgRoot.allNames()
                        model = names
                        var idx = defaultIndexBacking.value
                        currentIndex = (idx >= 0 && idx < names.length) ? idx : 0
                    }
                    onActivated: function(i) { defaultIndexBacking.value = i }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            // ══ ALL PRESETS ═══════════════════════════════════════════════
            Kirigami.Heading { text: "All Presets"; level: 3 }

            Repeater {
                model: cfgRoot.builtinNames
                delegate: RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    Rectangle { width: 8; height: 8; radius: 4; color: "#ff6644"; Layout.alignment: Qt.AlignVCenter }
                    QQC2.Label { text: modelData; Layout.fillWidth: true; opacity: 0.7; font.italic: true }
                    QQC2.Label { text: "built-in"; font.pixelSize: 10; opacity: 0.4 }
                }
            }

            ListModel {
                id: userModel
                function rebuild() {
                    clear()
                    for (var i = 0; i < cfgRoot.userPresets.length; i++) {
                        var p = cfgRoot.userPresets[i]
                        append({ pname: p.name, pwork: p.workMin, pbreak: p.breakMin })
                    }
                }
            }

            Repeater {
                model: userModel
                delegate: RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    property int myIdx: index
                    Rectangle { width: 8; height: 8; radius: 4; color: "#44aaff"; Layout.alignment: Qt.AlignVCenter }
                    QQC2.Label { text: model.pname; Layout.fillWidth: true }
                    QQC2.Label { text: model.pwork + "m work / " + model.pbreak + "m break"; font.pixelSize: 10; opacity: 0.5 }
                    QQC2.Button {
                        text: "Delete"
                        onClicked: {
                            var arr = cfgRoot.userPresets.slice()
                            arr.splice(myIdx, 1)
                            cfgRoot.userPresets = arr
                            cfgRoot.savePresets()
                            if (defaultIndexBacking.value > cfgRoot.builtinNames.length - 1 + myIdx)
                                defaultIndexBacking.value = Math.max(0, defaultIndexBacking.value - 1)
                        }
                    }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            // ══ CREATE NEW PRESET ═════════════════════════════════════════
            Kirigami.Heading { text: "Create New Preset"; level: 3 }

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                QQC2.Label { text: "Name:" }
                QQC2.TextField { id: presetName; Layout.fillWidth: true; placeholderText: "e.g. Deep Work 90/15" }
            }

            RowLayout {
                Layout.fillWidth: true; spacing: 6
                QQC2.SpinBox { id: qfWork;  from: 1; to: 240; value: 25; implicitWidth: 72 }
                QQC2.Label   { text: "work mins"; Layout.alignment: Qt.AlignVCenter }
                QQC2.SpinBox { id: qfBreak; from: 1; to: 120; value: 5;  implicitWidth: 72 }
                QQC2.Label   { text: "break mins"; Layout.alignment: Qt.AlignVCenter }
            }

            QQC2.Button {
                text: "Save preset"
                enabled: presetName.text.trim().length > 0
                onClicked: {
                    var arr = cfgRoot.userPresets.slice()
                    arr.push({
                        name: presetName.text.trim(),
                        workMin: qfWork.value,
                        breakMin: qfBreak.value
                    })
                    cfgRoot.userPresets = arr
                    cfgRoot.savePresets()
                    presetName.text = ""
                }
            }

            Item { height: 16; width: 1 }
        }
    }
}

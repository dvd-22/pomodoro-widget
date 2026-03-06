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
    property var draftBlocks: []

    function parsePresets() {
        try { userPresets = JSON.parse(presetsJsonBacking.text) }
        catch(e) { userPresets = [] }
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

    function draftTotal() {
        var t = 0
        for (var i = 0; i < draftBlocks.length; i++) t += draftBlocks[i].duration
        return Math.round(t / 60)
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
                        append({ pname: p.name, pblocks: p.sessions ? p.sessions.length : 0 })
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
                    QQC2.Label { text: model.pblocks + " blocks"; font.pixelSize: 10; opacity: 0.5 }
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

            Kirigami.Heading { text: "Quick fill"; level: 4; opacity: 0.65 }
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                QQC2.SpinBox { id: qfReps;  from: 1; to: 20;  value: 4;  implicitWidth: 64 }
                QQC2.Label   { text: "×"; Layout.alignment: Qt.AlignVCenter }
                QQC2.SpinBox { id: qfWork;  from: 1; to: 240; value: 25; implicitWidth: 72 }
                QQC2.Label   { text: "m work"; Layout.alignment: Qt.AlignVCenter }
                QQC2.SpinBox { id: qfBreak; from: 1; to: 120; value: 5;  implicitWidth: 72 }
                QQC2.Label   { text: "m break"; Layout.alignment: Qt.AlignVCenter }
                QQC2.Button {
                    text: "Fill"
                    onClicked: {
                        var arr = []
                        for (var i = 0; i < qfReps.value; i++) {
                            arr.push({ type: "work",  duration: qfWork.value  * 60 })
                            arr.push({ type: "break", duration: qfBreak.value * 60 })
                        }
                        arr.push({ type: "work", duration: qfWork.value * 60 })
                        cfgRoot.draftBlocks = arr
                        draftModel.rebuild()
                    }
                }
            }

            Kirigami.Heading { text: "Or add blocks manually"; level: 4; opacity: 0.65 }
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                QQC2.ComboBox { id: blkType; model: ["Work", "Break"]; implicitWidth: 90 }
                QQC2.SpinBox  { id: blkMin; from: 1; to: 240; value: 25; implicitWidth: 72 }
                QQC2.Label    { text: "min"; Layout.alignment: Qt.AlignVCenter }
                QQC2.Button {
                    text: "+ Add"
                    onClicked: {
                        var arr = cfgRoot.draftBlocks.slice()
                        arr.push({ type: blkType.currentIndex === 0 ? "work" : "break",
                                   duration: blkMin.value * 60 })
                        cfgRoot.draftBlocks = arr
                        draftModel.rebuild()
                        // do NOT reset blkType so user can add another of same type
                    }
                }
                QQC2.Button {
                    text: "Clear all"
                    onClicked: { cfgRoot.draftBlocks = []; draftModel.clear() }
                }
            }

            QQC2.Label {
                visible: cfgRoot.draftBlocks.length > 0
                text:    cfgRoot.draftBlocks.length + " blocks · " + cfgRoot.draftTotal() + " min total"
                font.pixelSize: 11; opacity: 0.75
            }

            ListModel {
                id: draftModel
                function rebuild() {
                    clear()
                    for (var i = 0; i < cfgRoot.draftBlocks.length; i++) {
                        var b = cfgRoot.draftBlocks[i]
                        append({ btype: b.type, bmins: Math.round(b.duration / 60) })
                    }
                }
            }

            Repeater {
                model: draftModel
                delegate: RowLayout {
                    Layout.fillWidth: true; spacing: 8
                    property int myIdx: index
                    Rectangle { width: 10; height: 10; radius: 3; color: model.btype === "work" ? "#ff6644" : "#44cc88"; Layout.alignment: Qt.AlignVCenter }
                    QQC2.Label { text: (model.btype === "work" ? "Work" : "Break") + "  —  " + model.bmins + " min"; Layout.fillWidth: true }
                    QQC2.Button {
                        text: "✕"; implicitWidth: 28
                        onClicked: {
                            var arr = cfgRoot.draftBlocks.slice()
                            arr.splice(myIdx, 1)
                            cfgRoot.draftBlocks = arr
                            draftModel.rebuild()
                        }
                    }
                }
            }

            QQC2.Button {
                text: "💾  Save preset"
                enabled: presetName.text.trim().length > 0 && cfgRoot.draftBlocks.length > 0
                onClicked: {
                    var arr = cfgRoot.userPresets.slice()
                    arr.push({ name: presetName.text.trim(), sessions: cfgRoot.draftBlocks.slice() })
                    cfgRoot.userPresets = arr
                    cfgRoot.savePresets()
                    presetName.text     = ""
                    cfgRoot.draftBlocks = []
                    draftModel.clear()
                }
            }

            Item { height: 16; width: 1 }
        }
    }
}

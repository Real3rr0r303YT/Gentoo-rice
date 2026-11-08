// Gentoo-rice Blocks – SDDM-Theme im Klötzchen-Look (Qt 6)
// Alle Grafiken prozedural erzeugt (tools/gen-pixel-textures.py), keine fremden Texturen/Schriften.
// Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#3a3a3e"

    function cfg(key, fallback) {
        if (typeof config === "undefined" || !config)
            return fallback
        var v = config[key]
        return (v === undefined || v === null || v === "") ? fallback : v
    }
    readonly property int px: Math.max(2, Number(cfg("pixel", 4)) * Math.min(width / 1920, height / 1080))
    readonly property color textColor: "#f0f0f0"
    readonly property color hoverColor: "#ffff9a"

    // ── Bausteine ─────────────────────────────────────────────
    // Gekachelte Pixel-Textur, hart (ohne Glättung) vergrößert
    component Tiles: Item {
        id: tiles
        property string tex: "stone"
        clip: true
        Item {
            width: Math.ceil(tiles.width / root.px) + 16
            height: Math.ceil(tiles.height / root.px) + 16
            scale: root.px
            transformOrigin: Item.TopLeft
            Image {
                anchors.fill: parent
                source: "assets/" + tiles.tex + ".png"
                fillMode: Image.Tile
                horizontalAlignment: Image.AlignLeft
                verticalAlignment: Image.AlignTop
                smooth: false
            }
        }
    }

    // Pixel-Schrift: Text klein rendern und ohne Glättung hochskalieren
    component PixelText: Item {
        id: pt
        property string text: ""
        property color color: root.textColor
        property int size: 8
        property real zoom: root.px
        implicitWidth: (label.implicitWidth + 1) * zoom
        implicitHeight: (label.implicitHeight + 1) * zoom
        width: implicitWidth
        height: implicitHeight
        Item {
            width: label.implicitWidth + 1
            height: label.implicitHeight + 1
            scale: pt.zoom
            transformOrigin: Item.TopLeft
            layer.enabled: true
            layer.smooth: false
            Text {
                x: 1
                y: 1
                text: pt.text
                color: Qt.darker(pt.color, 3.6)
                font: label.font
                renderType: Text.NativeRendering
            }
            Text {
                id: label
                text: pt.text
                color: pt.color
                font.family: "monospace"
                font.pixelSize: pt.size
                font.bold: true
                font.hintingPreference: Font.PreferFullHinting
                renderType: Text.NativeRendering
            }
        }
    }

    // Klötzchen-Button mit Kanten-Schattierung
    component BlockButton: Item {
        id: bb
        property string text: ""
        signal clicked
        property bool hot: area.containsMouse || activeFocus
        height: 20 * root.px
        Tiles {
            anchors.fill: parent
            tex: "stone"
        }
        Rectangle { anchors.fill: parent; color: bb.hot ? "#30ffffff" : "#18000000" }
        // Bevel: hell oben/links, dunkel unten/rechts
        Rectangle { x: 0; y: 0; width: parent.width; height: root.px; color: "#c8c8cc" }
        Rectangle { x: 0; y: 0; width: root.px; height: parent.height; color: "#c8c8cc" }
        Rectangle { x: 0; y: parent.height - root.px; width: parent.width; height: root.px; color: "#2a2a2e" }
        Rectangle { x: parent.width - root.px; y: 0; width: root.px; height: parent.height; color: "#2a2a2e" }
        // Rahmen (weiß bei Hover)
        Rectangle {
            anchors.fill: parent
            anchors.margins: -root.px
            color: "transparent"
            border.width: root.px
            border.color: bb.hot ? "#ffffff" : "#111114"
        }
        PixelText {
            anchors.centerIn: parent
            text: bb.text
            color: bb.hot ? root.hoverColor : root.textColor
        }
        MouseArea {
            id: area
            anchors.fill: parent
            hoverEnabled: true
            onClicked: bb.clicked()
        }
        Keys.onReturnPressed: bb.clicked()
        Keys.onSpacePressed: bb.clicked()
    }

    // ── Hintergrund: Fels, unten Gras + Erde ──────────────────
    Tiles {
        anchors.fill: parent
        tex: "stone"
    }
    Rectangle { anchors.fill: parent; color: "#55000000" }
    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        Tiles { width: parent.width; height: 16 * root.px; tex: "grass" }
        Tiles { width: parent.width; height: 32 * root.px; tex: "dirt" }
    }

    // ── Titel + Uhr ───────────────────────────────────────────
    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
    PixelText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.08
        text: "GENTOO-RICE"
        zoom: root.px * 2.2
        color: "#d8d8de"
    }
    Column {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8 * root.px
        spacing: root.px
        PixelText {
            anchors.right: parent.right
            text: Qt.formatTime(root.now, "HH:mm")
            zoom: root.px * 1.6
        }
        PixelText {
            anchors.right: parent.right
            text: Qt.locale("de_DE").toString(root.now, "ddd d. MMM")
            color: "#c0c0c6"
        }
    }

    // ── Anmelde-Panel ─────────────────────────────────────────
    // Beim allerersten Start ist lastUser leer → ersten Benutzer aus der Liste nehmen
    property string userName: (typeof userModel !== "undefined" && userModel && userModel.lastUser) ? userModel.lastUser : users.currentText
    ComboBox {
        id: users
        visible: false
        model: typeof userModel !== "undefined" && userModel ? userModel : []
        textRole: "name"
        currentIndex: typeof userModel !== "undefined" && userModel && userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    }
    property string message: ""

    function doLogin() {
        root.message = ""
        if (typeof sddm !== "undefined" && sddm)
            sddm.login(root.userName, password.text, sessions.currentIndex)
    }

    Item {
        id: panel
        width: 120 * root.px
        height: col.implicitHeight + 16 * root.px
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -6 * root.px

        Tiles { anchors.fill: parent; tex: "deepstone" }
        Rectangle {
            anchors.fill: parent
            color: "#40000000"
            border.width: root.px
            border.color: "#111114"
        }

        Column {
            id: col
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 8 * root.px
            width: parent.width - 16 * root.px
            spacing: 5 * root.px

            Rectangle {
                width: 30 * root.px
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#1b1b1f"
                border.width: root.px
                border.color: "#8b8b91"
                Image {
                    anchors.fill: parent
                    anchors.margins: root.px * 2
                    source: "file://" + root.cfg("avatar", "")
                    fillMode: Image.PreserveAspectFit
                    smooth: false
                    cache: false
                }
            }

            PixelText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.userName
            }

            // Passwortfeld (schwarzes Eingabefeld mit grauem Rahmen)
            Rectangle {
                width: parent.width
                height: 18 * root.px
                color: "#000000"
                border.width: root.px
                border.color: password.activeFocus ? "#ffffff" : "#a0a0a0"
                TextInput {
                    id: password
                    anchors.fill: parent
                    anchors.leftMargin: 4 * root.px
                    anchors.rightMargin: 4 * root.px
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "*"
                    color: "#e0e0e0"
                    font.family: "monospace"
                    font.pixelSize: 9 * root.px
                    font.bold: true
                    focus: true
                    clip: true
                    Keys.onReturnPressed: root.doLogin()
                    Keys.onEnterPressed: root.doLogin()
                }
                PixelText {
                    anchors.verticalCenter: parent.verticalCenter
                    x: 4 * root.px
                    visible: password.text.length === 0 && !password.activeFocus
                    text: "Passwort"
                    color: "#808086"
                }
            }

            PixelText {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text !== ""
                text: root.message !== "" ? root.message : ((typeof keyboard !== "undefined" && keyboard && keyboard.capsLock) ? "Feststelltaste an" : "")
                color: root.message !== "" ? "#ff6060" : root.hoverColor
            }

            BlockButton {
                width: parent.width
                text: "Anmelden"
                onClicked: root.doLogin()
            }
        }
    }

    // ── Sitzung / Neustart / Aus (unten über dem Boden) ───────
    ComboBox {
        id: sessions
        visible: false
        model: typeof sessionModel !== "undefined" && sessionModel ? sessionModel : []
        textRole: "name"
        Component.onCompleted: {
            var i = find(root.cfg("preferredSession", "Gentoo-rice"), Qt.MatchContains)
            if (i < 0)
                i = find("Hyprland", Qt.MatchContains)
            currentIndex = Math.max(0, i)
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 56 * root.px
        spacing: 4 * root.px
        BlockButton {
            width: 124 * root.px
            text: "> " + (sessions.currentText.length > 22 ? sessions.currentText.slice(0, 21) + "." : (sessions.currentText !== "" ? sessions.currentText : "-"))
            onClicked: if (sessions.count > 0) sessions.currentIndex = (sessions.currentIndex + 1) % sessions.count
        }
        BlockButton {
            width: 64 * root.px
            text: "Neustart"
            onClicked: if (typeof sddm !== "undefined" && sddm) sddm.reboot()
        }
        BlockButton {
            width: 72 * root.px
            text: "Ausschalten"
            onClicked: if (typeof sddm !== "undefined" && sddm) sddm.powerOff()
        }
    }

    Connections {
        target: typeof sddm !== "undefined" && sddm ? sddm : null
        ignoreUnknownSignals: true
        function onLoginFailed() {
            root.message = "Falsches Passwort"
            password.text = ""
            password.forceActiveFocus()
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}

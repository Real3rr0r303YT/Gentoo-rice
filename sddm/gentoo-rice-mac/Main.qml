// Gentoo-rice – SDDM-Theme im macOS-Stil (Qt 6)
// Eigene Umsetzung ohne Apple-Grafiken: Uhr oben, Avatar + Passwort-Pille unten, runde Knöpfe
// Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "#101014"

    function cfg(key, fallback) {
        if (typeof config === "undefined" || !config || config === null)
            return fallback
        var v = config[key]
        return (v === undefined || v === null || v === "") ? fallback : v
    }
    readonly property string fontName: cfg("font", "Inter")
    readonly property real s: Math.max(0.6, Math.min(width / 1920, height / 1080))
    readonly property color white: "#ffffff"

    // ── Zustand ───────────────────────────────────────────────
    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
    property int userIndex: typeof userModel !== "undefined" && userModel && userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    readonly property int userCount: typeof userModel !== "undefined" && userModel ? userModel.count : 0
    // Beim allerersten Start kennt SDDM keinen "letzten Benutzer" → Benutzer aus der Liste nehmen
    readonly property string userName: users.currentText !== "" ? users.currentText : ((typeof userModel !== "undefined" && userModel && userModel.lastUser) ? userModel.lastUser : "")
    property string errorText: ""
    property bool busy: false
    readonly property bool capsLock: typeof keyboard !== "undefined" && keyboard ? !!keyboard.capsLock : false
    readonly property int layoutCount: typeof keyboard !== "undefined" && keyboard && keyboard.layouts ? keyboard.layouts.length : 0
    readonly property string layoutName: {
        if (layoutCount > 0) {
            const l = keyboard.layouts[keyboard.currentLayout]
            if (l && l.shortName)
                return String(l.shortName).toUpperCase()
        }
        return "DE"
    }

    function doLogin() {
        if (root.userName === "") {
            root.errorText = "Kein Benutzer gefunden"
            return
        }
        root.errorText = ""
        root.busy = true
        if (typeof sddm !== "undefined" && sddm)
            sddm.login(root.userName, password.text, sessions.currentIndex)
    }

    // unsichtbare Listen (Benutzer, Sitzungen)
    ComboBox {
        id: users
        visible: false
        model: typeof userModel !== "undefined" && userModel ? userModel : []
        textRole: "name"
        currentIndex: root.userIndex
    }
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

    // ── Hintergrund: Wallpaper (weich) + leichte Abdunklung ────
    Image {
        anchors.fill: parent
        source: root.cfg("background", "") !== "" ? "file://" + root.cfg("background", "") : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.18) }
            GradientStop { position: 0.6; color: Qt.rgba(0, 0, 0, 0.12) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.42) }
        }
    }

    // ── Statusleiste oben rechts (Tastatur, Sitzung) ───────────
    Row {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 10 * root.s
        anchors.rightMargin: 18 * root.s
        spacing: 18 * root.s
        Text {
            text: sessions.currentText !== "" ? sessions.currentText : "Hyprland"
            color: root.white
            opacity: sessArea.containsMouse ? 1.0 : 0.85
            font.family: root.fontName
            font.pixelSize: 14 * root.s
            font.weight: Font.Medium
            MouseArea {
                id: sessArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (sessions.count > 0) sessions.currentIndex = (sessions.currentIndex + 1) % sessions.count
            }
        }
        Text {
            text: root.layoutName
            color: root.white
            opacity: 0.85
            font.family: root.fontName
            font.pixelSize: 14 * root.s
            font.weight: Font.DemiBold
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.layoutCount > 1)
                        keyboard.currentLayout = (keyboard.currentLayout + 1) % root.layoutCount
                }
            }
        }
    }

    // ── Datum + große Uhr ─────────────────────────────────────
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.08
        spacing: -6 * root.s
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale("de_DE").toString(root.now, "dddd, d. MMMM")
            color: root.white
            opacity: 0.88
            font.family: root.fontName
            font.pixelSize: 26 * root.s
            font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.now, "H:mm")
            color: root.white
            opacity: 0.92
            font.family: root.fontName
            font.pixelSize: 150 * root.s
            font.weight: Font.Bold
            font.letterSpacing: -3 * root.s
        }
    }

    // ── Benutzer + Passwort (unten mittig) ────────────────────
    Column {
        id: loginBox
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.17
        spacing: 12 * root.s

        SequentialAnimation {
            id: shake
            loops: 2
            NumberAnimation { target: loginBox; property: "anchors.horizontalCenterOffset"; to: -12; duration: 45 }
            NumberAnimation { target: loginBox; property: "anchors.horizontalCenterOffset"; to: 12; duration: 90 }
            NumberAnimation { target: loginBox; property: "anchors.horizontalCenterOffset"; to: 0; duration: 45 }
        }

        // Avatar (von sddm-sync.sh rund zugeschnitten)
        Item {
            width: 96 * root.s
            height: width
            anchors.horizontalCenter: parent.horizontalCenter
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.25)
                Text {
                    anchors.centerIn: parent
                    visible: avatar.status !== Image.Ready
                    text: root.userName !== "" ? root.userName.charAt(0).toUpperCase() : "?"
                    color: root.white
                    font.family: root.fontName
                    font.pixelSize: 42 * root.s
                    font.weight: Font.DemiBold
                }
            }
            Image {
                id: avatar
                anchors.fill: parent
                source: root.cfg("avatar", "") !== "" ? "file://" + root.cfg("avatar", "") : ""
                fillMode: Image.PreserveAspectFit
                smooth: true
                cache: false
            }
        }

        // Name – Klick wechselt den Benutzer (bei mehreren)
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.userName !== "" ? root.userName : "Benutzer"
            color: root.white
            font.family: root.fontName
            font.pixelSize: 19 * root.s
            font.weight: Font.DemiBold
            MouseArea {
                anchors.fill: parent
                enabled: root.userCount > 1
                cursorShape: root.userCount > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.userIndex = (root.userIndex + 1) % root.userCount
            }
        }

        // Passwort-Pille mit Pfeil
        Item {
            width: 230 * root.s
            height: 34 * root.s
            anchors.horizontalCenter: parent.horizontalCenter
            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(1, 1, 1, password.activeFocus ? 0.26 : 0.2)
                border.width: root.errorText !== "" ? 1 : 0
                border.color: "#ff8a80"
            }
            TextField {
                id: password
                anchors.fill: parent
                anchors.rightMargin: 30 * root.s
                leftPadding: 16 * root.s
                echoMode: TextInput.Password
                passwordCharacter: "●"
                placeholderText: "Passwort eingeben"
                placeholderTextColor: Qt.rgba(1, 1, 1, 0.62)
                color: root.white
                selectionColor: Qt.rgba(1, 1, 1, 0.35)
                font.family: root.fontName
                font.pixelSize: 14 * root.s
                verticalAlignment: TextInput.AlignVCenter
                focus: true
                background: Item {}
                Keys.onReturnPressed: root.doLogin()
                Keys.onEnterPressed: root.doLogin()
                onTextEdited: root.errorText = ""
            }
            // Pfeil-Knopf (erscheint, sobald etwas eingegeben ist)
            Rectangle {
                id: go
                width: 24 * root.s
                height: width
                radius: width / 2
                anchors.right: parent.right
                anchors.rightMargin: 5 * root.s
                anchors.verticalCenter: parent.verticalCenter
                color: goArea.containsMouse ? Qt.rgba(1, 1, 1, 0.5) : Qt.rgba(1, 1, 1, 0.32)
                opacity: password.text !== "" || root.busy ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: 150 } }
                Canvas {
                    anchors.centerIn: parent
                    width: parent.width * 0.5
                    height: width
                    onPaint: {
                        const c = getContext("2d")
                        c.reset()
                        c.strokeStyle = "#ffffff"
                        c.lineWidth = Math.max(1.5, width * 0.14)
                        c.lineCap = "round"
                        c.lineJoin = "round"
                        c.beginPath()
                        c.moveTo(width * 0.12, height / 2)
                        c.lineTo(width * 0.88, height / 2)
                        c.moveTo(width * 0.55, height * 0.18)
                        c.lineTo(width * 0.88, height / 2)
                        c.lineTo(width * 0.55, height * 0.82)
                        c.stroke()
                    }
                }
                MouseArea {
                    id: goArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.doLogin()
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.errorText !== "" ? root.errorText : (root.capsLock ? "Feststelltaste ist aktiv" : (root.busy ? "Anmelden …" : "Enter drücken zum Anmelden"))
            color: root.white
            opacity: root.errorText !== "" ? 1.0 : 0.62
            font.family: root.fontName
            font.pixelSize: 13 * root.s
        }
    }

    // ── Ruhezustand / Neustart / Ausschalten ──────────────────
    component PowerButton: Item {
        id: pb
        property string label: ""
        property string kind: "power"   // sleep | restart | power
        signal clicked
        width: 78 * root.s
        height: 76 * root.s
        Rectangle {
            id: circle
            width: 44 * root.s
            height: width
            radius: width / 2
            anchors.horizontalCenter: parent.horizontalCenter
            color: area.containsMouse ? Qt.rgba(1, 1, 1, 0.32) : Qt.rgba(1, 1, 1, 0.18)
            Behavior on color { ColorAnimation { duration: 120 } }
            Canvas {
                anchors.centerIn: parent
                width: parent.width * 0.46
                height: width
                onPaint: {
                    const c = getContext("2d")
                    c.reset()
                    c.strokeStyle = "#ffffff"
                    c.fillStyle = "#ffffff"
                    c.lineWidth = Math.max(1.5, width * 0.11)
                    c.lineCap = "round"
                    const cx = width / 2, cy = height / 2, r = width * 0.4
                    c.beginPath()
                    if (pb.kind === "sleep") {
                        // Mond
                        c.arc(cx, cy, r, 0, Math.PI * 2)
                        c.fill()
                        c.globalCompositeOperation = "destination-out"
                        c.beginPath()
                        c.arc(cx + r * 0.55, cy - r * 0.35, r * 0.85, 0, Math.PI * 2)
                        c.fill()
                    } else if (pb.kind === "restart") {
                        c.arc(cx, cy, r, -Math.PI * 0.35, Math.PI * 1.45)
                        c.stroke()
                        c.beginPath()
                        const ax = cx + r * Math.cos(-Math.PI * 0.35), ay = cy + r * Math.sin(-Math.PI * 0.35)
                        c.moveTo(ax - r * 0.5, ay - r * 0.05)
                        c.lineTo(ax + r * 0.05, ay)
                        c.lineTo(ax + r * 0.05, ay - r * 0.55)
                        c.stroke()
                    } else {
                        c.arc(cx, cy, r, -Math.PI * 0.3, Math.PI * 1.3)
                        c.stroke()
                        c.beginPath()
                        c.moveTo(cx, cy - r * 1.15)
                        c.lineTo(cx, cy - r * 0.1)
                        c.stroke()
                    }
                }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: circle.bottom
            anchors.topMargin: 7 * root.s
            text: pb.label
            color: root.white
            opacity: 0.88
            font.family: root.fontName
            font.pixelSize: 12 * root.s
            font.weight: Font.Medium
        }
        MouseArea {
            id: area
            anchors.fill: circle
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pb.clicked()
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 26 * root.s
        spacing: 22 * root.s
        PowerButton {
            label: "Ruhezustand"
            kind: "sleep"
            visible: typeof sddm === "undefined" || !sddm || !!sddm.canSuspend
            onClicked: if (typeof sddm !== "undefined" && sddm) sddm.suspend()
        }
        PowerButton {
            label: "Neustart"
            kind: "restart"
            visible: typeof sddm === "undefined" || !sddm || !!sddm.canReboot
            onClicked: if (typeof sddm !== "undefined" && sddm) sddm.reboot()
        }
        PowerButton {
            label: "Ausschalten"
            kind: "power"
            visible: typeof sddm === "undefined" || !sddm || !!sddm.canPowerOff
            onClicked: if (typeof sddm !== "undefined" && sddm) sddm.powerOff()
        }
    }

    // ── Rückmeldungen von SDDM ────────────────────────────────
    Connections {
        target: typeof sddm !== "undefined" && sddm ? sddm : null
        ignoreUnknownSignals: true
        function onLoginFailed() {
            root.busy = false
            root.errorText = "Falsches Passwort"
            password.text = ""
            password.forceActiveFocus()
            shake.start()
        }
        function onLoginSucceeded() {
            root.busy = false
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}

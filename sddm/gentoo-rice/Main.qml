// Gentoo-rice – SDDM-Theme (Qt 6), blauer Glas-Look
// Copyright (C) 2026 3rr0r303YT – GPL-3.0-or-later
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    width: 1920
    height: 1080

    // ── Konfiguration (theme.conf / theme.conf.user) ──────────
    function cfg(key, fallback) {
        if (typeof config === "undefined" || !config || config === null)
            return fallback
        var v = config[key]
        return (v === undefined || v === null || v === "") ? fallback : v
    }
    // palette=blue (Standard): feste Blautöne · palette=wallpaper: Farben vom Rice (pywal)
    readonly property bool wallColors: cfg("palette", "blue") === "wallpaper"
    readonly property color cBg: wallColors ? cfg("bg", "#0b1220") : "#0b1220"
    readonly property color cFg: wallColors ? cfg("fg", "#e6edf7") : "#e6edf7"
    readonly property color cAccent: wallColors ? cfg("accent", "#3b82f6") : "#3b82f6"
    readonly property color cAccent2: wallColors ? cfg("accent2", "#22d3ee") : "#22d3ee"
    readonly property color cMuted: wallColors ? cfg("muted", "#64748b") : "#64748b"
    readonly property color cError: "#f87171"
    readonly property string fontName: cfg("font", "JetBrains Mono")
    readonly property real s: Math.max(0.6, Math.min(width / 1920, height / 1080))

    function alpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    color: cBg

    // ── Auswahlfeld im Rice-Look ──────────────────────────────
    component RiceCombo: ComboBox {
        id: combo
        font.family: root.fontName
        font.pixelSize: 14 * root.s
        contentItem: Text {
            leftPadding: 16 * root.s
            rightPadding: combo.indicator.width + 8 * root.s
            text: combo.displayText
            font: combo.font
            color: root.cFg
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        indicator: Text {
            x: combo.width - width - 14 * root.s
            anchors.verticalCenter: parent.verticalCenter
            text: "▾"
            color: root.cAccent2
            font.pixelSize: 14 * root.s
        }
        background: Rectangle {
            radius: height / 2
            color: combo.hovered ? root.alpha(root.cAccent, 0.18) : root.alpha(root.cBg, 0.55)
            border.width: 1
            border.color: combo.activeFocus ? root.cAccent : root.alpha(root.cFg, 0.12)
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        delegate: ItemDelegate {
            id: entry
            required property int index
            required property string name
            width: combo.width
            highlighted: combo.highlightedIndex === index
            contentItem: Text {
                text: entry.name
                color: entry.highlighted ? "#ffffff" : root.cFg
                font: combo.font
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: 10 * root.s
                color: entry.highlighted ? root.cAccent : "transparent"
            }
        }
        popup: Popup {
            y: -implicitHeight - 6 * root.s
            width: combo.width
            implicitHeight: contentItem.implicitHeight + 12 * root.s
            padding: 6 * root.s
            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: combo.popup.visible ? combo.delegateModel : null
                currentIndex: combo.highlightedIndex
            }
            background: Rectangle {
                radius: 14 * root.s
                color: root.alpha(root.cBg, 0.94)
                border.width: 1
                border.color: root.alpha(root.cAccent, 0.5)
            }
        }
    }

    // ── Runder Knopf in der unteren Leiste ────────────────────
    component PillButton: Button {
        id: pill
        height: 40 * root.s
        font.family: root.fontName
        font.pixelSize: 14 * root.s
        contentItem: Text {
            text: pill.text
            font: pill.font
            color: pill.enabled ? root.cFg : root.cMuted
            leftPadding: 12 * root.s
            rightPadding: 12 * root.s
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: height / 2
            color: pill.down ? root.alpha(root.cAccent, 0.5) : (pill.hovered ? root.alpha(root.cAccent, 0.25) : root.alpha(root.cBg, 0.55))
            border.width: 1
            border.color: pill.hovered ? root.alpha(root.cAccent, 0.7) : root.alpha(root.cFg, 0.12)
            Behavior on color { ColorAnimation { duration: 150 } }
        }
    }

    // ── Hintergrund: weichgezeichnetes Wallpaper + blauer Schleier ──
    Image {
        id: bgImage
        anchors.fill: parent
        source: root.cfg("background", "") !== "" ? "file://" + root.cfg("background", "") : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(0.07, 0.2, 0.5, 0.62) }
            GradientStop { position: 0.5; color: Qt.rgba(0.04, 0.1, 0.28, 0.78) }
            GradientStop { position: 1.0; color: Qt.rgba(0.02, 0.04, 0.12, 0.92) }
        }
    }
    // ── Inhalt (blendet beim Start weich ein) ─────────────────
    Item {
        id: stage
        anchors.fill: parent
        opacity: 0
        Component.onCompleted: fadeIn.start()
        NumberAnimation {
            id: fadeIn
            target: stage
            property: "opacity"
            to: 1
            duration: 600
            easing.type: Easing.OutCubic
        }

        // ── Uhr + Datum ───────────────────────────────────────
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.1
            spacing: 2 * root.s
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(root.now, "HH:mm")
                color: root.cFg
                font.family: root.fontName
                font.pixelSize: 124 * root.s
                font.weight: Font.Light
                font.letterSpacing: -2 * root.s
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.locale("de_DE").toString(root.now, "dddd, d. MMMM")
                color: root.cAccent2
                font.family: root.fontName
                font.pixelSize: 22 * root.s
                font.letterSpacing: 1 * root.s
            }
        }

        // ── Login-Karte (Glas) ────────────────────────────────
        Item {
            id: cardBox
            width: 400 * root.s
            height: card.height
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: parent.height * 0.4

            // Schatten
            Rectangle {
                anchors.fill: card
                anchors.topMargin: 14 * root.s
                anchors.margins: -6 * root.s
                radius: card.radius + 6 * root.s
                color: Qt.rgba(0, 0, 0, 0.28)
            }

            Rectangle {
                id: card
                width: parent.width
                height: content.implicitHeight + 56 * root.s
                radius: 26 * root.s
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.rgba(0.12, 0.18, 0.32, 0.62) }
                    GradientStop { position: 1.0; color: Qt.rgba(0.06, 0.1, 0.2, 0.72) }
                }
                border.width: 1
                border.color: root.alpha(root.cAccent, 0.35)

                SequentialAnimation {
                    id: shake
                    loops: 2
                    NumberAnimation { target: cardBox; property: "anchors.horizontalCenterOffset"; to: -14; duration: 45 }
                    NumberAnimation { target: cardBox; property: "anchors.horizontalCenterOffset"; to: 14; duration: 90 }
                    NumberAnimation { target: cardBox; property: "anchors.horizontalCenterOffset"; to: 0; duration: 45 }
                }

                Column {
                    id: content
                    anchors.top: parent.top
                    anchors.topMargin: 30 * root.s
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 56 * root.s
                    spacing: 14 * root.s

                    // runder Avatar mit Verlaufsring (rund zugeschnitten von scripts/sddm-sync.sh)
                    Item {
                        width: 108 * root.s
                        height: width
                        anchors.horizontalCenter: parent.horizontalCenter
                        Rectangle {
                            anchors.fill: parent
                            radius: width / 2
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: root.cAccent2 }
                                GradientStop { position: 1.0; color: root.cAccent }
                            }
                        }
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 3 * root.s
                            radius: width / 2
                            color: root.cBg
                            Text {
                                anchors.centerIn: parent
                                visible: avatar.status !== Image.Ready
                                text: root.userName !== "" ? root.userName.charAt(0).toUpperCase() : "?"
                                color: root.cFg
                                font.family: root.fontName
                                font.pixelSize: 44 * root.s
                                font.bold: true
                            }
                        }
                        Image {
                            id: avatar
                            anchors.fill: parent
                            anchors.margins: 6 * root.s
                            source: root.cfg("avatar", "") !== "" ? "file://" + root.cfg("avatar", "") : ""
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            cache: false
                        }
                    }

                    // Benutzername (immer sichtbar) bzw. Auswahl bei mehreren Benutzern
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: !userBox.visible
                        text: root.userName !== "" ? root.userName : "Benutzer"
                        color: root.cFg
                        font.family: root.fontName
                        font.pixelSize: 21 * root.s
                        font.bold: true
                    }
                    RiceCombo {
                        id: userBox
                        width: parent.width
                        height: 44 * root.s
                        visible: count > 1
                        model: typeof userModel !== "undefined" && userModel ? userModel : []
                        textRole: "name"
                        currentIndex: typeof userModel !== "undefined" && userModel && userModel.lastIndex >= 0 ? userModel.lastIndex : 0
                    }

                    // Passwort + Anzeigen-Schalter
                    TextField {
                        id: password
                        width: parent.width
                        height: 50 * root.s
                        echoMode: showPw.checked ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "●"
                        placeholderText: "Passwort"
                        placeholderTextColor: root.alpha(root.cFg, 0.45)
                        color: root.cFg
                        selectionColor: root.cAccent
                        font.family: root.fontName
                        font.pixelSize: 16 * root.s
                        leftPadding: 20 * root.s
                        rightPadding: showPw.width + 12 * root.s
                        focus: true
                        background: Rectangle {
                            radius: height / 2
                            color: root.alpha(root.cBg, 0.55)
                            border.width: password.activeFocus ? 2 : 1
                            border.color: root.errorText !== "" ? root.cError : (password.activeFocus ? root.cAccent : root.alpha(root.cFg, 0.14))
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                        }
                        Keys.onReturnPressed: root.doLogin()
                        Keys.onEnterPressed: root.doLogin()
                        onTextEdited: root.errorText = ""

                        Button {
                            id: showPw
                            checkable: true
                            focusPolicy: Qt.NoFocus
                            anchors.right: parent.right
                            anchors.rightMargin: 6 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height - 12 * root.s
                            width: 72 * root.s
                            text: checked ? "Verbergen" : "Zeigen"
                            font.family: root.fontName
                            font.pixelSize: 11 * root.s
                            contentItem: Text {
                                text: showPw.text
                                font: showPw.font
                                color: showPw.checked ? root.cAccent2 : root.alpha(root.cFg, 0.6)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                radius: height / 2
                                color: showPw.hovered ? root.alpha(root.cAccent, 0.22) : "transparent"
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: root.errorText !== "" || root.capsLock
                        text: root.errorText !== "" ? root.errorText : "Feststelltaste ist aktiv"
                        color: root.errorText !== "" ? root.cError : root.cAccent2
                        font.family: root.fontName
                        font.pixelSize: 13 * root.s
                    }

                    Button {
                        id: loginButton
                        width: parent.width
                        height: 48 * root.s
                        text: root.busy ? "Anmelden …" : "Anmelden"
                        font.family: root.fontName
                        font.pixelSize: 15 * root.s
                        font.bold: true
                        onClicked: root.doLogin()
                        contentItem: Text {
                            text: loginButton.text
                            font: loginButton.font
                            color: "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle {
                            radius: height / 2
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: root.cAccent }
                                GradientStop { position: 1.0; color: Qt.darker(root.cAccent2, 1.15) }
                            }
                            opacity: loginButton.down ? 0.75 : (loginButton.hovered ? 0.9 : 1.0)
                        }
                    }
                }
            }
        }

        // ── Leiste unten: Sitzung, Tastatur, Neustart, Aus ─────
        Row {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 28 * root.s
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10 * root.s

            RiceCombo {
                id: sessionBox
                width: 260 * root.s
                height: 40 * root.s
                model: typeof sessionModel !== "undefined" && sessionModel ? sessionModel : []
                textRole: "name"
                Component.onCompleted: {
                    var i = find(root.cfg("preferredSession", "Gentoo-rice"), Qt.MatchContains)
                    if (i < 0)
                        i = find("Hyprland", Qt.MatchContains)
                    if (i < 0 && typeof sessionModel !== "undefined" && sessionModel)
                        i = sessionModel.lastIndex
                    currentIndex = Math.max(0, i)
                }
            }

            PillButton {
                text: root.layoutName
                font.bold: true
                enabled: root.layoutCount > 1
                onClicked: {
                    if (root.layoutCount > 1)
                        keyboard.currentLayout = (keyboard.currentLayout + 1) % root.layoutCount
                }
            }

            PillButton {
                text: "Neustart"
                enabled: typeof sddm === "undefined" || !sddm || sddm.canReboot
                onClicked: {
                    if (typeof sddm !== "undefined" && sddm)
                        sddm.reboot()
                }
            }
            PillButton {
                text: "Herunterfahren"
                enabled: typeof sddm === "undefined" || !sddm || sddm.canPowerOff
                onClicked: {
                    if (typeof sddm !== "undefined" && sddm)
                        sddm.powerOff()
                }
            }
        }
    }

    // ── Zustand ───────────────────────────────────────────────
    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    // Beim allerersten Start kennt SDDM keinen "letzten Benutzer" → ersten Benutzer der Liste nehmen
    readonly property string userName: userBox.visible ? userBox.currentText : ((typeof userModel !== "undefined" && userModel && userModel.lastUser) ? userModel.lastUser : userBox.currentText)
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
            sddm.login(root.userName, password.text, sessionBox.currentIndex)
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

// Gentoo-rice – SDDM-Theme (Qt 6)
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
    readonly property color cBg: cfg("bg", "#16131f")
    readonly property color cFg: cfg("fg", "#f2f0f8")
    readonly property color cAccent: cfg("accent", "#7aa2f7")
    readonly property color cAccent2: cfg("accent2", "#bb9af7")
    readonly property color cMuted: cfg("muted", "#4a4458")
    readonly property string fontName: cfg("font", "JetBrains Mono")
    readonly property real s: Math.max(0.6, Math.min(width / 1920, height / 1080))

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
            color: root.cAccent
            font.pixelSize: 14 * root.s
        }
        background: Rectangle {
            radius: height / 2
            color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.55)
            border.width: 1
            border.color: combo.activeFocus ? root.cAccent : Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.15)
        }
        delegate: ItemDelegate {
            id: entry
            required property int index
            required property string name
            width: combo.width
            highlighted: combo.highlightedIndex === index
            contentItem: Text {
                text: entry.name
                color: entry.highlighted ? root.cBg : root.cFg
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
                color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.92)
                border.width: 1
                border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.6)
            }
        }
    }

    // ── Hintergrund: vorab weichgezeichnetes Wallpaper ─────────
    Image {
        id: bgImage
        anchors.fill: parent
        source: "file://" + root.cfg("background", "")
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.25) }
            GradientStop { position: 1.0; color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.65) }
        }
    }

    // ── Uhr + Datum ───────────────────────────────────────────
    property date now: new Date()
    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.12
        spacing: 4 * root.s
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(root.now, "HH:mm")
            color: root.cFg
            font.family: root.fontName
            font.pixelSize: 132 * root.s
            font.weight: Font.ExtraBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale("de_DE").toString(root.now, "dddd, d. MMMM")
            color: root.cAccent
            font.family: root.fontName
            font.pixelSize: 24 * root.s
        }
    }

    // ── Login-Karte ───────────────────────────────────────────
    property string userName: userBox.visible ? userBox.currentText : (typeof userModel !== "undefined" && userModel && userModel.lastUser ? userModel.lastUser : "")
    property string errorText: ""

    function doLogin() {
        root.errorText = ""
        if (typeof sddm !== "undefined" && sddm)
            sddm.login(root.userName, password.text, sessionBox.currentIndex)
    }

    Rectangle {
        id: card
        width: 420 * root.s
        height: content.implicitHeight + 56 * root.s
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: parent.height * 0.44
        radius: 22 * root.s
        color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.55)
        border.width: 2
        border.color: Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.55)

        SequentialAnimation {
            id: shake
            loops: 2
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: -14; duration: 45 }
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 14; duration: 90 }
            NumberAnimation { target: card; property: "anchors.horizontalCenterOffset"; to: 0; duration: 45 }
        }

        Column {
            id: content
            anchors.top: parent.top
            anchors.topMargin: 28 * root.s
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 56 * root.s
            spacing: 14 * root.s

            // runder Avatar (rund zugeschnitten von scripts/sddm-sync.sh)
            Item {
                width: 112 * root.s
                height: width
                anchors.horizontalCenter: parent.horizontalCenter
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: root.cMuted
                    border.width: 3
                    border.color: root.cAccent
                }
                Image {
                    anchors.fill: parent
                    anchors.margins: 5 * root.s
                    source: "file://" + root.cfg("avatar", "")
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    cache: false
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !userBox.visible
                text: root.userName
                color: root.cFg
                font.family: root.fontName
                font.pixelSize: 20 * root.s
                font.bold: true
            }

            RiceCombo {
                id: userBox
                width: parent.width
                visible: typeof userModel !== "undefined" && userModel && userModel.count > 1
                model: typeof userModel !== "undefined" && userModel ? userModel : []
                textRole: "name"
                height: 44 * root.s
                currentIndex: typeof userModel !== "undefined" && userModel ? Math.max(0, userModel.lastIndex) : 0
                font.family: root.fontName
            }

            TextField {
                id: password
                width: parent.width
                height: 50 * root.s
                echoMode: TextInput.Password
                passwordCharacter: "●"
                placeholderText: "Passwort …"
                placeholderTextColor: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.5)
                color: root.cFg
                font.family: root.fontName
                font.pixelSize: 16 * root.s
                horizontalAlignment: TextInput.AlignHCenter
                focus: true
                background: Rectangle {
                    radius: height / 2
                    color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.08)
                    border.width: 2
                    border.color: password.activeFocus ? root.cAccent : Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.15)
                }
                Keys.onReturnPressed: root.doLogin()
                Keys.onEnterPressed: root.doLogin()
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.errorText !== "" || (typeof keyboard !== "undefined" && keyboard && keyboard.capsLock)
                text: root.errorText !== "" ? root.errorText : "Feststelltaste ist aktiv"
                color: root.errorText !== "" ? "#ff5577" : root.cAccent2
                font.family: root.fontName
                font.pixelSize: 13 * root.s
            }

            Button {
                id: loginButton
                width: parent.width
                height: 46 * root.s
                text: "Anmelden"
                font.family: root.fontName
                font.pixelSize: 15 * root.s
                font.bold: true
                onClicked: root.doLogin()
                contentItem: Text {
                    text: loginButton.text
                    font: loginButton.font
                    color: root.cBg
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: height / 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.cAccent }
                        GradientStop { position: 1.0; color: root.cAccent2 }
                    }
                    opacity: loginButton.down ? 0.75 : (loginButton.hovered ? 0.92 : 1.0)
                }
            }
        }
    }

    // ── Leiste unten: Sitzung, Tastatur, Neustart, Aus ─────────
    Row {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28 * root.s
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12 * root.s

        RiceCombo {
            id: sessionBox
            width: 260 * root.s
            height: 40 * root.s
            model: typeof sessionModel !== "undefined" && sessionModel ? sessionModel : []
            textRole: "name"
            font.family: root.fontName
            Component.onCompleted: {
                var i = find(root.cfg("preferredSession", "Gentoo-rice"), Qt.MatchContains)
                if (i < 0)
                    i = find("Hyprland", Qt.MatchContains)
                if (i < 0 && typeof sessionModel !== "undefined" && sessionModel)
                    i = sessionModel.lastIndex
                currentIndex = Math.max(0, i)
            }
        }

        Rectangle {
            width: 56 * root.s
            height: 40 * root.s
            radius: height / 2
            color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.55)
            border.width: 1
            border.color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.15)
            Text {
                anchors.centerIn: parent
                text: "DE"
                color: root.cFg
                font.family: root.fontName
                font.pixelSize: 14 * root.s
                font.bold: true
            }
        }

        Repeater {
            model: [
                { label: "Neustart", action: "reboot" },
                { label: "Herunterfahren", action: "poweroff" }
            ]
            delegate: Button {
                id: pbtn
                required property var modelData
                height: 40 * root.s
                text: modelData.label
                font.family: root.fontName
                font.pixelSize: 14 * root.s
                enabled: typeof sddm === "undefined" || !sddm || (modelData.action === "reboot" ? sddm.canReboot : sddm.canPowerOff)
                onClicked: {
                    if (typeof sddm === "undefined" || !sddm)
                        return
                    if (modelData.action === "reboot")
                        sddm.reboot()
                    else
                        sddm.powerOff()
                }
                contentItem: Text {
                    text: pbtn.text
                    font: pbtn.font
                    color: root.cFg
                    leftPadding: 10 * root.s
                    rightPadding: 10 * root.s
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: height / 2
                    color: pbtn.hovered ? Qt.rgba(root.cAccent.r, root.cAccent.g, root.cAccent.b, 0.35) : Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.55)
                    border.width: 1
                    border.color: Qt.rgba(root.cFg.r, root.cFg.g, root.cFg.b, 0.15)
                }
            }
        }
    }

    // ── Rückmeldungen von SDDM ────────────────────────────────
    Connections {
        target: typeof sddm !== "undefined" && sddm ? sddm : null
        ignoreUnknownSignals: true
        function onLoginFailed() {
            root.errorText = "Falsches Passwort"
            password.text = ""
            password.forceActiveFocus()
            shake.start()
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}

/* Darkroot OS – Diashow während der Installation */
import QtQuick
import calamares.slideshow 1.0

Presentation {
    id: presentation
    function nextSlide() { presentation.goToNextSlide() }
    Timer {
        interval: 7000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: nextSlide()
    }
    Slide {
        Rectangle { anchors.fill: parent; color: "#0b0b10" }
        Text {
            anchors.centerIn: parent
            text: "Darkroot OS\nGentoo + Hyprland – dein System, dein Code."
            color: "#e6edf7"; font.pixelSize: 26; horizontalAlignment: Text.AlignHCenter
        }
    }
    Slide {
        Rectangle { anchors.fill: parent; color: "#0b0b10" }
        Text {
            anchors.centerIn: parent
            text: "Nach dem ersten Login installiert sich das Gentoo-rice:\nHyprland, Waybar, Themes, Mac-Login, Apps."
            color: "#e6edf7"; font.pixelSize: 22; horizontalAlignment: Text.AlignHCenter
        }
    }
    Slide {
        Rectangle { anchors.fill: parent; color: "#0b0b10" }
        Text {
            anchors.centerIn: parent
            text: "Super + D – Rice-Menü\nSuper + Leertaste – Apps\nSuper + Enter – Terminal"
            color: "#e6edf7"; font.pixelSize: 22; horizontalAlignment: Text.AlignHCenter
        }
    }
    function onActivate() { }
    function onLeave() { }
}

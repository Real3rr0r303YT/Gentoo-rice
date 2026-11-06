#!/usr/bin/env python3
"""Rendert ein SDDM-Theme ohne SDDM (Attrappen für sddm, userModel, sessionModel, keyboard, config).

Nutzung:
    pip install PySide6-Essentials
    QT_QPA_PLATFORM=offscreen python3 tools/sddm-preview.py sddm/gentoo-rice vorschau.png [theme.conf.user]

Beendet sich mit Code 1, wenn QML-Fehler oder JavaScript-Laufzeitfehler auftreten (für CI).
"""
import configparser
import warnings
import os
import sys

from PySide6.QtCore import (QAbstractListModel, QByteArray, QModelIndex, QObject, Property, Qt, QTimer,
                            QUrl, Signal, Slot, qInstallMessageHandler)
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlPropertyMap
from PySide6.QtQuick import QQuickView

theme_dir = os.path.abspath(sys.argv[1])
out = sys.argv[2] if len(sys.argv) > 2 else "sddm-preview.png"
conf_user = sys.argv[3] if len(sys.argv) > 3 else ""

problems = []


def on_message(mode, ctx, msg):
    if any(k in msg for k in ("TypeError", "ReferenceError", "Error:", "is not defined", "Cannot assign")):
        problems.append(msg)
    print(msg, file=sys.stderr)


qInstallMessageHandler(on_message)
warnings.simplefilter("ignore", DeprecationWarning)
app = QGuiApplication(sys.argv)


class ListModel(QAbstractListModel):
    def __init__(self, names, last):
        super().__init__()
        self._n, self._last = names, last

    def rowCount(self, parent=QModelIndex()):
        return len(self._n)

    def data(self, idx, role):
        return self._n[idx.row()] if role == Qt.UserRole + 1 else None

    def roleNames(self):
        return {Qt.UserRole + 1: QByteArray(b"name")}

    @Property(int, constant=True)
    def count(self):
        return len(self._n)

    @Property(int, constant=True)
    def lastIndex(self):
        return self._last

    @Property(str, constant=True)
    def lastUser(self):
        return self._n[self._last]


class Sddm(QObject):
    loginFailed = Signal()
    loginSucceeded = Signal()

    @Property(bool, constant=True)
    def canReboot(self):
        return True

    @Property(bool, constant=True)
    def canPowerOff(self):
        return True

    @Slot(str, str, int)
    def login(self, user, password, session):
        print(f"login({user}, ***, {session})")

    @Slot()
    def reboot(self):
        pass

    @Slot()
    def powerOff(self):
        pass


class Keyboard(QObject):
    @Property(bool, constant=True)
    def capsLock(self):
        return False


config = QQmlPropertyMap()
cp = configparser.ConfigParser()
cp.optionxform = str
cp.read([os.path.join(theme_dir, "theme.conf")] + ([conf_user] if conf_user else []))
for k, v in cp["General"].items():
    config.insert(k, v)

MOCKS = {
    "config": config,
    "userModel": ListModel(["benutzer"], 0),
    "sessionModel": ListModel(["Hyprland", "Hyprland (Gentoo-rice)"], 0),
    "sddm": Sddm(),
    "keyboard": Keyboard(),
}
view = QQuickView()
for name, obj in MOCKS.items():
    view.rootContext().setContextProperty(name, obj)
view.setResizeMode(QQuickView.SizeRootObjectToView)
view.resize(1600, 900)
view.setSource(QUrl.fromLocalFile(os.path.join(theme_dir, "Main.qml")))
for e in view.errors():
    problems.append(e.toString())
view.show()


def finish():
    view.grabWindow().save(out)
    print("Vorschau:", out)
    app.exit(1 if problems else 0)


QTimer.singleShot(1500, finish)
code = app.exec()
if problems:
    print(f"{len(problems)} Problem(e) in {theme_dir}", file=sys.stderr)
sys.exit(code)

#!/usr/bin/env python3
# Adds the Radiojoy lock screen to a clone of Omarchy's built-in lock plugin:
# a clock column, full-body Alastor / Emily art at the sides (following the lock
# background), and a background that steps along the wallpaper order on every lock.
# Usage: patch-lock.py <plugin-dir> [--check]   (--check only tests that it applies)
# Nothing is written unless every change applies; exits 1 if the lock code changed
# too much (newer Omarchy), leaving the stock lock alone.
import sys
from pathlib import Path

plugin = Path(sys.argv[1])
check = "--check" in sys.argv
BIN = '\\"$HOME/.local/bin/radiojoy-lock-background\\"'

VIEW_BLOCK = '''    // Radiojoy Week: today's prompt under the tagline (theme file radiojoy-week.txt).
    FileView {
      id: weekFile
      path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/radiojoy-week.txt"
      blockLoading: true
      watchChanges: true
      onFileChanged: reload()
    }
    readonly property string weekPrompt: {
      var day = Qt.formatDate(lockDecor.now, "yyyy-MM-dd") + "\t"
      var lines = String(weekFile.text() || "").split("\n")
      for (var i = 0; i < lines.length; i++)
        if (lines[i].indexOf(day) === 0) return lines[i].slice(day.length).trim()
      return ""
    }
    // Radiojoy (omarchy-radiojoy): full-body art at the sides when the theme ships it,
    // following the lock background (Alastor / Emily / both).
    readonly property string themeDir: "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/"
    readonly property bool hasSideArt: leftArt.status === Image.Ready || rightArt.status === Image.Ready
    readonly property string artMode: {
      var p = String(root.backgroundPath)
      return /-alastor\\.[a-z]+$/.test(p) ? "alastor-" : (/-emily\\.[a-z]+$/.test(p) ? "emily-" : "")
    }

    Image {
      id: leftArt
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      anchors.leftMargin: Math.round(parent.width * 0.04)
      width: Math.round(parent.width * 0.3)
      height: Math.round(parent.height * 0.93)
      source: lockStage.themeDir + "lock-" + lockStage.artMode + "left.png"
      cache: false
      fillMode: Image.PreserveAspectFit
      horizontalAlignment: Image.AlignLeft
      verticalAlignment: Image.AlignBottom
      smooth: true
      mipmap: true
      visible: status === Image.Ready
    }

    Image {
      id: rightArt
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.rightMargin: Math.round(parent.width * 0.02)
      width: Math.round(parent.width * 0.3)
      // Alastor's two forms are both tall full-body figures; give them the same height
      height: Math.round(parent.height * (lockStage.artMode === "alastor-" ? 0.93 : 0.8))
      source: lockStage.themeDir + "lock-" + lockStage.artMode + "right.png"
      cache: false
      fillMode: Image.PreserveAspectFit
      horizontalAlignment: Image.AlignRight
      verticalAlignment: Image.AlignBottom
      smooth: true
      mipmap: true
      visible: status === Image.Ready
    }

    // Keeps the clock readable over bright wallpapers.
    Rectangle {
      visible: lockStage.hasSideArt
      anchors.fill: lockDecor
      anchors.margins: -Math.round(root.height * 0.02)
      radius: Style.cornerRadius
      color: Commons.Color.lock.background
      opacity: 0.6
    }

    Column {
      id: lockDecor
      visible: lockStage.hasSideArt
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: inputField.top
      anchors.bottomMargin: Math.round(root.height * 0.05)
      spacing: Math.round(root.height * 0.012)

      property date now: new Date()
      Timer {
        interval: 1000
        running: lockDecor.visible
        repeat: true
        onTriggered: lockDecor.now = new Date()
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: Qt.formatTime(lockDecor.now, "HH:mm")
        color: Commons.Color.lock.text
        font.family: Style.font.family
        font.pixelSize: Math.round(root.height * 0.11)
        font.weight: Font.Light
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: Qt.formatDate(lockDecor.now, "dddd d MMMM")
        color: Commons.Color.lock.text
        opacity: 0.75
        font.family: Style.font.family
        font.pixelSize: Math.round(root.height * 0.025)
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: lockStage.artMode === "alastor-" ? "~ stay tuned ~"
          : lockStage.artMode === "emily-" ? "~ have a heavenly day ~" : "~ stay tuned, my angel ~"
        color: lockStage.artMode === "emily-" ? "#c8ccff" : "#ff6f8a"
        font.family: Style.font.family
        font.italic: true
        font.pixelSize: Math.round(root.height * 0.022)
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: lockStage.weekPrompt !== ""
        textFormat: Text.PlainText
        text: "\u2605 Radiojoy Week \u00b7 " + lockStage.weekPrompt
        color: "#f2c14e"
        font.family: Style.font.family
        font.pixelSize: Math.round(root.height * 0.022)
      }
    }

'''

PATCHES = {
    "LockView.qml": [
        ("import QtQuick.Effects\n", "import QtQuick.Effects\nimport Quickshell\nimport Quickshell.Io\n"),
        ("  Rectangle {\n    anchors.fill: parent\n    color: Commons.Color.background\n",
         "  Rectangle {\n    id: lockStage\n    anchors.fill: parent\n    color: Commons.Color.background\n"),
        ("    BorderSurface {\n      id: inputField\n", VIEW_BLOCK + "    BorderSurface {\n      id: inputField\n"),
    ],
    "Service.qml": [
        ("  function refreshBackground() {\n",
         "  // Radiojoy: the next lock steps the background along the wallpaper order.\n"
         "  property bool advanceBackground: false\n  function refreshBackground() {\n"),
        ("    Qt.callLater(function() {\n      root.refreshBackground()\n",
         "    Qt.callLater(function() {\n      root.advanceBackground = true\n      root.refreshBackground()\n"),
        ('    command: ["readlink", "-f", root.currentBackgroundLink]\n',
         '    command: ["bash", "-c", "' + BIN + ' " + (root.advanceBackground ? "next" : "")]\n'),
        ('        var next = String(text || "").trim()\n',
         '        root.advanceBackground = false\n        var next = String(text || "").trim()\n'),
    ],
}

out = {}
for name, edits in PATCHES.items():
    path = plugin / name
    if not path.exists():
        sys.exit(f"patch-lock: {path} missing")
    text = path.read_text()
    if "Radiojoy" in text:
        sys.exit(f"patch-lock: {name} is already patched")
    for old, new in edits:
        if text.count(old) != 1:
            sys.exit(f"patch-lock: {name}: expected code not found (Omarchy's lock changed): {old.strip()[:60]!r}")
        text = text.replace(old, new)
    out[path] = text

if not check:
    for path, text in out.items():
        path.write_text(text)
print("patch-lock: ok" + (" (check only)" if check else ""))

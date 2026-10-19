import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Radiojoy: only visible while the radiojoy theme is active. Follows the wallpaper:
// NN-alastor.* / NN-emily.* show that character's icons and quotes, anything else both.
// Left-click: next theme wallpaper. Right-click: a random line from the matching quotes.
BarWidget {
  id: root
  moduleName: "radiojoy.button"
  property bool rjActive: false
  property string rjWho: ""   // "-alastor", "-emily" or "" (both)
  visible: rjActive
  implicitWidth: visible ? btn.implicitWidth : 0
  implicitHeight: visible ? btn.implicitHeight : 0

  function sh(cmd) { runner.command = ["bash", "-c", cmd]; runner.running = true }

  Process { id: runner }
  Process {
    id: themeCheck
    command: ["bash", "-c", "{ test -f ~/.local/state/omarchy/current/theme/radiojoy && echo radiojoy || echo other; }; readlink -f ~/.local/state/omarchy/current/background"]
    stdout: StdioCollector {
      onStreamFinished: {
        var out = text.trim().split("\n")
        root.rjActive = out[0] === "radiojoy"
        var bg = out.length > 1 ? out[1] : ""
        root.rjWho = /-alastor\.[a-z]+$/.test(bg) ? "-alastor" : (/-emily\.[a-z]+$/.test(bg) ? "-emily" : "")
      }
    }
  }
  Timer {
    interval: 1000; repeat: true; running: true; triggeredOnStart: true
    onTriggered: themeCheck.running = true
  }

  WidgetButton {
    id: btn
    bar: root.bar
    text: root.rjWho === "-alastor" ? "󰐹 󰱯" : (root.rjWho === "-emily" ? "󰛓 󰙴" : "󰐹 󰋑 󰛓")
    tooltipText: (root.rjWho === "-alastor" ? "Alastor" : (root.rjWho === "-emily" ? "Emily" : "Radiojoy")) + " — left: next wallpaper · right: tune in"
    onPressed: function(button) {
      if (button === Qt.RightButton)
        root.sh("d=~/.local/state/omarchy/current/theme/splash; f=$d/quotes" + root.rjWho + ".txt; [[ -s $f ]] || f=$d/quotes.txt; q=$(shuf -n1 \"$f\") && notify-send -a Radiojoy 'Now broadcasting' \"$q\"")
      else
        root.sh("omarchy theme bg next")
    }
  }
}

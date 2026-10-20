import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Radiojoy: only visible while the radiojoy theme is active. Follows the wallpaper:
// NN-alastor.* / NN-emily.* show that character's icons and quotes, anything else both.
// During Radiojoy Week (theme file radiojoy-week.txt) it wears a star and shows the
// day's prompt; while Spotify plays it goes "on air".
// Left-click: next theme wallpaper (during the week: check for new art and update
// the collage, radiojoy-week --update).
// Right-click: a random line from the matching quotes.
BarWidget {
  id: root
  moduleName: "radiojoy.button"
  property bool rjActive: false
  property string rjWho: ""     // "-alastor", "-emily" or "" (both)
  property bool rjOnAir: false  // Spotify is playing
  property string rjWeek: ""    // today's Radiojoy Week prompt, if any
  visible: rjActive
  implicitWidth: visible ? btn.implicitWidth : 0
  implicitHeight: visible ? btn.implicitHeight : 0

  readonly property string themeDir: "~/.local/state/omarchy/current/theme"

  function sh(cmd) { runner.command = ["bash", "-c", cmd]; runner.running = true }

  Process { id: runner }
  Process {
    id: stateCheck
    // one line each: theme, wallpaper, Spotify status, today's week prompt
    command: ["bash", "-c",
      "t=" + root.themeDir + "; { test -f $t/radiojoy && echo radiojoy || echo other; }; " +
      "readlink -f ~/.local/state/omarchy/current/background; " +
      "playerctl -p spotify status 2>/dev/null || echo none; " +
      "grep -s \"^$(date +%F)\t\" $t/radiojoy-week.txt | cut -f2-; true"]
    stdout: StdioCollector {
      onStreamFinished: {
        var out = text.split("\n")
        root.rjActive = out[0] === "radiojoy"
        var bg = out.length > 1 ? out[1] : ""
        root.rjWho = /-alastor\.[a-z]+$/.test(bg) ? "-alastor" : (/-emily\.[a-z]+$/.test(bg) ? "-emily" : "")
        root.rjOnAir = out.length > 2 && out[2].trim() === "Playing"
        root.rjWeek = out.length > 3 ? out[3].trim() : ""
      }
    }
  }
  Timer {
    interval: 1000; repeat: true; running: true; triggeredOnStart: true
    onTriggered: stateCheck.running = true
  }
  // The shell starts with the theme's base colours; re-apply the wallpaper's palette.
  Timer {
    interval: 2500; running: true
    onTriggered: if (root.rjActive) root.sh("\"$HOME/.local/bin/radiojoy-sync\"")
  }

  WidgetButton {
    id: btn
    bar: root.bar
    active: root.rjOnAir
    text: (root.rjWho === "-alastor" ? "󰐹 󰱯" : (root.rjWho === "-emily" ? "󰛓 󰙴" : "󰐹 󰋑 󰛓"))
      + (root.rjWeek ?  " 󰓎" : "") + (root.rjOnAir ? " 󰑊" : "")
    tooltipText: (root.rjWho === "-alastor" ? "Alastor" : (root.rjWho === "-emily" ? "Emily" : "Radiojoy"))
      + (root.rjOnAir ? " · ON AIR" : "")
      + (root.rjWeek ? "\n★ Radiojoy Week · " + root.rjWeek : "")
      + (root.rjWeek ? "\nleft: check for new art · right: tune in" : "\nleft: next wallpaper · right: tune in")
    onPressed: function(button) {
      if (button === Qt.RightButton)
        root.sh("d=" + root.themeDir + "/splash; f=$d/quotes" + root.rjWho + ".txt; [[ -s $f ]] || f=$d/quotes.txt; q=$(shuf -n1 \"$f\"); " +
          (root.rjWeek
            ? "notify-send -a Radiojoy '★ Radiojoy Week' \"" + root.rjWeek + "\n$q\""
            : "notify-send -a Radiojoy 'Now broadcasting' \"$q\""))
      else if (root.rjWeek)
        root.sh("\"$HOME/.local/bin/radiojoy-week\" --update")
      else
        root.sh("omarchy theme bg next")
    }
  }
}

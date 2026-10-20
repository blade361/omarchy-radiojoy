import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui

// Radiojoy: only visible while the radiojoy theme is active. Follows the wallpaper:
// NN-alastor.* / NN-emily.* show that character's icons and quotes, anything else both.
// During Radiojoy Week (theme file radiojoy-week.txt) it wears a star and shows the
// day's prompt; while Spotify plays it goes "on air".
// Left-click: next theme wallpaper (during the week: check for new art and update
// the collage, radiojoy-week --update).
// Right-click: a random line from the matching quotes.
// Middle-click: the credits page (every artist's piece, with a link to the post).
// No polling: an inotify watch on ~/.local/state/omarchy/current (wallpaper and
// theme swaps), Spotify from MPRIS, and a once-a-minute check for the date.
BarWidget {
  id: root
  moduleName: "radiojoy.button"
  property bool rjActive: false
  property string rjWho: ""     // "-alastor", "-emily" or "" (both)
  readonly property bool rjOnAir: {  // Spotify is playing
    var ps = Mpris.players ? Mpris.players.values : []
    for (var i = 0; i < ps.length; i++)
      if (ps[i].isPlaying && /spotify/i.test(ps[i].identity || ps[i].desktopEntry || "")) return true
    return false
  }
  property string rjWeek: ""    // today's Radiojoy Week prompt, if any
  visible: rjActive
  implicitWidth: visible ? btn.implicitWidth : 0
  implicitHeight: visible ? btn.implicitHeight : 0

  readonly property string themeDir: "~/.local/state/omarchy/current/theme"

  function sh(cmd) { runner.command = ["bash", "-c", cmd]; runner.running = true }

  Process { id: runner }
  Process {
    id: stateCheck
    // one line each: theme, wallpaper, today's week prompt
    command: ["bash", "-c",
      "t=" + root.themeDir + "; { test -f $t/radiojoy && echo radiojoy || echo other; }; " +
      "readlink -f ~/.local/state/omarchy/current/background; " +
      "grep -s \"^$(date +%F)\t\" $t/radiojoy-week.txt | cut -f2-; true"]
    stdout: StdioCollector {
      onStreamFinished: {
        var out = text.split("\n")
        root.rjActive = out[0] === "radiojoy"
        var bg = out.length > 1 ? out[1] : ""
        root.rjWho = /-alastor\.[a-z]+$/.test(bg) ? "-alastor" : (/-emily\.[a-z]+$/.test(bg) ? "-emily" : "")
        root.rjWeek = out.length > 2 ? out[2].trim() : ""
      }
    }
  }
  function refresh() { if (!stateCheck.running) stateCheck.running = true; else again.restart() }
  Timer { id: again; interval: 300; onTriggered: root.refresh() }
  // wallpaper or theme swapped: both are symlink/dir renames in current/
  Process {
    id: watcher
    running: true
    command: ["bash", "-c", "exec inotifywait -m -q -e create,moved_to,delete ~/.local/state/omarchy/current"]
    stdout: SplitParser { onRead: function() { settle.restart() } }
  }
  Timer { id: settle; interval: 150; onTriggered: root.refresh() }
  // the date (today's prompt), and a fallback if inotifywait isn't installed
  Timer {
    interval: watcher.running ? 60000 : 3000; repeat: true; running: true; triggeredOnStart: true
    onTriggered: root.refresh()
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
      + (root.rjWeek ? "\nleft: check for new art · middle: credits · right: tune in"
                     : "\nleft: next wallpaper · middle: credits · right: tune in")
    onPressed: function(button) {
      if (button === Qt.RightButton)
        root.sh("d=" + root.themeDir + "/splash; f=$d/quotes" + root.rjWho + ".txt; [[ -s $f ]] || f=$d/quotes.txt; q=$(shuf -n1 \"$f\"); " +
          (root.rjWeek
            ? "notify-send -a Radiojoy '★ Radiojoy Week' \"" + root.rjWeek + "\n$q\""
            : "notify-send -a Radiojoy 'Now broadcasting' \"$q\""))
      else if (button === Qt.MiddleButton)
        root.sh("\"$HOME/.local/bin/radiojoy-week\" --credits")
      else if (root.rjWeek)
        root.sh("\"$HOME/.local/bin/radiojoy-week\" --update")
      else
        root.sh("omarchy theme bg next")
    }
  }
}

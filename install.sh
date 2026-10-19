#!/bin/bash
# omarchy-radiojoy installer. Run from the repo: ./install.sh
#   --no-lock     keep your current lock screen
#   --no-splash   don't add the terminal splash to ~/.bashrc
#   --no-spotify  skip the Spicetify extension
#   --files-only  only copy files (no packages, services, theme switch); for testing
set -euo pipefail

repo=$(cd "$(dirname "$0")" && pwd)
lock=1 splash=1 spotify=1 session=1
for arg in "$@"; do
  case $arg in
    --no-lock) lock= ;;
    --no-splash) splash= ;;
    --no-spotify) spotify= ;;
    --files-only) session= lock= spotify= ;;
    -h | --help) sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg" >&2; exit 1 ;;
  esac
done

say() { printf '\e[38;2;220;34;73m📻\e[0m %s\n' "$*"; }
warn() { printf '\e[38;2;242;193;78m!\e[0m %s\n' "$*" >&2; }

if [[ $session ]]; then
  command -v omarchy >/dev/null || { echo "This theme needs Omarchy (omarchy.org)." >&2; exit 1; }
  missing=()
  python3 -c 'import PIL' 2>/dev/null || missing+=(python-pillow)
  python3 -c 'import numpy' 2>/dev/null || missing+=(python-numpy)
  if (( ${#missing[@]} )); then
    say "Installing ${missing[*]} (draws the terminal art)"
    omarchy pkg add "${missing[@]}"
  fi
fi

themes=$HOME/.config/omarchy/themes
if [[ -d $themes/radiojoy && ! -f $themes/radiojoy/radiojoy ]]; then
  backup=$themes/radiojoy.bak.$(date +%Y%m%d%H%M%S)
  warn "An older 'radiojoy' theme was moved to $backup"
  mv "$themes/radiojoy" "$backup"
fi
say "Theme → $themes/radiojoy"
mkdir -p "$themes/radiojoy"
cp -r "$repo/theme/." "$themes/radiojoy/"

say "Scripts → ~/.local/bin"
mkdir -p "$HOME/.local/bin"
install -m 755 "$repo"/bin/radiojoy-* "$HOME/.local/bin/"

say "Hooks → ~/.config/omarchy/hooks"
mkdir -p "$HOME/.config/omarchy/hooks/theme-set.d" "$HOME/.config/omarchy/hooks/post-boot.d"
install -m 755 "$repo/hooks/theme-set-radiojoy" "$HOME/.config/omarchy/hooks/theme-set.d/radiojoy"
install -m 755 "$repo/hooks/post-boot-radiojoy" "$HOME/.config/omarchy/hooks/post-boot.d/radiojoy"

say "Bar button → ~/.config/omarchy/plugins/radiojoy.button"
mkdir -p "$HOME/.config/omarchy/plugins"
rm -rf "$HOME/.config/omarchy/plugins/radiojoy.button"
cp -r "$repo/plugins/radiojoy.button" "$HOME/.config/omarchy/plugins/"

say "Wallpaper watcher → ~/.config/systemd/user"
mkdir -p "$HOME/.config/systemd/user"
cp "$repo"/systemd/radiojoy-sync.* "$HOME/.config/systemd/user/"

if [[ $splash ]]; then
  if grep -q '>>> omarchy-radiojoy >>>' "$HOME/.bashrc" 2>/dev/null; then
    say "Terminal splash already in ~/.bashrc"
  else
    say "Terminal splash → ~/.bashrc"
    printf '\n' >>"$HOME/.bashrc"
    cat "$repo/install/bashrc-block.sh" >>"$HOME/.bashrc"
  fi
fi

if [[ $session ]]; then
  systemctl --user daemon-reload
  systemctl --user enable --now radiojoy-sync.path radiojoy-week.timer >/dev/null
  omarchy bar put radiojoy.button >/dev/null 2>&1 || warn "Couldn't add the bar button; add 'radiojoy.button' from the bar settings"
fi

if [[ $lock ]]; then
  user_lock=${USER:-$(id -un)}.lock
  clone=$HOME/.config/omarchy/plugins/$user_lock
  if [[ -d $clone ]]; then
    if grep -q Radiojoy "$clone/LockView.qml" 2>/dev/null; then
      say "Lock screen already has Radiojoy"
    else
      warn "You already have a custom lock screen ($user_lock); left it alone. See README → Lock screen."
    fi
  elif jq -e '(.disabledPlugins // []) | index("omarchy.lock")' "$HOME/.config/omarchy/shell.json" >/dev/null 2>&1; then
    warn "You already use a custom lock screen; left it alone. See README → Lock screen."
  elif python3 "$repo/install/patch-lock.py" "${OMARCHY_PATH:-/usr/share/omarchy}/shell/plugins/lock" --check >/dev/null; then
    say "Lock screen → $user_lock (a clone of Omarchy's lock with Radiojoy added)"
    omarchy plugin clone omarchy.lock >/dev/null
    if ! python3 "$repo/install/patch-lock.py" "$clone"; then
      warn "Patching failed; going back to Omarchy's lock"
      omarchy plugin remove "$user_lock" --yes >/dev/null 2>&1 || true
      omarchy plugin enable omarchy.lock >/dev/null 2>&1 || true
    fi
  else
    warn "This Omarchy version's lock screen changed; kept the stock lock (everything else works)"
  fi
fi

if [[ $spotify ]] && command -v spicetify >/dev/null; then
  say "Spotify colours → Spicetify extension radiojoy-follow.js"
  ext=$(dirname "$(spicetify -c)")/Extensions
  mkdir -p "$ext"
  cp "$repo/spicetify/radiojoy-follow.js" "$ext/"
  spicetify config extensions radiojoy-follow.js >/dev/null
  spicetify apply >/dev/null 2>&1 || warn "spicetify apply failed; run it yourself"
fi

if [[ $session ]]; then
  say "Switching to the Radiojoy theme"
  omarchy theme set radiojoy
  "$HOME/.local/bin/radiojoy-sync"
fi

say "Done! Open a new terminal, and click the radio on the bar for the next wallpaper."
say "Fan art isn't included; the README links the artists' Radiojoy pieces."

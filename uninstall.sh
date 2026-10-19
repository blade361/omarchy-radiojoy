#!/bin/bash
# Removes omarchy-radiojoy. Switch to another theme first (omarchy theme set <name>);
# your own screensaver and borders come back when you do.
set -uo pipefail

if [[ -f $HOME/.local/state/omarchy/current/theme/radiojoy ]]; then
  echo "Switch to another theme first, e.g.: omarchy theme set tokyo-night" >&2
  exit 1
fi

systemctl --user disable --now radiojoy-sync.path >/dev/null 2>&1
rm -f "$HOME"/.config/systemd/user/radiojoy-sync.{path,service}
systemctl --user daemon-reload

# reset terminal colours and Zen/Firefox colours while the scripts still exist
"$HOME/.local/bin/radiojoy-sync" >/dev/null 2>&1
rm -f "$HOME"/.local/bin/radiojoy-{sync,splash,splash-refresh,sixel,lock-background,term-colors}
rm -f "$HOME/.config/omarchy/hooks/theme-set.d/radiojoy" "$HOME/.config/omarchy/hooks/post-boot.d/radiojoy"
omarchy plugin disable radiojoy.button >/dev/null 2>&1
rm -rf "$HOME/.config/omarchy/plugins/radiojoy.button"

# the ~/.bashrc block between the markers
if [[ -f $HOME/.bashrc ]]; then
  sed -i '/^# >>> omarchy-radiojoy >>>$/,/^# <<< omarchy-radiojoy <<<$/d' "$HOME/.bashrc"
fi

user_lock=${USER:-$(id -un)}.lock
if grep -q Radiojoy "$HOME/.config/omarchy/plugins/$user_lock/LockView.qml" 2>/dev/null; then
  omarchy plugin remove "$user_lock" --yes >/dev/null 2>&1
  omarchy plugin enable omarchy.lock >/dev/null 2>&1
fi

if command -v spicetify >/dev/null; then
  spicetify config extensions radiojoy-follow.js- >/dev/null 2>&1 && spicetify apply >/dev/null 2>&1
fi

rm -rf "$HOME/.config/omarchy/themes/radiojoy" "${XDG_CACHE_HOME:-$HOME/.cache}/radiojoy-sixel"
rm -f "$HOME/.local/state/omarchy/radiojoy-border" "$HOME/.local/state/omarchy/radiojoy-lock-background" "$HOME/.local/state/omarchy/radiojoy-term-colors"
echo "omarchy-radiojoy removed."

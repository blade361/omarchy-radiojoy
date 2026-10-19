# >>> omarchy-radiojoy >>>
# Radiojoy terminal splash (only while the Radiojoy theme is active). The splash may
# be redrawn when the wallpaper changes until this terminal is used: the second
# prompt means Enter was pressed.
if [[ $- == *i* && -t 1 && -f ~/.local/state/omarchy/current/theme/radiojoy ]]; then
  ~/.local/bin/radiojoy-splash
fi
__radiojoy_used() {
  (( ++__radiojoy_prompts == 2 )) && rm -f "${XDG_RUNTIME_DIR:-/tmp}/radiojoy-splash/$(basename "$(tty)")"
}
PROMPT_COMMAND+=(__radiojoy_used)
# <<< omarchy-radiojoy <<<

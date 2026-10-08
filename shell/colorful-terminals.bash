# shellcheck shell=bash
# Colorful Terminals: tints the terminal background by project folder.
# Sourced from ~/.bashrc. Before each prompt it checks the current folder
# against ~/.config/colorful-terminals/projects.conf and sends OSC 11 (set
# background) or, when leaving a project, OSC 111 (back to the theme). A
# color is sent again at every prompt, so a terminal that reloaded its config
# (Omarchy's theme switch signals Ghostty and Kitty, and Alacritty watches its
# file) is back in its color at the next prompt. Inside tmux it colors the
# tmux pane instead, which tmux keeps per pane, so there it is set only once.
#
# Super+Ctrl+Alt+Shift+1…8 gives this one terminal a color of its own, which
# wins over project colors until Super+Ctrl+Alt+Shift+0 or the shell exits:
# the helper leaves the color in $_ct_request and Hyprland presses
# Ctrl+Alt+Shift+F12 in the focused terminal, which runs _ct_key here.

# shellcheck source=lib/config.bash
source "${BASH_SOURCE[0]%/*}/../lib/config.bash" || return 0

_ct_shown=${_ct_shown-}   # color on screen now; "" = theme color
_ct_paint=${_ct_paint-}   # this terminal's own color; "" = by project
_ct_request=${XDG_RUNTIME_DIR:+$XDG_RUNTIME_DIR/colorful-terminals/paint}

# Shows <color>, or the theme color for "".
_ct_apply() {
  local color=$1
  if [[ -n ${TMUX-} && -n ${TMUX_PANE-} ]]; then
    if [[ -n $color ]]; then
      command tmux set -p -t "$TMUX_PANE" window-style "bg=$color" \; \
        set -p -t "$TMUX_PANE" window-active-style "bg=$color" > /dev/null 2>&1
    else
      command tmux set -p -u -t "$TMUX_PANE" window-style \; \
        set -p -u -t "$TMUX_PANE" window-active-style > /dev/null 2>&1
    fi
  elif [[ -n $color ]]; then
    printf '\e]11;%s\a' "$color"
  else
    printf '\e]111\a'
  fi
}

# Shows this terminal's own color, or else the project color for $PWD.
_ct_show() {
  local want=$_ct_paint
  if [[ -z $want ]]; then
    _ct_load
    _ct_match_dir "$PWD"
    want=$_ct_match
  fi
  if [[ $want != "$_ct_shown" ]] || [[ -n $want && ( -z ${TMUX-} || -z ${TMUX_PANE-} ) ]]; then
    _ct_apply "$want"
    _ct_shown=$want
  fi
}

_ct_prompt() {
  local status=$?
  _ct_show
  return "$status"
}

# Takes the color the helper left and empties the file, which tells the
# helper this terminal got it.
_ct_key() {
  local color=""
  [[ -n $_ct_request && -r $_ct_request ]] || return 0
  IFS= read -r color < "$_ct_request"
  : >| "$_ct_request"
  if [[ $color == reset ]]; then
    _ct_paint=""
  elif [[ $color =~ ^#[0-9a-fA-F]{6}$ ]]; then
    _ct_paint=$color
  else
    return 0
  fi
  _ct_show
}

# Only for interactive shells that draw on a real terminal.
[[ $- == *i* && -t 1 && $TERM != linux && $TERM != dumb ]] || return 0

# Sourcing ~/.bashrc again must not add the hook twice.
if [[ " ${PROMPT_COMMAND[*]} " != *_ct_prompt* ]]; then
  PROMPT_COMMAND="_ct_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

# Ctrl+Alt+Shift+F12, in every keymap.
for _ct_keymap in emacs vi-insert vi-command; do
  bind -m "$_ct_keymap" -x '"\e[24;8~": _ct_key' 2> /dev/null
done
unset _ct_keymap

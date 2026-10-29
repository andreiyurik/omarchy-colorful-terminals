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
# wins over project colors until Super+Ctrl+Alt+Shift+0 or the shell exits.
# At a prompt the helper leaves the color in $_ct_request and Hyprland presses
# Ctrl+Alt+Shift+F12 in the focused terminal, which runs _ct_key here. While a
# program runs, the helper colors the terminal itself and leaves the color in
# $_ct_inbox, this terminal's own file, which the next prompt takes.

# shellcheck source=lib/config.bash
source "${BASH_SOURCE[0]%/*}/../lib/config.bash" || return 0

_ct_shown=${_ct_shown-}   # color on screen now; "" = theme color
_ct_paint=${_ct_paint-}   # this terminal's own color; "" = by project
_ct_request=${XDG_RUNTIME_DIR:+$XDG_RUNTIME_DIR/colorful-terminals/paint}
_ct_inbox=${_ct_inbox-}

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
  [[ -z $_ct_inbox || ! -s $_ct_inbox ]] || _ct_take "$_ct_inbox"
  _ct_show
  return "$status"
}

# Takes the color the helper left in <file> and empties the file, which tells
# the helper this terminal got it. Fails if there was no color.
_ct_take() {
  local color=""
  [[ -r $1 ]] || return 1
  IFS= read -r color < "$1"
  : >| "$1"
  if [[ $color == reset ]]; then
    _ct_paint=""
  elif [[ $color =~ ^#[0-9a-fA-F]{6}$ ]]; then
    _ct_paint=$color
  else
    return 1
  fi
}

_ct_key() {
  [[ -n $_ct_request ]] && _ct_take "$_ct_request" && _ct_show
  return 0
}

# Only for interactive shells that draw on a real terminal.
[[ $- == *i* && -t 1 && $TERM != linux && $TERM != dumb ]] || return 0

# This terminal's file, named after its tty: /dev/pts/3 is tty/pts-3. A color
# left there for an earlier terminal on the same tty is not ours.
if [[ -z $_ct_inbox && -n $_ct_request ]] && _ct_tty=$(tty 2> /dev/null) && [[ $_ct_tty == /dev/* ]]; then
  _ct_tty=${_ct_tty#/dev/}
  _ct_inbox=${_ct_request%/*}/tty/${_ct_tty//\//-}
  [[ ! -s $_ct_inbox ]] || : >| "$_ct_inbox"
fi
unset _ct_tty

# Sourcing ~/.bashrc again must not add the hook twice.
if [[ " ${PROMPT_COMMAND[*]} " != *_ct_prompt* ]]; then
  PROMPT_COMMAND="_ct_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

# Ctrl+Alt+Shift+F12, in every keymap.
for _ct_keymap in emacs vi-insert vi-command; do
  bind -m "$_ct_keymap" -x '"\e[24;8~": _ct_key' 2> /dev/null
done
unset _ct_keymap

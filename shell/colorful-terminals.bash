# shellcheck shell=bash
# Colorful Terminals: tints the terminal background by project folder.
# Sourced from ~/.bashrc. Before each prompt it checks the current folder
# against ~/.config/colorful-terminals/projects.conf and, only when the color
# should change, sends OSC 11 (set background) or OSC 111 (back to the theme).
# Inside tmux it colors the tmux pane instead, which tmux keeps per pane.

# shellcheck source=lib/config.bash
source "${BASH_SOURCE[0]%/*}/../lib/config.bash" || return 0

_ct_shown=${_ct_shown-}   # color on screen now; "" = theme color

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

_ct_prompt() {
  local status=$?
  _ct_load
  _ct_match_dir "$PWD"
  if [[ $_ct_match != "$_ct_shown" ]]; then
    _ct_apply "$_ct_match"
    _ct_shown=$_ct_match
  fi
  return "$status"
}

# Only for interactive shells that draw on a real terminal.
[[ $- == *i* && -t 1 && $TERM != linux && $TERM != dumb ]] || return 0

# Sourcing ~/.bashrc again must not add the hook twice.
if [[ " ${PROMPT_COMMAND[*]} " != *_ct_prompt* ]]; then
  PROMPT_COMMAND="_ct_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

# shellcheck shell=bash
# Colorful Terminals: tints the terminal background by project folder.
# Sourced from ~/.bashrc. Before each prompt it checks the current folder
# against ~/.config/colorful-terminals/projects.conf and, only when the color
# should change, sends OSC 11 (set background) or OSC 111 (back to the theme).

# Only for interactive shells that draw on a real terminal.
[[ $- == *i* && -t 1 && $TERM != linux && $TERM != dumb ]] || return 0

# shellcheck source=lib/config.bash
source "${BASH_SOURCE[0]%/*}/../lib/config.bash" || return 0

_ct_shown=${_ct_shown-}   # color on screen now; "" = theme color

_ct_prompt() {
  local status=$?
  _ct_load
  _ct_match_dir "$PWD"
  if [[ $_ct_match != "$_ct_shown" ]]; then
    if [[ -n $_ct_match ]]; then
      printf '\e]11;%s\a' "$_ct_match"
    else
      printf '\e]111\a'
    fi
    _ct_shown=$_ct_match
  fi
  return "$status"
}

# Sourcing ~/.bashrc again must not add the hook twice.
if [[ " ${PROMPT_COMMAND[*]} " != *_ct_prompt* ]]; then
  PROMPT_COMMAND="_ct_prompt${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

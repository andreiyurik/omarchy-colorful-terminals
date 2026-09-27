# Colorful Terminals for zsh: tints the terminal background by project folder.
# Sourced from ~/.zshrc. Before each prompt it checks the current folder
# against ~/.config/colorful-terminals/projects.conf and, only when the color
# should change, sends OSC 11 (set background) or OSC 111 (back to the theme).
# Inside tmux it colors the tmux pane instead.
#
# It reads projects.conf by the same rules as lib/config.bash (tests/hooks.test.sh
# checks they agree), in plain zsh: no forks, no modules.

typeset -g _ct_file="$HOME/.config/colorful-terminals/projects.conf"
typeset -g _ct_shown=${_ct_shown-}

# Sets REPLY to the color for folder $1: the project with the longest matching
# path wins. "" means no project here.
_ct_color_for() {
  emulate -L zsh
  setopt extended_glob
  local dir=$1 line body pt c p
  integer i n best=-1
  REPLY=""
  [[ -r $_ct_file ]] || return 0
  for line in "${(@f)$(<$_ct_file)}"; do
    line=${line%$'\r'}
    line=${line##[[:space:]]#}
    line=${line%%[[:space:]]#}
    [[ -z $line || $line == \#* ]] && continue
    [[ $line == [a-z][a-z-]#[[:space:]]#=* ]] && continue
    [[ $line == (\~|/)* ]] || continue

    # A comment starts at the first "#" with a space before it and a space
    # (or the end of the line) after it; "#1a3a5a" is never a comment.
    body=$line
    if [[ $line == *[[:space:]]\#* ]]; then
      n=${#line}
      for (( i = 2; i <= n; i++ )); do
        [[ ${line[i]} == '#' && ${line[i-1]} == [[:space:]] ]] || continue
        if (( i == n )) || [[ ${line[i+1]} == [[:space:]] ]]; then
          body=${line[1,i-2]}
          body=${body%%[[:space:]]#}
          break
        fi
      done
    fi

    c=${body##*[[:space:]]}
    [[ $c == \#[0-9A-Fa-f](#c6) ]] || continue
    (( ${#body} > ${#c} )) || continue
    pt=${body[1,-$(( ${#c} + 1 ))]}
    pt=${pt%%[[:space:]]#}
    [[ -n $pt ]] || continue

    case $pt in
      ('~') p=$HOME ;;
      ('~/'*) p=$HOME/${pt[3,-1]} ;;
      (/*) p=$pt ;;
      (*) continue ;;
    esac
    while [[ $p == */ && $p != / ]]; do p=${p%/}; done

    if [[ $dir == $p || $dir == $p/* || $p == / ]] && (( ${#p} > best )); then
      REPLY=$c
      best=${#p}
    fi
  done
}

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

_ct_precmd() {
  local REPLY
  _ct_color_for "$PWD"
  if [[ $REPLY != "$_ct_shown" ]]; then
    _ct_apply "$REPLY"
    _ct_shown=$REPLY
  fi
}

# Only for interactive shells that draw on a real terminal.
[[ -o interactive && -t 1 && $TERM != linux && $TERM != dumb ]] || return 0

# add-zsh-hook keeps one copy, so sourcing ~/.zshrc again adds nothing.
autoload -Uz add-zsh-hook
add-zsh-hook precmd _ct_precmd

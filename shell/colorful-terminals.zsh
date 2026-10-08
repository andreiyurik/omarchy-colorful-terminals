# Colorful Terminals for zsh: tints the terminal background by project folder.
# Sourced from ~/.zshrc. Before each prompt it checks the current folder
# against ~/.config/colorful-terminals/projects.conf and sends OSC 11 (set
# background) or, when leaving a project, OSC 111 (back to the theme). A
# color is sent again at every prompt, so a terminal that reloaded its config
# (a theme switch) is back in its color at the next prompt. Inside tmux it
# colors the tmux pane instead, which keeps its style, so there it is set once.
#
# Super+Ctrl+Alt+Shift+1…8 gives this one terminal a color of its own (see
# the bash hook): Hyprland presses Ctrl+Alt+Shift+F12, which runs _ct_key.
#
# It reads projects.conf by the same rules as lib/config.bash (tests/hooks.test.sh
# checks they agree), in plain zsh: no forks, no modules.

typeset -g _ct_file="$HOME/.config/colorful-terminals/projects.conf"
typeset -g _ct_shown=${_ct_shown-}
typeset -g _ct_paint=${_ct_paint-}
typeset -g _ct_request=${XDG_RUNTIME_DIR:+$XDG_RUNTIME_DIR/colorful-terminals/paint}

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
    [[ $line == [a-z][a-z0-9-]#[[:space:]]#=* ]] && continue
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

# Shows this terminal's own color, or else the project color for $PWD.
_ct_precmd() {
  local REPLY=$_ct_paint
  [[ -n $REPLY ]] || _ct_color_for "$PWD"
  if [[ $REPLY != "$_ct_shown" ]] || [[ -n $REPLY && ( -z ${TMUX-} || -z ${TMUX_PANE-} ) ]]; then
    _ct_apply "$REPLY"
    _ct_shown=$REPLY
  fi
}

# Takes the color the helper left and empties the file, which tells the
# helper this terminal got it.
_ct_key() {
  local color
  [[ -n $_ct_request && -r $_ct_request ]] || return 0
  color=$(<$_ct_request)
  : >| $_ct_request
  if [[ $color == reset ]]; then
    _ct_paint=""
  elif [[ $color == \#[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f] ]]; then
    _ct_paint=$color
  else
    return 0
  fi
  _ct_precmd
}

# Only for interactive shells that draw on a real terminal.
[[ -o interactive && -t 1 && $TERM != linux && $TERM != dumb ]] || return 0

# add-zsh-hook keeps one copy, so sourcing ~/.zshrc again adds nothing.
autoload -Uz add-zsh-hook
add-zsh-hook precmd _ct_precmd

# Ctrl+Alt+Shift+F12, in every keymap.
zle -N _ct_key
bindkey -M emacs '\e[24;8~' _ct_key
bindkey -M viins '\e[24;8~' _ct_key
bindkey -M vicmd '\e[24;8~' _ct_key

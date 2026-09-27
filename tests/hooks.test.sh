#!/bin/bash
# The zsh and fish hooks read projects.conf by the same rules as the bash one,
# and every hook colors terminals and tmux panes as you cd. Shells or tmux that
# are not installed are skipped. CT_ZSH and CT_FISH point at other binaries.
# shellcheck disable=SC2016,SC2001 # zsh and fish code in single quotes on purpose; sed cuts many lines
set -uo pipefail
# shellcheck source=tests/lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

zsh=${CT_ZSH:-$(command -v zsh || true)}
fish=${CT_FISH:-$(command -v fish || true)}

# A projects.conf full of edge cases.
write_conf() {
  mkdir -p "${conf%/*}"
  printf '%s\n' \
    '# header, then the cases' \
    '~/code/shop  #1a3a5a' \
    $'\t ~/code/blog\t#1A3A5A  ' \
    '~/a  #111111 # one  two' \
    '~/b  #222222 #' \
    '~/My Projects/web app   #333333' \
    '/srv/app #444444' \
    $'~/crlf #555555\r' \
    '~/nested/inner/ #666666' \
    '~/nested #777777' \
    '~bob/x #888888' \
    'code/rel #999999' \
    'replace-group-keys = yes' \
    '~/color-only' \
    '~/c green' \
    '~/seven #1234567' \
    '~/hash#tag  #aaaaaa' \
    '~/sp #x/y #bbbbbb' > "$conf"
  printf '~/last #cccccc' >> "$conf"   # no final newline
}
answers_bash() {
  bash -c 'source "$1/lib/config.bash"; _ct_load; shift; for d; do _ct_match_dir "$d"; printf "%s=%s\n" "$d" "$_ct_match"; done' _ "$repo" "$@"
}
answers_zsh() {
  "$zsh" -f -c 'source "$1/shell/colorful-terminals.zsh"; shift; for d in "$@"; do _ct_color_for "$d"; printf "%s=%s\n" "$d" "$REPLY"; done' _ "$repo" "$@"
}
answers_fish() {
  "$fish" --no-config -c 'source $argv[1]/shell/colorful-terminals.fish; for d in $argv[2..]; printf "%s=%s\n" $d (__ct_color_for $d); end' "$repo" "$@"
}

echo "hooks: every shell reads projects.conf the same way"
new_home
write_conf
dirs=(
  "$HOME/code/shop" "$HOME/code/shop/src/deep" "$HOME/code/shopping" "$HOME/code/blog"
  "$HOME/a" "$HOME/b/x" "$HOME/My Projects/web app/src" "/srv/app" "/srv/application"
  "$HOME/crlf" "$HOME/nested" "$HOME/nested/inner/deep" "$HOME/nested/other"
  "$HOME/color-only" "$HOME/c" "$HOME/seven" "$HOME/hash#tag" "$HOME/sp #x/y" "$HOME/last" "$HOME" "/"
)
reference=$(answers_bash "${dirs[@]}")
eq "bash reference sees the right projects" \
  "#1a3a5a #1a3a5a  #1A3A5A #111111 #222222 #333333 #444444  #555555 #777777 #666666 #777777    #aaaaaa #bbbbbb #cccccc  " \
  "$(sed 's/.*=//' <<< "$reference" | paste -sd ' ')"
if [[ -n $zsh ]]; then eq "zsh agrees with bash" "$reference" "$(answers_zsh "${dirs[@]}")"; else echo "  SKIP: zsh"; fi
if [[ -n $fish ]]; then eq "fish agrees with bash" "$reference" "$(answers_fish "${dirs[@]}")"; else echo "  SKIP: fish"; fi

printf '~ #dddddd\n/ #eeeeee\n~/code #1a3a5a\n' > "$conf"
reference=$(answers_bash "$HOME/x" "/etc" "$HOME/code/y")
eq "home and root projects" "#dddddd #eeeeee #1a3a5a" "$(sed 's/.*=//' <<< "$reference" | paste -sd ' ')"
[[ -z $zsh ]] || eq "zsh: home and root" "$reference" "$(answers_zsh "$HOME/x" "/etc" "$HOME/code/y")"
[[ -z $fish ]] || eq "fish: home and root" "$reference" "$(answers_fish "$HOME/x" "/etc" "$HOME/code/y")"

rm "$conf"
[[ -z $zsh ]] || eq "zsh: no file, no color" "$HOME/a=" "$(answers_zsh "$HOME/a")"
[[ -z $fish ]] || eq "fish: no file, no color" "$HOME/a=" "$(answers_fish "$HOME/a")"

# ---------------------------------------------------------------- terminals

# Runs <shell command> in a pseudo-terminal, feeding it <input>, and prints the
# OSC 11/111 codes it drew, in order.
osc_codes() {
  local command=$1 input=$2
  printf '%s\nexit\n' "$input" | TERM=xterm-256color script -q -e -c "$command" /dev/null 2>&1 |
    grep -aoE $'\x1b\\]11;#[0-9a-fA-F]{6}\x07|\x1b\\]111\x07' | sed $'s/\x1b\\]//; s/\x07//' | paste -sd ' '
}

project_home() {
  omarchy_like_home
  mkdir -p "$HOME/code/shop/src" "$HOME/code/shop/admin" "${conf%/*}"
  printf '~/code/shop  #1a3a5a\n~/code/shop/admin  #681e1e\n' > "$conf"
}
omarchy_like_home() {
  new_home
  mkdir -p "$HOME/.config/hypr" "$HOME/.config/omarchy/extensions"
  : > "$HOME/.bashrc"
}
walk=$'cd ~/code/shop/src\ncd ~/code/shop/admin\ncd ~/code/shop\ncd /'
expected="11;#1a3a5a 11;#681e1e 11;#1a3a5a 111"

# The helper adds zsh and fish blocks only when it finds those shells.
shells_bin=$(mktemp -d)
homes+=("$shells_bin")
[[ -z $zsh ]] || ln -s "$zsh" "$shells_bin/zsh"
[[ -z $fish ]] || ln -s "$fish" "$shells_bin/fish"
export PATH="$shells_bin:$PATH"

echo "hooks: terminals"
if ! command -v script > /dev/null; then
  echo "  SKIP: needs script(1) for a pseudo-terminal"
else
  if [[ -n $zsh ]]; then
    project_home
    : > "$HOME/.zshrc"
    "$helper" integration install --yes > /dev/null
    eq "zsh: colors follow cd" "$expected" "$(osc_codes "env ZDOTDIR=$HOME $zsh -i" "$walk")"
    eq "zsh: sourcing twice keeps one hook" "1" \
      "$(printf 'source ~/.zshrc\nsource ~/.zshrc\nprint hooks=${#${(M)precmd_functions:#_ct_precmd}}\nexit\n' |
        TERM=xterm-256color script -q -e -c "env ZDOTDIR=$HOME $zsh -i" /dev/null 2>&1 | grep -ao 'hooks=[0-9]*' | tail -n 1 | cut -d= -f2)"
  else
    echo "  SKIP: zsh"
  fi
  if [[ -n $fish ]]; then
    project_home
    mkdir -p "$HOME/.config/fish"
    "$helper" integration install --yes > /dev/null
    eq "fish: colors follow cd" "$expected" "$(osc_codes "env XDG_CONFIG_HOME=$HOME/.config $fish -i" "$walk")"
    out=$(printf 'cd ~/code/shop\nfalse\necho "status=$status"\nexit\n' |
      TERM=xterm-256color script -q -e -c "env XDG_CONFIG_HOME=$HOME/.config $fish -i" /dev/null 2>&1)
    ok "fish: keeps \$status" grep -aq 'status=1' <<< "$out"
  else
    echo "  SKIP: fish"
  fi
fi

echo "hooks: tmux panes"
if ! command -v tmux > /dev/null || ! command -v script > /dev/null; then
  echo "  SKIP: needs tmux and script(1)"
else
  # A private tmux server: its own socket, no config, gone at the end.
  socket="ct-test-$$"
  t() { tmux -L "$socket" -f /dev/null "$@"; }
  pane_bg() { t show -p -v -t "$1" window-style 2> /dev/null || true; }
  wait_for() {   # <pane> <expected window-style>
    local i
    for ((i = 0; i < 40; i++)); do [[ $(pane_bg "$1") == "$2" ]] && return 0; sleep 0.1; done
    return 1
  }
  check_tmux() {   # <name> <shell command>
    local name=$1 command=$2 pane
    t kill-server 2> /dev/null
    pane=$(t new-session -d -P -F '#{pane_id}' -x 80 -y 24 "$command")
    sleep 0.5
    t send-keys -t "$pane" 'cd ~/code/shop/src' Enter
    if wait_for "$pane" "bg=#1a3a5a"; then pass; else fail "$name: pane takes the project color" "got: $(pane_bg "$pane")"; fi
    eq "$name: active style too" "bg=#1a3a5a" "$(t show -p -v -t "$pane" window-active-style 2> /dev/null)"
    t send-keys -t "$pane" 'cd /' Enter
    if wait_for "$pane" ""; then pass; else fail "$name: back to the theme outside" "got: $(pane_bg "$pane")"; fi
    t kill-server 2> /dev/null
  }
  project_home
  "$helper" integration install --yes > /dev/null
  check_tmux "bash in tmux" "env TERM=tmux-256color bash --noprofile --rcfile $HOME/.bashrc -i"
  if [[ -n $zsh ]]; then
    : > "$HOME/.zshrc"
    "$helper" integration install --yes > /dev/null
    check_tmux "zsh in tmux" "env ZDOTDIR=$HOME $zsh -i"
  fi
  if [[ -n $fish ]]; then
    mkdir -p "$HOME/.config/fish"
    "$helper" integration install --yes > /dev/null
    check_tmux "fish in tmux" "env XDG_CONFIG_HOME=$HOME/.config $fish -i"
  fi
fi

finish

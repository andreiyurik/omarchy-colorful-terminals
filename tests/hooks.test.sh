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
# OSC 11/111 codes it drew, in order. The input waits for the first prompt.
type_into() { sleep 1; printf '%s\nexit\n' "$1"; }
osc_codes() {
  local command=$1 input=$2
  type_into "$input" | TERM=xterm-256color script -q -e -c "$command" /dev/null 2>&1 |
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
# Each shell with its distribution's own system config, as users have it.
zsh_i() { printf 'env ZDOTDIR=%s %s -i' "$HOME" "$zsh"; }
fish_i() { printf 'env XDG_CONFIG_HOME=%s/.config %s -i' "$HOME" "$fish"; }
bash_i() { printf 'bash --noprofile --rcfile %s/.bashrc -i' "$HOME"; }
# A line of another tool's prompt hook that says it ran and what $? it saw.
count_mine() { grep -ao '<mine:[0-9]*>' <<< "$1" | wc -l; }
if ! command -v script > /dev/null; then
  echo "  SKIP: needs script(1) for a pseudo-terminal"
else
  # bash beside another prompt hook (starship, direnv and friends)
  project_home
  printf '%s\n' 'PROMPT_COMMAND='"'"'printf "<mine:%s>" "$?"'"'" > "$HOME/.bashrc"
  "$helper" integration install --yes > /dev/null
  out=$(type_into $'cd ~/code/shop/src\nfalse' | TERM=xterm-256color script -q -e -c "$(bash_i)" /dev/null 2>&1)
  eq "bash: colors beside another prompt hook" "11;#1a3a5a" \
    "$(grep -aoE $'\x1b\\]11;#[0-9a-f]{6}' <<< "$out" | sed $'s/\x1b\\]//' | paste -sd ' ')"
  ok "bash: the other hook still runs" test "$(count_mine "$out")" -ge 3
  ok "bash: and still sees \$? of the command" grep -aq '<mine:1>' <<< "$out"
  if ((BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] >= 501)); then
    project_home
    printf '%s\n' 'PROMPT_COMMAND=('"'"'printf "<mine:%s>" "$?"'"'"' '"'"'printf "<two>"'"'"')' > "$HOME/.bashrc"
    "$helper" integration install --yes > /dev/null
    out=$(type_into $'cd ~/code/shop/src' | TERM=xterm-256color script -q -e -c "$(bash_i)" /dev/null 2>&1)
    ok "bash 5.1+: PROMPT_COMMAND as an array keeps every entry" test "$(grep -ac '<two>' <<< "$out")" -ge 1
    ok "bash 5.1+: and colors" grep -aq $'\x1b\\]11;#1a3a5a' <<< "$out"
  fi

  if [[ -n $zsh ]]; then
    project_home
    : > "$HOME/.zshrc"
    "$helper" integration install --yes > /dev/null
    eq "zsh: colors follow cd" "$expected" "$(osc_codes "$(zsh_i)" "$walk")"
    eq "zsh: sourcing twice keeps one hook" "1" \
      "$(type_into $'source ~/.zshrc\nsource ~/.zshrc\nprint hooks=${#${(M)precmd_functions:#_ct_precmd}}' |
        TERM=xterm-256color script -q -e -c "$(zsh_i)" /dev/null 2>&1 | grep -ao 'hooks=[0-9]*' | tail -n 1 | cut -d= -f2)"

    project_home
    printf '%s\n' 'precmd() { print -n "<mine:$?>" }' 'autoload -Uz add-zsh-hook' \
      'other() { print -n "<two>" }' 'add-zsh-hook precmd other' > "$HOME/.zshrc"
    "$helper" integration install --yes > /dev/null
    out=$(type_into $'cd ~/code/shop/src\nfalse' | TERM=xterm-256color script -q -e -c "$(zsh_i)" /dev/null 2>&1)
    ok "zsh: colors beside other precmd hooks" grep -aq $'\x1b\\]11;#1a3a5a' <<< "$out"
    ok "zsh: precmd() still runs" test "$(count_mine "$out")" -ge 3
    ok "zsh: and still sees \$? of the command" grep -aq '<mine:1>' <<< "$out"
    ok "zsh: add-zsh-hook ones too" test "$(grep -ac '<two>' <<< "$out")" -ge 1
  else
    echo "  SKIP: zsh"
  fi

  if [[ -n $fish ]]; then
    project_home
    mkdir -p "$HOME/.config/fish"
    "$helper" integration install --yes > /dev/null
    eq "fish: colors follow cd" "$expected" "$(osc_codes "$(fish_i)" "$walk")"
    out=$(type_into $'cd ~/code/shop\nfalse\necho "status=$status"' |
      TERM=xterm-256color script -q -e -c "$(fish_i)" /dev/null 2>&1)
    ok "fish: keeps \$status" grep -aq 'status=1' <<< "$out"

    project_home
    mkdir -p "$HOME/.config/fish"
    printf '%s\n' 'function mine --on-event fish_prompt; printf "<mine:%s>" $status; end' > "$HOME/.config/fish/config.fish"
    "$helper" integration install --yes > /dev/null
    out=$(type_into $'cd ~/code/shop/src\nfalse' | TERM=xterm-256color script -q -e -c "$(fish_i)" /dev/null 2>&1)
    ok "fish: colors beside another fish_prompt handler" grep -aq $'\x1b\\]11;#1a3a5a' <<< "$out"
    ok "fish: the other handler still runs" test "$(count_mine "$out")" -ge 3
    ok "fish: and still sees \$status of the command" grep -aq '<mine:1>' <<< "$out"
  else
    echo "  SKIP: fish"
  fi
fi

echo "hooks: speed"
# Every prompt reads projects.conf, so it must stay cheap: 30 projects, 200
# prompts in a row, no more than 20 ms each on average.
new_home
mkdir -p "${conf%/*}" "$HOME/p/15/src"
for i in $(seq 1 30); do printf '~/p/%s  #1a3a5a\n' "$i"; done > "$conf"
ms_per_prompt() {   # <shell command that runs 200 prompts> ; prints ms per prompt
  local start end
  start=$(date +%s%N)
  "$@" > /dev/null 2>&1 || { echo 99999; return; }
  end=$(date +%s%N)
  echo $(((end - start) / 200 / 1000000))
}
fast() {   # <name> <ms>
  if (($2 <= 20)); then pass; else fail "$1: $2 ms per prompt, over 20"; fi
  printf '  %s: %s ms per prompt\n' "$1" "$2"
}
cd "$HOME/p/15/src" || exit 1
fast "bash" "$(ms_per_prompt bash -c 'source "$1/shell/colorful-terminals.bash"; for ((i = 0; i < 200; i++)); do _ct_prompt; done' _ "$repo")"
if [[ -n $zsh ]]; then
  fast "zsh" "$(ms_per_prompt "$zsh" -f -c 'source "$1/shell/colorful-terminals.zsh"; repeat 200 _ct_precmd' _ "$repo")"
fi
if [[ -n $fish ]]; then
  fast "fish" "$(ms_per_prompt "$fish" --no-config -c 'source $argv[1]/shell/colorful-terminals.fish; for i in (seq 200); set -l c (__ct_color_for $PWD); end' "$repo")"
fi
cd / || exit 1

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
    local name=$1 command=$2 pane i
    t kill-server 2> /dev/null
    pane=$(t new-session -d -P -F '#{pane_id}' -x 80 -y 24 "$command")
    # Type only once the shell has drawn its first prompt.
    for ((i = 0; i < 50; i++)); do [[ -n $(t capture-pane -p -t "$pane" 2> /dev/null | tr -d '[:space:]') ]] && break; sleep 0.1; done
    sleep 0.3
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
    check_tmux "zsh in tmux" "$(zsh_i)"
  fi
  if [[ -n $fish ]]; then
    mkdir -p "$HOME/.config/fish"
    "$helper" integration install --yes > /dev/null
    check_tmux "fish in tmux" "$(fish_i)"
  fi
fi

finish

#!/bin/bash
# Super+Ctrl+Alt+Shift+digit in real pseudo-terminals: script(1) stands in for
# the terminal program, a stand-in hyprctl says it is the focused window, and
# the helper has to find the terminal under it the way it does in Hyprland.
# shellcheck disable=SC2016 # shell code in single quotes on purpose
set -uo pipefail
# shellcheck source=tests/lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

if ! command -v script > /dev/null || [[ ! -r /proc/self/stat ]]; then
  echo "paint: SKIP (needs script(1) and /proc)"
  exit 0
fi

new_home
mkdir -p "$HOME/code/shop" "${conf%/*}" "$HOME/run" "$HOME/fake-bin"
chmod 700 "$HOME/run"
printf '~/code/shop  #1a3a5a\npaint-2 = #123456\n' > "$conf"
fake="$HOME/fake-bin"
cat > "$fake/hyprctl" <<'FAKE'
#!/bin/bash
case $1 in
  activewindow) printf '{"class":"x","tags":["terminal*"],"pid":%s}\n' "$FAKE_PID" ;;
  eval)
    touch "$HOME/key-sent"
    # A shell at its prompt answers with its file name and folder.
    [[ -z ${FAKE_ANSWER-} ]] || printf 'pts-77\n%s\n' "$FAKE_ANSWER" > "$XDG_RUNTIME_DIR/colorful-terminals/paint"
    ;;
esac
exit 0
FAKE
# Records each notification; FAKE_CLICK=remember clicks its button.
cat > "$fake/notify-send" <<'FAKE'
#!/bin/bash
printf '%s\n' "$*" >> "$HOME/notified"
[[ $* == *--action=* && -n ${FAKE_CLICK-} ]] && echo "$FAKE_CLICK"
exit 0
FAKE
chmod +x "$fake"/*
paint() { FAKE_PID=$1 PATH="$fake:$PATH" HYPRLAND_INSTANCE_SIGNATURE=test XDG_RUNTIME_DIR="$HOME/run" "$helper" paint "$2"; }
inbox() { local t=${1#/dev/}; cat "$HOME/run/colorful-terminals/tty/${t//\//-}" 2> /dev/null; }

terminals=()
# Starts <command> in a terminal of its own; sets term (the "terminal
# program"), shell (the process on its tty), tty and drawn (what it drew).
open_terminal() {
  local i
  drawn=$(mktemp "$HOME/drawn.XXXXXX")
  sleep 20 | TERM=xterm-256color script -q -f -c "$1" "$drawn" > /dev/null 2>&1 &
  term=$! shell="" tty=""
  terminals+=("$term")
  for ((i = 0; i < 100; i++)); do
    read -r shell < "/proc/$term/task/$term/children" 2> /dev/null
    shell=${shell%% *}
    [[ -n $shell ]] && tty=$(readlink "/proc/$shell/fd/0" 2> /dev/null) && [[ $tty == /dev/pts/* ]] && break
    sleep 0.05
  done
  sleep 0.3
}
drew() { grep -aqF "$1" "$drawn"; }
clean() { rm -f "$HOME/key-sent" "$HOME/notified"; }
# The offer runs in the background; waits for <n> notifications.
notified() {
  local i
  for ((i = 0; i < 60; i++)); do
    (($({ wc -l < "$HOME/notified"; } 2> /dev/null || echo 0) >= $1)) && break
    sleep 0.05
  done
  sleep 0.2
  cat "$HOME/notified" 2> /dev/null
}

echo "paint: a program running in the terminal"
open_terminal "sleep 20"
ok "colors it" paint "$term" 2
ok "at once, without the shell" drew $'\e]11;#123456\a'
ok "sends no key into the program" test ! -e "$HOME/key-sent"
eq "leaves the color for the shell's next prompt" "#123456" "$(inbox "$tty")"
ok "no notification" test ! -e "$HOME/notified"
eq "the folder for it is private" "700" "$(stat -c %a "$HOME/run/colorful-terminals/tty")"
ok "0 there" paint "$term" 0
ok "outside a project is the theme color" drew $'\e]111\a'
eq "and the shell is told" "reset" "$(inbox "$tty")"
clean

open_terminal "cd $HOME/code/shop && exec sleep 20"
ok "0 in a project" paint "$term" 0
ok "is the project color" drew $'\e]11;#1a3a5a\a'
clean

echo "paint: a shell at its prompt"
open_terminal "bash --noprofile --norc -i"
ok "that does not answer (opened before turning on)" paint "$term" 2
ok "gets the key first" test -e "$HOME/key-sent"
ok "then is colored directly" drew $'\e]11;#123456\a'
clean

echo "paint: Remember this color for the folder"
# Without git it offers the folder itself, so then the test starts there.
mkdir -p "$HOME/code/blog/src"
start=$HOME/code/blog
if command -v git > /dev/null; then
  git -C "$HOME/code/blog" init -q
  start=$HOME/code/blog/src
fi
open_terminal "cd $start && exec sleep 20"
FAKE_CLICK=remember paint "$term" 2
out=$(notified 2)
ok "offers it for the git repository, not the folder inside" grep -qF -- 'Keep this color for blog? Every terminal in ~/code/blog will turn this color, and Super+Ctrl+Alt+2 will open it.' <<< "$out"
ok "with a Remember button" grep -qF -- '--action=remember=Remember' <<< "$out"
ok "Remember adds the project" grep -qE '^~/code/blog +#123456$' "$conf"
ok "and says which key opens it" grep -qF 'blog is a project now Super+Ctrl+Alt+2 opens it.' <<< "$out"
eq "the terminal follows its project from now on" "reset" "$(inbox "$tty")"
clean

open_terminal "cd $HOME/code/shop && exec sleep 20"
FAKE_CLICK=remember paint "$term" 2
out=$(notified 2)
ok "in a project of another color: change it" grep -qF -- 'Make shop this color? ~/code/shop is project 1. Every terminal there will turn this color.' <<< "$out"
ok "with a Change color button" grep -qF -- '--action=remember=Change color' <<< "$out"
ok "which changes the project" grep -qE '^~/code/shop +#123456$' "$conf"
clean
paint "$term" 2
notified 1 > /dev/null
ok "the same color again: nothing to ask" test ! -e "$HOME/notified"
clean

paint "$term" 3
notified 1 > /dev/null
ok "a button not clicked" grep -q 'Make shop this color' "$HOME/notified"
ok "changes nothing" grep -qE '^~/code/shop +#123456$' "$conf"
clean
paint "$term" 0
notified 1 > /dev/null
ok "0 asks nothing" test ! -e "$HOME/notified"
open_terminal "cd $HOME && exec sleep 20"
paint "$term" 3
notified 1 > /dev/null
ok "in ~ nothing is asked" test ! -e "$HOME/notified"
clean

if command -v python3 > /dev/null; then
  echo "paint: one process, several terminals"
  rm -f "$HOME/run/colorful-terminals/tty/"*
  python3 -I -c '
import os, pty, sys, time
for _ in range(2):
    pid, fd = pty.fork()
    if pid == 0:
        time.sleep(20)
        os._exit(0)
time.sleep(20)
' &
  term=$!
  terminals+=("$term")
  sleep 0.5
  fails "a busy one is not guessed" paint "$term" 2
  ok "the key was tried" test -e "$HOME/key-sent"
  ok "and a notification says why" grep -q 'several terminals' "$HOME/notified"
  eq "nothing is left for any shell" "" "$(cat "$HOME/run/colorful-terminals/tty/"* 2> /dev/null)"
  clean
  FAKE_ANSWER=$start FAKE_CLICK=remember ok "one at its prompt answers the key" paint "$term" 4
  out=$(notified 2)
  ok "and tells its folder, so it can be remembered there too" grep -qF 'Make blog this color?' <<< "$out"
  eq "and its file, to follow the project after" "reset" "$(cat "$HOME/run/colorful-terminals/tty/pts-77" 2> /dev/null)"
  clean
else
  echo "  SKIP: needs python3"
fi

if command -v tmux > /dev/null; then
  echo "paint: tmux"
  socket="ct-paint-$$"
  t() { tmux -L "$socket" -f /dev/null "$@"; }
  open_terminal "tmux -f /dev/null -L $socket new-session 'sleep 20'"
  sleep 0.5
  pane=$(t list-panes -a -F '#{pane_id}' 2> /dev/null | head -n 1)
  pane_tty=$(t list-panes -a -F '#{pane_tty}' 2> /dev/null | head -n 1)
  ok "a program in a pane" paint "$term" 2
  eq "colors that pane" "bg=#123456" "$(t show -p -v -t "$pane" window-style 2> /dev/null)"
  eq "active too" "bg=#123456" "$(t show -p -v -t "$pane" window-active-style 2> /dev/null)"
  ok "not the whole terminal" bash -c '! grep -aqF $'"'"'\e]11;#123456'"'"' "$1"' _ "$drawn"
  eq "leaves the color for the pane's shell" "#123456" "$(inbox "$pane_tty")"
  ok "0 in the pane" paint "$term" 0
  eq "takes it away" "" "$(t show -p -v -t "$pane" window-style 2> /dev/null)"
  t kill-server 2> /dev/null
  clean
else
  echo "  SKIP: tmux"
fi

kill "${terminals[@]}" 2> /dev/null
pkill -P "$$" sleep 2> /dev/null
wait 2> /dev/null
finish

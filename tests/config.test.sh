#!/bin/bash
# projects.conf parsing, color by folder, and the helper's editing commands.
set -uo pipefail
# shellcheck source=tests/lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

echo "config: parsing"
new_home
source "$repo/lib/config.bash"

parse() {
  _ct_parse_line "$1"
  printf '%s|%s|%s|%s' "$_ct_kind" "$_ct_path_text" "$_ct_color" "$_ct_comment"
}
eq "plain project line" "project|~/code/shop|#1a3a5a|" "$(parse '~/code/shop  #1a3a5a')"
eq "tabs and indentation" "project|~/code/shop|#1A3A5A|" "$(parse $'\t ~/code/shop\t#1A3A5A  ')"
eq "comment after color" "project|~/a|#111111| # one  two" "$(parse '~/a  #111111 # one  two')"
eq "comment right after the hash" "project|~/a|#111111| #" "$(parse '~/a  #111111 #')"
eq "folder with spaces" "project|~/My Projects/web app|#222222|" "$(parse '~/My Projects/web app   #222222')"
eq "absolute folder" "project|/srv/app|#333333|" "$(parse '/srv/app #333333')"
eq "windows line ending" "project|~/a|#444444|" "$(parse $'~/a #444444\r')"
eq "comment line" "blank|||" "$(parse '# ~/a #111111')"
eq "empty line" "blank|||" "$(parse '   ')"
eq "setting" "setting|||" "$(parse 'replace-group-keys = yes')"
_ct_parse_line 'paint-3 =  #681E1E'
eq "setting with a digit" "setting|paint-3|#681E1E" "$_ct_kind|$_ct_key|$_ct_value"
eq "missing color" "problem|||" "$(parse '~/a')"
eq "color name instead of hex" "problem|||" "$(parse '~/a green')"
eq "short hex" "problem|||" "$(parse '~/a #fff')"
eq "relative folder" "problem|||" "$(parse 'code/a #111111')"
eq "~user is not supported" "problem|||" "$(parse '~bob/a #111111')"
eq "old dash line" "problem|||" "$(parse '-  #46262a')"

_ct_parse_line '~/a/b/ #111111'
eq "trailing slash dropped" "$HOME/a/b" "$_ct_path"
_ct_parse_line '~ #111111'
eq "home itself" "$HOME" "$_ct_path"

echo "config: color by folder"
mkdir -p "${conf%/*}"
cat > "$conf" <<'EOF'
# header
~/code/shop          #111111
~/code/shop/admin    #222222
~/code/shopping      #333333
/srv/app             #444444
~/code/shop          #555555
replace-group-keys = yes
~/broken
EOF
_ct_load
eq "every project line counts, duplicates too" "5" "${#_ct_paths[@]}"
match() { _ct_match_dir "$1"; printf '%s' "$_ct_match"; }
eq "project folder" "#111111" "$(match "$HOME/code/shop")"
eq "subfolder inherits" "#111111" "$(match "$HOME/code/shop/src/lib")"
eq "nested project wins" "#222222" "$(match "$HOME/code/shop/admin")"
eq "inside nested project" "#222222" "$(match "$HOME/code/shop/admin/x")"
eq "prefix is not a parent" "#333333" "$(match "$HOME/code/shopping")"
eq "outside any project" "" "$(match "$HOME/code")"
eq "absolute project" "#444444" "$(match /srv/app/logs)"
eq "first duplicate wins" "#111111" "$(match "$HOME/code/shop/x")"
eq "unrelated folder" "" "$(match /tmp)"

echo "config: helper edits"
new_home
mkdir -p "$HOME/code/shop" "$HOME/code/blog" "$HOME/code/api" "$HOME/My Projects/web app"
h() { "$helper" "$@"; }
ok "add first project" h add '~/code/shop'
eq "file gets a header and the project" "~/code/shop             #003b63" "$(grep -v '^#' "$conf" | grep .)"
ok "add with trailing slash" h add "$HOME/code/blog/"
ok "add with explicit color" h add '~/code/api' '#ABCDEF'
fails "duplicate folder" h add '~/code/shop'
fails "missing folder" h add '~/nope'
fails "relative folder" h add 'code/shop'
fails "bad color" h add '~/code/api' '#12'
ok "folder with spaces" h add '~/My Projects/web app'
eq "list" "1  Super+Ctrl+Alt+1  #003b63  ~/code/shop
2  Super+Ctrl+Alt+2  #1a4311  ~/code/blog
3  Super+Ctrl+Alt+3  #abcdef  ~/code/api
4  Super+Ctrl+Alt+4  #5e2024  ~/My Projects/web app" "$(h list | head -n 4)"

ok "move 3 up" h move 3 up
eq "order after move" "~/code/api" "$(h list | sed -n 2p | awk '{print $4}')"
ok "move top up is harmless" h move 1 up
fails "move needs a direction" h move 1 sideways
ok "recolor" h color 1 '#010203'
eq "recolor keeps folder" "1  Super+Ctrl+Alt+1  #010203  ~/code/shop" "$(h list | sed -n 1p)"
ok "remove 2" h remove 2
fails "remove out of range" h remove 9
fails "remove zero" h remove 0
ok "undo puts it back in place" h add '~/code/api' '#abcdef' --at 2
eq "undo position" "2  Super+Ctrl+Alt+2  #abcdef  ~/code/api" "$(h list | sed -n 2p)"

echo "config: hand edits survive"
new_home
mkdir -p "$HOME/a" "$HOME/b" "${conf%/*}"
cat > "$conf" <<'EOF'
# My projects
~/a   #111111   # work
# keep this comment
~/b   #222222
EOF
ok "recolor a commented line" "$helper" color 1 '#333333'
eq "comment kept" "~/a                     #333333   # work" "$(sed -n 2p "$conf")"
eq "other comment kept" "# keep this comment" "$(sed -n 3p "$conf")"
printf 'replace-group-keys = no\n' >> "$conf"
fails "set is gone with the Super+Alt keys" "$helper" set replace-group-keys yes
before=$(cat "$conf")
ok "move keeps everything else" "$helper" move 1 down
eq "only the two project lines swapped" "~/b   #222222|# keep this comment|~/a                     #333333   # work" \
  "$(grep -v -e '^# My' -e '^replace' -e '^$' "$conf" | paste -sd '|')"
ok "move back" "$helper" move 2 up
eq "move there and back is a no-op" "$before" "$(cat "$conf")"

echo "config: state for the panel"
cat >> "$conf" <<'EOF'
~/gone  #444444
~/c green
EOF
state=$("$helper" state)
eq "state is JSON with 3 projects" "3" "$(jq '.projects | length' <<< "$state")"
eq "missing folder flagged" "false" "$(jq '.projects[2].exists' <<< "$state")"
eq "bad line reported" "~/c green" "$(jq -r '.problems[0].text' <<< "$state")"
eq "palette has 8 colors" "8" "$(jq '.palette | length' <<< "$state")"
eq "integration not installed" "false" "$(jq '.integration.installed' <<< "$state")"
eq "an old replace-group-keys line is not a problem" "1" "$(jq '.problems | length' <<< "$state")"
mkdir -p "$HOME/Projects/site/.git" "$HOME/repo/.git" "$HOME/.hidden/x/.git"
scan=$("$helper" scan)
eq "repos found, hidden skipped" '["~/Projects/site","~/repo"]' "$(jq -c '.repos | sort' <<< "$scan")"
eq "dirs completes" '["~/Projects"]' "$("$helper" dirs '~/Pro')"

echo "config: key conflicts from hyprctl"
fake="$HOME/fake-bin"
mkdir -p "$fake" "$HOME/code/current"
cat > "$fake/hyprctl" <<'EOF'
#!/bin/bash
[[ $1 == binds ]] || exit 0
printf 'bindd\n\tmodmask: 76\n\tsubmap: \n\tkey: SUPER + CTRL + ALT + code:10\n\tkeycode: 0\n\tdescription: Open my notes\n\n'
printf 'bindd\n\tmodmask: 76\n\tsubmap: \n\tkey: 2\n\tkeycode: 0\n\tdescription: Project: heartwood\n\n'
printf 'bindd\n\tmodmask: 76\n\tsubmap: \n\tkey: SUPER + CTRL + ALT + code:11\n\tkeycode: 0\n\tdescription: Project 2: blog\n\n'
printf 'bindd\n\tmodmask: 76\n\tsubmap: \n\tkey: SUPER + CTRL + ALT + code:19\n\tkeycode: 0\n\tdescription: Colorful Terminals settings\n\n'
printf 'bindd\n\tmodmask: 72\n\tsubmap: \n\tkey: SUPER + ALT + code:10\n\tkeycode: 0\n\tdescription: Switch to group window 1\n\n'
printf 'bindd\n\tmodmask: 64\n\tsubmap: \n\tkey: SUPER + code:10\n\tkeycode: 0\n\tdescription: Switch to workspace 1\n\n'
printf 'bindd\n\tmodmask: 77\n\tsubmap: \n\tkey: SUPER + CTRL + ALT + SHIFT + code:12\n\tkeycode: 0\n\tdescription: Screenshot\n\n'
printf 'bindd\n\tmodmask: 77\n\tsubmap: \n\tkey: SUPER + CTRL + ALT + SHIFT + code:10\n\tkeycode: 0\n\tdescription: Terminal color 1\n\n'
printf 'bindd\n\tmodmask: 77\n\tsubmap: \n\tkey: SUPER + CTRL + ALT + SHIFT + code:19\n\tkeycode: 0\n\tdescription: Terminal color off\n\n'
printf 'bindd\n\tmodmask: 76\n\tsubmap: resize\n\tkey: 3\n\tkeycode: 0\n\tdescription: In a submap\n'
EOF
# shellcheck disable=SC2016 # $HOME expands when the fake runs
printf '#!/bin/bash\necho "$HOME/code/current"\n' > "$fake/omarchy-cmd-terminal-cwd"
chmod +x "$fake"/*
scan=$(PATH="$fake:$PATH" HYPRLAND_INSTANCE_SIGNATURE=test "$helper" scan)
eq "conflicts: only Super+Ctrl+Alt digits that are not ours; Omarchy's Super+Alt is no clash" \
  '[{"digit":1,"byCode":true,"description":"Open my notes","shift":false},{"digit":2,"byCode":false,"description":"Project: heartwood","shift":false},{"digit":3,"byCode":true,"description":"Screenshot","shift":true}]' \
  "$(jq -c .conflicts <<< "$scan")"
eq "current folder of the focused terminal" "~/code/current" "$(jq -r .currentDir <<< "$scan")"

echo "config: colors for any terminal"
new_home
mkdir -p "$HOME/code/shop"
h add '~/code/shop' > /dev/null
eq "list shows the color keys" "Super+Ctrl+Alt+Shift+3  #5e2024  Red" "$(h list | grep -F 'Shift+3' | sed 's/^ *//')"
ok "set color 3" h paint-color 3 '#ABCDEF'
ok "set color 1" h paint-color 1 '#111111'
ok "set color 8" h paint-color 8 '#222222'
ok "change color 3" h paint-color 3 '#333333'
eq "one line each, in order, under a comment" \
  "~/code/shop             #003b63||# Super+Ctrl+Alt+Shift+1…8 color the terminal you are in; +0 takes the color away.|paint-1 = #111111|paint-3 = #333333|paint-8 = #222222" \
  "$(grep -v '^# [CT]' "$conf" | sed 1d | paste -sd '|')"
eq "list names a custom color" "Super+Ctrl+Alt+Shift+3  #333333  your color" "$(h list | grep -F 'Shift+3' | sed 's/^ *//')"
eq "state has the custom colors" '{"1":"#111111","3":"#333333","8":"#222222"}' "$("$helper" state | jq -c .paint)"
eq "and they are not problems" "0" "$("$helper" state | jq '.problems | length')"
fails "keys go up to 8" h paint-color 9 '#111111'
fails "0 has no color" h paint-color 0 '#111111'
fails "hex only" h paint-color 2 red
ok "back to default" h paint-color 1 default
ok "default twice is fine" h paint-color 1 default
ok "back to default" h paint-color 3 default
ok "back to default" h paint-color 8 default
eq "the comment goes with the last one, file as before" "# Colorful Terminals: one project per line, the folder and then its color.|# The 1st project opens with Super+Ctrl+Alt+1, the 2nd with Super+Ctrl+Alt+2, up to 9.|# Colors are #rrggbb. Edit here or in the panel (Super+Ctrl+Alt+0); both stay in sync.||~/code/shop             #003b63" \
  "$(paste -sd '|' "$conf")"
printf 'paint-9 = #111111\npaint-2 = blue\n' >> "$conf"
eq "bad color lines are problems" "paint-9 = #111111|paint-2 = blue" "$("$helper" state | jq -r '[.problems[].text] | join("|")')"
eq "a project color is untouched by all this" "1  Super+Ctrl+Alt+1  #003b63  ~/code/shop" "$(h list | head -n 1)"
mkdir -p "$HOME/.local/state/omarchy/current/theme"
printf 'accent = "#000000"\nbackground = "#faf4ed"\n' > "$HOME/.local/state/omarchy/current/theme/colors.toml"
eq "a light theme gets the light palette by default" "Super+Ctrl+Alt+Shift+1  #aedbfb  Blue" "$(h list | grep -F 'Shift+1' | sed 's/^ *//')"
printf 'background = "#1a1b26"\n' > "$HOME/.local/state/omarchy/current/theme/colors.toml"
eq "a dark theme the dark one" "Super+Ctrl+Alt+Shift+1  #003b63  Blue" "$(h list | grep -F 'Shift+1' | sed 's/^ *//')"

echo "config: the color keys"
# A stand-in Hyprland: the focused window's tags, and a key press that a shell
# at a prompt answers by emptying the request file.
fake="$HOME/fake-bin"
mkdir -p "$fake" "$HOME/run"
chmod 700 "$HOME/run"
cat > "$fake/hyprctl" <<'EOF'
#!/bin/bash
case $1 in
  activewindow) printf '{"class":"x","tags":[%s]}\n' "$FAKE_TAGS" ;;
  eval)
    printf '%s\n' "$2" > "$HOME/eval.lua"
    cp "$XDG_RUNTIME_DIR/colorful-terminals/paint" "$HOME/request" 2> /dev/null
    [[ $FAKE_SHELL == answers ]] && : > "$XDG_RUNTIME_DIR/colorful-terminals/paint"
    ;;
esac
exit 0
EOF
cat > "$fake/notify-send" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$HOME/notified"
EOF
chmod +x "$fake"/*
paint() { PATH="$fake:$PATH" HYPRLAND_INSTANCE_SIGNATURE=test XDG_RUNTIME_DIR="$HOME/run" "$helper" paint "$@"; }
h paint-color 2 '#123456' > /dev/null
export FAKE_TAGS='"default-opacity*","terminal*"' FAKE_SHELL=answers
ok "a color key in a terminal" paint 2
eq "hands over that key's color" "#123456" "$(cat "$HOME/request")"
ok "sends Ctrl+Alt+Shift+F12 down and up" grep -q 'mods = "CTRL ALT SHIFT", key = "F12", state = "up"' "$HOME/eval.lua"
ok "and cleans up" test ! -e "$HOME/run/colorful-terminals/paint"
eq "the folder is private" "700" "$(stat -c %a "$HOME/run/colorful-terminals")"
ok "no notification when it worked" test ! -e "$HOME/notified"
ok "0 takes the color away" paint 0
eq "as a reset" "reset" "$(cat "$HOME/request")"
ok "a default color" paint 7
eq "is the palette's" "#572142" "$(cat "$HOME/request")"
fails "no key 9" paint 9
fails "no key 10" paint 10
FAKE_SHELL=busy fails "a terminal that does not answer" paint 1
eq "says why" "-a Colorful Terminals -- The terminal kept its color Colors change at a shell prompt, in terminals opened after Colorful Terminals was turned on." "$(cat "$HOME/notified")"
ok "and leaves nothing behind for a later key press" test ! -e "$HOME/run/colorful-terminals/paint"
rm -f "$HOME/notified" "$HOME/request"
FAKE_TAGS='"default-opacity*"' fails "a browser in focus" paint 1
ok "is told to click a terminal" grep -q 'No terminal in focus' "$HOME/notified"
ok "and gets no key" test ! -e "$HOME/request"
unset FAKE_TAGS FAKE_SHELL

finish

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
eq "setting read" "yes" "$_ct_replace_group_keys"
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
eq "file gets a header and the project" "~/code/shop             #1a3a5a" "$(grep -v '^#' "$conf" | grep .)"
ok "add with trailing slash" h add "$HOME/code/blog/"
ok "add with explicit color" h add '~/code/api' '#ABCDEF'
fails "duplicate folder" h add '~/code/shop'
fails "missing folder" h add '~/nope'
fails "relative folder" h add 'code/shop'
fails "bad color" h add '~/code/api' '#12'
ok "folder with spaces" h add '~/My Projects/web app'
eq "list" "1  Super+Alt+1  #1a3a5a  ~/code/shop
2  Super+Alt+2  #213f12  ~/code/blog
3  Super+Alt+3  #abcdef  ~/code/api
4  Super+Alt+4  #681e1e  ~/My Projects/web app" "$(h list)"

ok "move 3 up" h move 3 up
eq "order after move" "~/code/api" "$(h list | sed -n 2p | awk '{print $4}')"
ok "move top up is harmless" h move 1 up
fails "move needs a direction" h move 1 sideways
ok "recolor" h color 1 '#010203'
eq "recolor keeps folder" "1  Super+Alt+1  #010203  ~/code/shop" "$(h list | sed -n 1p)"
ok "remove 2" h remove 2
fails "remove out of range" h remove 9
fails "remove zero" h remove 0
ok "undo puts it back in place" h add '~/code/api' '#abcdef' --at 2
eq "undo position" "2  Super+Alt+2  #abcdef  ~/code/api" "$(h list | sed -n 2p)"

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
ok "setting added" "$helper" set replace-group-keys yes
eq "setting line" "1" "$(grep -c '^replace-group-keys = yes$' "$conf")"
ok "setting changed in place" "$helper" set replace-group-keys no
eq "one setting line" "1" "$(grep -c '^replace-group-keys' "$conf")"
fails "unknown setting" "$helper" set colors loud
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
eq "explicit key setting reported" "true" "$(jq '.replaceGroupKeysSet' <<< "$state")"
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
printf 'bindd\n\tmodmask: 72\n\tsubmap: \n\tkey: SUPER + ALT + code:10\n\tkeycode: 0\n\tdescription: Switch to group window 1\n\n'
printf 'bindd\n\tmodmask: 72\n\tsubmap: \n\tkey: 2\n\tkeycode: 0\n\tdescription: Project: heartwood\n\n'
printf 'bindd\n\tmodmask: 72\n\tsubmap: \n\tkey: SUPER + ALT + code:11\n\tkeycode: 0\n\tdescription: Project 2: blog\n\n'
printf 'bindd\n\tmodmask: 72\n\tsubmap: \n\tkey: SUPER + ALT + code:19\n\tkeycode: 0\n\tdescription: Colorful Terminals settings\n\n'
printf 'bindd\n\tmodmask: 64\n\tsubmap: \n\tkey: SUPER + code:10\n\tkeycode: 0\n\tdescription: Switch to workspace 1\n\n'
printf 'bindd\n\tmodmask: 72\n\tsubmap: resize\n\tkey: 3\n\tkeycode: 0\n\tdescription: In a submap\n'
EOF
# shellcheck disable=SC2016 # $HOME expands when the fake runs
printf '#!/bin/bash\necho "$HOME/code/current"\n' > "$fake/omarchy-cmd-terminal-cwd"
chmod +x "$fake"/*
scan=$(PATH="$fake:$PATH" HYPRLAND_INSTANCE_SIGNATURE=test "$helper" scan)
eq "conflicts: Omarchy keycode bind and a user keysym bind, not ours" \
  '[{"digit":1,"byCode":true,"description":"Switch to group window 1"},{"digit":2,"byCode":false,"description":"Project: heartwood"}]' \
  "$(jq -c .conflicts <<< "$scan")"
eq "current folder of the focused terminal" "~/code/current" "$(jq -r .currentDir <<< "$scan")"

finish

#!/bin/bash
# Installing and removing the three marked blocks, and the bash hook itself.
set -uo pipefail
# shellcheck source=tests/lib.bash
source "$(dirname "${BASH_SOURCE[0]}")/lib.bash"

bashrc() { printf '%s' "$HOME/.bashrc"; }
hyprland() { printf '%s' "$HOME/.config/hypr/hyprland.lua"; }
menu() { printf '%s' "$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"; }

# A home that looks like a fresh Omarchy install.
omarchy_home() {
  new_home
  mkdir -p "$HOME/.config/hypr" "$HOME/.config/omarchy/extensions"
  printf '# ~/.bashrc\nsource ~/.local/share/omarchy/default/bash/rc\n\n' > "$(bashrc)"
  printf 'require("hypr.bindings")\n-- o.window("qemu", { workspace = "5" })\n' > "$(hyprland)"
  printf '{\n  // Extend the Quickshell Omarchy menu with JSONC.\n  // "personal": {"icon":"","label":"Personal"},\n}\n' > "$(menu)"
}

snapshot() { for f in "$(bashrc)" "$(hyprland)" "$(menu)"; do printf '== %s\n' "$f"; cat "$f" 2> /dev/null || echo "(missing)"; done; }

# The menu file after the same comment and trailing-comma stripping Omarchy does.
menu_json() {
  sed -E '/^[[:space:]]*\/\//d' "$(menu)" | tr '\n' '\r' | sed -E 's/,([[:space:]\r]*[]}])/\1/g' | tr '\r' '\n'
}

echo "integration: install and uninstall"
omarchy_home
before=$(snapshot)
fails "install refuses without a terminal or --yes" "$helper" integration install < /dev/null
eq "refusal changed nothing" "$before" "$(snapshot)"
ok "install" "$helper" integration install --yes
eq "one block in ~/.bashrc" "1" "$(grep -c '^# BEGIN colorful-terminals' "$(bashrc)")"
eq "one block in hyprland.lua" "1" "$(grep -c '^-- BEGIN colorful-terminals' "$(hyprland)")"
eq "one block in the menu" "1" "$(grep -c '// BEGIN colorful-terminals' "$(menu)")"
eq "bashrc keeps its lines first" "# ~/.bashrc" "$(head -n 1 "$(bashrc)")"
ok "menu is still valid JSON" jq -e '."style.colorful-terminals".label == "Colorful Terminals"' <<< "$(menu_json)"
eq "state says installed" "true" "$("$helper" state | jq '.integration.installed')"
ok "backups made" test -n "$(ls "$HOME/.config/colorful-terminals/backup/"bashrc.* 2> /dev/null)"
ok "bash block parses" bash -n "$(bashrc)"
if command -v luac > /dev/null; then ok "lua block parses" luac -p "$(hyprland)"; fi

once=$(snapshot)
ok "install again" "$helper" integration install --yes
eq "installing twice adds nothing" "$once" "$(snapshot)"

ok "uninstall" "$helper" integration uninstall --yes
eq "uninstall restores every file byte for byte" "$before" "$(snapshot)"
ok "uninstall again is harmless" "$helper" integration uninstall --yes
eq "still the original" "$before" "$(snapshot)"

echo "integration: Super+Ctrl+Alt keys"
omarchy_home
mkdir -p "${conf%/*}"
printf 'replace-group-keys = yes\n' > "$conf"
ok "install with a line left from the Super+Alt days" "$helper" integration install --yes
eq "the old line is harmless" "true" "$("$helper" state | jq '.integration.installed and (.problems | length == 0)')"
fails "the key choice is gone from install" "$helper" integration install --yes --replace-group-keys yes
eq "the menu entry does not name keys" "0" "$(grep -c 'Super+Alt' "$(menu)")"

# Upgrading from 0.4: the menu block still says Super+Alt until it is refreshed.
omarchy_home
"$helper" integration install --yes > /dev/null
sed -i 's/hotkey for each project/Super+Alt key for each project/' "$(menu)"
ok "installing over an older version" "$helper" integration install --yes
eq "refreshes the old block in place" "0 1" "$(grep -c 'Super+Alt' "$(menu)") $(grep -c 'BEGIN colorful-terminals' "$(menu)")"

echo "integration: zsh and fish"
# Stand-ins for the shells, so the helper sees them installed.
shells_bin=$(mktemp -d)
homes+=("$shells_bin")
printf '#!/bin/sh\nexit 0\n' > "$shells_bin/zsh"
cp "$shells_bin/zsh" "$shells_bin/fish"
chmod +x "$shells_bin"/*
with_shells() { PATH="$shells_bin:$PATH" "$@"; }

omarchy_home
printf '# my zshrc\n' > "$HOME/.zshrc"
mkdir -p "$HOME/.config/fish/conf.d"
if ! command -v zsh > /dev/null && ! command -v fish > /dev/null; then
  eq "a config without the shell is not enough (uv makes both)" \
    '["~/.bashrc","~/.config/hypr/hyprland.lua","~/.config/omarchy/extensions/omarchy-menu.jsonc"]' \
    "$("$helper" state | jq -c '[.integration.files[].file]')"
fi
before=$(snapshot; cat "$HOME/.zshrc"; find "$HOME/.config/fish" -type f)
eq "zsh and fish users need them too" "false" "$(with_shells "$helper" state | jq '.integration.installed')"
eq "the panel lists them" '["~/.bashrc","~/.zshrc","~/.config/fish/conf.d/colorful-terminals.fish","~/.config/hypr/hyprland.lua","~/.config/omarchy/extensions/omarchy-menu.jsonc"]' \
  "$(with_shells "$helper" state | jq -c '[.integration.files[].file]')"
ok "install for zsh and fish" with_shells "$helper" integration install --yes
eq "one block in ~/.zshrc, after its lines" "# my zshrc|# BEGIN colorful-terminals" "$(head -n 2 "$HOME/.zshrc" | cut -c1-26 | paste -sd '|')"
fishfile="$HOME/.config/fish/conf.d/colorful-terminals.fish"
ok "fish gets its own file" test -f "$fishfile"
eq "fish block sources the fish hook" '1' "$(grep -c "source '.*/shell/colorful-terminals.fish'; end" "$fishfile")"
eq "state says installed" "true" "$(with_shells "$helper" state | jq '.integration.installed')"
zsh=${CT_ZSH:-$(command -v zsh || true)}
fish=${CT_FISH:-$(command -v fish || true)}
if [[ -n $zsh ]]; then ok "zsh block parses" "$zsh" -n "$HOME/.zshrc"; fi
if [[ -n $fish ]]; then ok "fish block parses" "$fish" -n "$fishfile"; fi
ok "uninstall, even with the shells gone" "$helper" integration uninstall --yes
eq "zshrc back, fish file gone" "$before" "$(snapshot; cat "$HOME/.zshrc"; find "$HOME/.config/fish" -type f)"

omarchy_home
SHELL=/usr/bin/zsh with_shells "$helper" integration install --yes > /dev/null
ok "zsh as the login shell gets a ~/.zshrc" grep -q 'BEGIN colorful-terminals' "$HOME/.zshrc"

echo "integration: unusual files"
omarchy_home
printf 'alias ll="ls -l"' > "$(bashrc)"   # no final newline
rm "$(hyprland)" "$(menu)"
before=$(snapshot)
ok "install without final newline or files" "$helper" integration install --yes
eq "block starts on its own line" "alias ll=\"ls -l\"" "$(head -n 1 "$(bashrc)")"
ok "created menu is valid JSON" jq -e 'has("style.colorful-terminals")' <<< "$(menu_json)"
ok "uninstall" "$helper" integration uninstall --yes
eq "exact bytes back, created files removed" "$before" "$(snapshot)"
eq "no trailing newline added" "alias ll=\"ls -l\"" "$(cat "$(bashrc)")"

omarchy_home
real="$HOME/dotfiles/bashrc"
mkdir -p "${real%/*}"
mv "$(bashrc)" "$real"
ln -s "$real" "$(bashrc)"
ok "install through a symlinked ~/.bashrc" "$helper" integration install --yes
ok "~/.bashrc is still a symlink" test -L "$(bashrc)"
eq "block went into the real file" "1" "$(grep -c 'BEGIN colorful-terminals' "$real")"
ok "uninstall" "$helper" integration uninstall --yes
ok "still a symlink after uninstall" test -L "$(bashrc)"

omarchy_home
ok "install" "$helper" integration install --yes
printf 'export EDITOR=nvim\n' >> "$(bashrc)"
ok "uninstall after the user edited the file" "$helper" integration uninstall --yes
eq "their edit survives" "export EDITOR=nvim" "$(tail -n 1 "$(bashrc)")"
eq "our block is gone" "0" "$(grep -c colorful-terminals "$(bashrc)")"

omarchy_home
printf '[]\n' > "$(menu)"
fails "menu without an object is not touched" "$helper" integration install --yes
eq "menu unchanged" "[]" "$(cat "$(menu)")"

echo "integration: bash hook"
if ! command -v script > /dev/null; then
  echo "  SKIP: needs script(1) for a pseudo-terminal"
else
  omarchy_home
  mkdir -p "$HOME/code/shop/src" "$HOME/code/shop/admin" "${conf%/*}"
  printf '~/code/shop  #1a3a5a\n~/code/shop/admin  #681e1e\n' > "$conf"
  "$helper" integration install --yes > /dev/null
  run_shell() {
    printf '%s\nexit\n' "$1" | TERM=xterm-256color script -q -e -c "bash --noprofile --rcfile $HOME/.bashrc -i" /dev/null 2>&1 |
      tr -d '\r' | sed 's/\x1b\]0;[^\x07]*\x07//g'
  }
  # ~/.bashrc sources Omarchy's defaults, which do not exist here.
  sed -i '/omarchy\/default\/bash\/rc/d' "$(bashrc)"
  out=$(run_shell $'cd ~/code/shop/src\ncd ~/code/shop/admin\ncd ~/code/shop\ncd /\nfalse\necho "status=$?"\nsource ~/.bashrc\nsource ~/.bashrc\necho "hooks=$(grep -o _ct_prompt <<< "${PROMPT_COMMAND[*]}" | wc -l)"')
  seq=$(grep -oE $'\x1b\\]11;#[0-9a-f]{6}\x07|\x1b\\]111\x07' <<< "$out" | sed $'s/\x1b\\]//; s/\x07//' | paste -sd ' ')
  eq "colors follow cd: sub, nested, parent, outside" "11;#1a3a5a 11;#681e1e 11;#1a3a5a 111" "$seq"
  ok "keeps \$? for the prompt" grep -q 'status=1' <<< "$out"
  eq "sourcing twice keeps one hook" "hooks=1" "$(grep -o 'hooks=[0-9]*' <<< "$out" | tail -n 1)"
  out=$(TERM=xterm-256color bash --noprofile --rcfile "$HOME/.bashrc" -i -c 'cd ~/code/shop; echo done' < /dev/null 2>&1)
  ok "no escape codes without a terminal" test "$(grep -c $'\x1b\\]11' <<< "$out")" = 0
fi

echo "integration: changing projects refreshes the keys without a config reload"
# A fake hyprctl records every call. `binds` answers with our own keys only,
# then with a clash on Super+Ctrl+Alt+1.
omarchy_home
fake="$HOME/fake-bin"
mkdir -p "$fake" "$HOME/code/shop" "$HOME/code/blog" "$HOME/code/api"
cat > "$fake/hyprctl" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$HOME/hyprctl.calls"
[[ $1 == binds ]] || exit 0
printf 'bindd\n\tmodmask: 76\n\tsubmap: \n\tkey: SUPER + CTRL + ALT + code:10\n\tkeycode: 0\n\tdescription: Project 1: shop\n\n'
[[ -f $HOME/clash ]] && printf 'bindd\n\tmodmask: 76\n\tsubmap: \n\tkey: SUPER + CTRL + ALT + code:10\n\tkeycode: 0\n\tdescription: Open my notes\n\n'
exit 0
EOF
chmod +x "$fake/hyprctl"
with_hypr() { PATH="$fake:$PATH" HYPRLAND_INSTANCE_SIGNATURE=test "$helper" "$@"; }
calls() { grep -v '^binds' "$HOME/hyprctl.calls" 2> /dev/null | cut -d' ' -f1 | sort -u | paste -sd ' '; }
ok "add before turning on" with_hypr add "$HOME/code/shop" '#1a3a5a'
eq "touches Hyprland only when the keys block is installed" "" "$(calls)"
ok "turn on" "$helper" integration install --yes
: > "$HOME/hyprctl.calls"
ok "add" with_hypr add "$HOME/code/blog" '#213f12'
ok "move" with_hypr move 2 up
ok "color key" with_hypr paint-color 3 '#5a1a3a'
ok "remove" with_hypr remove 1
eq "each change re-binds through eval, never a config reload" "eval" "$(calls)"
eq "four changes, four re-binds" "4" "$(grep -c '^eval' "$HOME/hyprctl.calls")"
ok "the eval runs hypr/keys.lua in rebind mode from the plugin folder" \
  grep -qF 'dofile(dir .. "/hypr/keys.lua")(dir, { rebind = true })' "$HOME/hyprctl.calls"
ok "from this plugin folder" grep -qF "${helper%/bin/*}" "$HOME/hyprctl.calls"
touch "$HOME/clash"
: > "$HOME/hyprctl.calls"
ok "add with a clash on one of our keys" with_hypr add "$HOME/code/api" '#681e1e'
eq "then the keys are left alone, so the other binding survives" "" "$(calls)"
ok "a change without Hyprland is fine" env -u HYPRLAND_INSTANCE_SIGNATURE "$helper" move 1 down

finish

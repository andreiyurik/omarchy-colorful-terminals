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

echo "integration: key choice at install"
omarchy_home
eq "no key setting before install" "false" "$("$helper" state | jq '.replaceGroupKeysSet')"
ok "install with project keys first" "$helper" integration install --yes --replace-group-keys yes
eq "choice saved" "true" "$("$helper" state | jq '.replaceGroupKeys and .replaceGroupKeysSet')"
fails "bad key choice refused" "$helper" integration install --yes --replace-group-keys maybe
fails "unknown option refused" "$helper" integration install --yes --force
ok "keep Omarchy's keys" "$helper" integration install --yes --replace-group-keys no
eq "choice changed" "false" "$("$helper" state | jq '.replaceGroupKeys')"

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

finish

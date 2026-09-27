# shellcheck shell=bash disable=SC2034  # variables used by the test files
# Tiny test helpers. Every test file gets a fresh temporary HOME, so the real
# ~/.bashrc and ~/.config are never touched.

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
helper="$repo/bin/colorful-terminals"
failures=0
passes=0
homes=()

new_home() {
  HOME=$(mktemp -d)
  export HOME
  homes+=("$HOME")
  unset HYPRLAND_INSTANCE_SIGNATURE XDG_CONFIG_HOME ZDOTDIR TMUX TMUX_PANE
  export SHELL=/bin/bash
  conf="$HOME/.config/colorful-terminals/projects.conf"
}

cleanup_homes() { ((${#homes[@]} == 0)) || rm -rf -- "${homes[@]}"; }

pass() { passes=$((passes + 1)); }

fail() {
  failures=$((failures + 1))
  printf '  FAIL: %s\n' "$1"
  [[ -z ${2-} ]] || printf '%s\n' "$2" | sed 's/^/        /'
}

# eq <name> <expected> <actual>
eq() {
  if [[ $2 == "$3" ]]; then pass; else fail "$1" "expected: $(printf '%q' "$2")"$'\n'"actual:   $(printf '%q' "$3")"; fi
}

# ok <name> <command...>: the command must succeed
ok() {
  local name=$1 out
  shift
  if out=$("$@" 2>&1); then pass; else fail "$name" "$out"; fi
}

# fails <name> <command...>: the command must fail
fails() {
  local name=$1 out
  shift
  if out=$("$@" 2>&1); then fail "$name (should have failed)" "$out"; else pass; fi
}

finish() {
  cleanup_homes
  printf '  %d passed, %d failed\n' "$passes" "$failures"
  ((failures == 0))
}

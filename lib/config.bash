# shellcheck shell=bash
# Reads ~/.config/colorful-terminals/projects.conf. Shared by the bash hook and
# the helper, so both agree on every line. Pure bash: no subshells, no forks,
# cheap enough to run before every prompt.
#
# File format, one entry per line:
#   ~/code/shop        #243453      project folder, then its color
#   ~/code/blog  #23402f  # note    anything after " # " is a comment
#   paint-3 = #681e1e               a setting: the color on Super+Ctrl+Alt+Shift+3
#   # comment                       ignored
# The Nth project line opens with Super+Ctrl+Alt+N.

_ct_file="$HOME/.config/colorful-terminals/projects.conf"

# Parses one line into _ct_kind (blank|project|setting|problem) and fields.
_ct_parse_line() {
  local line=${1%$'\r'} body
  _ct_kind=blank _ct_path_text="" _ct_path="" _ct_color="" _ct_comment="" _ct_key="" _ct_value=""
  line=${line#"${line%%[![:space:]]*}"}
  line=${line%"${line##*[![:space:]]}"}
  [[ -z $line || $line == \#* ]] && return 0

  if [[ $line =~ ^([a-z][a-z0-9-]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
    _ct_kind=setting _ct_key=${BASH_REMATCH[1]} _ct_value=${BASH_REMATCH[2]}
    return 0
  fi

  _ct_kind=problem
  [[ $line == [~/]* ]] || return 0

  body=$line
  # A comment starts at the first "#" that has a space before it and a space
  # (or the end of the line) after it; "#1a3a5a" is never a comment.
  if [[ $line =~ [[:space:]]#([[:space:]]|$) ]]; then
    local i n=${#line}
    for ((i = 1; i < n; i++)); do
      [[ ${line:i:1} == "#" && ${line:i-1:1} == [[:space:]] ]] || continue
      if ((i + 1 == n)) || [[ ${line:i+1:1} == [[:space:]] ]]; then
        body=${line:0:i-1}
        body=${body%"${body##*[![:space:]]}"}
        _ct_comment=${line:${#body}}
        break
      fi
    done
  fi
  [[ $body =~ ^(.*[^[:space:]])[[:space:]]+(#[0-9A-Fa-f]{6})$ ]] || return 0

  local path_text=${BASH_REMATCH[1]} color=${BASH_REMATCH[2]} path
  case $path_text in
    "~") path=$HOME ;;
    "~/"*) path=$HOME/${path_text:2} ;;
    /*) path=$path_text ;;
    *) _ct_comment=""; return 0 ;;
  esac
  while [[ $path == */ && $path != / ]]; do path=${path%/}; done
  _ct_path_text=$path_text _ct_color=$color _ct_path=$path
  _ct_kind=project
}

# Fills _ct_paths/_ct_colors (projects in order).
_ct_load() {
  _ct_paths=() _ct_colors=()
  [[ -r $_ct_file ]] || return 0
  local line
  while IFS= read -r line || [[ -n $line ]]; do
    _ct_parse_line "$line"
    case $_ct_kind in
      project) _ct_paths+=("$_ct_path") _ct_colors+=("$_ct_color") ;;
    esac
  done < "$_ct_file"
}

# Prints the color for a folder: the project with the longest matching path
# wins, so a project inside another project keeps its own color. Empty means
# "no project here". Sets _ct_match instead of printing to avoid a subshell.
_ct_match_dir() {
  local dir=$1 i p best_len=-1
  _ct_match=""
  for i in "${!_ct_paths[@]}"; do
    p=${_ct_paths[i]}
    if [[ $dir == "$p" || $dir == "$p"/* || $p == / ]] && ((${#p} > best_len)); then
      _ct_match=${_ct_colors[i]}
      best_len=${#p}
    fi
  done
}

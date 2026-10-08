# Colorful Terminals for fish: tints the terminal background by project folder.
# Loaded from ~/.config/fish/conf.d/colorful-terminals.fish. Before each
# prompt it checks the current folder against
# ~/.config/colorful-terminals/projects.conf and sends OSC 11 (set background)
# or, when leaving a project, OSC 111 (back to the theme). A color is sent
# again at every prompt, so a terminal that reloaded its config (a theme
# switch) is back in its color at the next prompt. Inside tmux it colors the
# tmux pane instead, which keeps its style, so there it is set once.
#
# Super+Ctrl+Alt+Shift+1…8 gives this one terminal a color of its own (see
# the bash hook): Hyprland presses Ctrl+Alt+Shift+F12, which runs __ct_key.
#
# It reads projects.conf by the same rules as lib/config.bash (tests/hooks.test.sh
# checks they agree), with fish builtins only.

set -g __ct_file $HOME/.config/colorful-terminals/projects.conf
set -q __ct_shown; or set -g __ct_shown ''
set -q __ct_paint; or set -g __ct_paint ''
set -g __ct_request
set -q XDG_RUNTIME_DIR; and test -n "$XDG_RUNTIME_DIR"
and set -g __ct_request $XDG_RUNTIME_DIR/colorful-terminals/paint

# Prints the color for folder <dir>: the project with the longest matching
# path wins. Nothing means no project here.
function __ct_color_for --argument-names dir
    test -r $__ct_file; or return 0
    set -l best ''
    set -l best_len -1
    while read -l line
        set line (string replace -r '\r$' '' -- $line)
        set line (string trim -- $line)
        test -n "$line"; or continue
        string match -q -- '#*' $line; and continue
        string match -rq -- '^[a-z][a-z0-9-]*\s*=' $line; and continue
        string match -rq -- '^[~/]' $line; or continue

        # A comment starts at the first "#" with a space before it and a
        # space (or the end of the line) after it.
        set -l body $line
        set -l comment (string match -r -- '^(.*?)\s#(?:\s|$)' $line)
        and set body (string trim -r -- $comment[2])

        set -l parts (string match -r -- '^(.*\S)\s+(#[0-9A-Fa-f]{6})$' $body)
        or continue
        set -l pt $parts[2]
        set -l p
        switch $pt
            case '~'
                set p $HOME
            case '~/*'
                set p $HOME/(string sub -s 3 -- $pt)
            case '/*'
                set p $pt
            case '*'
                continue
        end
        while test "$p" != /; and string match -q -- '*/' $p
            set p (string replace -r '/$' '' -- $p)
        end

        set -l len (string length -- $p)
        if test "$dir" = "$p"; or test "$p" = /; or test (string sub -l (math $len + 1) -- $dir) = "$p/"
            if test $len -gt $best_len
                set best $parts[3]
                set best_len $len
            end
        end
    end < $__ct_file
    test -n "$best"; and echo $best
    return 0
end

# Shows <color>, or the theme color for "".
function __ct_apply --argument-names color
    if set -q TMUX; and set -q TMUX_PANE
        if test -n "$color"
            command tmux set -p -t $TMUX_PANE window-style "bg=$color" \; \
                set -p -t $TMUX_PANE window-active-style "bg=$color" >/dev/null 2>&1
        else
            command tmux set -p -u -t $TMUX_PANE window-style \; \
                set -p -u -t $TMUX_PANE window-active-style >/dev/null 2>&1
        end
    else if test -n "$color"
        printf '\e]11;%s\a' $color
    else
        printf '\e]111\a'
    end
end

# Only for interactive shells that draw on a real terminal.
status is-interactive; and isatty stdout; and not contains -- "$TERM" linux dumb
or return 0

# Shows this terminal's own color, or else the project color for $PWD.
# A named event handler replaces itself, so loading this again adds nothing.
function __ct_prompt --on-event fish_prompt
    set -l color $__ct_paint
    test -n "$color"; or set color (__ct_color_for $PWD)
    set -l in_tmux 0
    set -q TMUX; and set -q TMUX_PANE; and set in_tmux 1
    if test "$color" != "$__ct_shown"; or test -n "$color" -a $in_tmux -eq 0
        __ct_apply "$color"
        set -g __ct_shown "$color"
    end
end

# Takes the color the helper left and empties the file, which tells the
# helper this terminal got it.
function __ct_key
    test -n "$__ct_request"; and test -r $__ct_request; or return 0
    read -l color <$__ct_request
    true >$__ct_request
    if test "$color" = reset
        set -g __ct_paint ''
    else if string match -rq -- '^#[0-9A-Fa-f]{6}$' "$color"
        set -g __ct_paint $color
    else
        return 0
    end
    __ct_prompt
end

# Ctrl+Alt+Shift+F12, in the default and vi insert modes. fish 4 names keys;
# fish 3 matches the raw sequence.
for __ct_mode in default insert
    if test (string split -f1 . $version) -ge 4
        bind -M $__ct_mode ctrl-alt-shift-f12 __ct_key
    else
        bind -M $__ct_mode \e\[24\;8~ __ct_key
    end
end
set -e __ct_mode

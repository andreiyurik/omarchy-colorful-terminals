# Colorful Terminals for Omarchy

[![Tests](https://github.com/andreiyurik/omarchy-colorful-terminals/actions/workflows/tests.yml/badge.svg)](https://github.com/andreiyurik/omarchy-colorful-terminals/actions/workflows/tests.yml)
[![Omarchy plugin](https://img.shields.io/badge/Omarchy-plugin-81a1c1)](https://omarchy.org/)
[![MIT license](https://img.shields.io/github/license/andreiyurik/omarchy-colorful-terminals?color=9ece6a)](LICENSE)

Give every project its own terminal color, so you always know which project a terminal belongs to.

An [Omarchy](https://omarchy.org/) plugin for Hyprland: a different terminal background color per project folder in Ghostty, Kitty, Alacritty and foot, in bash, zsh and fish, inside tmux too, and `Super+Ctrl+Alt+1…9` hotkeys that open a project or jump to its window.

![Three terminals tinted blue, green and red by project, next to the Colorful Terminals settings panel](preview.png)

- **Automatic.** `cd` into a project and the background turns its color. Leave it and the theme color comes back. Subfolders keep the project color; a project inside another project keeps its own.
- **Project keys.** `Super+Ctrl+Alt+1…9` opens project 1…9 in a terminal, or jumps to its window if one is already open.
- **One small panel.** Add folders, pick colors, and reorder, with the keyboard or the mouse. Every change is saved as you make it.

It keys off the folder, not the way the terminal was opened, so it works with any project launcher (Project Launcher, Tableau, a tmux sessionizer, or plain `cd`).

## Install

```bash
omarchy plugin add https://github.com/andreiyurik/omarchy-colorful-terminals --enable
```

Then click the palette icon (󰏘) on the right of the bar.

1. Pick a folder: **Enter** adds the one you are in, or type to search your git repositories.
2. Choose **Turn on**. The panel lists the files it adds a block to, and **Show exact lines** shows every line first (see [What it changes](#what-it-changes)). Nothing changes before this.
3. Press **Enter** to open your first project in a new terminal, in its color.

After that, the bar icon, `Super+Ctrl+Alt+0`, or **Omarchy menu › Style › Colorful Terminals** opens the panel. To move the icon: `omarchy bar move andreiyurik.colorful-terminals --section left`. Without the icon, `omarchy-shell shell toggle andreiyurik.colorful-terminals '{}'` opens it too.

To update: `omarchy plugin update andreiyurik.colorful-terminals`, then `omarchy restart shell` so the new panel shows. (The shell reloads a plugin's entry file on its own, but keeps parts it has already loaded until it restarts.)

## Keys

| Keys | What it does |
|---|---|
| `Super+Ctrl+Alt+1` … `Super+Ctrl+Alt+9` | Open project N, or jump to its open window |
| `Super+Ctrl+Alt+0` | Open the settings panel |

In the panel:

| Keys | What it does |
|---|---|
| `↑` `↓` | Move between projects |
| `←` `→` | Change the project's color |
| `C` or `#` | Type a custom color, like `#1a3a5a`, with a live preview |
| `Shift+↑` `Shift+↓` | Move it up or down; this changes its key number |
| `Enter` | Open the project |
| `Del` | Remove it (**Undo** or `Ctrl+Z` puts it back) |
| `A` | Add a project (`Tab` completes a path) |
| `Ctrl+U` | Turn off, after asking |
| `Esc` | Close |

The bottom of the panel shows the few keys that matter for what is selected, and the buttons show theirs on hover. Everything also works with the mouse. Letter keys go by position, so they work on any keyboard layout, and the folder field understands a path typed on a Russian layout (`Ё.` is `~/`).

## The settings file

Everything lives in one file you can also edit by hand:
`~/.config/colorful-terminals/projects.conf`. The panel picks up your edits
while it is open, and new prompts use them right away.

```
# folder                color
~/code/shop             #1a3a5a
~/code/blog             #213f12     # anything after " # " is a comment
~/work/api-gateway      #681e1e
```

The first project line opens with `Super+Ctrl+Alt+1`, the second with `Super+Ctrl+Alt+2`, and so on. You can have more than nine projects: the rest get colors but no key. A `replace-group-keys` line from versions before 0.5 does nothing now and can be deleted.

## What it changes

The plugin itself only lives in `~/.config/omarchy/plugins/andreiyurik.colorful-terminals/`. To work, it adds one marked block to each of these files, and only after you choose **Turn on** in the panel:

| File | What the block does |
|---|---|
| `~/.bashrc` | Sources the hook that sets the terminal color before each prompt |
| `~/.zshrc` | The same for zsh, only if zsh is installed and you use it |
| `~/.config/fish/conf.d/colorful-terminals.fish` | The same for fish, in a file of its own, only if fish is installed and you use it |
| `~/.config/hypr/hyprland.lua` | Loads the `Super+Ctrl+Alt+0…9` keys |
| `~/.config/omarchy/extensions/omarchy-menu.jsonc` | Adds **Style › Colorful Terminals** to the Omarchy menu |

Each block starts with `BEGIN colorful-terminals` and ends with `END colorful-terminals`. Before changing a file, the plugin saves a copy to `~/.config/colorful-terminals/backup/`. A symlinked `~/.bashrc` stays a symlink.

The keys are `Super+Ctrl+Alt` because every other `Super`+digit combination is Omarchy's: workspaces, moving windows, bar panels, and group tabs on `Super+Alt`. So the plugin never takes a key of Omarchy's. If you bind something of your own to a `Super+Ctrl+Alt`+digit, the panel says so. Nothing needs sudo, nothing goes over the network, and nothing is collected.

## Remove

1. In the panel, choose **Turn off…** (or press `Ctrl+U`) and confirm. This removes the blocks and gives each file back exactly as it was (any edits you made since are kept). The same thing from a terminal:

   ```bash
   ~/.config/omarchy/plugins/andreiyurik.colorful-terminals/bin/colorful-terminals integration uninstall
   ```

2. Remove the plugin:

   ```bash
   omarchy plugin remove andreiyurik.colorful-terminals
   ```

Your project list and the backups stay in `~/.config/colorful-terminals/`. Delete that folder if you do not want them. If you remove the plugin first, the blocks stay behind but do nothing; delete the lines between the `BEGIN` and `END` markers by hand.

## Limitations

- **The color changes at the next prompt.** It switches when a command finishes and the shell draws its prompt, not in the middle of a running script.
- **bash, zsh and fish**, in terminals that support the standard OSC 11 background code: Ghostty, Kitty, Alacritty and foot all do. Inside tmux the tmux pane takes the color instead. Not inside zellij.
- **Terminals opened before you turn it on** get colors once you open them again; their shell has not loaded the hook yet.
- **Light themes get a light palette.** Colors picked on a dark theme are marked on a light one, so you can pick a light color instead.
- A program that paints its own background, such as a full-screen editor theme, covers the color while it runs.
- Folder names containing ` # ` (space, hash, space) or line breaks are not supported.

## FAQ

**How do I change the terminal background color per directory?**
Add the folder in the panel. The shell hook sends the standard OSC 11 escape code whenever you enter it, and OSC 111 to restore the theme color when you leave. Inside tmux it sets the pane's style instead, so each pane keeps its own color.

**Does it work with my terminal?**
With any terminal that supports OSC 11: Ghostty (Omarchy's default), Kitty, Alacritty and foot all do. And with bash, zsh and fish, in tmux or not.

**Can I tell projects apart at a glance in Hyprland?**
Yes: every project terminal has its own color, and its window gets the app id `org.omarchy.project_<name>`, so `Super+Ctrl+Alt+N` finds it again instead of opening a second one.

**Does it need a project launcher?**
No, and it works alongside one. The color depends only on the current folder.

## Development

```bash
tests/run              # every test, in a temporary HOME
tests/render-panel out # screenshots of the panel in each state (at 2x)
tests/render-preview   # regenerate preview.png
tests/distros/run      # bash, zsh, fish and tmux on Arch, Ubuntu, Debian and Fedora (docker)
tests/omarchy/run      # the panel on Omarchy's latest release and its default branch (docker)
tests/release-vm/run   # before a release: the plugin in a real Omarchy, in QEMU (docker, KVM)
```

The tests never touch your real `~/.bashrc`, `~/.zshrc` or `~/.config`. `tests/distros/run` runs the shell tests in a container per distribution, with each one's own shells and system shell config, as a normal user and without network; CI runs it for all four. `tests/omarchy/run` renders the panel on Omarchy's own shell code, fetched from GitHub: the latest release and the default branch. CI runs it on every push and once a day, so a change in Omarchy that breaks the panel is caught before a release reaches users.

Before a release, `tests/release-vm/run` installs the real Omarchy ISO in a QEMU/KVM virtual machine and goes through the plugin the way a user does: `omarchy plugin add`, the bar icon and the panel, Turn on, `Super+Ctrl+Alt+1` pressed on a virtual keyboard, the project terminal and its color in Ghostty, `Super+Ctrl+Alt+0`, `omarchy plugin update`, Turn off (every file back byte for byte), and `omarchy plugin remove`. QEMU runs in a container, so nothing is installed on your machine. The first run downloads the 6 GB ISO and installs Omarchy, up to 40 minutes; the installed system is cached and later runs take minutes. Screenshots land in `tests/release-vm/out/`.

A release is tagged only when all three are green: `tests/run` with CI (every push), `tests/omarchy/run` (every push and daily), and `tests/release-vm/run` (before the tag). The hook tests use zsh, fish and tmux when they are installed (`CT_ZSH` and `CT_FISH` point at other binaries) and skip them otherwise.

## License

[MIT](LICENSE)

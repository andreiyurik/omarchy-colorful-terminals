# Colorful Terminals for Omarchy

**A terminal background color for every project, and a hotkey that opens it.**

[![Tests](https://github.com/andreiyurik/omarchy-colorful-terminals/actions/workflows/tests.yml/badge.svg)](https://github.com/andreiyurik/omarchy-colorful-terminals/actions/workflows/tests.yml)
[![Omarchy plugin](https://img.shields.io/badge/Omarchy-plugin-81a1c1)](https://omarchy.org/)
[![MIT license](https://img.shields.io/github/license/andreiyurik/omarchy-colorful-terminals?color=9ece6a)](LICENSE)

![Three terminals on Omarchy Linux, each with its own background color: blue for shop, green for blog, red for api-gateway. Next to them the Colorful Terminals panel lists every project with its Super+Ctrl+Alt hotkey.](preview.png)

You have eight terminals open. Two are in the shop, three in the blog, one is `ssh`'d into production. They all look exactly the same, and the only way to tell them apart is to read the prompt. Sooner or later a `git push --force` or a `rm -rf build` lands in the wrong one.

Colorful Terminals is an [Omarchy](https://omarchy.org/) plugin that fixes this at the root: every project folder gets its own terminal background color. `cd` into the project and the terminal turns blue. Leave it and the theme color comes back. Press `Super+Ctrl+Alt+1` and the shop opens in a blue terminal, or its window comes to the front if it is already open. You know where you are before you read a single character.

It works in Ghostty, Kitty, Alacritty and foot, in bash, zsh and fish, inside tmux, and with any project launcher, because it keys off the folder and nothing else.

## Install

```bash
omarchy plugin add https://github.com/andreiyurik/omarchy-colorful-terminals --enable
```

Click the palette icon (󰏘) on the right of the bar, then:

1. **Pick a folder.** Enter adds the one you are in, or type to search your git repositories.
2. **Turn on.** The panel lists the five files it will add a block to, with **Show exact lines** if you want to see every line first. Nothing changes before this.
3. **Press Enter.** Your first project opens in a new terminal, in its color.

Open the panel again any time with `Super+Ctrl+Alt+0`, the bar icon, or **Omarchy menu › Style › Colorful Terminals**.

To update: `omarchy plugin update andreiyurik.colorful-terminals`, then `omarchy restart shell` so the new panel shows.

## What works where

Every terminal that understands the standard OSC 11 escape code can be colored. Omarchy's four terminals all do.

| Terminal | Project colors | Color keys (`Super+Ctrl+Alt+Shift`) | Notes |
|---|:-:|:-:|---|
| Ghostty (Omarchy's default) | ✓ | ✓ | Tested on every release in a real Omarchy VM |
| Kitty | ✓ | ✓ | Each kitty window has its own color |
| Alacritty | ✓ | ✓ | |
| foot | ✓ | ✓ | |
| Any other terminal with OSC 11 (WezTerm, Konsole, GNOME Terminal) | ✓ | ✓ | Not tested by the release test |

The shell does the coloring, so your shell matters more than your terminal.

| Shell or multiplexer | Project colors | Color keys | Tested on |
|---|:-:|:-:|---|
| bash | ✓ | ✓ | Arch, Ubuntu, Debian, Fedora |
| zsh | ✓ | ✓ | Arch, Ubuntu, Debian, Fedora |
| fish 3 and 4 | ✓ | ✓ | Arch, Ubuntu, Debian, Fedora |
| tmux | ✓ per pane | ✓ per pane | in all three shells |
| zellij | ✗ | ✗ | zellij paints its own background |

The hook runs before each prompt and costs 1–5 ms, with no forks. The color changes when the shell draws its prompt, so a terminal that reloaded its config on a theme switch is back in its color one prompt later.

## Hotkeys

| Keys | What it does |
|---|---|
| `Super+Ctrl+Alt+1` … `9` | Open project 1…9 in a terminal, or jump to its open window |
| `Super+Ctrl+Alt+0` | Open the settings panel |
| `Super+Ctrl+Alt+Shift+1` … `8` | Give the terminal you are in color 1…8, project or not |
| `Super+Ctrl+Alt+Shift+0` | Take that color away: back to the project or theme color |

**Why these keys.** Omarchy already uses every other `Super`+digit combination: `Super` switches workspaces, `Super+Shift` moves windows, `Super+Shift+Alt` moves them silently, `Super+Ctrl` opens bar panels, and `Super+Alt` picks a window in a group. `Super+Ctrl+Alt` is the one layer Omarchy leaves free on the digits, and it is the layer Omarchy itself uses for its own extras (`Super+Ctrl+Alt+D` is the calendar, `+T` the time). So the plugin takes no key of Omarchy's, you lose nothing, and the keys feel like part of the system. The release test checks every Omarchy key is untouched, and the panel warns if a binding of your own shares one.

The keys are bound by keycode, the same way Omarchy binds its own digits, so they work on any keyboard layout. The panel shows each project's key under its name, and Omarchy's keybindings list (`Super+K`) shows them all: project keys with their folder names, color keys with their colors.

A color from `Super+Ctrl+Alt+Shift` belongs to that one terminal. It stays when you `cd` into a project and goes away with `Super+Ctrl+Alt+Shift+0` or when the terminal closes. It is always the terminal you are in, even when one terminal program draws all your windows, because the shell in that terminal does the coloring. If a program is running there (an editor, `btop`, `ssh`), the shell cannot answer, so a notification says so and nothing changes.

### In the panel

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

On the **Any terminal** row, `←` `→` go from key to key, `Shift+←` `Shift+→` change that key's color, `C` types a custom one, and `Del` puts it back to the palette color. Everything also works with the mouse, and the footer always shows the few keys that matter for what is selected. Letter keys go by position, so they work on any layout, and the folder field understands a path typed on a Russian layout (`Ё.` is `~/`).

## Default colors

Eight hues around the color wheel, all at the same low brightness: far enough apart to tell at a glance, dark enough that your theme's text stays readable on every stock Omarchy theme (contrast 4.8 or better on all 22). A new project gets the first color no other project uses. The color keys use the same eight, in the same order.

| Key | Dark themes | | Light themes | |
|:-:|---|---|---|---|
| 1 | ![](https://img.shields.io/badge/-%20%20%20%20-1a3a5a) Blue | `#1a3a5a` | ![](https://img.shields.io/badge/-%20%20%20%20-c3d9f7) Blue | `#c3d9f7` |
| 2 | ![](https://img.shields.io/badge/-%20%20%20%20-213f12) Green | `#213f12` | ![](https://img.shields.io/badge/-%20%20%20%20-d4edbf) Green | `#d4edbf` |
| 3 | ![](https://img.shields.io/badge/-%20%20%20%20-681e1e) Red | `#681e1e` | ![](https://img.shields.io/badge/-%20%20%20%20-f7c9c9) Red | `#f7c9c9` |
| 4 | ![](https://img.shields.io/badge/-%20%20%20%20-4c2276) Violet | `#4c2276` | ![](https://img.shields.io/badge/-%20%20%20%20-dccbf8) Violet | `#dccbf8` |
| 5 | ![](https://img.shields.io/badge/-%20%20%20%20-621d4b) Plum | `#621d4b` | ![](https://img.shields.io/badge/-%20%20%20%20-f8cce9) Pink | `#f8cce9` |
| 6 | ![](https://img.shields.io/badge/-%20%20%20%20-4c3316) Brown | `#4c3316` | ![](https://img.shields.io/badge/-%20%20%20%20-f5cda6) Peach | `#f5cda6` |
| 7 | ![](https://img.shields.io/badge/-%20%20%20%20-262e82) Indigo | `#262e82` | ![](https://img.shields.io/badge/-%20%20%20%20-eeeea0) Lemon | `#eeeea0` |
| 8 | ![](https://img.shields.io/badge/-%20%20%20%20-13402a) Jade | `#13402a` | ![](https://img.shields.io/badge/-%20%20%20%20-bdeed8) Mint | `#bdeed8` |

On a light theme the panel offers the light palette and marks any color picked for a dark one. A custom color is a hex code away (`C` in the panel), and the panel tells you if the theme's text would be hard to read on it or if it looks the same as the theme background.

## The settings file

Everything lives in one file you can also edit by hand: `~/.config/colorful-terminals/projects.conf`. The panel picks up your edits while it is open, and new prompts use them right away.

```
# folder                color
~/code/shop             #1a3a5a
~/code/blog             #213f12     # anything after " # " is a comment
~/work/api-gateway      #681e1e
paint-3 = #5a1a3a                   # your own color on Super+Ctrl+Alt+Shift+3
```

The first project line opens with `Super+Ctrl+Alt+1`, the second with `Super+Ctrl+Alt+2`, and so on. You can have more than nine projects: the rest get colors but no key. A color key without a `paint-N` line uses the palette color, dark or light to match your theme. A `replace-group-keys` line from versions before 0.5 does nothing now and can be deleted.

## What it changes

The plugin itself lives only in `~/.config/omarchy/plugins/andreiyurik.colorful-terminals/`. To work, it adds one marked block to each of these files, and only after you choose **Turn on**:

| File | What the block does |
|---|---|
| `~/.bashrc` | Sources the hook that sets the terminal color before each prompt |
| `~/.zshrc` | The same for zsh, only if zsh is installed and you use it |
| `~/.config/fish/conf.d/colorful-terminals.fish` | The same for fish, in a file of its own, only if fish is installed and you use it |
| `~/.config/hypr/hyprland.lua` | Loads the `Super+Ctrl+Alt+0…9` and `Super+Ctrl+Alt+Shift+0…8` keys |
| `~/.config/omarchy/extensions/omarchy-menu.jsonc` | Adds **Style › Colorful Terminals** to the Omarchy menu |

Each block starts with `BEGIN colorful-terminals` and ends with `END colorful-terminals`. Before changing a file, the plugin saves a copy to `~/.config/colorful-terminals/backup/`. A symlinked `~/.bashrc` stays a symlink. Nothing needs sudo, nothing goes over the network, and nothing is collected.

## Remove

1. In the panel, choose **Turn off…** (or press `Ctrl+U`) and confirm. This removes the blocks and gives each file back exactly as it was; edits you made since are kept. The same thing from a terminal:

   ```bash
   ~/.config/omarchy/plugins/andreiyurik.colorful-terminals/bin/colorful-terminals integration uninstall
   ```

2. Remove the plugin:

   ```bash
   omarchy plugin remove andreiyurik.colorful-terminals
   ```

Your project list and the backups stay in `~/.config/colorful-terminals/`. Delete that folder if you do not want them. If you remove the plugin first, the blocks stay behind but do nothing; delete the lines between the `BEGIN` and `END` markers by hand.

## Good to know

- **The color changes at the next prompt**, when a command finishes and the shell draws its prompt, not in the middle of a running script.
- **Terminals opened before you turn it on** get colors once you open them again; their shell has not loaded the hook yet.
- **A program that paints its own background**, such as a full-screen editor theme, covers the color while it runs.
- **Subfolders keep the project color.** A project inside another project keeps its own.
- **Folder names containing ` # `** (space, hash, space) or line breaks are not supported.

## FAQ

### How do I change the terminal background color per directory on Omarchy?

Install the plugin and add the folder in the panel. The shell hook sends OSC 11 whenever you enter that folder and OSC 111 to restore the theme color when you leave. Inside tmux it sets the pane's style instead, so each pane keeps its own color.

### Does it conflict with Omarchy's keybindings?

No. Omarchy uses `Super`, `Super+Shift`, `Super+Shift+Alt`, `Super+Ctrl` and `Super+Alt` with the digits; the plugin uses `Super+Ctrl+Alt` and `Super+Ctrl+Alt+Shift`, which Omarchy leaves free. See [Hotkeys](#hotkeys).

### Does it work with Ghostty, Kitty, Alacritty and foot? With zsh, fish and tmux?

Yes to all of them. See [What works where](#what-works-where).

### Does it need a project launcher?

No, and it works alongside one. The color depends only on the current folder, so Project Launcher, Tableau, a tmux sessionizer and a plain `cd` all get the same color.

### How does `Super+Ctrl+Alt+N` find the project's window?

Every project terminal gets the app id `org.omarchy.project_<name>`, so the key focuses that window instead of opening a second one.

### Is it safe?

It adds marked blocks to five files, only after you choose **Turn on**, with a backup of each, and **Turn off** restores them byte for byte. No sudo, no network. See [What it changes](#what-it-changes).

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

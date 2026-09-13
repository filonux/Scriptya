<p align="center">
  <img src="assets/icon.png" width="140" alt="Scriptya icon">
</p>

<h1 align="center">Scriptya</h1>

<p align="center">
  A menu for your scripts: it organizes them into folders, runs them with fuzzy search,<br>
  and turns any of them into a desktop app with its own icon.
</p>

<p align="center"><strong><a href="README_ES.md">Read in Spanish</a></strong></p>

<img width="648" height="440" alt="1-menu-en-scriptya" src="https://github.com/user-attachments/assets/d556eeb7-c9de-4d4d-a1f1-49cb309eb0fe" />
<img width="872" height="484" alt="3-demos-tests-scriptya" src="https://github.com/user-attachments/assets/38e96590-d07f-41b6-b0cd-d05194889e5f" />
<img width="653" height="631" alt="4-metadata-en-scriptya" src="https://github.com/user-attachments/assets/9b2f94d0-c51d-420c-a181-5c6a2a710ada" />
<img width="204" height="103" alt="5-nemo-en-scriptya" src="https://github.com/user-attachments/assets/810aba8f-8ddd-48a7-9a14-4b2285e92a76" />

*Update 10-09-2026. What's new:*
- **Many more script types**: beyond Shell, Scriptya now discovers, runs and manages Python, Node.js, Perl, Ruby, Lua, Fish, AWK, PHP and Go scripts, as well as standalone HTML pages — all with metadata (name, description, confirmation, order, icon, and more), custom icons, and full menu/Nemo integration, just like the original `.sh` scripts.
- **Full English guide**: this README is now complete in English, matching the Spanish version section by section.
- "Insert Metadata": a wizard that fills MENU/DESCRIPTION/CONFIRM/TERMINAL/SUDO/ORDER/ICON/ASK in an existing script without editing it by hand (and also edits or removes them all at once). The metadata can also be used to change the name of the desktop and application-menu shortcut automatically.
  
- Nemo integration: 4 right-click actions (Run/Install/Uninstall/Change icon) in the Cinnamon file manager, which can be enabled/disabled without leaving anything behind in the system.
  
- "Change Icon": change the icon of scripts or any installed program as many times as you want. You can even change Scriptya's icon to the one included in this repository instead of the generic icon used during installation, or change [LinuxMint Scripter](https://github.com/filonux/LinuxMint-Scripter)'s icon to the official one from its own repository, so everything looks properly integrated in the menu and on the desktop.

## The problem it solves

Running, installing, uninstalling and updating your scripts, adding metadata without touching the code, keeping a full history, customizing icons, integrating into the application menu and the file manager.

Scriptya is a single `.sh` file with no mandatory dependencies.

## What it does exactly

- **Opens a navigable menu** over the scripts folder you choose, respecting subfolders.
- **Searches while you type**, using [`fzf`](https://github.com/junegunn/fzf) when available; otherwise it falls back to a classic numbered menu where you can also type text to filter the list.
- **Reads metadata from every managed file** (shell/Python/Perl/Ruby/Lua/Fish/AWK comments for `.sh`/`.py`/`.pl`/`.rb`/`.lua`/`.fish`/`.awk`, PHP `//` comments for `.php`, `//` comments for Node.js (`.js`/`.mjs`/`.cjs`) and Go (`.go`), and HTML comments for `.html`/`.htm`) to decide how to display and run it: display name, description, whether it needs confirmation, the menu order and icon; executable scripts can also request `sudo`, a new terminal and input before starting.
- **Lets you insert that metadata without touching the code**: a wizard ("Insert Metadata") asks for each field one by one — with the current value in brackets, so you do not lose it when changing just one thing — and writes it at the beginning of the file without touching the rest of it. For HTML, it uses HTML comments and preserves the document. It can also edit the metadata later or remove it all at once.
- **Turns supported Shell, Python, Node.js, Perl, Ruby, Lua, Fish, AWK, PHP CLI, and Go scripts, or standalone HTML pages into independent apps**,  with its own icon, in the Cinnamon application menu and/or on the Desktop — without having to write a `.desktop` file by hand. If you give it an image, it resizes it to a square icon and, when it detects a flat background (the typical case with a logo), removes it automatically (with ImageMagick).
- **Changes the icon of any installed program**: Scriptya itself, a script or web page already converted into an app, or any other application with a menu entry — Firefox, GIMP, LibreOffice, whether it came from a `.deb`, Flatpak or Snap. For a system app, the new icon is stored in a personal copy, without touching the original or asking for a password.
- **Integrates into Nemo's right-click menu** (if enabled): adds actions to run, install, uninstall or change the icon of a script or web page directly from the file manager, without having to find it in Scriptya first. Everything lives in your user folder and can be disabled just as easily, without leaving anything behind.
- **Keeps an execution history**: date, result and whether `sudo` was used.
- **Lets you change the scripts folder** at any time, browsing with a folder selector (using the native system dialog when `zenity` is available).
- **Includes English and Spanish**: on first start it follows `LC_ALL`, then `LC_MESSAGES`, then `LANG`. Spanish locales use Spanish; everything else defaults to English. You can switch at any time with the one-letter command `scriptya l` or the `L)` action in the menu, and the choice is saved in Scriptya's config.

## The advantage

Add this above your script and it immediately appears properly integrated into the menu, with confirmation, with `sudo` when needed, and as a desktop icon if you want:

```bash
#!/bin/bash
# MENU: Update system
# DESCRIPTION: apt update, upgrade and autoremove
# CONFIRM: true
# TERMINAL: true
# SUDO: true

set -euo pipefail
apt update && apt upgrade -y && apt autoremove -y
```

For a Python script, the same metadata works after its shebang, using normal Python comments:

```python
#!/usr/bin/env python3
# MENU: Local report
# DESCRIPTION: Generates the daily report
# CONFIRM: true
# TERMINAL: true
# SUDO: false
# ORDER: 20
# ICON: assets/report.png

print("Hello from Python")
```

For a Node.js script, use normal `//` comments after the shebang:

```javascript
#!/usr/bin/env node
// MENU: Local Node tool
// DESCRIPTION: Generates a local report
// CONFIRM: true
// TERMINAL: true
// SUDO: false
// ORDER: 30
// ICON: assets/node.png

console.log("Hello from Node.js");
```

For a Perl script, use normal `#` comments after the shebang:

```perl
#!/usr/bin/env perl
# MENU: Perl Utility
# DESCRIPTION: A small Perl utility
# CONFIRM: false
# TERMINAL: true
# SUDO: false

print "Hello from Perl\n";
```

For a Ruby script, use normal `#` comments after the shebang:

```ruby
#!/usr/bin/env ruby
# MENU: Ruby Utility
# DESCRIPTION: A small Ruby utility
# CONFIRM: false
# TERMINAL: true
# SUDO: false

puts "Hello from Ruby"
```

For a Lua script, use normal `--` comments after the shebang:

```lua
#!/usr/bin/env lua
-- MENU: Lua Utility
-- DESCRIPTION: A small Lua utility
-- CONFIRM: false
-- TERMINAL: true
-- SUDO: false

print("Hello from Lua")
```

For a Fish script, use normal `#` comments after the shebang:

```fish
#!/usr/bin/env fish
# MENU: Fish Utility
# DESCRIPTION: A small Fish utility
# CONFIRM: false
# TERMINAL: false
# SUDO: false

echo "Hello from Fish"
```

For an AWK program, use normal `#` comments at the top of the file; `ASK` values are exposed through `ENVIRON`:

```awk
# MENU: AWK Utility
# DESCRIPTION: A small AWK utility
# CONFIRM: false
# TERMINAL: false
# SUDO: false

BEGIN {
    print "Hello from AWK"
}
```

For a PHP CLI script, use normal `//` comments right after the opening `<?php` tag:

```php
#!/usr/bin/env php
<?php
// MENU: PHP Utility
// DESCRIPTION: A small PHP utility
// CONFIRM: false
// TERMINAL: true
// SUDO: false

echo "Hello from PHP\n";
```

For a Go file, use normal `//` comments. Scriptya compiles and runs it with Go:

```go
// MENU: Go Utility
// DESCRIPTION: A small Go utility
// CONFIRM: false
// TERMINAL: false
// SUDO: false
// ORDER: 40

package main

import "fmt"

func main() {
    fmt.Println("Hello from Go")
}
```

For an HTML page, the same idea uses HTML comments. Keep them at the top of the document, after the `DOCTYPE` when present:

```html
<!DOCTYPE html>
<!-- MENU: Local dashboard -->
<!-- DESCRIPTION: Useful offline dashboard -->
<!-- CONFIRM: true -->
<!-- ORDER: 10 -->
<!-- ICON: assets/dashboard.png -->
<html>
```

Shell, Python, Node.js, Perl, Ruby, Lua, Fish, AWK, PHP, and Go files appear in Scriptya and run with their interpreter; Go files are compiled and run with Go; HTML files appear in Scriptya and running them opens that exact file with the default browser. `scriptya --icons` can turn it into an independent application using the same metadata.

The script is still a normal script: you can run it directly (`./update_system.sh`, `python3 report.py` or `go run tool.go`) without going through Scriptya, and it works exactly the same. Metadata is optional and ignored when missing. And if you do not feel like writing it by hand, the menu itself has a wizard ("Insert Metadata") that asks for each field and stores it for you.

## Installation

```bash
git clone https://github.com/filonux/Scriptya.git
cd Scriptya/script
./scriptya.sh --install
```

The wizard asks where your scripts are (or will be), whether you want a couple of example scripts to start with, and whether you want a shortcut and/or an application-menu entry. When it finishes, the `scriptya` command will be available in any terminal.

To try it without installing anything in the system:

```bash
./scriptya.sh              # opens the menu directly, exactly as it is
./scriptya.sh --desktop    # or creates a shortcut that runs this same file
```

## Commands

| Command | What it does |
|---|---|
| `scriptya` | Opens the main menu |
| `scriptya --install` | Installs to the system (`scriptya` command, config, symlink) |
| `scriptya --desktop` | Creates a shortcut that runs this file as-is, without installing anything |
| `scriptya --icons` | Wizard to turn a loose script or HTML page into a standalone app with an icon |
| `scriptya --uninstall-icons` | View or uninstall existing standalone apps |
| `scriptya --update` | Updates the installed copy with the current file |
| `scriptya --uninstall` | Uninstalls everything created by `--install` (your scripts are untouched) |
| `scriptya --version` | Shows the version |
| `scriptya --help` | Shows the help |
| `scriptya l` | Toggles Spanish / English and saves the preference |

These same actions ("Install Scripts", "Uninstall Scripts", "Change Icon", "Insert Metadata", "Find Scripts", "Nemo Integration" when installed, "View History") are also available from the menu itself, at the end of the root-folder list.

## Available metadata

They are optional and go at the beginning of every managed file. For `.sh`, `.py`, `.pl`, `.rb`, `.lua`, `.fish`, and `.awk` files, put them immediately after the shebang as comments. For AWK, `ASK` values are exposed as `SCRIPTYA_ASK_1`, `SCRIPTYA_ASK_2`, etc. For PHP, put `//` metadata immediately after `<?php`; legacy `#` metadata is also read for compatibility. For Node.js `.js`/`.mjs`/`.cjs`, use `//` after the shebang. For `.html`/`.htm`, use HTML comments near the top of the document (after the `DOCTYPE` when present).

For HTML, `MENU`, `DESCRIPTION`, `CONFIRM`, `ORDER` and `ICON` are used by Scriptya. For `.sh`, `.py`, `.pl`, `.rb`, `.lua`, `.fish`, `.awk`, `.go`, PHP, and Node.js files, all metadata fields can be used, including `TERMINAL`, `SUDO` and `ASK`.

Example HTML header:

```html
<!DOCTYPE html>
<!-- MENU: Local dashboard -->
<!-- DESCRIPTION: Useful offline dashboard -->
<!-- CONFIRM: true -->
<!-- ORDER: 10 -->
<!-- ICON: assets/dashboard.png -->
<html>
```

`.sh`, `.py`, `.js`, `.mjs`, `.cjs`, `.pl`, `.rb`, `.lua`, `.fish`, `.awk`, `.php`, `.go`, `.html` and `.htm` files placed directly inside the configured scripts folder, or one of its subfolders, appear in the Scriptya tree. Python files are launched with Python 3 (or their executable Python shebang when they are executable); Node.js files are launched with `node` (or their executable Node.js shebang); Perl files are launched with `perl` (or their executable Perl shebang); Ruby files are launched with `ruby` (or their executable Ruby shebang); Lua files are launched with `lua` (or their executable Lua shebang); Fish files are launched with `fish` (or their executable Fish shebang); AWK files are launched with `awk -f`; PHP files are launched with `php` (or their executable PHP shebang); HTML files open with the default browser. `scriptya --icons` can install the same page as a standalone application using its metadata name, description and icon.

| Field | What it controls | Default |
|---|---|---|
| `MENU` | Name displayed in the menu | filename |
| `DESCRIPTION` | Short description, below the name | (none) |
| `CONFIRM` | `true` to ask for confirmation before running | `false` |
| `TERMINAL` | `true` to open it in a new terminal, with a desktop notification when it finishes | `false` |
| `SUDO` | `true` to run it with `sudo` | `false` |
| `ORDER` | Number that decides menu order (lower comes first) | `500` |
| `ASK` | Asks for keyboard input. Repeatable; passed as positional arguments for scripts, or as `SCRIPTYA_ASK_1`, `SCRIPTYA_ASK_2`, etc. for AWK | (none) |
| `ICON` | Icon to use with "Install Scripts": image path or system theme icon name | selector during installation |

Alternative to `ORDER`: scripts without it are already sorted alphabetically among themselves, so prefixing filenames with numbers (`01_backup.sh`, `02_cleanup.sh`) gives you full control over the order without adding any metadata.

## Day-to-day use

- **Browse and run**: enter folders, run a script, go back. With `fzf` installed, type to filter in real time; without it, type a number or text to filter the list.
- **Install Scripts**: choose a `.sh`, `.py`, `.pl`, `.rb`, `.lua`, `.fish`, `.awk`, `.go`, Node.js (`.js`/`.mjs`/`.cjs`), PHP (`.php`), or HTML page from the tree, an icon (browsing images or typing a system icon name), and where you want the shortcut — Cinnamon application menu, Desktop, or both.
- **Uninstall Scripts**: lists what you installed as standalone apps (scripts and web pages) and lets you remove one, several (space-separated) or all of them.
- **Change Icon**: Scriptya's icon, an already installed script or web page, a new web page (it creates a standalone shortcut for it, like "Install Scripts" but for HTML), or any other system application — choose the target and then the new image, exactly as when installing.
- **Insert Metadata**: choose a `.sh`, `.py`, `.pl`, `.rb`, `.lua`, `.fish`, `.awk`, `.go`, Node.js (`.js`/`.mjs`/`.cjs`), PHP (`.php`), or HTML page from the tree and fill its metadata with a wizard — Enter keeps each field unchanged, `-` clears it. For HTML, the metadata is written as HTML comments and the document body is kept intact. When a file already has metadata, you can edit it or remove it all at once instead of re-entering the whole template.
- **Find Scripts**: change the active scripts folder, browsing with the native system selector when `zenity` is available.
- **Nemo Integration**: enable or disable it here. When enabled, it adds a right-click menu in Nemo: for an uninstalled `.sh`, `.py`, `.pl`, `.rb`, `.lua`, `.fish`, AWK (`.awk`), Go (`.go`), PHP (`.php`), or Node.js file, Run and Install; for an installed one, Run, Uninstall and Change icon; for an uninstalled `.html`/`.htm`, Change icon and Install; for an installed one, Change icon and Uninstall. It does not touch system files — it lives in `~/.local/share/nemo/actions` and can be removed just as easily, without leaving a trace.
- **View History**: the latest executions, with date, result (✓/✗) and whether `sudo` was used. It is stored in `~/.local/share/scriptya/history.log`.
- **Language**: the interface follows the system locale on first start, defaults to English when the locale is not Spanish, and can be switched instantly with `scriptya l` or the `L)` menu entry. The manual choice is persisted in `~/.config/scriptya/config.conf`.

## Demo suite

The repository includes [`examples/`](examples/) with safe examples for every supported file type, plus dedicated cases for confirmation, ASK, icons, metadata editing and non-zero exit status. Start Scriptya and point the scripts folder to `examples/scripts` to exercise them from the normal menu.

The demo has its own [English guide](examples/README.md) and [Spanish guide](examples/README_ES.md). Each example is designed to be run, installed, uninstalled, given an icon, edited with **Insert Metadata**, and tested from Nemo when that integration is enabled.

## Compatibility

Tested on **Linux Mint 22.3 Cinnamon**. Since it uses only Bash, coreutils and the standard freedesktop.org `.desktop` files, it should behave the same on other Ubuntu/Debian-based distributions and other desktop environments (GNOME, XFCE, MATE...), although so far it has only been verified on Mint/Cinnamon. The exception is Nemo integration: it only makes sense when using Nemo (the Cinnamon file manager); in another desktop environment that specific option does nothing, but the rest of Scriptya works the same.

Optional dependencies — none of these are mandatory, Scriptya works without them, but they improve the experience:

| Tool | What it is for |
|---|---|
| `fzf` | Fuzzy-search menu instead of the numbered menu |
| `zenity` | Native folder/image selector |
| `imagemagick` | Automatic resizing and transparency handling when installing or changing an icon |
| `libnotify` (`notify-send`) | Desktop notification when a script finishes in a new terminal |
| `xdg-user-dirs` | Detects the real Desktop folder, whatever the system language |
| `python3` | Needed to run `.py` files without an executable Python shebang (usually already installed) |
| `node` | Needed to run `.js`/`.mjs`/`.cjs` files without an executable Node.js shebang |
| `perl` | Needed to run `.pl` files without an executable Perl shebang |
| `ruby` | Needed to run `.rb` files without an executable Ruby shebang |
| `lua` | Needed to run `.lua` files without an executable Lua shebang |
| `fish` | Needed to run `.fish` files without an executable Fish shebang |
| `awk` | Needed to run `.awk` files |
| `php` | Needed to run `.php` files without an executable PHP shebang |
| `go` | Needed to run `.go` files |
| `libglib2.0-bin` (`gio`) | Marks new shortcuts as trusted so Nemo does not ask for permission to open them |
| `xdg-utils` (`xdg-open`) | Opens HTML pages in the default browser when running them or using "Icon for HTML" |

## About the language

Scriptya now ships with a complete English and Spanish interface: menus, help, messages and generated Nemo actions are localized. The code comments remain in their original language so the implementation does not become unnecessarily larger.

On first start, the language follows `LC_ALL`, then `LC_MESSAGES`, then `LANG`. A Spanish locale (`es_*`, or the common equivalent locale forms) selects Spanish. Any other locale selects English. Once you switch manually, the preference is stored in the Scriptya config and remains in effect until you switch again.

The fastest way to change it is:

```bash
scriptya l
```

The same switch is available as `L)` in the main menu.

## Testing

The project includes a focused Bash test suite in [`tests/test_scriptya.sh`](tests/test_scriptya.sh). It checks syntax, executable permissions, real locale detection precedence, translation coverage including error paths, manual language persistence, backward-compatible configs, confirmation input in both languages, Nemo action localization, CLI language switching, and terminal-layout smoke checks. It is designed to stay independent from optional tools such as `fzf`, `zenity`, ImageMagick and Nemo.

Run it with:

```bash
chmod +x tests/test_scriptya.sh
./tests/test_scriptya.sh
```

## Contributing

Issues and pull requests are welcome — there are templates in `.github/` for reporting bugs, proposing improvements, or sending a PR. The complete guide is in [CONTRIBUTING.md](.github/CONTRIBUTING.md).

## License

GPLv3. See the [LICENSE](LICENSE.txt) file.

---

Made by **[Filonux](https://github.com/filonux)**.

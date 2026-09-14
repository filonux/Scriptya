# Scriptya Demo

[Español](README_ES.md)

A compact, safe demo set for Scriptya's supported file types and workflows. The examples are local-only: they print deterministic results, open one self-contained HTML page, or deliberately return a documented error.

## Examples

| File | Main coverage |
|---|---|
| `01-shell-demo.sh` | Shell baseline, metadata, icon, arguments |
| `02-python-demo.py` | Python, shebang, metadata, arguments |
| `03-node-demo.js` | Node.js, shebang, `//` metadata, arguments |
| `04-perl-demo.pl` | Perl, warnings/strict mode, metadata, arguments |
| `05-ruby-demo.rb` | Ruby, metadata, arguments |
| `06-lua-demo.lua` | Lua, shebang, metadata, arguments |
| `07-fish-demo.fish` | Fish, shebang, metadata, arguments |
| `08-html-demo.html` | HTML discovery, metadata, icon, browser launch |
| `09-confirm-and-ask.sh` | `CONFIRM` plus two `ASK` values |
| `10-failure.sh` | Non-zero exit status (`7`) and history |
| `11-php-demo.php` | PHP CLI, `<?php` metadata placement, `ASK` |
| `12-awk-demo.awk` | AWK, metadata, `ASK` via `ENVIRON` |
| `13-go-demo.go` | Go compilation, execution, metadata, `ASK` |

`demo-blue.svg` and `demo-green.svg` are small local icons used by the examples. They include SVG titles so they remain meaningful outside Scriptya too.

## Showcase examples

A second, more visual set for the most common languages. Same safety rules as above (no `SUDO`, no `TERMINAL`, no network, no files written), but focused on look and feel — a boxed dashboard, a small bar chart, a progress bar, or a richer HTML page — rather than the plain `_OK` tokens the minimal set uses for automated checks.

| File | Main coverage |
|---|---|
| `14-shell-showcase-demo.sh` | Boxed dashboard, small table, ANSI progress bar |
| `15-python-showcase-demo.py` | Boxed banner, bar chart, progress bar (stdlib only) |
| `16-node-showcase-demo.js` | Boxed banner, bar chart, progress bar (Node core only) |
| `17-html-showcase-demo.html` | Gradient page, animated cards, self-contained CSS |

They still print a final `*_SHOWCASE_DEMO_OK` line (or show it as a badge, for the HTML one) so they stay easy to spot in a screenshot or a quick check.

## Practical examples

A third set: small but genuinely useful tools, one per common language, each with its own icon. Unlike the two sets above, `ORDER` places them after the showcase set (`180`-`200`) rather than after their matching filename number, so a real-life example next to the language basics never fights it for the same menu slot.

| File | Main coverage |
|---|---|
| `01-system-glance.sh` | Real dashboard: uptime, load average, memory and disk usage |
| `02-password-generator.py` | Two `ASK` prompts, `secrets`-based generation, entropy estimate |
| `03-quick-notes.js` | Two-way file I/O: appends a timestamped note next to itself and lists the last ones |

`03-quick-notes.js` is the one exception to "no files written" below: it keeps its notes in `showcase-notes.txt`, next to the script itself. Delete that file at any time to reset it.

`showcase-gauge.svg`, `showcase-key.svg` and `showcase-notepad.svg` are their icons, one per example, in the same minimal style as `demo-blue.svg`/`demo-green.svg`.

## Quick verification

Set the Scriptya scripts directory to `examples/scripts` and check discovery first. Then use:

- `01-shell-demo.sh` for the normal run path.
- `09-confirm-and-ask.sh` for confirmation and two prompts.
- `10-failure.sh` for error reporting and history; it must return `7`.
- `08-html-demo.html` for HTML detection, metadata editing and browser opening.
- `Change Icon` on an installed demo to switch between `demo-blue.svg` and `demo-green.svg`.
- `Insert Metadata` on a disposable copy; Enter keeps a value and `-` clears it.
- `scriptya l` to exercise English/Spanish UI without changing demo source or output.

For direct execution, pass an argument such as `demo` to the script examples. The expected prefixes are `SHELL_DEMO_OK`, `PYTHON_DEMO_OK`, `NODE_DEMO_OK`, `PERL_DEMO_OK`, `RUBY_DEMO_OK`, `LUA_DEMO_OK`, `FISH_DEMO_OK`, `PHP_DEMO_OK`, `AWK_DEMO_OK` and `GO_DEMO_OK`.

`09-confirm-and-ask.sh` should print both submitted values. `10-failure.sh` should print `EXPECTED_FAILURE|7` and exit with `7`. The HTML page should display `HTML_DEMO_OK`.

The practical examples print `SYSTEM_GLANCE_OK`, `PASSWORD_DEMO_OK|<length>|<y or n>` and `QUICK_NOTES_OK|<note count>` respectively.

## Safe by default

The examples do not enable `SUDO` or `TERMINAL`, modify system state, contact a network service, or require elevated privileges. Test those options on a disposable copy when needed. Lua, Fish, PHP CLI, AWK and Go require their normal interpreters/tools; missing runtimes should be reported by Scriptya rather than hidden by the demos. The showcase set follows the same rules; the Node.js one only uses Node's own core APIs (no `npm install` needed) and the HTML one has no `<script>` tag and loads no remote resource. The only file either set writes is `03-quick-notes.js`'s own `showcase-notes.txt`, described above.

All metadata is intentionally short and limited to features the examples demonstrate. Original filenames and paths are part of the demo contract and should not be changed.

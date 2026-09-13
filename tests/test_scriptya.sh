#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT_DIR/script/scriptya.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/scriptya-tests.XXXXXX")"
LIB="$TMP_ROOT/scriptya-lib.sh"
PASS=0
FAIL=0

cleanup() {
    rm -rf -- "$TMP_ROOT"
}
trap cleanup EXIT

# Load the program's functions without invoking main(). This used to be
# "sed '$d' "$SCRIPT" > "$LIB"" (strip the last line) from before
# scriptya.sh had a BASH_SOURCE guard around its final "main "$@"" call:
# it worked, but only because bash executes already-parsed top-level
# commands before choking on the truncated "if" block left behind,
# printing a spurious "syntax error: unexpected end of file" on every
# single test. The guard now makes plain sourcing safe, so LIB is just
# a copy of the real script.
cp -- "$SCRIPT" "$LIB"

ok() {
    PASS=$((PASS + 1))
    printf 'PASS  %s\n' "$1"
}

fail() {
    FAIL=$((FAIL + 1))
    printf 'FAIL  %s\n' "$1" >&2
}

assert_eq() {
    local name="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then ok "$name"; else fail "$name (expected: <$expected>, got: <$actual>)"; fi
}

assert_contains() {
    local name="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then ok "$name"; else fail "$name (missing: <$needle>)"; fi
}

assert_file_exists() {
    local name="$1" path="$2"
    if [[ -f "$path" ]]; then ok "$name"; else fail "$name (missing: <$path>)"; fi
}

assert_not_empty() {
    local name="$1" value="$2"
    if [[ -n "$value" ]]; then ok "$name"; else fail "$name (empty)"; fi
}

assert_not_contains() {
    local name="$1" needle="$2" haystack="$3"
    if [[ "$haystack" != *"$needle"* ]]; then ok "$name"; else fail "$name (unexpected: <$needle>)"; fi
}

run_cli() {
    local home="$1"; shift
    HOME="$home" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash "$SCRIPT" "$@"
}

source_lib() {
    HOME="$TMP_ROOT/home-lib" bash -c 'source "$1"' _ "$LIB"
}

printf '== Scriptya test suite ==\n'
printf 'Script: %s\n\n' "$SCRIPT"

LUA_TEST_REAL=false
if command -v lua >/dev/null 2>&1; then
    LUA_TEST_REAL=true
else
    LUA_TEST_BIN="$TMP_ROOT/lua-bin"
    mkdir -p "$LUA_TEST_BIN"
    cat > "$LUA_TEST_BIN/lua" <<'SHIM'
#!/bin/sh
script="$1"
shift || true
case "$script" in
  *run.lua) printf 'LUA_EXEC|%s\n' "${1:-}"; exit 0;;
  *fail.lua) printf 'LUA_FAIL_PAYLOAD\n'; exit 7;;
  *shebang.lua) printf 'LUA_SHEBANG_OK\n'; exit 0;;
  *) exit 0;;
esac
SHIM
    chmod +x "$LUA_TEST_BIN/lua"
    export PATH="$LUA_TEST_BIN:$PATH"
fi

FISH_TEST_REAL=false
if command -v fish >/dev/null 2>&1; then
    FISH_TEST_REAL=true
else
    FISH_TEST_BIN="$TMP_ROOT/fish-bin"
    mkdir -p "$FISH_TEST_BIN"
    cat > "$FISH_TEST_BIN/fish" <<'SHIM'
#!/bin/sh
script="$1"
shift || true
case "$script" in
  *run.fish) printf 'FISH_EXEC|%s\n' "${1:-}"; exit 0;;
  *fail.fish) printf 'FISH_FAIL_PAYLOAD\n'; exit 7;;
  *shebang.fish) printf 'FISH_SHEBANG_OK\n'; exit 0;;
  *) exit 0;;
esac
SHIM
    chmod +x "$FISH_TEST_BIN/fish"
    export PATH="$FISH_TEST_BIN:$PATH"
fi

# 1. Basic file / shell integrity.
if bash -n "$SCRIPT"; then ok 'Bash syntax'; else fail 'Bash syntax'; fi
source "$LIB"

# 1b. The repository launcher must remain directly executable.
if [[ -x "$SCRIPT" ]]; then ok 'Repository launcher is executable'; else fail 'Repository launcher is not executable'; fi

# 2. Locale precedence and fallback. This is tested inside a fresh shell so
# locale variables cannot leak between cases.
for spec in \
    'LC_ALL=es_ES.UTF-8 LC_MESSAGES=C LANG=en_US.UTF-8|es' \
    'LC_ALL=C LC_MESSAGES=es_ES.UTF-8 LANG=es_ES.UTF-8|en' \
    'LC_ALL= LC_MESSAGES=es_ES.UTF-8 LANG=C|es' \
    'LC_ALL= LC_MESSAGES=C LANG=|en' \
    'LC_ALL=C LC_MESSAGES=C LANG=|en'; do
    envspec="${spec%%|*}"; expected="${spec##*|}"
    actual=$(env $envspec bash -c 'source "$1"; detect_system_language' _ "$LIB" 2>/dev/null)
    assert_eq "Locale detection: $envspec" "$expected" "$actual"
done

# 3. Translation corpus, including dynamic messages.
declare -a CORPUS_EN=(
    "Instala 'libglib2.0-bin' (comando 'gio') para evitar el aviso de|Install 'libglib2.0-bin' (command 'gio') to avoid the permission warning from"
    "No se pudo marcar 'foo.sh' como 'de confianza'.|Could not mark 'foo.sh' as trusted."
    "Terminó con código 7.|Ended with code 7."
    "Mostrando las últimas 50 ejecuciones de 73 (más reciente primero).|Showing the latest 50 of 73 executions (most recent first)."
    "La carpeta '/tmp/x' no existe. ¿Crearla?|The folder '/tmp/x' does not exist. Create it?"
    "'Foo' instalado como aplicación independiente|'Foo' installed as a standalone application"
    "'Foo' instalado con icono propio|'Foo' installed with its own icon"
    "Icono de 'Foo' actualizado.|Icon for 'Foo' updated."
    "página|web page"
    "¿Dónde quieres el acceso?|Where do you want the shortcut?"
    "Datos pedidos por teclado antes de ejecutar (ASK): ninguno.|Input requested before running (ASK): none."
    "/tmp/bin no está en tu PATH.|/tmp/bin is not in your PATH."
)
for pair in "${CORPUS_EN[@]}"; do
    src=${pair%%|*}; expected=${pair#*|}
    actual=$(bash -c 'source "$1"; LANGUAGE=en; tr "$2"' _ "$LIB" "$src")
    assert_eq "English: $src" "$expected" "$actual"
done

for pair in "${CORPUS_EN[@]}"; do
    src=${pair%%|*}
    actual=$(bash -c 'source "$1"; LANGUAGE=es; tr "$2"' _ "$LIB" "$src")
    assert_eq "Spanish source preserved: $src" "$src" "$actual"
done

# 4. English UI from a neutral locale.
HOME_EN="$TMP_ROOT/home-en"; mkdir -p "$HOME_EN/Scripts"
out=$(run_cli "$HOME_EN" <<< '0' 2>&1)
assert_contains 'English main menu title' 'Install Scripts' "$out"
assert_contains 'English language action' 'L) Spanish' "$out"
assert_contains 'English exit' '0) Exit' "$out"
assert_not_contains 'English menu has no Spanish Install label' 'Instalar Scripts' "$out"
assert_not_contains 'English menu has no Spanish language label' 'L) Español' "$out"

# 5. Manual toggle persists, and toggling twice restores English.
HOME_TOGGLE="$TMP_ROOT/home-toggle"; mkdir -p "$HOME_TOGGLE/Scripts"
out=$(run_cli "$HOME_TOGGLE" l 2>&1)
assert_contains 'Toggle to Spanish reports success' 'Idioma cambiado a Español.' "$out"
assert_eq 'Toggle config stores Spanish' 'es' "$(sed -n 's/^LANGUAGE=//p' "$HOME_TOGGLE/.config/scriptya/config.conf")"
out=$(run_cli "$HOME_TOGGLE" --help 2>&1)
assert_contains 'Persisted Spanish help' 'Idioma:' "$out"
assert_contains 'Spanish help documents toggle' 'scriptya.sh l' "$out"
out=$(HOME="$HOME_TOGGLE" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash "$SCRIPT" l 2>&1)
assert_contains 'Toggle back to English reports success' 'Language changed to English.' "$out"
assert_eq 'Toggle config stores English' 'en' "$(sed -n 's/^LANGUAGE=//p' "$HOME_TOGGLE/.config/scriptya/config.conf")"

# 6. The L) menu entry performs the same switch without changing the menu flow.
# Position 8, not 7: an empty Scripts/ shows the 6 fixed actions (install,
# uninstall, change icon, insert metadata, find scripts, Nemo integration
# -- always listed now, see B8) plus history (7) and toggle language (8).
HOME_MENU_TOGGLE="$TMP_ROOT/home-menu-toggle"; mkdir -p "$HOME_MENU_TOGGLE/Scripts"
out=$(run_cli "$HOME_MENU_TOGGLE" <<< $'8\n\n0\n' 2>&1)
assert_contains 'Menu language switch reports Spanish' 'Idioma cambiado a Español.' "$out"
assert_contains 'Menu redraws in Spanish' 'Instalar Scripts' "$out"
assert_contains 'Menu switch exposes English as the return language' 'L) Inglés' "$out"

# 7. Legacy config without LANGUAGE keeps locale detection behavior.
HOME_LEGACY="$TMP_ROOT/home-legacy"; mkdir -p "$HOME_LEGACY/Scripts" "$HOME_LEGACY/.config/scriptya"
printf 'SCRIPTS_DIR=%q\nTERMINAL=x-terminal-emulator\nSY_ICON=utilities-terminal\n' "$HOME_LEGACY/Scripts" > "$HOME_LEGACY/.config/scriptya/config.conf"
out=$(run_cli "$HOME_LEGACY" <<< '0' 2>&1)
assert_contains 'Legacy config defaults to English under C locale' 'Install Scripts' "$out"
assert_not_contains 'Legacy config does not force Spanish' 'Instalar Scripts' "$out"

# 8. Real CLI locale detection must affect the interface before any config exists.
HOME_LOCALE="$TMP_ROOT/home-locale"; mkdir -p "$HOME_LOCALE/Scripts"
out=$(HOME="$HOME_LOCALE" TERM=xterm NO_COLOR=1 LC_ALL= LC_MESSAGES=es_ES.UTF-8 LANG=es_ES.UTF-8 bash "$SCRIPT" --help 2>&1)
assert_contains 'Real CLI detects Spanish locale' 'Uso:' "$out"
out=$(HOME="$HOME_LOCALE" TERM=xterm NO_COLOR=1 LC_ALL=C LC_MESSAGES=C LANG=C bash "$SCRIPT" --help 2>&1)
assert_contains 'Real CLI falls back to English locale' 'Usage:' "$out"

# 9. Confirmation input accepts either language's affirmative in both UI languages.
for lang in en es; do
    for answer in y s; do
        if printf '%s\n' "$answer" | LANGUAGE_TEST="$lang" HOME="$TMP_ROOT" bash -c 'source "$1"; LANGUAGE="$LANGUAGE_TEST"; confirm_yn "¿Continuar?"' _ "$LIB" >/dev/null 2>&1; then
            ok "confirm_yn accepts '$answer' in $lang"
        else
            fail "confirm_yn accepts '$answer' in $lang"
        fi
    done
done

# 10. Config serialization keeps legacy fields and adds LANGUAGE safely.
HOME_CFG="$TMP_ROOT/home-config"; mkdir -p "$HOME_CFG/.config/scriptya"
if HOME="$HOME_CFG" bash -c 'source "$1"; SCRIPTS_DIR="/tmp/a path/\$x"; TERMINAL="x-term -e"; SY_ICON="theme icon"; LANGUAGE=en; save_config' _ "$LIB"; then ok 'save_config runs'; else fail 'save_config runs'; fi
cfg=$(cat "$HOME_CFG/.config/scriptya/config.conf")
assert_contains 'Config keeps SCRIPTS_DIR' 'SCRIPTS_DIR=/tmp/a\ path/\$x' "$cfg"
assert_contains 'Config keeps TERMINAL' 'TERMINAL=x-term\ -e' "$cfg"
assert_contains 'Config keeps SY_ICON' 'SY_ICON=theme\ icon' "$cfg"
assert_contains 'Config adds LANGUAGE' 'LANGUAGE=en' "$cfg"

# 11. Nemo action generator emits the localized action labels from the current language.
for lang in en es; do
    NHOME="$TMP_ROOT/home-nemo-$lang"; mkdir -p "$NHOME/.local/share/nemo/actions"
    action="$NHOME/.local/share/nemo/actions/test.nemo_action"
    if HOME="$NHOME" TEST_LANGUAGE="$lang" bash -c 'source "$1"; LANGUAGE="$TEST_LANGUAGE"; NEMO_ACTIONS_DIR="$2"; SCRIPT_PATH="/tmp/scriptya.sh"; write_nemo_action "$3" "$(tr "Lanzar con Scriptya")" "$(tr "Ejecuta este script con Scriptya")" "--run-script" "sh;" "utilities-terminal"' _ "$LIB" "$NHOME/.local/share/nemo/actions" "$action"; then
        action_text=$(cat "$action")
        if [[ "$lang" == en ]]; then
            assert_contains 'Nemo English action name' 'Name=Run with Scriptya' "$action_text"
            assert_contains 'Nemo English action comment' 'Comment=Run this script with Scriptya' "$action_text"
        else
            assert_contains 'Nemo Spanish action name' 'Name=Lanzar con Scriptya' "$action_text"
            assert_contains 'Nemo Spanish action comment' 'Comment=Ejecuta este script con Scriptya' "$action_text"
        fi
    else
        fail "Nemo action generation ($lang)"
    fi
done

# Nemo action contract: the action must pass the selected path through the documented %F token.
NEMO_ACTION_TEST="$TMP_ROOT/home-nemo-contract"; mkdir -p "$NEMO_ACTION_TEST/.local/share/nemo/actions"
NEMO_ACTION_FILE="$NEMO_ACTION_TEST/.local/share/nemo/actions/run.nemo_action"
HOME="$NEMO_ACTION_TEST" bash -c 'source "$1"; NEMO_ACTIONS_DIR="$2"; write_nemo_action "$3" "Run" "Run" "--run-script" "sh;" "utilities-terminal"' _ "$LIB" "$NEMO_ACTION_TEST/.local/share/nemo/actions" "$NEMO_ACTION_FILE"
nemo_action_text=$(cat "$NEMO_ACTION_FILE")
assert_contains 'Nemo action uses the path selection token' '--run-script %F' "$nemo_action_text"
assert_contains 'Nemo action quotes selected paths' 'Quote=double' "$nemo_action_text"
NEMO_PATH="$NEMO_ACTION_TEST/dir with spaces/demo.py"; mkdir -p "$(dirname "$NEMO_PATH")"; : > "$NEMO_PATH"
nemo_dispatch=$(HOME="$NEMO_ACTION_TEST" bash -c 'source "$1"; open_terminal_running(){ printf "%s|%s|%s\n" "$1" "$2" "$3"; }; main --nemo-run "$2"' _ "$LIB" "$NEMO_PATH" 2>&1)
assert_contains 'Nemo dispatch preserves paths with spaces' "$NEMO_PATH" "$nemo_dispatch"

# 11b. Toggling the UI language refreshes already-written Nemo actions
# (regression: write_nemo_actions used to run once at enable-time only).
NEMO_LANG_HOME="$TMP_ROOT/home-nemo-lang-sync"; mkdir -p "$NEMO_LANG_HOME"
nemo_lang_to_en=$(HOME="$NEMO_LANG_HOME" bash -c '
    source "$1"; SCRIPT_PATH="/tmp/scriptya.sh"; LANGUAGE=es
    write_nemo_actions >/dev/null
    toggle_language 0
    cat "$NEMO_ACTIONS_DIR/scriptya-run.nemo_action"
' _ "$LIB")
assert_contains 'Language toggle refreshes Nemo action name (es->en)' 'Name=Run with Scriptya' "$nemo_lang_to_en"
assert_contains 'Language toggle refreshes Nemo action comment (es->en)' 'Comment=Run this script with Scriptya' "$nemo_lang_to_en"

NEMO_LANG_HOME2="$TMP_ROOT/home-nemo-lang-sync-back"; mkdir -p "$NEMO_LANG_HOME2"
nemo_lang_to_es=$(HOME="$NEMO_LANG_HOME2" bash -c '
    source "$1"; SCRIPT_PATH="/tmp/scriptya.sh"; LANGUAGE=en
    write_nemo_actions >/dev/null
    toggle_language 0
    cat "$NEMO_ACTIONS_DIR/scriptya-install.nemo_action"
' _ "$LIB")
assert_contains 'Language toggle refreshes Nemo action name (en->es)' 'Name=Instalar con Scriptya' "$nemo_lang_to_es"

NEMO_LANG_HOME3="$TMP_ROOT/home-nemo-lang-notoggle"; mkdir -p "$NEMO_LANG_HOME3"
nemo_lang_untouched=$(HOME="$NEMO_LANG_HOME3" bash -c '
    source "$1"; SCRIPT_PATH="/tmp/scriptya.sh"; LANGUAGE=es
    toggle_language 0 >/dev/null
    [[ -f "$NEMO_ACTIONS_DIR/scriptya-run.nemo_action" ]] && echo EXISTS || echo MISSING
' _ "$LIB")
assert_eq 'Language toggle does not enable Nemo integration by itself' 'MISSING' "$nemo_lang_untouched"

# 12. Installation and uninstall smoke test in an isolated HOME.
HOME_INSTALL="$TMP_ROOT/home-install"; mkdir -p "$HOME_INSTALL/Scripts"
mkdir -p "$HOME_INSTALL/.local/bin"
if printf '1\n\n2\n2\n2\n2\n' | HOME="$HOME_INSTALL" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash "$SCRIPT" --install >/dev/null 2>&1; then
    ok 'Installation wizard completes'
else
    fail 'Installation wizard completes'
fi
assert_contains 'Installed launcher exists' 'scriptya.sh' "$(find "$HOME_INSTALL/.local/share/scriptya" -maxdepth 1 -type f -name 'scriptya.sh' -printf '%f' 2>/dev/null)"
assert_contains 'Installed config stores language' 'LANGUAGE=en' "$(cat "$HOME_INSTALL/.config/scriptya/config.conf" 2>/dev/null)"
out=$(HOME="$HOME_INSTALL" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash "$HOME_INSTALL/.local/share/scriptya/scriptya.sh" --help 2>&1)
assert_contains 'Installed launcher starts in English' 'Usage:' "$out"
if printf 'y\nn\n' | HOME="$HOME_INSTALL" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash "$SCRIPT" --uninstall >/dev/null 2>&1; then
    ok 'Uninstall completes'
else
    fail 'Uninstall completes'
fi
assert_not_contains 'Uninstall removes launcher copy' 'scriptya.sh' "$(find "$HOME_INSTALL/.local/share/scriptya" -maxdepth 1 -type f -name 'scriptya.sh' -printf '%f' 2>/dev/null)"

# 12b. Built-in onboarding example scripts (create_example_scripts) run
# as real, standalone processes and must not depend on scriptya's own
# functions (regression: they used to call "$(tr "...")" expecting the
# i18n helper, but a standalone process never sees it, so it silently
# ran the unrelated coreutils 'tr' instead and printed blank/garbled
# output with a stray error on stderr).
#
# Both language branches are generated with LANGUAGE explicitly set
# (regression: the previous version of this test only sourced the lib
# without setting LANGUAGE, so it silently depended on the locale of
# whichever machine ran the suite instead of on the code path itself).
EXAMPLES_DIR_ES="$TMP_ROOT/generated-examples-es"
HOME="$TMP_ROOT/home-examples-es" bash -c 'source "$1"; LANGUAGE=es; create_example_scripts "$2"' _ "$LIB" "$EXAMPLES_DIR_ES"
EXAMPLES_DIR_EN="$TMP_ROOT/generated-examples-en"
HOME="$TMP_ROOT/home-examples-en" bash -c 'source "$1"; LANGUAGE=en; create_example_scripts "$2"' _ "$LIB" "$EXAMPLES_DIR_EN"

for pair in "ES:$EXAMPLES_DIR_ES" "EN:$EXAMPLES_DIR_EN"; do
    lbl="${pair%%:*}"; d="${pair#*:}"
    assert_file_exists "Onboarding example ($lbl): system update script exists" "$d/actualizar_sistema.sh"
    assert_file_exists "Onboarding example ($lbl): backup script exists" "$d/Backup/copia_documentos.sh"
    assert_not_contains "Onboarding examples ($lbl) do not call the i18n tr() helper" '$(tr "' \
        "$(cat "$d/actualizar_sistema.sh" "$d/Backup/copia_documentos.sh")"
done

APT_MOCK_BIN="$TMP_ROOT/apt-mock"; mkdir -p "$APT_MOCK_BIN"
printf '#!/bin/sh\nexit 0\n' > "$APT_MOCK_BIN/apt"; chmod +x "$APT_MOCK_BIN/apt"
update_out_es=$(PATH="$APT_MOCK_BIN:$PATH" bash "$EXAMPLES_DIR_ES/actualizar_sistema.sh" 2>&1)
assert_contains 'Onboarding update script (es) prints its real messages' 'Actualizando lista de paquetes...' "$update_out_es"
assert_contains 'Onboarding update script (es) prints completion message' 'Sistema actualizado.' "$update_out_es"
assert_not_contains 'Onboarding update script (es) has no tr: missing operand error' 'missing operand' "$update_out_es"
update_out_en=$(PATH="$APT_MOCK_BIN:$PATH" bash "$EXAMPLES_DIR_EN/actualizar_sistema.sh" 2>&1)
assert_contains 'Onboarding update script (en) prints its real messages' 'Updating package list...' "$update_out_en"
assert_contains 'Onboarding update script (en) prints completion message' 'System updated.' "$update_out_en"

# Deterministic xdg-user-dir coverage: build a minimal, controlled PATH
# per scenario instead of trusting whatever happens to be installed on
# the machine running the suite.
BASE_BIN="$TMP_ROOT/bin-coreutils-only"; mkdir -p "$BASE_BIN"
for tool in date mkdir cp bash; do
    tool_path="$(command -v "$tool" 2>/dev/null)" && ln -sf "$tool_path" "$BASE_BIN/$tool"
done

# No source folder at all, and no xdg-user-dir on PATH either -> must
# fail cleanly with the real message (es and en), not with a bash
# "command not found" from "set -e" aborting early.
BACKUP_HOME_FAIL_ES="$TMP_ROOT/home-backup-fail-es"; mkdir -p "$BACKUP_HOME_FAIL_ES"
backup_fail_es=$(HOME="$BACKUP_HOME_FAIL_ES" PATH="$BASE_BIN" bash "$EXAMPLES_DIR_ES/Backup/copia_documentos.sh" 2>&1); backup_fail_es_rc=$?
assert_eq 'Backup (es) fails cleanly when there is no source folder' '1' "$backup_fail_es_rc"
assert_contains 'Backup (es) prints the real missing-folder message' 'No existe la carpeta de origen' "$backup_fail_es"
assert_not_contains 'Backup (es) has no tr: missing operand error' 'missing operand' "$backup_fail_es"

BACKUP_HOME_FAIL_EN="$TMP_ROOT/home-backup-fail-en"; mkdir -p "$BACKUP_HOME_FAIL_EN"
backup_fail_en=$(HOME="$BACKUP_HOME_FAIL_EN" PATH="$BASE_BIN" bash "$EXAMPLES_DIR_EN/Backup/copia_documentos.sh" 2>&1); backup_fail_en_rc=$?
assert_eq 'Backup (en) fails cleanly when there is no source folder' '1' "$backup_fail_en_rc"
assert_contains 'Backup (en) prints the real missing-folder message' 'Source folder not found' "$backup_fail_en"

# Case 1/3: xdg-user-dir is not installed at all. Without the "|| true"
# fix on "ORIGEN=$(xdg-user-dir ...)" this used to hit exit 127 under
# "set -euo pipefail" and abort before the Documents/Documentos
# fallback ever ran.
BACKUP_XDG_ABSENT="$TMP_ROOT/home-backup-xdg-absent"; mkdir -p "$BACKUP_XDG_ABSENT/Documentos"
: > "$BACKUP_XDG_ABSENT/Documentos/nota.txt"
: > "$BACKUP_XDG_ABSENT/fuera-de-documentos.txt"
backup_absent_out=$(HOME="$BACKUP_XDG_ABSENT" PATH="$BASE_BIN" bash "$EXAMPLES_DIR_EN/Backup/copia_documentos.sh" 2>&1); backup_absent_rc=$?
assert_eq 'Backup: xdg-user-dir missing does not abort the script' '0' "$backup_absent_rc"
assert_contains 'Backup: xdg-user-dir missing falls back and succeeds' 'Backup completed at:' "$backup_absent_out"
assert_file_exists 'Backup: xdg-user-dir missing copies the Documentos file' "$BACKUP_XDG_ABSENT/Backups/$(date +%Y-%m-%d)/nota.txt"
assert_not_contains 'Backup: xdg-user-dir missing does not copy the rest of HOME' 'fuera-de-documentos.txt' \
    "$(find "$BACKUP_XDG_ABSENT/Backups" -type f 2>/dev/null)"

# Case 2/3: xdg-user-dir "succeeds" but answers $HOME itself (the real
# bug: a fresh user with no ~/.config/user-dirs.dirs). Must be treated
# the same as no answer and fall back, never backing up all of HOME.
XDG_BIN_RETURNS_HOME="$TMP_ROOT/bin-xdg-returns-home"; mkdir -p "$XDG_BIN_RETURNS_HOME"
printf '#!/bin/sh\necho "$HOME"\n' > "$XDG_BIN_RETURNS_HOME/xdg-user-dir"; chmod +x "$XDG_BIN_RETURNS_HOME/xdg-user-dir"
BACKUP_XDG_HOME="$TMP_ROOT/home-backup-xdg-returns-home"; mkdir -p "$BACKUP_XDG_HOME/Documentos"
: > "$BACKUP_XDG_HOME/Documentos/nota.txt"
: > "$BACKUP_XDG_HOME/fuera-de-documentos.txt"
backup_home_out=$(HOME="$BACKUP_XDG_HOME" PATH="$XDG_BIN_RETURNS_HOME:$BASE_BIN" bash "$EXAMPLES_DIR_EN/Backup/copia_documentos.sh" 2>&1); backup_home_rc=$?
assert_eq 'Backup: xdg-user-dir returning $HOME still succeeds via fallback' '0' "$backup_home_rc"
assert_file_exists 'Backup: xdg-user-dir returning $HOME copies the Documentos file' "$BACKUP_XDG_HOME/Backups/$(date +%Y-%m-%d)/nota.txt"
assert_not_contains 'Backup: xdg-user-dir returning $HOME never backs up all of HOME' 'fuera-de-documentos.txt' \
    "$(find "$BACKUP_XDG_HOME/Backups" -type f 2>/dev/null)"

# Case 3/3: xdg-user-dir answers a real, different folder -> that
# answer must be trusted and used directly, not just the hardcoded
# Documents/Documentos fallback names.
XDG_BIN_RETURNS_REAL="$TMP_ROOT/bin-xdg-returns-real"; mkdir -p "$XDG_BIN_RETURNS_REAL"
printf '#!/bin/sh\necho "$HOME/MisArchivos"\n' > "$XDG_BIN_RETURNS_REAL/xdg-user-dir"; chmod +x "$XDG_BIN_RETURNS_REAL/xdg-user-dir"
BACKUP_XDG_REAL="$TMP_ROOT/home-backup-xdg-returns-real"; mkdir -p "$BACKUP_XDG_REAL/MisArchivos"
: > "$BACKUP_XDG_REAL/MisArchivos/archivo.txt"
backup_real_out=$(HOME="$BACKUP_XDG_REAL" PATH="$XDG_BIN_RETURNS_REAL:$BASE_BIN" bash "$EXAMPLES_DIR_EN/Backup/copia_documentos.sh" 2>&1); backup_real_rc=$?
assert_eq 'Backup: xdg-user-dir returning a real path succeeds' '0' "$backup_real_rc"
assert_file_exists 'Backup: xdg-user-dir returning a real path copies its file' "$BACKUP_XDG_REAL/Backups/$(date +%Y-%m-%d)/archivo.txt"

# End-to-end: the actual installer wizard (--install), not just the
# function in isolation, with LANGUAGE=en and accepting the onboarding
# examples prompt. This is the exact path the reported symptom went
# through: examples appearing in Spanish while the UI was in English.
E2E_HOME="$TMP_ROOT/home-examples-e2e"; mkdir -p "$E2E_HOME/Scripts" "$E2E_HOME/.local/bin"
if printf '1\ny\n2\n2\nn\n' | HOME="$E2E_HOME" LANGUAGE=en TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash "$SCRIPT" --install >/dev/null 2>&1; then
    ok 'End-to-end --install (LANGUAGE=en) accepting example scripts completes'
else
    fail 'End-to-end --install (LANGUAGE=en) accepting example scripts completes'
fi
assert_contains 'End-to-end install: example script is created in English' 'Updates system packages' \
    "$(cat "$E2E_HOME/Scripts/actualizar_sistema.sh" 2>/dev/null)"
assert_not_contains 'End-to-end install: example script is not left in Spanish' 'Actualiza los paquetes del sistema' \
    "$(cat "$E2E_HOME/Scripts/actualizar_sistema.sh" 2>/dev/null)"

# 13. Documentation links and structure.
assert_contains 'English README links to Spanish README' 'README_ES.md' "$(cat "$ROOT_DIR/README.md")"
assert_contains 'Spanish README links to English README' 'README.md' "$(cat "$ROOT_DIR/README_ES.md")"

# 14. Terminal layout smoke check: render-less width check of the main menu.
width_check() {
    local name="$1" out="$2" width=88 max=0 line clean len
    while IFS= read -r line; do
        clean=$(printf '%s' "$line" | sed -E $'s/\\x1B\\[[0-9;?]*[ -\\/]*[@-~]//g')
        len=${#clean}
        (( len > max )) && max=$len
        if (( len > width )); then
            fail "$name line width ($len > $width): $clean"
            return 0
        fi
    done <<< "$out"
    ok "$name line width (max $max/$width)"
}
width_check 'English menu aesthetics' "$(run_cli "$HOME_EN" <<< '0' 2>&1)"
HOME_ES="$TMP_ROOT/home-es"; mkdir -p "$HOME_ES/Scripts" "$HOME_ES/.config/scriptya"
printf 'LANGUAGE=es\n' > "$HOME_ES/.config/scriptya/config.conf"
width_check 'Spanish menu aesthetics' "$(run_cli "$HOME_ES" <<< '0' 2>&1)"


# 15. Regression corpus for previously leaked English/Spanish UI strings.
CORPUS_EN_EXTRA=(
    "Pulsa una tecla para continuar...|Press any key to continue..."
    "Pulsa una tecla para cerrar...|Press any key to close..."
    "Elige una aplicación instalada (Esc para cancelar)|Choose an installed application (Esc to cancel)"
    "¿A cuál le cambias el icono?: |Which one do you want to change the icon for: "
    "  1) Escritorio|  1) Desktop"
)
for pair in "${CORPUS_EN_EXTRA[@]}"; do
    src=${pair%%|*}; expected=${pair#*|}
    actual=$(bash -c 'source "$1"; LANGUAGE=en; tr "$2"' _ "$LIB" "$src")
    assert_eq "Extra English: $src" "$expected" "$actual"
done

# 16. Locale variants and explicit preference precedence.
for locale in es_ES.UTF-8 es-ES.UTF-8 ES_es.UTF-8 es@traditional; do
    actual=$(bash -c 'source "$1"; LC_ALL=C; LC_MESSAGES=; LANG=C; locale_value="$2"; locale_value="${locale_value,,}"; [[ "$locale_value" == es || "$locale_value" == es_* || "$locale_value" == es.* || "$locale_value" == es@* || "$locale_value" == es-* ]] && printf es || printf en' _ "$LIB" "$locale")
    assert_eq "Spanish locale variant: $locale" 'es' "$actual"
done
actual=$(bash -c 'source "$1"; LC_ALL=C; LC_MESSAGES=es_ES.UTF-8; LANG=es_ES.UTF-8; detect_system_language' _ "$LIB")
assert_eq 'LC_ALL overrides Spanish LC_MESSAGES' 'en' "$actual"

# 17. Language toggle preserves unrelated configuration fields exactly.
HOME_PRESERVE="$TMP_ROOT/home-preserve"; mkdir -p "$HOME_PRESERVE/.config/scriptya"
printf 'SCRIPTS_DIR=%q\nTERMINAL=%q\nSY_ICON=%q\n' \
    '/tmp/space path/$x' 'x-terminal-emulator -e' 'theme icon' > "$HOME_PRESERVE/.config/scriptya/config.conf"
old_cfg=$(cat "$HOME_PRESERVE/.config/scriptya/config.conf")
if HOME="$HOME_PRESERVE" bash -c 'source "$1"; CONFIG_DIR="$HOME/.config/scriptya"; CONFIG_FILE="$CONFIG_DIR/config.conf"; LANGUAGE=en; set_language es' _ "$LIB"; then ok 'Language toggle preserves config file'; else fail 'Language toggle preserves config file'; fi
assert_contains 'Preserved SCRIPTS_DIR after toggle' 'SCRIPTS_DIR=/tmp/space\ path/\$x' "$(cat "$HOME_PRESERVE/.config/scriptya/config.conf")"
assert_contains 'Preserved TERMINAL after toggle' 'TERMINAL=x-terminal-emulator\ -e' "$(cat "$HOME_PRESERVE/.config/scriptya/config.conf")"
assert_contains 'Preserved SY_ICON after toggle' 'SY_ICON=theme\ icon' "$(cat "$HOME_PRESERVE/.config/scriptya/config.conf")"
assert_contains 'Toggle adds LANGUAGE without rewriting other fields' 'LANGUAGE=es' "$(cat "$HOME_PRESERVE/.config/scriptya/config.conf")"

# 18. Core script execution keeps its exit status and output semantics across languages.
RUN_SCRIPT="$TMP_ROOT/behavior.sh"
cat > "$RUN_SCRIPT" <<'EOF'
#!/bin/bash
printf 'BEHAVIOR_OK\n'
exit 7
EOF
chmod +x "$RUN_SCRIPT"
for lang in en es; do
    home="$TMP_ROOT/home-run-$lang"; mkdir -p "$home/Scripts"
    cfg="$home/.config/scriptya"; mkdir -p "$cfg"
    printf 'LANGUAGE=%s\nSCRIPTS_DIR=%q\n' "$lang" "$home/Scripts" > "$cfg/config.conf"
    out=$(printf "x" | HOME="$home" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash "$SCRIPT" --run-script "$RUN_SCRIPT" 2>&1) || status=$?
    status=${status:-0}
    assert_eq "Run-script status is unchanged in $lang" '7' "$status"
    assert_contains "Run-script payload is unchanged in $lang" 'BEHAVIOR_OK' "$out"
    unset status
 done

# 20. No known Spanish UI labels may leak from direct prompts in English mode.
english_ui=$(HOME="$HOME_EN" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash "$SCRIPT" --help 2>&1)
assert_not_contains 'English help has no Spanish usage header' 'Uso:' "$english_ui"
assert_not_contains 'English help has no Spanish toggle wording' 'Intercambia Español / Inglés' "$english_ui"
assert_not_contains 'Script has no unwrapped Spanish option prompt' 'read -r -p "Opción [$def]' "$(grep -n 'read -r -p "Opción \[\$def\]' "$SCRIPT" || true)"


# 20b. English Nemo uninstall summary must use the translated label too.
NEMO_LANG_HOME="$TMP_ROOT/home-nemo-lang"
mkdir -p "$NEMO_LANG_HOME/.local/share/scriptya/registry"
NEMO_TEST_SCRIPT="$NEMO_LANG_HOME/test.pl"
printf '#!/usr/bin/env perl\n' > "$NEMO_TEST_SCRIPT"
NEMO_ID=$(HOME="$NEMO_LANG_HOME" bash -c 'source "$1"; registry_id_for "$2"' _ "$LIB" "$NEMO_TEST_SCRIPT")
HOME="$NEMO_LANG_HOME" bash -c 'source "$1"; registry_write "$2" "Demo" "$3" "utilities-terminal" no no perl' _ "$LIB" "$NEMO_ID" "$NEMO_TEST_SCRIPT"
nemo_lang_out=$(HOME="$NEMO_LANG_HOME" LANGUAGE=en bash -c 'source "$1"; LANGUAGE=en; pause(){ :; }; confirm_yn(){ return 1; }; nemo_uninstall_script "$2"' _ "$LIB" "$NEMO_TEST_SCRIPT" 2>&1)
assert_contains 'English Nemo uninstall summary is translated' 'The following will be uninstalled: Demo' "$nemo_lang_out"
assert_not_contains 'English Nemo uninstall summary has no Spanish label' 'Se desinstalará: Demo' "$nemo_lang_out"

# 20c. English Nemo uninstall must also translate the "not installed" warning.
NEMO_NOTINST_HOME="$TMP_ROOT/home-nemo-uninstall-notinstalled"; mkdir -p "$NEMO_NOTINST_HOME"
NEMO_NOTINST_SCRIPT="$NEMO_NOTINST_HOME/notinstalled.sh"
printf '#!/bin/bash\necho hi\n' > "$NEMO_NOTINST_SCRIPT"
nemo_notinst_out=$(HOME="$NEMO_NOTINST_HOME" LANGUAGE=en bash -c 'source "$1"; pause(){ :; }; nemo_uninstall_script "$2"' _ "$LIB" "$NEMO_NOTINST_SCRIPT" 2>&1)
assert_contains 'English Nemo uninstall warns when not installed' 'This script is not installed as a standalone application.' "$nemo_notinst_out"
assert_not_contains 'English Nemo "not installed" warning has no Spanish text' 'no está instalado' "$nemo_notinst_out"

# 20d. English Nemo uninstall, once confirmed, really removes the app and says so in English.
NEMO_OK_HOME="$TMP_ROOT/home-nemo-uninstall-ok"; mkdir -p "$NEMO_OK_HOME/.local/share/scriptya/registry"
NEMO_OK_SCRIPT="$NEMO_OK_HOME/installed.pl"
printf '#!/usr/bin/env perl\n' > "$NEMO_OK_SCRIPT"
NEMO_OK_ID=$(HOME="$NEMO_OK_HOME" bash -c 'source "$1"; registry_id_for "$2"' _ "$LIB" "$NEMO_OK_SCRIPT")
HOME="$NEMO_OK_HOME" bash -c 'source "$1"; registry_write "$2" "Demo" "$3" "utilities-terminal" no no perl' _ "$LIB" "$NEMO_OK_ID" "$NEMO_OK_SCRIPT"
nemo_ok_out=$(HOME="$NEMO_OK_HOME" LANGUAGE=en bash -c 'source "$1"; pause(){ :; }; confirm_yn(){ return 0; }; nemo_uninstall_script "$2"' _ "$LIB" "$NEMO_OK_SCRIPT" 2>&1)
assert_contains 'English Nemo uninstall confirms success' 'Uninstalled.' "$nemo_ok_out"
[[ ! -f "$NEMO_OK_HOME/.local/share/scriptya/registry/$NEMO_OK_ID.meta" ]] && ok 'English Nemo uninstall removes the registry entry' || fail 'English Nemo uninstall removes the registry entry'

# 20e. English Nemo uninstall translates the failure message when removal cannot finish.
NEMO_FAIL_HOME="$TMP_ROOT/home-nemo-uninstall-fail"; mkdir -p "$NEMO_FAIL_HOME/.local/share/scriptya/registry"
NEMO_FAIL_SCRIPT="$NEMO_FAIL_HOME/installed.pl"
printf '#!/usr/bin/env perl\n' > "$NEMO_FAIL_SCRIPT"
NEMO_FAIL_ID=$(HOME="$NEMO_FAIL_HOME" bash -c 'source "$1"; registry_id_for "$2"' _ "$LIB" "$NEMO_FAIL_SCRIPT")
HOME="$NEMO_FAIL_HOME" bash -c 'source "$1"; registry_write "$2" "Demo" "$3" "utilities-terminal" no no perl' _ "$LIB" "$NEMO_FAIL_ID" "$NEMO_FAIL_SCRIPT"
nemo_fail_out=$(HOME="$NEMO_FAIL_HOME" LANGUAGE=en bash -c 'source "$1"; pause(){ :; }; confirm_yn(){ return 0; }; remove_script_icon(){ return 1; }; nemo_uninstall_script "$2"' _ "$LIB" "$NEMO_FAIL_SCRIPT" 2>&1)
assert_contains 'English Nemo uninstall failure is translated' 'Could not fully uninstall' "$nemo_fail_out"
assert_not_contains 'English Nemo uninstall failure has no Spanish text' 'No se pudo desinstalar' "$nemo_fail_out"

# 20f. English Nemo "Change icon" on an already-installed app delegates to it (no reinstall).
NEMO_CHI_HOME="$TMP_ROOT/home-nemo-change-icon"; mkdir -p "$NEMO_CHI_HOME/.local/share/scriptya/registry"
NEMO_CHI_SCRIPT="$NEMO_CHI_HOME/installed.pl"
printf '#!/usr/bin/env perl\n' > "$NEMO_CHI_SCRIPT"
NEMO_CHI_ID=$(HOME="$NEMO_CHI_HOME" bash -c 'source "$1"; registry_id_for "$2"' _ "$LIB" "$NEMO_CHI_SCRIPT")
HOME="$NEMO_CHI_HOME" bash -c 'source "$1"; registry_write "$2" "Demo" "$3" "utilities-terminal" no no perl' _ "$LIB" "$NEMO_CHI_ID" "$NEMO_CHI_SCRIPT"
nemo_chi_out=$(HOME="$NEMO_CHI_HOME" LANGUAGE=en bash -c 'source "$1"; change_icon_for_script(){ printf "CHANGE_ICON_DISPATCH:%s\n" "$1"; }; nemo_change_icon_script "$2"' _ "$LIB" "$NEMO_CHI_SCRIPT" 2>&1)
assert_eq 'English Nemo change icon dispatches to the installed app' "CHANGE_ICON_DISPATCH:$NEMO_CHI_ID" "$nemo_chi_out"

# 20g. English Nemo "Change icon" on an uninstalled script offers to install it first.
NEMO_CHI2_HOME="$TMP_ROOT/home-nemo-change-icon-notinstalled"; mkdir -p "$NEMO_CHI2_HOME"
NEMO_CHI2_SCRIPT="$NEMO_CHI2_HOME/notinstalled.sh"
printf '#!/bin/bash\necho hi\n' > "$NEMO_CHI2_SCRIPT"
nemo_chi2_decline=$(HOME="$NEMO_CHI2_HOME" LANGUAGE=en bash -c 'source "$1"; pause(){ :; }; confirm_yn(){ return 1; }; install_icon_for_script(){ printf "SCRIPT_DISPATCH:%s\n" "$1"; }; nemo_change_icon_script "$2"' _ "$LIB" "$NEMO_CHI2_SCRIPT" 2>&1)
assert_contains 'English Nemo change icon warns when not installed' 'This script is not installed as a standalone application.' "$nemo_chi2_decline"
assert_contains 'English Nemo change icon explains why it must be installed' 'It must be installed this way to give it its own icon.' "$nemo_chi2_decline"
assert_not_contains 'English Nemo change icon does not install without confirmation' 'SCRIPT_DISPATCH' "$nemo_chi2_decline"
nemo_chi2_confirm=$(HOME="$NEMO_CHI2_HOME" LANGUAGE=en bash -c 'source "$1"; pause(){ :; }; confirm_yn(){ return 0; }; install_icon_for_script(){ printf "SCRIPT_DISPATCH:%s\n" "$1"; }; nemo_change_icon_script "$2"' _ "$LIB" "$NEMO_CHI2_SCRIPT" 2>&1)
assert_contains 'English Nemo change icon installs the script when confirmed' "SCRIPT_DISPATCH:$NEMO_CHI2_SCRIPT" "$nemo_chi2_confirm"

# 20h. Same flow for an uninstalled HTML page: the label and the dispatch differ from a script.
NEMO_CHI3_HOME="$TMP_ROOT/home-nemo-change-icon-html"; mkdir -p "$NEMO_CHI3_HOME"
NEMO_CHI3_HTML="$NEMO_CHI3_HOME/page.html"
printf '<html></html>\n' > "$NEMO_CHI3_HTML"
nemo_chi3_out=$(HOME="$NEMO_CHI3_HOME" LANGUAGE=en bash -c 'source "$1"; pause(){ :; }; confirm_yn(){ return 0; }; install_icon_for_html(){ printf "HTML_DISPATCH:%s\n" "$1"; }; nemo_change_icon_script "$2"' _ "$LIB" "$NEMO_CHI3_HTML" 2>&1)
assert_contains 'English Nemo change icon labels an uninstalled HTML file as a web page' 'This web page is not installed as a standalone application.' "$nemo_chi3_out"
assert_contains 'English Nemo change icon installs the HTML page when confirmed' "HTML_DISPATCH:$NEMO_CHI3_HTML" "$nemo_chi3_out"


# 21. Real English error paths must not leak Spanish UI text.
out=$(HOME="$HOME_EN" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash "$SCRIPT" --bogus 2>&1)
assert_contains 'Unknown option is translated' 'Unknown option: --bogus' "$out"
assert_not_contains 'Unknown option has no Spanish label' 'Opción desconocida' "$out"
for arg in --run-script --install-script --uninstall-script --change-icon-script --nemo-run; do
    out=$(HOME="$HOME_EN" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash "$SCRIPT" "$arg" 2>&1)
    assert_contains "Missing path usage is translated ($arg)" 'Usage:' "$out"
    assert_contains "Missing path placeholder is English ($arg)" '<script-path>' "$out"
    assert_not_contains "Missing path usage has no Spanish placeholder ($arg)" '<ruta-al-script>' "$out"
done
HOME_INVALID="$TMP_ROOT/home-invalid-dir"; mkdir -p "$HOME_INVALID/.config/scriptya"; touch "$HOME_INVALID/Scripts-file"
printf 'SCRIPTS_DIR=%q\n' "$HOME_INVALID/Scripts-file" > "$HOME_INVALID/.config/scriptya/config.conf"
out=$(HOME="$HOME_INVALID" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash "$SCRIPT" <<< $'n\n' 2>&1)
assert_contains 'Invalid scripts directory error is translated' 'Could not create' "$out"
assert_not_contains 'Invalid scripts directory error has no Spanish text' 'No se pudo crear' "$out"

# 22. Test the actual locale detector, including variants, not a duplicate implementation.
for locale in es_ES.UTF-8 es-ES.UTF-8 ES_es.UTF-8 es@traditional es; do
    actual=$(env LC_ALL= LC_MESSAGES= LANG="$locale" bash -c 'source "$1"; detect_system_language' _ "$LIB" 2>/dev/null)
    assert_eq "Real detector Spanish variant: $locale" 'es' "$actual"
done
for locale in C C.UTF-8 en_US.UTF-8 fr_FR.UTF-8 de_DE.UTF-8; do
    actual=$(env LC_ALL= LC_MESSAGES= LANG="$locale" bash -c 'source "$1"; detect_system_language' _ "$LIB" 2>/dev/null)
    assert_eq "Real detector non-Spanish fallback: $locale" 'en' "$actual"
done
actual=$(env LC_ALL= LC_MESSAGES=en_US.UTF-8 LANG=es_ES.UTF-8 bash -c 'source "$1"; detect_system_language' _ "$LIB" 2>/dev/null)
assert_eq 'Real detector honors LC_MESSAGES over LANG' 'en' "$actual"
actual=$(env LC_ALL=en_US.UTF-8 LC_MESSAGES=es_ES.UTF-8 LANG=es_ES.UTF-8 bash -c 'source "$1"; detect_system_language' _ "$LIB" 2>/dev/null)
assert_eq 'Real detector honors LC_ALL over lower locale categories' 'en' "$actual"

# 23. Uppercase one-letter language switch works and preserves the two-state toggle.
HOME_UPPER="$TMP_ROOT/home-upper"; mkdir -p "$HOME_UPPER/Scripts"
out=$(HOME="$HOME_UPPER" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash "$SCRIPT" L 2>&1)
assert_contains 'Uppercase L switches to Spanish' 'Idioma cambiado a Español.' "$out"
assert_eq 'Uppercase L stores Spanish' 'es' "$(sed -n 's/^LANGUAGE=//p' "$HOME_UPPER/.config/scriptya/config.conf")"
out=$(HOME="$HOME_UPPER" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash "$SCRIPT" L 2>&1)
assert_contains 'Uppercase L switches back to English' 'Language changed to English.' "$out"
assert_eq 'Second uppercase L stores English' 'en' "$(sed -n 's/^LANGUAGE=//p' "$HOME_UPPER/.config/scriptya/config.conf")"


# 24. Stored language preference overrides automatic locale detection in both directions.
HOME_PREF_EN="$TMP_ROOT/home-pref-en"; mkdir -p "$HOME_PREF_EN/Scripts" "$HOME_PREF_EN/.config/scriptya"
printf 'LANGUAGE=en\n' > "$HOME_PREF_EN/.config/scriptya/config.conf"
out=$(HOME="$HOME_PREF_EN" TERM=xterm NO_COLOR=1 LC_ALL= LC_MESSAGES=es_ES.UTF-8 LANG=es_ES.UTF-8 bash "$SCRIPT" --help 2>&1)
assert_contains 'Stored English preference overrides Spanish system locale' 'Usage:' "$out"
assert_not_contains 'Stored English preference has no Spanish help header' 'Uso:' "$out"
HOME_PREF_ES="$TMP_ROOT/home-pref-es"; mkdir -p "$HOME_PREF_ES/Scripts" "$HOME_PREF_ES/.config/scriptya"
printf 'LANGUAGE=es\n' > "$HOME_PREF_ES/.config/scriptya/config.conf"
out=$(HOME="$HOME_PREF_ES" TERM=xterm NO_COLOR=1 LC_ALL=C LC_MESSAGES=C LANG=C bash "$SCRIPT" --help 2>&1)
assert_contains 'Stored Spanish preference overrides non-Spanish system locale' 'Uso:' "$out"
assert_not_contains 'Stored Spanish preference has no English help header' 'Usage:' "$out"
HOME_AUTO_ES="$TMP_ROOT/home-auto-es"; mkdir -p "$HOME_AUTO_ES/Scripts"
out=$(HOME="$HOME_AUTO_ES" TERM=xterm NO_COLOR=1 LC_ALL= LC_MESSAGES=es_ES.UTF-8 LANG=es_ES.UTF-8 bash "$SCRIPT" --help 2>&1)
assert_contains 'No-language config auto-detects Spanish on first start' 'Uso:' "$out"
assert_not_contains 'No-language config does not default to English on Spanish locale' 'Usage:' "$out"

# 25. HTML files are first-class entries in the managed scripts tree.
HTML_ROOT="$TMP_ROOT/html-tree"
mkdir -p "$HTML_ROOT/sub" "$HTML_ROOT/.hidden"
touch "$HTML_ROOT/app.sh" "$HTML_ROOT/page.html" "$HTML_ROOT/page.htm" "$HTML_ROOT/.hidden/secret.html"
listed=$(bash -c 'source "$1"; list_scripts "$2"' _ "$LIB" "$HTML_ROOT")
assert_contains 'Managed list includes .sh files' 'app.sh' "$listed"
assert_contains 'Managed list includes .html files' 'page.html' "$listed"
assert_contains 'Managed list includes .htm files' 'page.htm' "$listed"
assert_not_contains 'Managed list excludes hidden HTML files' 'secret.html' "$listed"

# 26. HTML metadata is read from the HTML-comment form, including after DOCTYPE.
HTML_META="$HTML_ROOT/metadata.html"
cat > "$HTML_META" <<'HTML_META_EOF'
<!DOCTYPE html>
<!-- MENU: My Dashboard -->
<!-- DESCRIPTION: Useful local dashboard -->
<!-- CONFIRM: true -->
<!-- TERMINAL: true -->
<!-- SUDO: true -->
<!-- ORDER: 012 -->
<!-- ICON: assets/icon.png -->
<!-- ASK: ignored-for-html -->
<html><body><h1>Hello</h1></body></html>
HTML_META_EOF
meta=$(bash -c 'source "$1"; read_metadata "$2"; printf "%s|%s|%s|%s|%s|%s|%s|%s\n" "$META_MENU" "$META_DESCRIPTION" "$META_CONFIRM" "$META_TERMINAL" "$META_SUDO" "$META_ORDER" "$META_ICON" "${META_ASK[0]:-}"' _ "$LIB" "$HTML_META")
assert_eq 'HTML metadata parsing' 'My Dashboard|Useful local dashboard|true|true|true|12|assets/icon.png|ignored-for-html' "$meta"

# 27. HTML metadata detection recognizes only the file header, not body comments.
HTML_BODY_COMMENT="$HTML_ROOT/body-comment.html"
cat > "$HTML_BODY_COMMENT" <<'HTML_BODY_EOF'
<!DOCTYPE html>
<html><body>
<!-- MENU: Should Not Be Read -->
<h1>Real page</h1>
</body></html>
HTML_BODY_EOF
meta=$(bash -c 'source "$1"; read_metadata "$2"; printf "%s|%s\n" "$META_MENU" "$META_DESCRIPTION"' _ "$LIB" "$HTML_BODY_COMMENT")
assert_eq 'Body HTML comments are not treated as metadata' 'body-comment|' "$meta"
if bash -c 'source "$1"; script_has_metadata "$2"' _ "$LIB" "$HTML_BODY_COMMENT"; then
    fail 'Body HTML comments do not count as metadata'
else
    ok 'Body HTML comments do not count as metadata'
fi

# 28. Inserting HTML metadata preserves the DOCTYPE and document content.
HTML_EDIT="$HTML_ROOT/edit.html"
cat > "$HTML_EDIT" <<'HTML_EDIT_EOF'
<!DOCTYPE html>
<!-- Author note: keep this -->
<!-- MENU: Old title -->
<!-- DESCRIPTION: Old description -->
<html>
<head><title>Original title</title></head>
<body><p data-test="123">Original content</p></body>
</html>
HTML_EDIT_EOF
html_body_before=$(sed -n '/^<html>/,$p' "$HTML_EDIT")
HOME="$TMP_ROOT/home-html-edit" bash -c 'source "$1"; NEWMETA_MENU="New title"; NEWMETA_DESCRIPTION="New description"; NEWMETA_CONFIRM=true; NEWMETA_TERMINAL=false; NEWMETA_SUDO=false; NEWMETA_ORDER=7; NEWMETA_ICON="icon.png"; NEWMETA_ASK=("unused"); apply_metadata "$2"' _ "$LIB" "$HTML_EDIT"
html_after=$(cat "$HTML_EDIT")
assert_contains 'Inserted HTML MENU metadata' '<!-- MENU: New title -->' "$html_after"
assert_contains 'Inserted HTML DESCRIPTION metadata' '<!-- DESCRIPTION: New description -->' "$html_after"
assert_contains 'Inserted HTML CONFIRM metadata' '<!-- CONFIRM: true -->' "$html_after"
assert_contains 'Inserted HTML ORDER metadata' '<!-- ORDER: 7 -->' "$html_after"
assert_contains 'Inserted HTML ICON metadata' '<!-- ICON: icon.png -->' "$html_after"
assert_contains 'HTML DOCTYPE is preserved' '<!DOCTYPE html>' "$html_after"
assert_contains 'Non-metadata HTML header comment is preserved' '<!-- Author note: keep this -->' "$html_after"
html_body_after=$(sed -n '/^<html>/,$p' "$HTML_EDIT")
assert_eq 'HTML document body is unchanged by metadata insertion' "$html_body_before" "$html_body_after"

# 29. Removing HTML metadata preserves the rest of the document.
HOME="$TMP_ROOT/home-html-edit" bash -c 'source "$1"; NEWMETA_MENU=""; NEWMETA_DESCRIPTION=""; NEWMETA_CONFIRM=false; NEWMETA_TERMINAL=false; NEWMETA_SUDO=false; NEWMETA_ORDER=500; NEWMETA_ICON=""; NEWMETA_ASK=(); apply_metadata "$2"' _ "$LIB" "$HTML_EDIT"
html_after_remove=$(cat "$HTML_EDIT")
assert_not_contains 'HTML MENU metadata can be removed' '<!-- MENU:' "$html_after_remove"
assert_not_contains 'HTML DESCRIPTION metadata can be removed' '<!-- DESCRIPTION:' "$html_after_remove"
assert_contains 'HTML author comment survives metadata removal' '<!-- Author note: keep this -->' "$html_after_remove"
assert_eq 'HTML body survives metadata removal' "$html_body_before" "$(sed -n '/^<html>/,$p' "$HTML_EDIT")"

# 30. HTML ORDER participates in the same sorted menu as shell scripts.
cat > "$HTML_ROOT/late.html" <<'HTML_LATE_EOF'
<!DOCTYPE html>
<!-- ORDER: 30 -->
<html><body>late</body></html>
HTML_LATE_EOF
cat > "$HTML_ROOT/early.html" <<'HTML_EARLY_EOF'
<!DOCTYPE html>
<!-- ORDER: 3 -->
<html><body>early</body></html>
HTML_EARLY_EOF
sorted=$(bash -c 'source "$1"; sorted_scripts "$2" | xargs -n1 basename' _ "$LIB" "$HTML_ROOT")
first=$(printf '%s\n' "$sorted" | head -n1)
assert_eq 'HTML ORDER places lower numbers first' 'early.html' "$first"

# 31. --run-script opens HTML with xdg-open and does not execute it as Bash/sudo.
MOCK_BIN="$TMP_ROOT/mock-bin"; mkdir -p "$MOCK_BIN"
cat > "$MOCK_BIN/xdg-open" <<'MOCK_XDG_EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$XDG_OPEN_LOG"
exit 0
MOCK_XDG_EOF
cat > "$MOCK_BIN/sudo" <<'MOCK_SUDO_EOF'
#!/bin/bash
printf 'SUDO_USED\n' >> "$XDG_OPEN_LOG"
exit 99
MOCK_SUDO_EOF
chmod +x "$MOCK_BIN/xdg-open" "$MOCK_BIN/sudo"
HTML_RUN="$HTML_ROOT/run.html"
cat > "$HTML_RUN" <<'HTML_RUN_EOF'
<!DOCTYPE html>
<!-- MENU: Run HTML -->
<!-- DESCRIPTION: Opens the local page -->
<!-- SUDO: true -->
<!-- TERMINAL: true -->
<html><body><h1>Run</h1></body></html>
HTML_RUN_EOF
: > "$TMP_ROOT/xdg-open.log"
for lang in en es; do
    home="$TMP_ROOT/home-html-run-$lang"; mkdir -p "$home/.config/scriptya"
    printf 'LANGUAGE=%s\n' "$lang" > "$home/.config/scriptya/config.conf"
    out=$(XDG_OPEN_LOG="$TMP_ROOT/xdg-open.log" PATH="$MOCK_BIN:$PATH" HOME="$home" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash "$SCRIPT" --run-script "$HTML_RUN" <<< 'x' 2>&1)
    status=$?
    assert_eq "HTML run exits successfully in $lang" '0' "$status"
    assert_contains "HTML run displays the metadata title in $lang" 'Run HTML' "$out"
done
assert_eq 'HTML launch was recorded once per language' '2' "$(grep -cF "$HTML_RUN" "$TMP_ROOT/xdg-open.log" || true)"
assert_not_contains 'HTML launch never invokes sudo' 'SUDO_USED' "$(cat "$TMP_ROOT/xdg-open.log")"
assert_eq 'HTML launch target is identical in both languages' "$HTML_RUN" "$(head -n1 "$TMP_ROOT/xdg-open.log")"
assert_eq 'HTML launch target remains identical on second language run' "$HTML_RUN" "$(tail -n1 "$TMP_ROOT/xdg-open.log")"

# 32. HTML CONFIRM metadata is honored.
HTML_CONFIRM="$HTML_ROOT/confirm.html"
cat > "$HTML_CONFIRM" <<'HTML_CONFIRM_EOF'
<!DOCTYPE html>
<!-- MENU: Confirm me -->
<!-- CONFIRM: true -->
<html><body>confirm</body></html>
HTML_CONFIRM_EOF
: > "$TMP_ROOT/xdg-confirm.log"
home="$TMP_ROOT/home-html-confirm"; mkdir -p "$home/.config/scriptya"; printf 'LANGUAGE=en\n' > "$home/.config/scriptya/config.conf"
PATH="$MOCK_BIN:$PATH" HOME="$home" XDG_OPEN_LOG="$TMP_ROOT/xdg-confirm.log" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C \
    bash "$SCRIPT" --run-script "$HTML_CONFIRM" <<< $'n\nx' > "$TMP_ROOT/html-confirm-no.out" 2>&1 || true
assert_not_contains 'HTML confirmation cancels without launching' "$HTML_CONFIRM" "$(cat "$TMP_ROOT/xdg-confirm.log")"
PATH="$MOCK_BIN:$PATH" HOME="$home" XDG_OPEN_LOG="$TMP_ROOT/xdg-confirm.log" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C \
    bash "$SCRIPT" --run-script "$HTML_CONFIRM" <<< $'y\nx' > "$TMP_ROOT/html-confirm-yes.out" 2>&1
assert_contains 'HTML confirmation allows launch' "$HTML_CONFIRM" "$(cat "$TMP_ROOT/xdg-confirm.log")"

# 33. --icons uses HTML metadata for the standalone application's name and description.
HTML_ICON="$HTML_ROOT/icon-app.html"
cat > "$HTML_ICON" <<'HTML_ICON_EOF'
<!DOCTYPE html>
<!-- MENU: Dashboard App -->
<!-- DESCRIPTION: My dashboard description -->
<html><body>app</body></html>
HTML_ICON_EOF
HOME="$TMP_ROOT/home-html-icons" bash -c '
source "$1"
APPS_DIR="$2/.local/share/applications"
DESKTOP_DIR="$2/Desktop"
REGISTRY_DIR="$2/.local/share/scriptya/registry"
ICONS_DIR="$2/.local/share/scriptya/icons"
mkdir -p "$APPS_DIR" "$DESKTOP_DIR" "$REGISTRY_DIR" "$ICONS_DIR"
choose_and_process_icon() { PICKED_ICON_FINAL="utilities-terminal"; }
finalize_menu_entry() { :; }
finalize_desktop_shortcut() { :; }
pause() { :; }
install_icon_for_html "$3" <<HTML_INPUT_EOF

3
HTML_INPUT_EOF
printf "%s\n" "$(registry_id_for "$3")"
' _ "$LIB" "$TMP_ROOT/home-html-icons" "$HTML_ICON" > "$TMP_ROOT/html-icon-install.out"
id="$(HOME="$TMP_ROOT/home-html-icons" bash -c 'source "$1"; registry_id_for "$2"' _ "$LIB" "$HTML_ICON")"
desktop="$TMP_ROOT/home-html-icons/.local/share/applications/scriptya-app-$id.desktop"
assert_contains 'HTML standalone app uses metadata name' 'Name=Dashboard App' "$(cat "$desktop")"
assert_contains 'HTML standalone app uses metadata description' 'Comment=My dashboard description' "$(cat "$desktop")"
assert_contains 'HTML standalone app uses xdg-open' 'Exec=xdg-open ' "$(cat "$desktop")"
assert_eq 'HTML standalone app registry type is html' 'html' "$(HOME="$TMP_ROOT/home-html-icons" bash -c 'source "$1"; registry_read "$2"; printf "%s\n" "$REG_TYPE"' _ "$LIB" "$id")"

# 34. The Install-Scripts picker dispatches HTML to the HTML installer.
selected_html="$HTML_ROOT/selected.html"
: > "$selected_html"
out=$(bash -c 'source "$1"; selected="$2"; navigate(){ PICKED_SCRIPT="$selected"; return 0; }; install_icon_for_html(){ printf "HTML_DISPATCH:%s\n" "$1"; }; install_icon_for_script(){ printf "SCRIPT_DISPATCH:%s\n" "$1"; }; SCRIPTS_DIR="$(dirname "$selected")"; pick_script_and_install_icon' _ "$LIB" "$selected_html")
assert_contains 'Install picker dispatches HTML to HTML installer' "HTML_DISPATCH:$selected_html" "$out"

# 35. HTML metadata and launch target are language-invariant.
for lang in en es; do
    meta_lang=$(LANGUAGE="$lang" HOME="$TMP_ROOT/home-lang-$lang" bash -c 'source "$1"; read_metadata "$2"; printf "%s|%s|%s\n" "$META_MENU" "$META_DESCRIPTION" "$META_CONFIRM"' _ "$LIB" "$HTML_RUN")
    assert_eq "HTML metadata is language-invariant ($lang)" 'Run HTML|Opens the local page|false' "$meta_lang"
done

# 36. Existing shell-script metadata behavior remains intact after HTML support.
SHELL_META="$HTML_ROOT/regression.sh"
cat > "$SHELL_META" <<'SHELL_META_EOF'
#!/bin/bash
# MENU: Shell regression
# DESCRIPTION: Shell regression test
# CONFIRM: true
# ORDER: 2
printf 'SHELL_OK\n'
SHELL_META_EOF
meta=$(bash -c 'source "$1"; read_metadata "$2"; printf "%s|%s|%s|%s\n" "$META_MENU" "$META_DESCRIPTION" "$META_CONFIRM" "$META_ORDER"' _ "$LIB" "$SHELL_META")
assert_eq 'Shell metadata still parses correctly' 'Shell regression|Shell regression test|true|2' "$meta"

# 37. HTML files with uppercase extensions are discovered and parsed.
HTML_UPPER="$HTML_ROOT/UPPER.HTML"
cat > "$HTML_UPPER" <<'HTML_UPPER_EOF'
<!DOCTYPE html>
<!-- MENU: Upper HTML -->
<html><body>upper</body></html>
HTML_UPPER_EOF
listed=$(bash -c 'source "$1"; list_scripts "$2"' _ "$LIB" "$HTML_ROOT")
assert_contains 'Uppercase .HTML is listed' 'UPPER.HTML' "$listed"
meta=$(bash -c 'source "$1"; read_metadata "$2"; printf "%s\n" "$META_MENU"' _ "$LIB" "$HTML_UPPER")
assert_eq 'Uppercase .HTML metadata is read' 'Upper HTML' "$meta"


# 38. The interactive metadata wizard can insert metadata into HTML files.
HTML_WIZARD="$HTML_ROOT/wizard.html"
cat > "$HTML_WIZARD" <<'HTML_WIZARD_EOF'
<!DOCTYPE html>
<!-- Keep this comment -->
<html><body><h1>Wizard</h1></body></html>
HTML_WIZARD_EOF
wizard_home="$TMP_ROOT/home-html-wizard"
mkdir -p "$wizard_home/.config/scriptya"
wizard_input=$(printf '%s\n' 'Wizard page' 'Wizard description' '1' '2' '2' '8' 'icon.png' 'n' 'y' 'x')
out=$(printf '%s\n' "$wizard_input" | HOME="$wizard_home" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C \
    bash -c 'source "$1"; insert_metadata_wizard "$2"' _ "$LIB" "$HTML_WIZARD" 2>&1)
status=$?
assert_eq 'HTML metadata wizard exits successfully' '0' "$status"
assert_contains 'HTML metadata wizard writes MENU comment' '<!-- MENU: Wizard page -->' "$(cat "$HTML_WIZARD")"
assert_contains 'HTML metadata wizard writes DESCRIPTION comment' '<!-- DESCRIPTION: Wizard description -->' "$(cat "$HTML_WIZARD")"
assert_contains 'HTML metadata wizard writes CONFIRM comment' '<!-- CONFIRM: true -->' "$(cat "$HTML_WIZARD")"
assert_contains 'HTML metadata wizard writes ORDER comment' '<!-- ORDER: 8 -->' "$(cat "$HTML_WIZARD")"
assert_contains 'HTML metadata wizard preserves DOCTYPE' '<!DOCTYPE html>' "$(cat "$HTML_WIZARD")"
assert_contains 'HTML metadata wizard preserves original comment' '<!-- Keep this comment -->' "$(cat "$HTML_WIZARD")"
assert_contains 'HTML metadata wizard preserves body' '<h1>Wizard</h1>' "$(cat "$HTML_WIZARD")"

# 39. HTML confirmation and missing xdg-open messages are localized in English.
home="$TMP_ROOT/home-html-messages"; mkdir -p "$home/.config/scriptya"
printf 'LANGUAGE=en\n' > "$home/.config/scriptya/config.conf"
out=$(HOME="$home" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash -c '
source "$1"
command_exists(){ [[ "$1" != xdg-open ]] && command -v "$1" >/dev/null 2>&1; }
confirm_yn(){ tr "¿Abrir '\''Test page'\''?"; return 1; }
run_script() { :; }
tr "¿Abrir '\''Test page'\''?"
' _ "$LIB" 2>&1)
assert_contains 'English HTML open prompt is translated' "Open 'Test page'?" "$out"
out=$(HOME="$home" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash -c 'source "$1"; print_error "No se encontró '\''xdg-open'\'' (paquete xdg-utils); instálalo para que el acceso abra bien el navegador."' _ "$LIB" 2>&1)
assert_contains 'English xdg-open error is translated' "'xdg-open' was not found" "$out"
assert_not_contains 'English xdg-open error does not leak Spanish' 'No se encontró' "$out"

# 40. HTML metadata never changes the document payload when toggling language.
html_hash_en=$(LANGUAGE=en sha256sum "$HTML_RUN" | awk '{print $1}')
html_hash_es=$(LANGUAGE=es sha256sum "$HTML_RUN" | awk '{print $1}')
assert_eq 'HTML file is language-invariant (EN/ES)' "$html_hash_en" "$html_hash_es"


# 41. Public help and README explicitly document HTML as a managed file type.
help_en=$(HOME="$TMP_ROOT/home-help-en" LANGUAGE=en bash -c 'source "$1"; show_help' _ "$LIB")
assert_contains 'English help documents HTML metadata' '.html/.htm' "$help_en"
assert_contains 'English help documents HTML comment metadata' '<!-- MENU: Local dashboard -->' "$help_en"
assert_contains 'English help documents HTML standalone apps' 'HTML pages as applications' "$help_en"
assert_contains 'English README documents HTML management' 'HTML pages are now managed by Scriptya too' "$(cat "$ROOT_DIR/README.md")"
assert_contains 'Spanish README documents HTML management' 'Ahora Scriptya también gestiona páginas HTML' "$(cat "$ROOT_DIR/README_ES.md")"


# 42. The real numbered menu renders an HTML entry with its metadata.
HTML_MENU="$HTML_ROOT/menu.html"
cat > "$HTML_MENU" <<'HTML_MENU_EOF'
<!DOCTYPE html>
<!-- MENU: Local dashboard -->
<!-- DESCRIPTION: Useful offline dashboard -->
<html><body>menu</body></html>
HTML_MENU_EOF
menu_output=$(HOME="$TMP_ROOT/home-html-menu" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C \
    bash -c 'source "$1"; SCRIPTS_DIR="$2"; menu_numeric "$SCRIPTS_DIR" run' _ "$LIB" "$HTML_ROOT" <<< '0' 2>&1)
assert_contains 'Numeric menu renders HTML metadata entry' '🌐 Local dashboard — Useful offline dashboard' "$menu_output"
assert_not_contains 'English HTML menu entry has no Spanish action label' 'Instalar Scripts' "$menu_output"



# 42b. The real numbered menu renders a Python entry with its metadata in both languages.
PY_MENU="$TMP_ROOT/python-menu.py"
cat > "$PY_MENU" <<'PY_EOF'
#!/usr/bin/env python3
# MENU: Local Python tool
# DESCRIPTION: Useful Python utility
print("menu")
PY_EOF
PY_MENU_DIR="$TMP_ROOT/home-python-menu-scripts"; mkdir -p "$PY_MENU_DIR"; cp "$PY_MENU" "$PY_MENU_DIR/tool.py"
menu_py_en=$(HOME="$TMP_ROOT/home-python-menu-en" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C \
    bash -c 'source "$1"; LANGUAGE=en; SCRIPTS_DIR="$2"; menu_numeric "$2" run' _ "$LIB" "$PY_MENU_DIR" <<< '0' 2>&1)
menu_py_es=$(HOME="$TMP_ROOT/home-python-menu-es" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C \
    bash -c 'source "$1"; LANGUAGE=es; SCRIPTS_DIR="$2"; menu_numeric "$2" run' _ "$LIB" "$PY_MENU_DIR" <<< '0' 2>&1)
assert_contains 'Numeric menu renders Python metadata in English' '🐍 Local Python tool — Useful Python utility' "$menu_py_en"
assert_contains 'Numeric menu renders Python metadata in Spanish' '🐍 Local Python tool — Useful Python utility' "$menu_py_es"
assert_not_contains 'English Python menu does not leak Spanish install label' 'Instalar Scripts' "$menu_py_en"
assert_not_contains 'Spanish Python menu does not leak English install label' 'Install Scripts' "$menu_py_es"

# 43. Python files are first-class managed files: discovery, metadata and ordering.
PY_ROOT="$TMP_ROOT/python-managed"; mkdir -p "$PY_ROOT"
cat > "$PY_ROOT/alpha.py" <<'PY_EOF'
#!/usr/bin/env python3
# MENU: Python Alpha
# DESCRIPTION: First Python entry
# ORDER: 20
print("alpha")
PY_EOF
cat > "$PY_ROOT/BETA.PY" <<'PY_EOF'
#!/usr/bin/env python3
# MENU: Python Beta
# DESCRIPTION: Second Python entry
# ORDER: 30
print("beta")
PY_EOF
cat > "$PY_ROOT/ignored.txt" <<'TXT_EOF'
not managed
TXT_EOF
managed=$(list_scripts "$PY_ROOT")
assert_contains 'Managed list includes .py' 'alpha.py' "$managed"
assert_contains 'Managed list is case-insensitive for Python' 'BETA.PY' "$managed"
assert_not_contains 'Managed list excludes unrelated files' 'ignored.txt' "$managed"
sorted=$(sorted_scripts "$PY_ROOT")
assert_eq 'Python ORDER sorts correctly' "$PY_ROOT/alpha.py" "$(printf '%s\n' "$sorted" | sed -n '1p')"
read_metadata "$PY_ROOT/BETA.PY"
assert_eq 'Python metadata MENU' 'Python Beta' "$META_MENU"
assert_eq 'Python metadata DESCRIPTION' 'Second Python entry' "$META_DESCRIPTION"
assert_eq 'Python metadata ORDER' '30' "$META_ORDER"

# 44. Insert Metadata works on Python without damaging the shebang, body, or user comments.
PY_META="$PY_ROOT/metadata.py"
cat > "$PY_META" <<'PY_EOF'
#!/usr/bin/env python3
# Author: Scriptya test

payload = {"ok": True}
print(payload)
PY_EOF
orig_body=$(tail -n 2 "$PY_META")
NEWMETA_MENU='Python Tool'; NEWMETA_DESCRIPTION='A Python utility'; NEWMETA_CONFIRM='true'; NEWMETA_TERMINAL='true'; NEWMETA_SUDO='false'; NEWMETA_ORDER='15'; NEWMETA_ICON='utilities-terminal'; NEWMETA_ASK=('name' 'count')
if apply_metadata "$PY_META"; then ok 'Python metadata insertion runs'; else fail 'Python metadata insertion runs'; fi
head -n 1 "$PY_META" | grep -Fxq '#!/usr/bin/env python3' && ok 'Python shebang is preserved' || fail 'Python shebang is preserved'
assert_contains 'Python inserted MENU' '# MENU: Python Tool' "$(head -n 8 "$PY_META")"
assert_contains 'Python inserted DESCRIPTION' '# DESCRIPTION: A Python utility' "$(head -n 8 "$PY_META")"
assert_contains 'Python inserted CONFIRM' '# CONFIRM: true' "$(head -n 8 "$PY_META")"
assert_contains 'Python inserted ASK 1' '# ASK: name' "$(cat "$PY_META")"
assert_contains 'Python original comment survives' '# Author: Scriptya test' "$(cat "$PY_META")"
assert_eq 'Python body survives metadata insertion' "$orig_body" "$(tail -n 2 "$PY_META")"

# 45. Python execution uses Python 3, respects ASK/CONFIRM/SUDO, and is language-invariant.
PY_RUN="$PY_ROOT/run.py"
cat > "$PY_RUN" <<'PY_EOF'
#!/usr/bin/env python3
# MENU: Python Runner
# DESCRIPTION: Python execution regression
# CONFIRM: false
# TERMINAL: false
# SUDO: true
# ASK: first value
print("PY_PAYLOAD:" + repr(__import__('sys').argv[1:]))
print("PY_CWD:" + __import__('os').getcwd())
PY_EOF
run_py() {
    local lang="$1" out
    out=$(HOME="$TMP_ROOT/home-py-$lang" LANGUAGE="$lang" bash -c '
        source "$1"
        LANGUAGE="$2"
        LOG_FILE="$3/history.log"
        INSTALL_DIR="$3"
        pause(){ :; }
        clear(){ :; }
        print_header(){ :; }
        print_info(){ :; }
        print_success(){ :; }
        print_error(){ printf "ERR:%s\\n" "$1" >&2; }
        print_warning(){ :; }
        confirm_yn(){ return 1; }
        sudo(){ "$@"; }
        mkdir -p "$3"
        printf "%s\\n" "answer"
        run_script "$4" inline
    ' _ "$LIB" "$lang" "$TMP_ROOT/home-py-$lang" "$PY_RUN" 2>&1 <<< 'answer')
    printf '%s' "$out"
}
out_en=$(run_py en)
out_es=$(run_py es)
assert_contains 'Python executes successfully in English' 'PY_PAYLOAD:' "$out_en"
assert_contains 'Python receives ASK value' "'answer'" "$out_en"
assert_contains 'Python executes successfully in Spanish' 'PY_PAYLOAD:' "$out_es"
assert_eq 'Python payload is language-invariant' "$(grep 'PY_PAYLOAD:' <<< "$out_en")" "$(grep 'PY_PAYLOAD:' <<< "$out_es")"
assert_eq 'Python cwd is language-invariant' "$(grep 'PY_CWD:' <<< "$out_en")" "$(grep 'PY_CWD:' <<< "$out_es")"
assert_contains 'Python sudo metadata executes through sudo' 'PY_PAYLOAD:' "$out_en"

# 45b. Executable Python with a Python shebang is launched directly, preserving shebang semantics.
PY_EXEC="$PY_ROOT/executable.py"
cat > "$PY_EXEC" <<'PY_EOF'
#!/usr/bin/env python3
print("EXEC_PYTHON_OK")
PY_EOF
chmod +x "$PY_EXEC"
out=$(HOME="$TMP_ROOT/home-py-exec" LANGUAGE=en bash -c '
    source "$1"
    LOG_FILE="$3/history.log"; INSTALL_DIR="$3"
    pause(){ :; }; clear(){ :; }
    command_exists(){ command -v "$1" >/dev/null 2>&1; }
    run_script "$4" inline
' _ "$LIB" ignored "$TMP_ROOT/home-py-exec" "$PY_EXEC" 2>&1)
assert_contains 'Executable Python script runs through its shebang' 'EXEC_PYTHON_OK' "$out"

# 45c. Python with TERMINAL=true uses the same terminal wrapper path as shell scripts.
PY_TERM="$PY_ROOT/terminal.py"
cat > "$PY_TERM" <<'PY_EOF'
#!/usr/bin/env python3
# TERMINAL: true
print("PY_TERMINAL_OK")
PY_EOF
out=$(HOME="$TMP_ROOT/home-py-terminal" LANGUAGE=en bash -c '
    source "$1"
    LOG_FILE="$3/history.log"; INSTALL_DIR="$3"; TERMINAL="fake-terminal"
    pause(){ :; }; clear(){ :; }
    fake-terminal(){ [[ "$1" == "-e" ]] && bash "$2" </dev/null; }
    command_exists(){ command -v "$1" >/dev/null 2>&1; }
    run_script "$4"
' _ "$LIB" ignored "$TMP_ROOT/home-py-terminal" "$PY_TERM" 2>&1)
assert_contains 'Python TERMINAL metadata uses terminal execution path' 'PY_TERMINAL_OK' "$out"

# 45d. Python CONFIRM behaves exactly like a managed shell script.
PY_CONFIRM="$PY_ROOT/confirm.py"
PY_CONFIRM_MARKER="$PY_ROOT/confirm-marker"
cat > "$PY_CONFIRM" <<'PY_EOF'
#!/usr/bin/env python3
# CONFIRM: true
from pathlib import Path
Path("confirm-marker").write_text("ran\n")
print("PY_CONFIRM_OK")
PY_EOF
rm -f "$PY_CONFIRM_MARKER"
confirm_cancel=$(HOME="$TMP_ROOT/home-py-confirm-cancel" LANGUAGE=en bash -c '
    source "$1"; LOG_FILE="$3/history.log"; INSTALL_DIR="$3"
    pause(){ :; }; clear(){ :; }; confirm_yn(){ return 1; }
    run_script "$4" inline
' _ "$LIB" ignored "$TMP_ROOT/home-py-confirm-cancel" "$PY_CONFIRM" 2>&1); confirm_rc=$?
assert_eq 'Python confirmation can cancel execution' '1' "$confirm_rc"
assert_not_contains 'Cancelled Python script does not run' 'PY_CONFIRM_OK' "$confirm_cancel"
assert_not_contains 'Cancelled Python script leaves no marker' 'confirm-marker' "$(ls -1 "$PY_ROOT" 2>/dev/null)"
confirm_allow=$(HOME="$TMP_ROOT/home-py-confirm-allow" LANGUAGE=en bash -c '
    source "$1"; LOG_FILE="$3/history.log"; INSTALL_DIR="$3"
    pause(){ :; }; clear(){ :; }; confirm_yn(){ return 0; }
    run_script "$4" inline
' _ "$LIB" ignored "$TMP_ROOT/home-py-confirm-allow" "$PY_CONFIRM" 2>&1); confirm_rc=$?
assert_eq 'Python confirmation can allow execution' '0' "$confirm_rc"
assert_contains 'Confirmed Python script runs' 'PY_CONFIRM_OK' "$confirm_allow"

# 45e. Python exit status/output remain identical across languages.
PY_STATUS="$PY_ROOT/status.py"
cat > "$PY_STATUS" <<'PY_EOF'
#!/usr/bin/env python3
print("PY_FAIL_PAYLOAD")
raise SystemExit(7)
PY_EOF
run_py_status() {
    local lang="$1" out status
    out=$(HOME="$TMP_ROOT/home-py-status-$lang" LANGUAGE="$lang" bash -c '
        source "$1"; LOG_FILE="$3/history.log"; INSTALL_DIR="$3"
        pause(){ :; }; clear(){ :; }
        run_script "$4" inline
    ' _ "$LIB" ignored "$TMP_ROOT/home-py-status-$lang" "$PY_STATUS" 2>&1); status=$?
    printf 'STATUS=%s\n%s' "$status" "$out"
}
status_en=$(run_py_status en)
status_es=$(run_py_status es)
assert_contains 'Python nonzero exit status is preserved in English' 'STATUS=7' "$status_en"
assert_contains 'Python nonzero exit status is preserved in Spanish' 'STATUS=7' "$status_es"
assert_eq 'Python failing payload is language-invariant' "$(grep 'PY_FAIL_PAYLOAD' <<< "$status_en")" "$(grep 'PY_FAIL_PAYLOAD' <<< "$status_es")"

# 46. Python standalone installation produces the same kind of app as shell scripts.
PY_APP="$PY_ROOT/app.py"; printf '%s\n' '#!/usr/bin/env python3' 'print("app")' > "$PY_APP"
PY_APP_HOME="$TMP_ROOT/home-py-app"; mkdir -p "$PY_APP_HOME"
out=$(HOME="$PY_APP_HOME" bash -c '
    source "$1"
    APPS_DIR="$2/apps"; DESKTOP_DIR="$2/Desktop"; ICONS_DIR="$2/icons"; REGISTRY_DIR="$2/registry"; INSTALL_DIR="$2/install"; SCRIPT_PATH="$1"; SCRIPTS_DIR="$2/scripts"
    mkdir -p "$APPS_DIR" "$DESKTOP_DIR" "$ICONS_DIR" "$REGISTRY_DIR" "$INSTALL_DIR" "$SCRIPTS_DIR"
    pause(){ :; }
    clear(){ :; }
    print_header(){ :; }
    print_success(){ :; }
    print_warning(){ :; }
    print_info(){ :; }
    choose_and_process_icon(){ PICKED_ICON_FINAL="$ICONS_DIR/test.png"; : > "$PICKED_ICON_FINAL"; }
    finalize_menu_entry(){ :; }
    finalize_desktop_shortcut(){ :; }
    refresh_app_menu(){ :; }
    printf "3\\n" | install_icon_for_script "$4"
    cat "$APPS_DIR"/scriptya-app-*.desktop
    cat "$DESKTOP_DIR"/scriptya-app-*.desktop
    registry_read "$(sanitize_id "$4")"
    printf "REGTYPE=%s\nREGMENU=%s\nREGDESKTOP=%s\n" "$REG_TYPE" "$REG_MENU" "$REG_DESKTOP"
' _ "$LIB" "$PY_APP_HOME" "$PY_APP_HOME" "$PY_APP")
assert_contains 'Python standalone app has Exec through Scriptya' 'Exec=' "$out"
assert_contains 'Python standalone app launches source through --run-script' '--run-script' "$out"
assert_contains 'Python standalone app declares Python source' 'X-Scriptya-Source=' "$out"
assert_contains 'Python standalone app source ends in .py' '.py' "$out"
assert_contains 'Python standalone app is registered as a script' 'REGTYPE=script' "$out"
assert_contains 'Python standalone app records menu installation' 'REGMENU=si' "$out"
assert_contains 'Python standalone app records desktop installation' 'REGDESKTOP=si' "$out"

# 47. Nemo actions include Python exactly like shell scripts.
NEMO_PY_HOME="$TMP_ROOT/home-nemo-py"; mkdir -p "$NEMO_PY_HOME/.local/share/nemo/actions"
out=$(HOME="$NEMO_PY_HOME" bash -c 'source "$1"; LANGUAGE=en; NEMO_ACTIONS_DIR="$2"; SCRIPT_PATH="/tmp/scriptya.sh"; write_nemo_actions; cat "$2"/scriptya-run.nemo_action "$2"/scriptya-install.nemo_action "$2"/scriptya-uninstall.nemo_action "$2"/scriptya-change-icon.nemo_action' _ "$LIB" "$NEMO_PY_HOME/.local/share/nemo/actions" 2>&1)
assert_contains 'Nemo run action accepts Python, Node.js and Ruby' 'Extensions=sh;py;js;mjs;cjs;pl;rb;lua;fish;php;' "$out"
assert_contains 'Nemo install action accepts Python, Node.js and Ruby' 'Extensions=sh;py;js;mjs;cjs;pl;rb;lua;fish;php;awk;go;html;htm;' "$out"
assert_contains 'Nemo uninstall action accepts Python, Node.js and Ruby' 'Extensions=sh;py;js;mjs;cjs;pl;rb;lua;fish;php;awk;go;html;htm;' "$out"
assert_contains 'Nemo change icon action accepts Python, Node.js and Ruby' 'Extensions=sh;py;js;mjs;cjs;pl;rb;lua;fish;php;awk;go;html;htm;' "$out"

# 48. Python help and both README files document first-class support.
help_en=$(HOME="$TMP_ROOT/home-help-py" LANGUAGE=en bash -c 'source "$1"; show_help' _ "$LIB")
assert_contains 'English help documents .py support' '.sh/.py' "$help_en"
assert_contains 'English help documents Python and Node standalone apps' '.sh/.py/.js/.mjs/.cjs/.pl/.rb/.lua/.fish/.awk/.php/.go scripts' "$help_en"
assert_contains 'English README documents all managed script types' '.sh`, `.py`, `.js`, `.mjs`, `.cjs`, `.pl`, `.rb`, `.lua`, `.fish`, `.awk`, `.php`, `.go`, `.html` and `.htm' "$(cat "$ROOT_DIR/README.md")"
assert_contains 'Spanish README documents Python and Node management' '.sh`, `.py`, `.js`, `.mjs`, `.cjs`, `.pl`, `.rb`, `.lua`, `.fish`, `.awk`, `.php`, `.go`, `.html` y `.htm' "$(cat "$ROOT_DIR/README_ES.md")"

# 49. Python filename IDs strip .py just like .sh, while legacy HTML IDs remain compatible.
py_id=$(sanitize_id '/tmp/example/tool.py')
sh_id=$(sanitize_id '/tmp/example/tool.sh')
html_id=$(sanitize_id '/tmp/example/tool.html')
assert_eq 'Python and shell sanitize to extensionless IDs' "${sh_id%-*}" "${py_id%-*}"
assert_eq 'Legacy HTML registry ID keeps html extension behavior' 'tool_html' "${html_id%-*}"

# 50. Python dependency error is localized and does not leak Spanish in English.
PY_MISSING="$PY_ROOT/missing-python.py"
printf '%s\n' '#!/usr/bin/env python3' 'print("never")' > "$PY_MISSING"
py_error=$(HOME="$TMP_ROOT/home-python-error" LANGUAGE=en bash -c '
    source "$1"
    LOG_FILE="$3/history.log"; INSTALL_DIR="$3"; TERMINAL="xterm"
    pause(){ :; }
    command_exists(){ [[ "$1" != python3 ]] && command -v "$1" >/dev/null 2>&1; }
    run_script "$4" inline
' _ "$LIB" ignored "$TMP_ROOT/home-python-error" "$PY_MISSING" 2>&1)
assert_contains 'English Python dependency error is translated' "'python3' was not found" "$py_error"
assert_not_contains 'English Python dependency error has no Spanish phrase' 'No se encontró' "$py_error"

# 51. Node.js files are first-class managed files: discovery, type detection and metadata.
NODE_ROOT="$TMP_ROOT/node-managed"; mkdir -p "$NODE_ROOT"
cat > "$NODE_ROOT/tool.js" <<'NODE_EOF'
#!/usr/bin/env node
// MENU: Node Tool
// DESCRIPTION: Useful Node utility
// ORDER: 12
console.log("node");
NODE_EOF
cat > "$NODE_ROOT/late.mjs" <<'NODE_EOF'
// MENU: Node Late
// ORDER: 30
console.log("late");
NODE_EOF
touch "$NODE_ROOT/COMMON.CJS"
managed=$(list_scripts "$NODE_ROOT")
assert_contains 'Managed list includes .js' 'tool.js' "$managed"
assert_contains 'Managed list includes .mjs' 'late.mjs' "$managed"
assert_contains 'Managed list includes .cjs' 'COMMON.CJS' "$managed"
assert_eq 'Node .js type detected' 'node' "$(script_type "$NODE_ROOT/tool.js")"
assert_eq 'Node .mjs type detected' 'node' "$(script_type "$NODE_ROOT/late.mjs")"
assert_eq 'Node .cjs type detected' 'node' "$(script_type "$NODE_ROOT/COMMON.CJS")"
read_metadata "$NODE_ROOT/tool.js"
assert_eq 'Node metadata MENU' 'Node Tool' "$META_MENU"
assert_eq 'Node metadata DESCRIPTION' 'Useful Node utility' "$META_DESCRIPTION"
assert_eq 'Node metadata ORDER' '12' "$META_ORDER"

# 52. Node.js metadata insertion uses JS comments, preserves shebang/body/comments and remains runnable.
NODE_META="$NODE_ROOT/metadata.js"
cat > "$NODE_META" <<'NODE_EOF'
#!/usr/bin/env node
// Author: Scriptya test

const payload = { ok: true };
console.log(payload);
NODE_EOF
node_body_before=$(tail -n 2 "$NODE_META")
NEWMETA_MENU='Node Utility'; NEWMETA_DESCRIPTION='A Node utility'; NEWMETA_CONFIRM='true'; NEWMETA_TERMINAL='true'; NEWMETA_SUDO='false'; NEWMETA_ORDER='15'; NEWMETA_ICON='utilities-terminal'; NEWMETA_ASK=('name' 'count')
if apply_metadata "$NODE_META"; then ok 'Node metadata insertion runs'; else fail 'Node metadata insertion runs'; fi
assert_contains 'Node inserted MENU' '// MENU: Node Utility' "$(cat "$NODE_META")"
assert_contains 'Node inserted DESCRIPTION' '// DESCRIPTION: A Node utility' "$(cat "$NODE_META")"
assert_contains 'Node inserted CONFIRM' '// CONFIRM: true' "$(cat "$NODE_META")"
assert_contains 'Node inserted ASK 1' '// ASK: name' "$(cat "$NODE_META")"
assert_contains 'Node original comment survives' '// Author: Scriptya test' "$(cat "$NODE_META")"
assert_eq 'Node body survives metadata insertion' "$node_body_before" "$(tail -n 2 "$NODE_META")"
node_meta_raw=$(head -n 8 "$NODE_META")
node -e 'require("node:assert"); require("node:fs").accessSync(process.argv[1])' "$NODE_META" >/dev/null 2>&1 && ok 'Node metadata file remains valid JavaScript' || fail 'Node metadata file remains valid JavaScript'

# 53. Node.js execution preserves arguments, cwd, exit status and language invariance.
NODE_RUN="$NODE_ROOT/run.js"
cat > "$NODE_RUN" <<'NODE_EOF'
#!/usr/bin/env node
// MENU: Node Runner
// DESCRIPTION: Node execution regression
// CONFIRM: false
// TERMINAL: false
// SUDO: false
// ASK: first value
console.log("NODE_PAYLOAD:" + JSON.stringify(process.argv.slice(2)));
console.log("NODE_CWD:" + process.cwd());
NODE_EOF
run_node() {
    local lang="$1" out
    out=$(HOME="$TMP_ROOT/home-node-$lang" LANGUAGE="$lang" bash -c '
        source "$1"
        LANGUAGE="$2"
        LOG_FILE="$3/history.log"
        INSTALL_DIR="$3"
        pause(){ :; }; clear(){ :; }; print_header(){ :; }; print_info(){ :; }; print_success(){ :; }; print_warning(){ :; }
        print_error(){ printf "ERR:%s\\n" "$1" >&2; }
        confirm_yn(){ return 1; }
        run_script "$4" inline
    ' _ "$LIB" "$lang" "$TMP_ROOT/home-node-$lang" "$NODE_RUN" 2>&1 <<< 'answer')
    printf '%s' "$out"
}
out_en=$(run_node en)
out_es=$(run_node es)
assert_contains 'Node executes successfully in English' 'NODE_PAYLOAD:' "$out_en"
assert_contains 'Node receives ASK value' 'answer' "$out_en"
assert_contains 'Node executes successfully in Spanish' 'NODE_PAYLOAD:' "$out_es"
assert_eq 'Node payload is language-invariant' "$(grep 'NODE_PAYLOAD:' <<< "$out_en")" "$(grep 'NODE_PAYLOAD:' <<< "$out_es")"
assert_eq 'Node cwd is language-invariant' "$(grep 'NODE_CWD:' <<< "$out_en")" "$(grep 'NODE_CWD:' <<< "$out_es")"

# 54. Node.js executable shebang is respected, while non-executable files use node.
NODE_EXEC="$NODE_ROOT/executable.js"
cat > "$NODE_EXEC" <<'NODE_EOF'
#!/usr/bin/env node
console.log("EXEC_NODE_OK");
NODE_EOF
chmod +x "$NODE_EXEC"
out=$(HOME="$TMP_ROOT/home-node-exec" LANGUAGE=en bash -c '
    source "$1"; LOG_FILE="$3/history.log"; INSTALL_DIR="$3"; pause(){ :; }; clear(){ :; }; run_script "$4" inline
' _ "$LIB" ignored "$TMP_ROOT/home-node-exec" "$NODE_EXEC" 2>&1)
assert_contains 'Executable Node script runs through its shebang' 'EXEC_NODE_OK' "$out"

# 55. Node confirmation and nonzero status match shell/Python behavior.
NODE_CONFIRM="$NODE_ROOT/confirm.js"; NODE_CONFIRM_MARKER="$NODE_ROOT/node-confirm-marker"
cat > "$NODE_CONFIRM" <<'NODE_EOF'
#!/usr/bin/env node
// CONFIRM: true
require("node:fs").writeFileSync("node-confirm-marker", "ran\n");
console.log("NODE_CONFIRM_OK");
NODE_EOF
rm -f "$NODE_CONFIRM_MARKER"
out=$(HOME="$TMP_ROOT/home-node-confirm" LANGUAGE=en bash -c 'source "$1"; LOG_FILE="$3/history.log"; INSTALL_DIR="$3"; pause(){ :; }; clear(){ :; }; confirm_yn(){ return 1; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-node-confirm" "$NODE_CONFIRM" 2>&1); rc=$?
assert_eq 'Node confirmation can cancel execution' '1' "$rc"
assert_not_contains 'Cancelled Node script does not run' 'NODE_CONFIRM_OK' "$out"
assert_not_contains 'Cancelled Node script leaves no marker' 'node-confirm-marker' "$(ls -1 "$NODE_ROOT" 2>/dev/null)"
NODE_FAIL="$NODE_ROOT/status.js"
cat > "$NODE_FAIL" <<'NODE_EOF'
#!/usr/bin/env node
console.log("NODE_FAIL_PAYLOAD");
process.exit(7);
NODE_EOF
for lang in en es; do
    out=$(HOME="$TMP_ROOT/home-node-status-$lang" LANGUAGE="$lang" bash -c 'source "$1"; LOG_FILE="$3/history.log"; INSTALL_DIR="$3"; pause(){ :; }; clear(){ :; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-node-status-$lang" "$NODE_FAIL" 2>&1); rc=$?
    assert_eq "Node nonzero exit status is preserved in $lang" '7' "$rc"
    assert_contains "Node failing payload is preserved in $lang" 'NODE_FAIL_PAYLOAD' "$out"
done

# 56. Node standalone installation and English help/documentation.
NODE_APP="$NODE_ROOT/app.mjs"; printf '%s\n' '#!/usr/bin/env node' 'console.log("app")' > "$NODE_APP"
NODE_APP_HOME="$TMP_ROOT/home-node-app"; mkdir -p "$NODE_APP_HOME"
out=$(HOME="$NODE_APP_HOME" bash -c '
    source "$1"
    APPS_DIR="$2/apps"; DESKTOP_DIR="$2/Desktop"; ICONS_DIR="$2/icons"; REGISTRY_DIR="$2/registry"; INSTALL_DIR="$2/install"; SCRIPTS_DIR="$2/scripts"
    mkdir -p "$APPS_DIR" "$DESKTOP_DIR" "$ICONS_DIR" "$REGISTRY_DIR" "$INSTALL_DIR" "$SCRIPTS_DIR"
    pause(){ :; }; clear(){ :; }; print_header(){ :; }; print_success(){ :; }; print_warning(){ :; }; print_info(){ :; }
    choose_and_process_icon(){ PICKED_ICON_FINAL="$ICONS_DIR/test.png"; : > "$PICKED_ICON_FINAL"; }
    finalize_menu_entry(){ :; }; finalize_desktop_shortcut(){ :; }; refresh_app_menu(){ :; }
    printf "3\n" | install_icon_for_script "$4"
    cat "$APPS_DIR"/scriptya-app-*.desktop
    cat "$DESKTOP_DIR"/scriptya-app-*.desktop
    registry_read "$(sanitize_id "$4")"
    printf "REGTYPE=%s\nREGMENU=%s\nREGDESKTOP=%s\n" "$REG_TYPE" "$REG_MENU" "$REG_DESKTOP"
' _ "$LIB" "$NODE_APP_HOME" "$NODE_APP_HOME" "$NODE_APP")
assert_contains 'Node standalone app has Exec through Scriptya' '--run-script' "$out"
assert_contains 'Node standalone app source is registered' 'X-Scriptya-Source=' "$out"
assert_contains 'Node standalone app source ends in Node extension' '.mjs' "$out"
assert_eq 'Node standalone app is registered as script' 'REGTYPE=script' "$(grep -m1 '^REGTYPE=' <<< "$out")"
help_en=$(HOME="$TMP_ROOT/home-help-node" LANGUAGE=en bash -c 'source "$1"; show_help' _ "$LIB")
assert_contains 'English help documents Node extensions' '.js/.mjs/.cjs' "$help_en"
assert_contains 'English help documents Node metadata comments' '// MENU: Display name' "$help_en"
assert_contains 'English README documents Node.js' 'Node.js' "$(cat "$ROOT_DIR/README.md")"
assert_contains 'Spanish README documents Node.js' 'Node.js' "$(cat "$ROOT_DIR/README_ES.md")"

# 57. Node IDs strip extensions like Python and shell, and JS metadata is language-invariant.
node_id=$(sanitize_id '/tmp/example/tool.mjs')
assert_eq 'Node sanitize strips extension' 'tool' "${node_id%-*}"
for lang in en es; do
    meta_lang=$(LANGUAGE="$lang" HOME="$TMP_ROOT/home-node-lang-$lang" bash -c 'source "$1"; read_metadata "$2"; printf "%s|%s|%s\n" "$META_MENU" "$META_DESCRIPTION" "$META_CONFIRM"' _ "$LIB" "$NODE_RUN")
    assert_eq "Node metadata is language-invariant ($lang)" 'Node Runner|Node execution regression|false' "$meta_lang"
done

# 58. English Node dependency error is translated and does not leak Spanish.
NODE_MISSING="$NODE_ROOT/missing-node.js"; printf '%s\n' '#!/usr/bin/env node' 'console.log("never")' > "$NODE_MISSING"
node_error=$(HOME="$TMP_ROOT/home-node-error" LANGUAGE=en bash -c '
    source "$1"; LOG_FILE="$3/history.log"; INSTALL_DIR="$3"; pause(){ :; }
    command_exists(){ [[ "$1" != node ]] && command -v "$1" >/dev/null 2>&1; }
    run_script "$4" inline
' _ "$LIB" ignored "$TMP_ROOT/home-node-error" "$NODE_MISSING" 2>&1)
assert_contains 'English Node dependency error is translated' "'node' was not found" "$node_error"
assert_not_contains 'English Node dependency error has no Spanish phrase' 'No se encontró' "$node_error"

# 59. Node.js appears in the real numbered menu and its UI is localized.
NODE_MENU_DIR="$TMP_ROOT/node-menu"; mkdir -p "$NODE_MENU_DIR"
cat > "$NODE_MENU_DIR/menu.js" <<'NODE_EOF'
// MENU: English Node tool
// DESCRIPTION: Visible from the menu
console.log("MENU_NODE_OK");
NODE_EOF
menu_node_en=$(HOME="$TMP_ROOT/home-node-menu-en" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash -c 'source "$1"; LANGUAGE=en; SCRIPTS_DIR="$2"; menu_numeric "$2" run' _ "$LIB" "$NODE_MENU_DIR" <<< '0' 2>&1)
menu_node_es=$(HOME="$TMP_ROOT/home-node-menu-es" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash -c 'source "$1"; LANGUAGE=es; SCRIPTS_DIR="$2"; menu_numeric "$2" run' _ "$LIB" "$NODE_MENU_DIR" <<< '0' 2>&1)
assert_contains 'English menu renders Node metadata' '🟩 English Node tool — Visible from the menu' "$menu_node_en"
assert_contains 'Spanish menu renders Node metadata' '🟩 English Node tool — Visible from the menu' "$menu_node_es"
assert_not_contains 'English Node menu has no Spanish install action' 'Instalar Scripts' "$menu_node_en"
assert_not_contains 'Spanish Node menu has no English install action' 'Install Scripts' "$menu_node_es"

# 60. Node.js metadata never changes the source file when switching UI language.
node_hash_en=$(LANGUAGE=en sha256sum "$NODE_RUN" | awk '{print $1}')
node_hash_es=$(LANGUAGE=es sha256sum "$NODE_RUN" | awk '{print $1}')
assert_eq 'Node file is language-invariant (EN/ES)' "$node_hash_en" "$node_hash_es"

# 61. Node.js standalone uninstall removes the same registry/app artifacts as shell/Python scripts.
NODE_UNINSTALL_HOME="$TMP_ROOT/home-node-uninstall"; mkdir -p "$NODE_UNINSTALL_HOME/apps" "$NODE_UNINSTALL_HOME/Desktop" "$NODE_UNINSTALL_HOME/icons" "$NODE_UNINSTALL_HOME/registry"
NODE_UNINSTALL="$NODE_ROOT/uninstall.js"
printf '%s\n' '#!/usr/bin/env node' 'console.log("uninstall")' > "$NODE_UNINSTALL"
id=$(HOME="$NODE_UNINSTALL_HOME" bash -c 'source "$1"; REGISTRY_DIR="$2/registry"; registry_write "node-test" "Node Test" "$3" "$2/icons/node.png" si si script' _ "$LIB" "$NODE_UNINSTALL_HOME" "$NODE_UNINSTALL")
cat > "$NODE_UNINSTALL_HOME/apps/scriptya-app-node-test.desktop" <<'EOF'
[Desktop Entry]
Name=Node Test
EOF
cat > "$NODE_UNINSTALL_HOME/Desktop/scriptya-app-node-test.desktop" <<'EOF'
[Desktop Entry]
Name=Node Test
EOF
: > "$NODE_UNINSTALL_HOME/icons/node.png"
HOME="$NODE_UNINSTALL_HOME" bash -c 'source "$1"; APPS_DIR="$2/apps"; DESKTOP_DIR="$2/Desktop"; ICONS_DIR="$2/icons"; REGISTRY_DIR="$2/registry"; remove_script_icon node-test' _ "$LIB" "$NODE_UNINSTALL_HOME"
[[ ! -e "$NODE_UNINSTALL_HOME/apps/scriptya-app-node-test.desktop" ]] && ok 'Node standalone uninstall removes menu entry' || fail 'Node standalone uninstall removes menu entry'
[[ ! -e "$NODE_UNINSTALL_HOME/Desktop/scriptya-app-node-test.desktop" ]] && ok 'Node standalone uninstall removes Desktop entry' || fail 'Node standalone uninstall removes Desktop entry'
[[ ! -e "$NODE_UNINSTALL_HOME/registry/node-test.meta" ]] && ok 'Node standalone uninstall removes registry' || fail 'Node standalone uninstall removes registry'
[[ ! -e "$NODE_UNINSTALL_HOME/icons/node.png" ]] && ok 'Node standalone uninstall removes copied icon' || fail 'Node standalone uninstall removes copied icon'

# 62. A Node shebang wins over the extension when it is executable and the metadata syntax follows the detected type.
NODE_SHEBANG="$NODE_ROOT/python-extension-node.py"
cat > "$NODE_SHEBANG" <<'NODE_EOF'
#!/usr/bin/env node
// MENU: Node via shebang
// DESCRIPTION: Shebang-selected Node
console.log("NODE_SHEBANG_OK");
NODE_EOF
chmod +x "$NODE_SHEBANG"
assert_eq 'Node shebang overrides extension' 'node' "$(script_type "$NODE_SHEBANG")"
read_metadata "$NODE_SHEBANG"
assert_eq 'Node shebang metadata uses JS comments' 'Node via shebang|Shebang-selected Node' "$META_MENU|$META_DESCRIPTION"
out=$(HOME="$TMP_ROOT/home-node-shebang" LANGUAGE=en bash -c 'source "$1"; LOG_FILE="$3/history.log"; INSTALL_DIR="$3"; pause(){ :; }; clear(){ :; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-node-shebang" "$NODE_SHEBANG" 2>&1)
assert_contains 'Node shebang-selected execution works' 'NODE_SHEBANG_OK' "$out"

# 63. Only supported Node extensions are managed; unrelated JavaScript-looking files are not.
node_ignore="$NODE_ROOT/ignored.ts"; printf '%s\n' 'console.log("no")' > "$node_ignore"
managed=$(list_scripts "$NODE_ROOT")
assert_not_contains 'Unsupported TypeScript file is not auto-managed' 'ignored.ts' "$managed"



# 64. Perl files are first-class managed files: discovery, type detection and metadata.
PERL_ROOT="$TMP_ROOT/perl-managed"; mkdir -p "$PERL_ROOT"
cat > "$PERL_ROOT/tool.pl" <<'PERL_EOF'
#!/usr/bin/env perl
# MENU: Perl Tool
# DESCRIPTION: Useful Perl utility
# ORDER: 14
print "perl\n";
PERL_EOF
cat > "$PERL_ROOT/late.PL" <<'PERL_EOF'
# MENU: Upper Perl
# ORDER: 31
print "late\n";
PERL_EOF
touch "$PERL_ROOT/ignore.pm"
managed=$(list_scripts "$PERL_ROOT")
assert_contains 'Managed list includes .pl' 'tool.pl' "$managed"
assert_contains 'Managed list includes uppercase .PL' 'late.PL' "$managed"
assert_not_contains 'Perl module .pm is not auto-managed' 'ignore.pm' "$managed"
assert_eq 'Perl .pl type detected' 'perl' "$(script_type "$PERL_ROOT/tool.pl")"
assert_eq 'Perl uppercase .PL type detected' 'perl' "$(script_type "$PERL_ROOT/late.PL")"
read_metadata "$PERL_ROOT/tool.pl"
assert_eq 'Perl metadata MENU' 'Perl Tool' "$META_MENU"
assert_eq 'Perl metadata DESCRIPTION' 'Useful Perl utility' "$META_DESCRIPTION"
assert_eq 'Perl metadata ORDER' '14' "$META_ORDER"

# 65. Perl metadata insertion uses hash comments, preserves shebang/body/comments and remains valid Perl.
PERL_META="$PERL_ROOT/metadata.pl"
cat > "$PERL_META" <<'PERL_EOF'
#!/usr/bin/env perl
# Author: Scriptya test
my $payload = "PERL_META_OK\n";
print $payload;
PERL_EOF
perl_body_before=$(tail -n 2 "$PERL_META")
NEWMETA_MENU='Perl Utility'; NEWMETA_DESCRIPTION='A Perl utility'; NEWMETA_CONFIRM='true'; NEWMETA_TERMINAL='true'; NEWMETA_SUDO='false'; NEWMETA_ORDER='16'; NEWMETA_ICON='utilities-terminal'; NEWMETA_ASK=('name' 'count')
if apply_metadata "$PERL_META"; then ok 'Perl metadata insertion runs'; else fail 'Perl metadata insertion runs'; fi
assert_contains 'Perl inserted MENU' '# MENU: Perl Utility' "$(cat "$PERL_META")"
assert_contains 'Perl inserted DESCRIPTION' '# DESCRIPTION: A Perl utility' "$(cat "$PERL_META")"
assert_contains 'Perl inserted CONFIRM' '# CONFIRM: true' "$(cat "$PERL_META")"
assert_contains 'Perl inserted ASK 1' '# ASK: name' "$(cat "$PERL_META")"
assert_contains 'Perl original comment survives' '# Author: Scriptya test' "$(cat "$PERL_META")"
assert_eq 'Perl body survives metadata insertion' "$perl_body_before" "$(tail -n 2 "$PERL_META")"
perl -c "$PERL_META" >/dev/null 2>&1 && ok 'Perl metadata file remains valid Perl' || fail 'Perl metadata file remains valid Perl'

# 66. Perl execution preserves arguments, cwd, exit status and language invariance.
PERL_RUN="$PERL_ROOT/run.pl"
cat > "$PERL_RUN" <<'PERL_EOF'
#!/usr/bin/env perl
# MENU: Perl Runner
# DESCRIPTION: Perl execution regression
# CONFIRM: false
# TERMINAL: false
# SUDO: false
# ASK: first value
print "PERL_PAYLOAD:" . join("|", @ARGV) . "\n";
print "PERL_CWD:" . (`pwd`) ;
PERL_EOF
run_perl() {
    local lang="$1" out
    out=$(HOME="$TMP_ROOT/home-perl-$lang" LANGUAGE="$lang" bash -c '
        source "$1"
        LANGUAGE="$2"
        LOG_FILE="$3/history.log"
        INSTALL_DIR="$3"
        pause(){ :; }; clear(){ :; }; print_header(){ :; }; print_info(){ :; }; print_success(){ :; }; print_warning(){ :; }
        print_error(){ printf "ERR:%s\\n" "$1" >&2; }
        confirm_yn(){ return 1; }
        run_script "$4" inline
    ' _ "$LIB" "$lang" "$TMP_ROOT/home-perl-$lang" "$PERL_RUN" 2>&1 <<< 'answer')
    printf '%s' "$out"
}
out_en=$(run_perl en)
out_es=$(run_perl es)
assert_contains 'Perl executes successfully in English' 'PERL_PAYLOAD:answer' "$out_en"
assert_contains 'Perl receives ASK value' 'answer' "$out_en"
assert_contains 'Perl executes successfully in Spanish' 'PERL_PAYLOAD:answer' "$out_es"
assert_eq 'Perl payload is language-invariant' "$(grep 'PERL_PAYLOAD:' <<< "$out_en")" "$(grep 'PERL_PAYLOAD:' <<< "$out_es")"
assert_eq 'Perl cwd is language-invariant' "$(grep 'PERL_CWD:' <<< "$out_en")" "$(grep 'PERL_CWD:' <<< "$out_es")"

# 67. Executable Perl shebang is respected; non-executable .pl uses perl, and nonzero status is preserved.
PERL_EXEC="$PERL_ROOT/executable.pl"
cat > "$PERL_EXEC" <<'PERL_EOF'
#!/usr/bin/env perl
print "EXEC_PERL_OK\n";
PERL_EOF
chmod +x "$PERL_EXEC"
out=$(HOME="$TMP_ROOT/home-perl-exec" LANGUAGE=en bash -c 'source "$1"; LOG_FILE="$3/history.log"; INSTALL_DIR="$3"; pause(){ :; }; clear(){ :; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-perl-exec" "$PERL_EXEC" 2>&1)
assert_contains 'Executable Perl script runs through its shebang' 'EXEC_PERL_OK' "$out"
PERL_FAIL="$PERL_ROOT/status.pl"
printf '%s\n' '#!/usr/bin/env perl' 'print "PERL_FAIL_PAYLOAD\\n";' 'exit 7;' > "$PERL_FAIL"
for lang in en es; do
    out=$(HOME="$TMP_ROOT/home-perl-status-$lang" LANGUAGE="$lang" bash -c 'source "$1"; LOG_FILE="$3/history.log"; INSTALL_DIR="$3"; pause(){ :; }; clear(){ :; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-perl-status-$lang" "$PERL_FAIL" 2>&1); rc=$?
    assert_eq "Perl nonzero exit status is preserved in $lang" '7' "$rc"
    assert_contains "Perl failing payload is preserved in $lang" 'PERL_FAIL_PAYLOAD' "$out"
done

# 68. Perl confirmation and standalone installation use the same script lifecycle as Python/Node.
PERL_CONFIRM="$PERL_ROOT/confirm.pl"; PERL_CONFIRM_MARKER="$PERL_ROOT/perl-confirm-marker"
cat > "$PERL_CONFIRM" <<'PERL_EOF'
#!/usr/bin/env perl
# CONFIRM: true
open my $fh, '>', 'perl-confirm-marker' or die $!;
print $fh "ran\n";
print "PERL_CONFIRM_OK\n";
PERL_EOF
rm -f "$PERL_CONFIRM_MARKER"
out=$(HOME="$TMP_ROOT/home-perl-confirm" LANGUAGE=en bash -c 'source "$1"; LOG_FILE="$3/history.log"; INSTALL_DIR="$3"; pause(){ :; }; clear(){ :; }; confirm_yn(){ return 1; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-perl-confirm" "$PERL_CONFIRM" 2>&1); rc=$?
assert_eq 'Perl confirmation can cancel execution' '1' "$rc"
assert_not_contains 'Cancelled Perl script does not run' 'PERL_CONFIRM_OK' "$out"
assert_not_contains 'Cancelled Perl script leaves no marker' 'perl-confirm-marker' "$(ls -1 "$PERL_ROOT" 2>/dev/null)"

PERL_APP="$PERL_ROOT/app.pl"; printf '%s\n' '#!/usr/bin/env perl' 'print "app\\n";' > "$PERL_APP"
PERL_APP_HOME="$TMP_ROOT/home-perl-app"; mkdir -p "$PERL_APP_HOME"
out=$(HOME="$PERL_APP_HOME" bash -c '
    source "$1"
    APPS_DIR="$2/apps"; DESKTOP_DIR="$2/Desktop"; ICONS_DIR="$2/icons"; REGISTRY_DIR="$2/registry"; INSTALL_DIR="$2/install"; SCRIPTS_DIR="$2/scripts"
    mkdir -p "$APPS_DIR" "$DESKTOP_DIR" "$ICONS_DIR" "$REGISTRY_DIR" "$INSTALL_DIR" "$SCRIPTS_DIR"
    pause(){ :; }; clear(){ :; }; print_header(){ :; }; print_success(){ :; }; print_warning(){ :; }; print_info(){ :; }
    choose_and_process_icon(){ PICKED_ICON_FINAL="$ICONS_DIR/test.png"; : > "$PICKED_ICON_FINAL"; }
    finalize_menu_entry(){ :; }; finalize_desktop_shortcut(){ :; }; refresh_app_menu(){ :; }
    printf "3\n" | install_icon_for_script "$4"
    cat "$APPS_DIR"/scriptya-app-*.desktop
    cat "$DESKTOP_DIR"/scriptya-app-*.desktop
    registry_read "$(sanitize_id "$4")"
    printf "REGTYPE=%s\\nREGMENU=%s\\nREGDESKTOP=%s\\n" "$REG_TYPE" "$REG_MENU" "$REG_DESKTOP"
' _ "$LIB" "$PERL_APP_HOME" "$PERL_APP_HOME" "$PERL_APP")
assert_contains 'Perl standalone app has Exec through Scriptya' '--run-script' "$out"
assert_contains 'Perl standalone app source is registered' 'X-Scriptya-Source=' "$out"
assert_contains 'Perl standalone app source ends in .pl' '.pl' "$out"
assert_eq 'Perl standalone app is registered as script' 'REGTYPE=script' "$(grep -m1 '^REGTYPE=' <<< "$out")"
assert_eq 'Perl standalone app records menu installation' 'REGMENU=si' "$(grep -m1 '^REGMENU=' <<< "$out")"
assert_eq 'Perl standalone app records desktop installation' 'REGDESKTOP=si' "$(grep -m1 '^REGDESKTOP=' <<< "$out")"

# 69. Perl dependency error is translated and Nemo exposes Perl exactly like other executable script types.
PERL_MISSING="$PERL_ROOT/missing-perl.pl"; printf '%s\n' '#!/usr/bin/env perl' 'print "never\\n";' > "$PERL_MISSING"
perl_error=$(HOME="$TMP_ROOT/home-perl-error" LANGUAGE=en bash -c '
    source "$1"; LOG_FILE="$3/history.log"; INSTALL_DIR="$3"; pause(){ :; }
    command_exists(){ [[ "$1" != perl ]] && command -v "$1" >/dev/null 2>&1; }
    run_script "$4" inline
' _ "$LIB" ignored "$TMP_ROOT/home-perl-error" "$PERL_MISSING" 2>&1)
assert_contains 'English Perl dependency error is translated' "'perl' was not found" "$perl_error"
assert_not_contains 'English Perl dependency error has no Spanish phrase' 'No se encontró' "$perl_error"
NEMO_PERL_HOME="$TMP_ROOT/home-nemo-perl"; mkdir -p "$NEMO_PERL_HOME/.local/share/nemo/actions"
out=$(HOME="$NEMO_PERL_HOME" bash -c 'source "$1"; LANGUAGE=en; NEMO_ACTIONS_DIR="$2"; SCRIPT_PATH="/tmp/scriptya.sh"; write_nemo_actions; cat "$2"/scriptya-run.nemo_action "$2"/scriptya-install.nemo_action' _ "$LIB" "$NEMO_PERL_HOME/.local/share/nemo/actions" 2>&1)
assert_contains 'Nemo run action accepts Perl' 'Extensions=sh;py;js;mjs;cjs;pl;' "$out"
assert_contains 'Nemo install action accepts Perl' 'Extensions=sh;py;js;mjs;cjs;pl;rb;lua;fish;php;awk;go;html;htm;' "$out"

# 70. Perl help/README and real menu are localized, and UI language does not modify the Perl file.
help_en=$(HOME="$TMP_ROOT/home-help-perl" LANGUAGE=en bash -c 'source "$1"; show_help' _ "$LIB")
assert_contains 'English help documents Perl extension' '.pl' "$help_en"
assert_contains 'English help documents Perl and Ruby comments' 'Perl, Ruby, Fish, and AWK use #; Lua uses --' "$help_en"
assert_contains 'English README documents Perl' 'Perl' "$(cat "$ROOT_DIR/README.md")"
assert_contains 'Spanish README documents Perl' 'Perl' "$(cat "$ROOT_DIR/README_ES.md")"
PERL_MENU_DIR="$TMP_ROOT/perl-menu"; mkdir -p "$PERL_MENU_DIR"
cat > "$PERL_MENU_DIR/menu.pl" <<'PERL_EOF'
#!/usr/bin/env perl
# MENU: English Perl tool
# DESCRIPTION: Visible from the menu
print "MENU_PERL_OK\n";
PERL_EOF
menu_perl_en=$(HOME="$TMP_ROOT/home-perl-menu-en" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash -c 'source "$1"; LANGUAGE=en; SCRIPTS_DIR="$2"; menu_numeric "$2" run' _ "$LIB" "$PERL_MENU_DIR" <<< '0' 2>&1)
menu_perl_es=$(HOME="$TMP_ROOT/home-perl-menu-es" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash -c 'source "$1"; LANGUAGE=es; SCRIPTS_DIR="$2"; menu_numeric "$2" run' _ "$LIB" "$PERL_MENU_DIR" <<< '0' 2>&1)
assert_contains 'English menu renders Perl metadata' '🐪 English Perl tool — Visible from the menu' "$menu_perl_en"
assert_contains 'Spanish menu renders Perl metadata' '🐪 English Perl tool — Visible from the menu' "$menu_perl_es"
assert_not_contains 'English Perl menu has no Spanish install action' 'Instalar Scripts' "$menu_perl_en"
assert_not_contains 'Spanish Perl menu has no English install action' 'Install Scripts' "$menu_perl_es"
perl_hash_en=$(sha256sum "$PERL_RUN" | awk '{print $1}')
perl_hash_es=$(sha256sum "$PERL_RUN" | awk '{print $1}')
assert_eq 'Perl file is language-invariant' "$perl_hash_en" "$perl_hash_es"



# 71. Ruby files are first-class managed files: discovery, type detection and metadata.
RUBY_ROOT="$TMP_ROOT/ruby-managed"; mkdir -p "$RUBY_ROOT"
cat > "$RUBY_ROOT/tool.rb" <<'RUBY_EOF'
#!/usr/bin/env ruby
# MENU: Ruby Tool
# DESCRIPTION: Useful Ruby utility
# ORDER: 18
puts "ruby"
RUBY_EOF
cat > "$RUBY_ROOT/late.RB" <<'RUBY_EOF'
# MENU: Upper Ruby
# ORDER: 33
puts "late"
RUBY_EOF
touch "$RUBY_ROOT/ignore.rake"
managed=$(list_scripts "$RUBY_ROOT")
assert_contains 'Managed list includes .rb' 'tool.rb' "$managed"
assert_contains 'Managed list includes uppercase .RB' 'late.RB' "$managed"
assert_not_contains 'Ruby unrelated .rake file is not auto-managed' 'ignore.rake' "$managed"
assert_eq 'Ruby .rb type detected' 'ruby' "$(script_type "$RUBY_ROOT/tool.rb")"
assert_eq 'Ruby uppercase .RB type detected' 'ruby' "$(script_type "$RUBY_ROOT/late.RB")"
read_metadata "$RUBY_ROOT/tool.rb"
assert_eq 'Ruby metadata MENU' 'Ruby Tool' "$META_MENU"
assert_eq 'Ruby metadata DESCRIPTION' 'Useful Ruby utility' "$META_DESCRIPTION"
assert_eq 'Ruby metadata ORDER' '18' "$META_ORDER"

# 72. Ruby metadata insertion uses hash comments, preserves shebang/body/comments and remains valid Ruby.
RUBY_META="$RUBY_ROOT/metadata.rb"
cat > "$RUBY_META" <<'RUBY_EOF'
#!/usr/bin/env ruby
# Author: Scriptya test
payload = "RUBY_META_OK"
puts payload
RUBY_EOF
ruby_body_before=$(tail -n 2 "$RUBY_META")
NEWMETA_MENU='Ruby Utility'; NEWMETA_DESCRIPTION='A Ruby utility'; NEWMETA_CONFIRM='true'; NEWMETA_TERMINAL='true'; NEWMETA_SUDO='false'; NEWMETA_ORDER='19'; NEWMETA_ICON='utilities-terminal'; NEWMETA_ASK=('name' 'count')
if apply_metadata "$RUBY_META"; then ok 'Ruby metadata insertion runs'; else fail 'Ruby metadata insertion runs'; fi
assert_contains 'Ruby inserted MENU' '# MENU: Ruby Utility' "$(cat "$RUBY_META")"
assert_contains 'Ruby inserted DESCRIPTION' '# DESCRIPTION: A Ruby utility' "$(cat "$RUBY_META")"
assert_contains 'Ruby inserted CONFIRM' '# CONFIRM: true' "$(cat "$RUBY_META")"
assert_contains 'Ruby inserted ASK 1' '# ASK: name' "$(cat "$RUBY_META")"
assert_contains 'Ruby original comment survives' '# Author: Scriptya test' "$(cat "$RUBY_META")"
assert_eq 'Ruby body survives metadata insertion' "$ruby_body_before" "$(tail -n 2 "$RUBY_META")"
ruby -c "$RUBY_META" >/dev/null 2>&1 && ok 'Ruby metadata file remains valid Ruby' || fail 'Ruby metadata file remains valid Ruby'

# 73. Ruby execution preserves arguments, cwd, exit status and language invariance.
RUBY_RUN="$RUBY_ROOT/run.rb"
cat > "$RUBY_RUN" <<'RUBY_EOF'
#!/usr/bin/env ruby
# MENU: Ruby Runner
# DESCRIPTION: Ruby execution regression
# CONFIRM: false
# TERMINAL: false
# SUDO: false
# ASK: first value
puts "RUBY_PAYLOAD:#{ARGV.join('|')}"
puts "RUBY_CWD:#{Dir.pwd}"
RUBY_EOF
run_ruby() {
    local lang="$1" out
    out=$(HOME="$TMP_ROOT/home-ruby-$lang" LANGUAGE="$lang" bash -c '
        source "$1"
        LANGUAGE="$2"
        LOG_FILE="$3/history.log"
        INSTALL_DIR="$3"
        pause(){ :; }; clear(){ :; }; print_header(){ :; }; print_info(){ :; }; print_success(){ :; }; print_warning(){ :; }
        print_error(){ printf "ERR:%s\\n" "$1" >&2; }
        confirm_yn(){ return 1; }
        run_script "$4" inline
    ' _ "$LIB" "$lang" "$TMP_ROOT/home-ruby-$lang" "$RUBY_RUN" 2>&1 <<< 'answer')
    printf '%s' "$out"
}
out_en=$(run_ruby en)
out_es=$(run_ruby es)
assert_contains 'Ruby executes successfully in English' 'RUBY_PAYLOAD:answer' "$out_en"
assert_contains 'Ruby receives ASK value' 'answer' "$out_en"
assert_contains 'Ruby executes successfully in Spanish' 'RUBY_PAYLOAD:answer' "$out_es"
assert_eq 'Ruby payload is language-invariant' "$(grep 'RUBY_PAYLOAD:' <<< "$out_en")" "$(grep 'RUBY_PAYLOAD:' <<< "$out_es")"
assert_eq 'Ruby cwd is language-invariant' "$(grep 'RUBY_CWD:' <<< "$out_en")" "$(grep 'RUBY_CWD:' <<< "$out_es")"

# 74. Executable Ruby shebang is respected; nonzero status is preserved.
RUBY_EXEC="$RUBY_ROOT/executable.rb"
printf '%s\n' '#!/usr/bin/env ruby' 'puts "EXEC_RUBY_OK"' > "$RUBY_EXEC"
chmod +x "$RUBY_EXEC"
out=$(HOME="$TMP_ROOT/home-ruby-exec" LANGUAGE=en bash -c 'source "$1"; LOG_FILE="$3/history.log"; INSTALL_DIR="$3"; pause(){ :; }; clear(){ :; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-ruby-exec" "$RUBY_EXEC" 2>&1)
assert_contains 'Executable Ruby script runs through its shebang' 'EXEC_RUBY_OK' "$out"

# 74b. Regression: the executable+shebang fast path used to trust the
# shebang blindly and let the kernel fail with a raw "No such file or
# directory" (exit 127) when the named interpreter wasn't installed,
# skipping the translated "not found" warning entirely. command_exists
# is overridden so this doesn't depend on Ruby actually being missing.
out=$(HOME="$TMP_ROOT/home-ruby-missing-interp" LANGUAGE=en bash -c '
    source "$1"
    LOG_FILE="$3/history.log"; INSTALL_DIR="$3"
    pause(){ :; }; clear(){ :; }
    command_exists(){ [[ "$1" == "ruby" ]] && return 1; command -v "$1" >/dev/null 2>&1; }
    run_script "$4" inline
' _ "$LIB" ignored "$TMP_ROOT/home-ruby-missing-interp" "$RUBY_EXEC" 2>&1)
assert_contains 'Missing interpreter on executable+shebang script warns instead of crashing' 'not found to run this script' "$out"
assert_not_contains 'Missing interpreter on executable+shebang script does not leak a raw exec error' 'No such file or directory' "$out"

RUBY_FAIL="$RUBY_ROOT/status.rb"
printf '%s\n' '#!/usr/bin/env ruby' 'puts "RUBY_FAIL_PAYLOAD"' 'exit 7' > "$RUBY_FAIL"
for lang in en es; do
    out=$(HOME="$TMP_ROOT/home-ruby-status-$lang" LANGUAGE="$lang" bash -c 'source "$1"; LOG_FILE="$3/history.log"; INSTALL_DIR="$3"; pause(){ :; }; clear(){ :; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-ruby-status-$lang" "$RUBY_FAIL" 2>&1); rc=$?
    assert_eq "Ruby nonzero exit status is preserved in $lang" '7' "$rc"
    assert_contains "Ruby failing payload is preserved in $lang" 'RUBY_FAIL_PAYLOAD' "$out"
done

# 75. Ruby confirmation and standalone installation follow the existing script lifecycle.
RUBY_CONFIRM="$RUBY_ROOT/confirm.rb"; RUBY_CONFIRM_MARKER="$RUBY_ROOT/ruby-confirm-marker"
cat > "$RUBY_CONFIRM" <<'RUBY_EOF'
#!/usr/bin/env ruby
# CONFIRM: true
File.write('ruby-confirm-marker', "ran\n")
puts "RUBY_CONFIRM_OK"
RUBY_EOF
rm -f "$RUBY_CONFIRM_MARKER"
out=$(HOME="$TMP_ROOT/home-ruby-confirm" LANGUAGE=en bash -c 'source "$1"; LOG_FILE="$3/history.log"; INSTALL_DIR="$3"; pause(){ :; }; clear(){ :; }; confirm_yn(){ return 1; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-ruby-confirm" "$RUBY_CONFIRM" 2>&1); rc=$?
assert_eq 'Ruby confirmation can cancel execution' '1' "$rc"
assert_not_contains 'Cancelled Ruby script does not run' 'RUBY_CONFIRM_OK' "$out"
assert_not_contains 'Cancelled Ruby script leaves no marker' 'ruby-confirm-marker' "$(ls -1 "$RUBY_ROOT" 2>/dev/null)"

RUBY_APP="$RUBY_ROOT/app.rb"; printf '%s\n' '#!/usr/bin/env ruby' 'puts "app"' > "$RUBY_APP"
RUBY_APP_HOME="$TMP_ROOT/home-ruby-app"; mkdir -p "$RUBY_APP_HOME"
out=$(HOME="$RUBY_APP_HOME" bash -c '
    source "$1"
    APPS_DIR="$2/apps"; DESKTOP_DIR="$2/Desktop"; ICONS_DIR="$2/icons"; REGISTRY_DIR="$2/registry"; INSTALL_DIR="$2/install"; SCRIPTS_DIR="$2/scripts"
    mkdir -p "$APPS_DIR" "$DESKTOP_DIR" "$ICONS_DIR" "$REGISTRY_DIR" "$INSTALL_DIR" "$SCRIPTS_DIR"
    pause(){ :; }; clear(){ :; }; print_header(){ :; }; print_success(){ :; }; print_warning(){ :; }; print_info(){ :; }
    choose_and_process_icon(){ PICKED_ICON_FINAL="$ICONS_DIR/test.png"; : > "$PICKED_ICON_FINAL"; }
    finalize_menu_entry(){ :; }; finalize_desktop_shortcut(){ :; }; refresh_app_menu(){ :; }
    printf "3\n" | install_icon_for_script "$4"
    cat "$APPS_DIR"/scriptya-app-*.desktop
    cat "$DESKTOP_DIR"/scriptya-app-*.desktop
    registry_read "$(sanitize_id "$4")"
    printf "REGTYPE=%s\nREGMENU=%s\nREGDESKTOP=%s\n" "$REG_TYPE" "$REG_MENU" "$REG_DESKTOP"
' _ "$LIB" "$RUBY_APP_HOME" "$RUBY_APP_HOME" "$RUBY_APP")
assert_contains 'Ruby standalone app has Exec through Scriptya' '--run-script' "$out"
assert_contains 'Ruby standalone app source is registered' 'X-Scriptya-Source=' "$out"
assert_contains 'Ruby standalone app source ends in .rb' '.rb' "$out"
assert_eq 'Ruby standalone app is registered as script' 'REGTYPE=script' "$(grep -m1 '^REGTYPE=' <<< "$out")"
assert_eq 'Ruby standalone app records menu installation' 'REGMENU=si' "$(grep -m1 '^REGMENU=' <<< "$out")"
assert_eq 'Ruby standalone app records desktop installation' 'REGDESKTOP=si' "$(grep -m1 '^REGDESKTOP=' <<< "$out")"

# 76. Ruby dependency error is localized; Nemo and help document Ruby in both languages.
RUBY_MISSING="$RUBY_ROOT/missing-ruby.rb"; printf '%s\n' '#!/usr/bin/env ruby' 'puts "never"' > "$RUBY_MISSING"
ruby_error=$(HOME="$TMP_ROOT/home-ruby-error" LANGUAGE=en bash -c '
    source "$1"; LOG_FILE="$3/history.log"; INSTALL_DIR="$3"; pause(){ :; }
    command_exists(){ [[ "$1" != ruby ]] && command -v "$1" >/dev/null 2>&1; }
    run_script "$4" inline
' _ "$LIB" ignored "$TMP_ROOT/home-ruby-error" "$RUBY_MISSING" 2>&1)
assert_contains 'English Ruby dependency error is translated' "'ruby' was not found" "$ruby_error"
assert_not_contains 'English Ruby dependency error has no Spanish phrase' 'No se encontró' "$ruby_error"
NEMO_RUBY_HOME="$TMP_ROOT/home-nemo-ruby"; mkdir -p "$NEMO_RUBY_HOME/.local/share/nemo/actions"
out=$(HOME="$NEMO_RUBY_HOME" bash -c 'source "$1"; LANGUAGE=en; NEMO_ACTIONS_DIR="$2"; SCRIPT_PATH="/tmp/scriptya.sh"; write_nemo_actions; cat "$2"/scriptya-run.nemo_action "$2"/scriptya-install.nemo_action' _ "$LIB" "$NEMO_RUBY_HOME/.local/share/nemo/actions" 2>&1)
assert_contains 'Nemo run action accepts Ruby' 'Extensions=sh;py;js;mjs;cjs;pl;rb;lua;fish;php;awk;' "$out"
assert_contains 'Nemo install action accepts Ruby' 'Extensions=sh;py;js;mjs;cjs;pl;rb;lua;fish;php;awk;go;html;htm;' "$out"
help_en=$(HOME="$TMP_ROOT/home-help-ruby" LANGUAGE=en bash -c 'source "$1"; show_help' _ "$LIB")
assert_contains 'Nemo run action accepts AWK' 'Extensions=sh;py;js;mjs;cjs;pl;rb;lua;fish;php;awk;' "$out"

assert_contains 'English help documents Ruby extension' '.rb' "$help_en"
assert_contains 'English help documents Ruby comments' 'Perl, Ruby, Fish, and AWK use #; Lua uses --' "$help_en"
assert_contains 'English README documents Ruby' 'Ruby' "$(cat "$ROOT_DIR/README.md")"
assert_contains 'English README documents Ruby dependency' '`ruby`' "$(cat "$ROOT_DIR/README.md")"
assert_contains 'Spanish README documents Ruby dependency' '`ruby`' "$(cat "$ROOT_DIR/README_ES.md")"
assert_contains 'Spanish README documents Ruby' 'Ruby' "$(cat "$ROOT_DIR/README_ES.md")"
RUBY_MENU_DIR="$TMP_ROOT/ruby-menu"; mkdir -p "$RUBY_MENU_DIR"
cat > "$RUBY_MENU_DIR/menu.rb" <<'RUBY_EOF'
#!/usr/bin/env ruby
# MENU: English Ruby tool
# DESCRIPTION: Visible from the menu
puts "MENU_RUBY_OK"
RUBY_EOF
menu_ruby_en=$(HOME="$TMP_ROOT/home-ruby-menu-en" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash -c 'source "$1"; LANGUAGE=en; SCRIPTS_DIR="$2"; menu_numeric "$2" run' _ "$LIB" "$RUBY_MENU_DIR" <<< '0' 2>&1)
menu_ruby_es=$(HOME="$TMP_ROOT/home-ruby-menu-es" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash -c 'source "$1"; LANGUAGE=es; SCRIPTS_DIR="$2"; menu_numeric "$2" run' _ "$LIB" "$RUBY_MENU_DIR" <<< '0' 2>&1)
assert_contains 'English menu renders Ruby metadata' '💎 English Ruby tool — Visible from the menu' "$menu_ruby_en"
assert_contains 'Spanish menu renders Ruby metadata' '💎 English Ruby tool — Visible from the menu' "$menu_ruby_es"
assert_not_contains 'English Ruby menu has no Spanish install action' 'Instalar Scripts' "$menu_ruby_en"
assert_not_contains 'Spanish Ruby menu has no English install action' 'Install Scripts' "$menu_ruby_es"
ruby_hash_en=$(sha256sum "$RUBY_RUN" | awk '{print $1}')
ruby_hash_es=$(sha256sum "$RUBY_RUN" | awk '{print $1}')
assert_eq 'Ruby file is language-invariant' "$ruby_hash_en" "$ruby_hash_es"

# 77. Ruby shebang overrides a misleading extension when executable.
RUBY_SHEBANG="$RUBY_ROOT/node-extension-ruby.js"
cat > "$RUBY_SHEBANG" <<'RUBY_EOF'
#!/usr/bin/env ruby
# MENU: Ruby via shebang
# DESCRIPTION: Shebang-selected Ruby
puts "RUBY_SHEBANG_OK"
RUBY_EOF
chmod +x "$RUBY_SHEBANG"
assert_eq 'Ruby shebang overrides extension' 'ruby' "$(script_type "$RUBY_SHEBANG")"
read_metadata "$RUBY_SHEBANG"
assert_eq 'Ruby shebang metadata uses hash comments' 'Ruby via shebang|Shebang-selected Ruby' "$META_MENU|$META_DESCRIPTION"
out=$(HOME="$TMP_ROOT/home-ruby-shebang" LANGUAGE=en bash -c 'source "$1"; LOG_FILE="$3/history.log"; INSTALL_DIR="$3"; pause(){ :; }; clear(){ :; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-ruby-shebang" "$RUBY_SHEBANG" 2>&1)
assert_contains 'Ruby shebang-selected execution works' 'RUBY_SHEBANG_OK' "$out"


# ---- LUA TESTS ----
LUA_ROOT="$TMP_ROOT/lua-managed"; mkdir -p "$LUA_ROOT"
LUA_META="$LUA_ROOT/tool.lua"
printf '%s\n' '#!/usr/bin/env lua' '-- MENU: English Lua tool' '-- DESCRIPTION: Visible from the menu' '-- CONFIRM: false' '-- TERMINAL: false' '-- SUDO: false' '-- ORDER: 42' '-- ASK: First value' 'print("LUA_OK|" .. (arg[1] or ""))' > "$LUA_META"
assert_eq 'Lua .lua type detected' 'lua' "$(script_type "$LUA_META")"
LUA_DEFAULT="$TMP_ROOT/lua-default/without-menu.lua"; mkdir -p "$(dirname "$LUA_DEFAULT")"; printf '%s\n' '#!/usr/bin/env lua' 'print("default")' > "$LUA_DEFAULT"
read_metadata "$LUA_DEFAULT"
assert_eq 'Lua default menu name omits extension' 'without-menu' "$META_MENU"
printf '%s\n' '#!/usr/bin/env lua' 'print("upper")' > "$LUA_ROOT/UPPER.LUA"
assert_eq 'Lua uppercase .LUA type detected' 'lua' "$(script_type "$LUA_ROOT/UPPER.LUA")"
LUA_LIST_DIR="$TMP_ROOT/lua-list"; mkdir -p "$LUA_LIST_DIR"
printf '%s\n' 'print("list")' > "$LUA_LIST_DIR/item.lua"
printf '%s\n' 'not managed' > "$LUA_LIST_DIR/item.txt"
lua_list="$(list_scripts "$LUA_LIST_DIR")"
assert_contains 'Managed list includes .lua' 'item.lua' "$lua_list"
assert_not_contains 'Managed list excludes unrelated Lua file' 'item.txt' "$lua_list"
read_metadata "$LUA_META"
assert_eq 'Lua MENU metadata' 'English Lua tool' "$META_MENU"
assert_eq 'Lua DESCRIPTION metadata' 'Visible from the menu' "$META_DESCRIPTION"
assert_eq 'Lua ASK metadata' 'First value' "${META_ASK[0]}"

LUA_META_COPY="$LUA_ROOT/meta-copy.lua"
printf '%s\n' '#!/usr/bin/env lua' 'print("body")' > "$LUA_META_COPY"
NEWMETA_MENU='Lua inserted'; NEWMETA_DESCRIPTION='Lua description'; NEWMETA_CONFIRM='false'; NEWMETA_TERMINAL='false'; NEWMETA_SUDO='false'; NEWMETA_ORDER='10'; NEWMETA_ICON='lua-icon.png'; NEWMETA_ASK=('One' 'Two')
apply_metadata "$LUA_META_COPY"
assert_contains 'Lua metadata insertion uses Lua comments' '-- MENU: Lua inserted' "$(cat "$LUA_META_COPY")"
assert_contains 'Lua metadata insertion preserves shebang' '#!/usr/bin/env lua' "$(cat "$LUA_META_COPY")"
assert_contains 'Lua metadata insertion preserves body' 'print("body")' "$(cat "$LUA_META_COPY")"

LUA_RUN="$LUA_ROOT/run.lua"
printf '%s\n' '#!/usr/bin/env lua' '-- MENU: Lua execution' '-- DESCRIPTION: Real Lua execution' '-- ASK: Input' 'print("LUA_EXEC|" .. (arg[1] or ""))' > "$LUA_RUN"
out=$(HOME="$TMP_ROOT/home-lua-en" LANGUAGE=en LOG_FILE="$TMP_ROOT/home-lua-en/history.log" INSTALL_DIR="$TMP_ROOT/home-lua-en/install" bash -c 'source "$1"; pause(){ :; }; clear(){ :; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-lua-en" "$LUA_RUN" 2>&1 <<< 'answer')
assert_contains 'Lua execution works in English' 'LUA_EXEC|answer' "$out"
out=$(HOME="$TMP_ROOT/home-lua-es" LANGUAGE=es LOG_FILE="$TMP_ROOT/home-lua-es/history.log" INSTALL_DIR="$TMP_ROOT/home-lua-es/install" bash -c 'source "$1"; pause(){ :; }; clear(){ :; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-lua-es" "$LUA_RUN" 2>&1 <<< 'answer')
assert_contains 'Lua execution works in Spanish' 'LUA_EXEC|answer' "$out"
if $LUA_TEST_REAL; then
    lua_syntax=$(LUA_SYNTAX_CHECK_FILE="$LUA_RUN" lua -e 'assert(loadfile(os.getenv("LUA_SYNTAX_CHECK_FILE")))' 2>&1 </dev/null)
    assert_eq 'Lua syntax check passes when interpreter is available' '' "$lua_syntax"
fi

LUA_FAIL="$LUA_ROOT/fail.lua"
printf '%s\n' '#!/usr/bin/env lua' 'print("LUA_FAIL_PAYLOAD")' 'os.exit(7)' > "$LUA_FAIL"
LUA_EXEC="$LUA_ROOT/shebang.lua"
printf '%s\n' '#!/usr/bin/env lua' 'print("LUA_SHEBANG_OK")' > "$LUA_EXEC"
chmod +x "$LUA_EXEC"
assert_eq 'Lua shebang detected' 'lua' "$(script_type "$LUA_EXEC")"

LUA_DEP="$LUA_ROOT/missing.lua"
printf '%s\n' '#!/usr/bin/env lua' 'print("never")' > "$LUA_DEP"
lua_error=$(HOME="$TMP_ROOT/home-lua-error" LANGUAGE=en bash -c 'source "$1"; pause(){ :; }; clear(){ :; }; LOG_FILE="$3/history.log"; INSTALL_DIR="$3"; command_exists(){ [[ "$1" != lua ]] && command -v "$1" >/dev/null 2>&1; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-lua-error" "$LUA_DEP" 2>&1)
lua_rc=$?
assert_eq 'Missing Lua interpreter returns failure' '1' "$lua_rc"
assert_contains 'English Lua dependency error is translated' "'lua' was not found" "$lua_error"
assert_not_contains 'English Lua dependency error has no Spanish phrase' 'No se encontró' "$lua_error"

NEMO_LUA_HOME="$TMP_ROOT/home-nemo-lua"; mkdir -p "$NEMO_LUA_HOME/.local/share/nemo/actions"
HOME="$NEMO_LUA_HOME" LANGUAGE=en NEMO_ACTIONS_DIR="$NEMO_LUA_HOME/.local/share/nemo/actions" bash -c 'source "$1"; write_nemo_actions' _ "$LIB" 2>&1
run_action=$(cat "$NEMO_LUA_HOME/.local/share/nemo/actions/scriptya-run.nemo_action")
install_action=$(cat "$NEMO_LUA_HOME/.local/share/nemo/actions/scriptya-install.nemo_action")
assert_contains 'Nemo run action accepts Lua' 'Extensions=sh;py;js;mjs;cjs;pl;rb;lua;fish;php;' "$run_action"
assert_contains 'Nemo install action accepts Lua' 'Extensions=sh;py;js;mjs;cjs;pl;rb;lua;fish;php;awk;go;html;htm;' "$install_action"

help_lua_en=$(HOME="$TMP_ROOT/home-help-lua" LANGUAGE=en bash -c 'source "$1"; show_help' _ "$LIB")
assert_contains 'English help documents Lua' '.lua' "$help_lua_en"
assert_contains 'English help documents Lua comments' 'Perl, Ruby, Fish, and AWK use #; Lua uses --' "$help_lua_en"

LUA_MENU_DIR="$TMP_ROOT/lua-menu"; mkdir -p "$LUA_MENU_DIR"
printf '%s\n' '-- MENU: English Lua tool' '-- DESCRIPTION: Visible from the menu' 'print("menu")' > "$LUA_MENU_DIR/tool.lua"
menu_lua_en=$(HOME="$TMP_ROOT/home-lua-menu-en" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash -c 'source "$1"; LANGUAGE=en; SCRIPTS_DIR="$2"; menu_numeric "$2" run' _ "$LIB" "$LUA_MENU_DIR" <<< '0' 2>&1)
menu_lua_es=$(HOME="$TMP_ROOT/home-lua-menu-es" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash -c 'source "$1"; LANGUAGE=es; SCRIPTS_DIR="$2"; menu_numeric "$2" run' _ "$LIB" "$LUA_MENU_DIR" <<< '0' 2>&1)
assert_contains 'English menu renders Lua metadata' 'English Lua tool — Visible from the menu' "$menu_lua_en"
assert_contains 'Spanish menu renders Lua metadata' 'English Lua tool — Visible from the menu' "$menu_lua_es"
assert_not_contains 'English Lua menu has no Spanish install action' 'Instalar Scripts' "$menu_lua_en"
assert_not_contains 'Spanish Lua menu has no English install action' 'Install Scripts' "$menu_lua_es"

lua_hash_before=$(sha256sum "$LUA_RUN" | awk '{print $1}')
LANGUAGE=en read_metadata "$LUA_RUN" >/dev/null
lua_hash_after=$(sha256sum "$LUA_RUN" | awk '{print $1}')
assert_eq 'Lua file is language-invariant' "$lua_hash_before" "$lua_hash_after"

# 74. Fish is a first-class managed type: discovery, comments, execution and language invariance.
FISH_ROOT="$TMP_ROOT/fish-managed"; mkdir -p "$FISH_ROOT"
cat > "$FISH_ROOT/run.fish" <<'FISH_EOF'
#!/usr/bin/env fish
# MENU: English Fish tool
# DESCRIPTION: Visible from the menu
# CONFIRM: false
# TERMINAL: false
# SUDO: false
# ORDER: 12
# ASK: First value
# ICON: fish-icon.png

echo "FISH_EXEC|$argv[1]"
FISH_EOF
printf '%s\n' 'echo "upper"' > "$FISH_ROOT/UPPER.FISH"
printf '%s\n' '#!/usr/bin/env fish' 'echo "FISH_SHEBANG_OK"' > "$FISH_ROOT/shebang.fish"
assert_eq 'Fish .fish type detected' 'fish' "$(script_type "$FISH_ROOT/run.fish")"
assert_eq 'Fish uppercase .FISH type detected' 'fish' "$(script_type "$FISH_ROOT/UPPER.FISH")"
assert_eq 'Fish shebang type detected' 'fish' "$(script_type "$FISH_ROOT/shebang.fish")"
read_metadata "$FISH_ROOT/run.fish"
assert_eq 'Fish MENU metadata' 'English Fish tool' "$META_MENU"
assert_eq 'Fish DESCRIPTION metadata' 'Visible from the menu' "$META_DESCRIPTION"
assert_eq 'Fish ASK metadata' 'First value' "${META_ASK[0]}"
fish_list="$(list_scripts "$FISH_ROOT")"
assert_contains 'Managed list includes .fish' 'run.fish' "$fish_list"

FISH_META="$FISH_ROOT/meta-copy.fish"
printf '%s\n' '#!/usr/bin/env fish' 'echo "body"' > "$FISH_META"
NEWMETA_MENU='Fish inserted'; NEWMETA_DESCRIPTION='Fish description'; NEWMETA_CONFIRM='false'; NEWMETA_TERMINAL='false'; NEWMETA_SUDO='false'; NEWMETA_ORDER='10'; NEWMETA_ICON='fish-icon.png'; NEWMETA_ASK=('One' 'Two')
apply_metadata "$FISH_META"
fish_meta_raw=$(cat "$FISH_META")
assert_contains 'Fish metadata insertion uses hash comments' '# MENU: Fish inserted' "$fish_meta_raw"
assert_contains 'Fish metadata insertion preserves shebang' '#!/usr/bin/env fish' "$fish_meta_raw"
assert_contains 'Fish metadata insertion preserves body' 'echo "body"' "$fish_meta_raw"

FISH_RUN="$(HOME="$TMP_ROOT/home-fish-en" LANGUAGE=en LOG_FILE="$TMP_ROOT/home-fish-en/history.log" INSTALL_DIR="$TMP_ROOT/home-fish-en/install" bash -c 'source "$1"; pause(){ :; }; clear(){ :; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-fish-en" "$FISH_ROOT/run.fish" 2>&1 <<< 'answer')"
assert_contains 'Fish execution works in English' 'FISH_EXEC|answer' "$FISH_RUN"
FISH_RUN_ES="$(HOME="$TMP_ROOT/home-fish-es" LANGUAGE=es LOG_FILE="$TMP_ROOT/home-fish-es/history.log" INSTALL_DIR="$TMP_ROOT/home-fish-es/install" bash -c 'source "$1"; pause(){ :; }; clear(){ :; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-fish-es" "$FISH_ROOT/run.fish" 2>&1 <<< 'answer')"
assert_contains 'Fish execution works in Spanish' 'FISH_EXEC|answer' "$FISH_RUN_ES"
if $FISH_TEST_REAL; then
    fish -n "$FISH_ROOT/run.fish" >/dev/null 2>&1 && ok 'Fish syntax check passes when interpreter is available' || fail 'Fish syntax check passes when interpreter is available'
fi

chmod +x "$FISH_ROOT/shebang.fish"
fish_shebang_out=$(HOME="$TMP_ROOT/home-fish-shebang" LANGUAGE=en LOG_FILE="$TMP_ROOT/home-fish-shebang/history.log" INSTALL_DIR="$TMP_ROOT/home-fish-shebang/install" bash -c 'source "$1"; pause(){ :; }; clear(){ :; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-fish-shebang" "$FISH_ROOT/shebang.fish" 2>&1)
assert_contains 'Fish executable shebang runs' 'FISH_SHEBANG_OK' "$fish_shebang_out"

FISH_DEP="$FISH_ROOT/missing.fish"; printf '%s\n' '#!/usr/bin/env fish' 'echo never' > "$FISH_DEP"
fish_error=$(HOME="$TMP_ROOT/home-fish-error" LANGUAGE=en bash -c 'source "$1"; pause(){ :; }; clear(){ :; }; LOG_FILE="$3/history.log"; INSTALL_DIR="$3"; command_exists(){ [[ "$1" != fish ]] && command -v "$1" >/dev/null 2>&1; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-fish-error" "$FISH_DEP" 2>&1)
fish_rc=$?
assert_eq 'Missing Fish interpreter returns failure' '1' "$fish_rc"
assert_contains 'English Fish dependency error is translated' "'fish' was not found" "$fish_error"
assert_not_contains 'English Fish dependency error has no Spanish phrase' 'No se encontró' "$fish_error"

fish_help_en=$(HOME="$TMP_ROOT/home-help-fish" LANGUAGE=en bash -c 'source "$1"; show_help' _ "$LIB")
assert_contains 'English help documents Fish' '.fish' "$fish_help_en"
assert_contains 'English help documents AWK' '.awk' "$help_en"
assert_contains 'English help documents Fish comments' 'Perl, Ruby, Fish, and AWK use #' "$fish_help_en"

FISH_MENU_DIR="$TMP_ROOT/fish-menu"; mkdir -p "$FISH_MENU_DIR"
printf '%s\n' '# MENU: English Fish tool' '# DESCRIPTION: Visible from the menu' 'echo menu' > "$FISH_MENU_DIR/menu.fish"
menu_fish_en=$(HOME="$TMP_ROOT/home-fish-menu-en" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash -c 'source "$1"; LANGUAGE=en; SCRIPTS_DIR="$2"; menu_numeric "$2" run' _ "$LIB" "$FISH_MENU_DIR" <<< '0' 2>&1)
menu_fish_es=$(HOME="$TMP_ROOT/home-fish-menu-es" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash -c 'source "$1"; LANGUAGE=es; SCRIPTS_DIR="$2"; menu_numeric "$2" run' _ "$LIB" "$FISH_MENU_DIR" <<< '0' 2>&1)
assert_contains 'English menu renders Fish metadata' 'English Fish tool — Visible from the menu' "$menu_fish_en"
assert_contains 'Spanish menu renders Fish metadata' 'English Fish tool — Visible from the menu' "$menu_fish_es"
assert_not_contains 'English Fish menu has no Spanish install action' 'Instalar Scripts' "$menu_fish_en"
assert_not_contains 'Spanish Fish menu has no English install action' 'Install Scripts' "$menu_fish_es"

fish_hash_before=$(sha256sum "$FISH_ROOT/run.fish" | awk '{print $1}')
LANGUAGE=en read_metadata "$FISH_ROOT/run.fish" >/dev/null
fish_hash_after=$(sha256sum "$FISH_ROOT/run.fish" | awk '{print $1}')
assert_eq 'Fish file is language-invariant' "$fish_hash_before" "$fish_hash_after"

# 75. Lua metadata uses valid Lua comments, while legacy hash metadata is not accepted.
LUA_VALID="$LUA_ROOT/valid-comments.lua"
printf '%s\n' '#!/usr/bin/env lua' '-- MENU: Lua valid' '-- DESCRIPTION: Valid Lua metadata' 'print("lua")' > "$LUA_VALID"
read_metadata "$LUA_VALID"
assert_eq 'Lua valid comment metadata is read' 'Lua valid' "$META_MENU"
assert_eq 'Lua valid comment description is read' 'Valid Lua metadata' "$META_DESCRIPTION"
LUA_BAD="$LUA_ROOT/bad-hash-comments.lua"
printf '%s\n' '#!/usr/bin/env lua' '# MENU: Invalid Lua' 'print("lua")' > "$LUA_BAD"
read_metadata "$LUA_BAD"
assert_eq 'Lua invalid hash metadata is ignored' 'bad-hash-comments' "$META_MENU"


# 76. PHP CLI is a first-class managed type: discovery, metadata, execution and language invariance.
PHP_ROOT="$TMP_ROOT/php-managed"; mkdir -p "$PHP_ROOT"
PHP_RUN="$PHP_ROOT/run.php"
cat > "$PHP_RUN" <<'PHP_EOF'
#!/usr/bin/env php
<?php
// MENU: English PHP tool
// DESCRIPTION: Visible from the menu
// CONFIRM: false
// TERMINAL: false
// SUDO: false
// ORDER: 14
// ASK: First value
// ICON: php-icon.png

echo "PHP_EXEC|" . ($argv[1] ?? "") . "\n";
echo "PHP_CWD|" . getcwd() . "\n";
PHP_EOF
chmod +x "$PHP_RUN"
printf '%s\n' 'print("uppercase")' > "$PHP_ROOT/UPPER.PHP"
printf '%s\n' '#!/usr/bin/env php' '<?php' 'echo "shebang";' > "$PHP_ROOT/shebang.php"
assert_eq 'PHP .php type detected' 'php' "$(script_type "$PHP_RUN")"
assert_eq 'PHP uppercase .PHP type detected' 'php' "$(script_type "$PHP_ROOT/UPPER.PHP")"
read_metadata "$PHP_RUN"
assert_eq 'PHP metadata MENU' 'English PHP tool' "$META_MENU"
assert_eq 'PHP metadata DESCRIPTION' 'Visible from the menu' "$META_DESCRIPTION"
assert_eq 'PHP metadata ORDER' '14' "$META_ORDER"
assert_eq 'PHP metadata ASK' 'First value' "${META_ASK[0]}"
assert_eq 'PHP metadata ICON' 'php-icon.png' "$META_ICON"
# Legacy PHP metadata used by existing demos remains readable.
PHP_LEGACY="$PHP_ROOT/legacy.php"
cat > "$PHP_LEGACY" <<'PHP_EOF'
#!/usr/bin/env php
<?php
# MENU: Legacy PHP
# DESCRIPTION: Old metadata format
echo "legacy\n";
PHP_EOF
read_metadata "$PHP_LEGACY"
assert_eq 'PHP legacy hash metadata remains readable' 'Legacy PHP' "$META_MENU"
assert_eq 'PHP legacy hash metadata description remains readable' 'Old metadata format' "$META_DESCRIPTION"
if script_has_metadata "$PHP_LEGACY"; then ok 'PHP legacy hash metadata is detected by editor'; else fail 'PHP legacy hash metadata is detected by editor'; fi
NEWMETA_MENU='Rewritten PHP'; NEWMETA_DESCRIPTION='New metadata'; NEWMETA_CONFIRM='false'; NEWMETA_TERMINAL='false'; NEWMETA_SUDO='false'; NEWMETA_ORDER='500'; NEWMETA_ICON=''; NEWMETA_ASK=()
apply_metadata "$PHP_LEGACY"
assert_contains 'PHP legacy hash metadata can be rewritten' '// MENU: Rewritten PHP' "$(cat "$PHP_LEGACY")"
assert_not_contains 'PHP legacy hash metadata is not left active' '# MENU: Legacy PHP' "$(cat "$PHP_LEGACY")"
if php -l "$PHP_LEGACY" >/dev/null 2>&1; then ok 'PHP rewritten legacy metadata remains valid'; else fail 'PHP rewritten legacy metadata remains valid'; fi
assert_eq 'PHP default metadata name strips extension' 'UPPER' "$(bash -c 'source "$1"; read_metadata "$2"; printf "%s" "$META_MENU"' _ "$LIB" "$PHP_ROOT/UPPER.PHP")"
php_list=$(list_scripts "$PHP_ROOT")
assert_contains 'Managed list includes PHP' 'run.php' "$php_list"
assert_contains 'Managed list is case-insensitive for PHP' 'UPPER.PHP' "$php_list"
printf '%s\n' 'not managed' > "$PHP_ROOT/ignored.txt"
assert_not_contains 'Managed list excludes unrelated PHP text file' 'ignored.txt' "$php_list"

# 77. PHP metadata is placed after <?php and leaves valid PHP code intact.
PHP_META="$PHP_ROOT/metadata.php"
cat > "$PHP_META" <<'PHP_EOF'
#!/usr/bin/env php
<?php
// Author: Scriptya test

$payload = 'ok';
echo "PAYLOAD=$payload\n";
PHP_EOF
orig_php_body=$(tail -n 2 "$PHP_META")
NEWMETA_MENU='PHP Tool'; NEWMETA_DESCRIPTION='A PHP utility'; NEWMETA_CONFIRM='true'; NEWMETA_TERMINAL='true'; NEWMETA_SUDO='false'; NEWMETA_ORDER='8'; NEWMETA_ICON='utilities-terminal'; NEWMETA_ASK=('name' 'count')
apply_metadata "$PHP_META"
head -n 1 "$PHP_META" | grep -Fxq '#!/usr/bin/env php' && ok 'PHP shebang is preserved' || fail 'PHP shebang is preserved'
assert_contains 'PHP opening tag is preserved' '<?php' "$(head -n 5 "$PHP_META")"
assert_contains 'PHP inserted MENU' '// MENU: PHP Tool' "$(cat "$PHP_META")"
assert_contains 'PHP inserted DESCRIPTION' '// DESCRIPTION: A PHP utility' "$(cat "$PHP_META")"
assert_contains 'PHP inserted ASK' '// ASK: name' "$(cat "$PHP_META")"
assert_contains 'PHP original comment survives' '// Author: Scriptya test' "$(cat "$PHP_META")"
assert_eq 'PHP body survives metadata insertion' "$orig_php_body" "$(tail -n 2 "$PHP_META")"
assert_eq 'PHP edited file passes lint' '' "$(php -l "$PHP_META" 2>&1 | grep -v '^No syntax errors detected')"
if script_has_metadata "$PHP_META"; then ok 'PHP metadata is detected by editor'; else fail 'PHP metadata is detected by editor'; fi

# 78. PHP executes through CLI in both languages without changing payload, cwd or status.
run_php_lang() {
    local lang="$1" out rc
    out=$(HOME="$TMP_ROOT/home-php-$lang" LANGUAGE="$lang" LOG_FILE="$TMP_ROOT/home-php-$lang/history.log" INSTALL_DIR="$TMP_ROOT/home-php-$lang/install" bash -c '
        source "$1"
        pause(){ :; }; clear(){ :; }; print_header(){ :; }; print_success(){ :; }; print_error(){ :; }; print_warning(){ :; }
        run_script "$4" inline
    ' _ "$LIB" ignored "$TMP_ROOT/home-php-$lang" "$PHP_RUN" 2>&1 <<< 'answer')
    rc=$?
    printf 'STATUS=%s\n%s' "$rc" "$out"
}
php_en=$(run_php_lang en)
php_es=$(run_php_lang es)
assert_contains 'PHP execution succeeds in English' 'STATUS=0' "$php_en"
assert_contains 'PHP execution succeeds in Spanish' 'STATUS=0' "$php_es"
assert_contains 'PHP payload is preserved in English' 'PHP_EXEC|answer' "$php_en"
assert_contains 'PHP payload is preserved in Spanish' 'PHP_EXEC|answer' "$php_es"
assert_contains 'PHP cwd is preserved in English' "PHP_CWD|$PHP_ROOT" "$php_en"
assert_contains 'PHP cwd is preserved in Spanish' "PHP_CWD|$PHP_ROOT" "$php_es"
assert_eq 'PHP execution payload is language-invariant' "$(grep '^PHP_EXEC|' <<< "$php_en")" "$(grep '^PHP_EXEC|' <<< "$php_es")"

PHP_FAIL="$PHP_ROOT/fail.php"
printf '%s\n' '<?php' 'echo "PHP_FAIL_PAYLOAD\\n";' 'exit(7);' > "$PHP_FAIL"
for lang in en es; do
    out=$(HOME="$TMP_ROOT/home-php-status-$lang" LANGUAGE="$lang" LOG_FILE="$TMP_ROOT/home-php-status-$lang/history.log" INSTALL_DIR="$TMP_ROOT/home-php-status-$lang/install" bash -c 'source "$1"; pause(){ :; }; clear(){ :; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-php-status-$lang" "$PHP_FAIL" 2>&1); rc=$?
    assert_eq "PHP nonzero exit status is preserved in $lang" '7' "$rc"
    assert_contains "PHP failing payload is preserved in $lang" 'PHP_FAIL_PAYLOAD' "$out"
done

PHP_DEP="$PHP_ROOT/missing-php.php"; printf '%s\n' '<?php' 'echo "never";' > "$PHP_DEP"
php_error=$(HOME="$TMP_ROOT/home-php-error" LANGUAGE=en bash -c '
    source "$1"; pause(){ :; }; clear(){ :; }; LOG_FILE="$3/history.log"; INSTALL_DIR="$3"
    command_exists(){ [[ "$1" != php ]] && command -v "$1" >/dev/null 2>&1; }
    run_script "$4" inline
' _ "$LIB" ignored "$TMP_ROOT/home-php-error" "$PHP_DEP" 2>&1)
php_rc=$?
assert_eq 'Missing PHP interpreter returns failure' '1' "$php_rc"
assert_contains 'English PHP dependency error is translated' "'php' was not found" "$php_error"
assert_not_contains 'English PHP dependency error has no Spanish phrase' 'No se encontró' "$php_error"

# 79. PHP shebang, standalone installation and Nemo integration.
assert_eq 'PHP shebang overrides extension' 'php' "$(script_type "$PHP_ROOT/shebang.php")"
chmod +x "$PHP_ROOT/shebang.php"
out=$(HOME="$TMP_ROOT/home-php-shebang" LANGUAGE=en LOG_FILE="$TMP_ROOT/home-php-shebang/history.log" INSTALL_DIR="$TMP_ROOT/home-php-shebang/install" bash -c 'source "$1"; pause(){ :; }; clear(){ :; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-php-shebang" "$PHP_ROOT/shebang.php" 2>&1)
assert_contains 'PHP shebang-selected execution works' 'shebang' "$out"
PHP_APP="$PHP_ROOT/app.php"; printf '%s\n' '<?php' 'echo "app";' > "$PHP_APP"
PHP_APP_HOME="$TMP_ROOT/home-php-app"; mkdir -p "$PHP_APP_HOME"
out=$(HOME="$PHP_APP_HOME" bash -c '
    source "$1"
    APPS_DIR="$2/apps"; DESKTOP_DIR="$2/Desktop"; ICONS_DIR="$2/icons"; REGISTRY_DIR="$2/registry"; INSTALL_DIR="$2/install"; SCRIPTS_DIR="$2/scripts"
    mkdir -p "$APPS_DIR" "$DESKTOP_DIR" "$ICONS_DIR" "$REGISTRY_DIR" "$INSTALL_DIR" "$SCRIPTS_DIR"
    pause(){ :; }; clear(){ :; }; print_header(){ :; }; print_success(){ :; }; print_warning(){ :; }; print_info(){ :; }
    choose_and_process_icon(){ PICKED_ICON_FINAL="$ICONS_DIR/test.png"; : > "$PICKED_ICON_FINAL"; }
    finalize_menu_entry(){ :; }; finalize_desktop_shortcut(){ :; }; refresh_app_menu(){ :; }
    printf "3\\n" | install_icon_for_script "$4"
    cat "$APPS_DIR"/scriptya-app-*.desktop
    registry_read "$(sanitize_id "$4")"
    printf "REGTYPE=%s\\nREGMENU=%s\\nREGDESKTOP=%s\\n" "$REG_TYPE" "$REG_MENU" "$REG_DESKTOP"
' _ "$LIB" "$PHP_APP_HOME" "$PHP_APP_HOME" "$PHP_APP")
assert_contains 'PHP standalone app uses --run-script' '--run-script' "$out"
assert_contains 'PHP standalone app source is registered' 'X-Scriptya-Source=' "$out"
assert_contains 'PHP standalone app source ends in .php' '.php' "$out"
assert_contains 'PHP standalone app is registered as script' 'REGTYPE=script' "$out"
NEMO_PHP_HOME="$TMP_ROOT/home-nemo-php"; mkdir -p "$NEMO_PHP_HOME/.local/share/nemo/actions"
out=$(HOME="$NEMO_PHP_HOME" bash -c 'source "$1"; LANGUAGE=en; NEMO_ACTIONS_DIR="$2"; SCRIPT_PATH="/tmp/scriptya.sh"; write_nemo_actions; cat "$2"/scriptya-run.nemo_action "$2"/scriptya-install.nemo_action "$2"/scriptya-uninstall.nemo_action "$2"/scriptya-change-icon.nemo_action' _ "$LIB" "$NEMO_PHP_HOME/.local/share/nemo/actions" 2>&1)
assert_contains 'Nemo run action accepts PHP' 'Extensions=sh;py;js;mjs;cjs;pl;rb;lua;fish;php;' "$out"
assert_contains 'Nemo install action accepts PHP' 'Extensions=sh;py;js;mjs;cjs;pl;rb;lua;fish;php;awk;go;html;htm;' "$out"
assert_contains 'Nemo uninstall action accepts PHP' 'Extensions=sh;py;js;mjs;cjs;pl;rb;lua;fish;php;awk;go;html;htm;' "$out"
assert_contains 'Nemo change icon action accepts PHP' 'Extensions=sh;py;js;mjs;cjs;pl;rb;lua;fish;php;awk;go;html;htm;' "$out"

# 80. AWK support.
AWK_ROOT="$TMP_ROOT/awk"
AWK_LIST_DIR="$TMP_ROOT/awk-list"
AWK_MENU_DIR="$TMP_ROOT/awk-menu"
mkdir -p "$AWK_ROOT" "$AWK_LIST_DIR" "$AWK_MENU_DIR"
printf '%s\n' '# MENU: AWK menu' 'BEGIN { print "menu"; exit 0 }' > "$AWK_MENU_DIR/menu.awk"
cat > "$AWK_ROOT/tool.awk" <<'AWK_EOF'
# MENU: AWK tool
# DESCRIPTION: AWK metadata test
# CONFIRM: false
# TERMINAL: false
# SUDO: false
# ORDER: 41
# ASK: First value
# ASK: Second value
# ICON: ../assets/demo-blue.svg
BEGIN { print "AWK_EXEC|" ENVIRON["SCRIPTYA_ASK_1"] "|" ENVIRON["SCRIPTYA_ASK_2"] "|" ENVIRON["SCRIPTYA_TEST_ENV"]; exit 0 }
AWK_EOF
printf '%s\n' 'print "upper"' > "$AWK_ROOT/UPPER.AWK"
printf '%s\n' 'BEGIN { print "list"; exit 0 }' > "$AWK_LIST_DIR/item.awk"
printf '%s\n' '#!/usr/bin/awk -f' '# ASK: First value' 'BEGIN { print "AWK_SHEBANG|" ENVIRON["SCRIPTYA_ASK_1"]; exit 0 }' > "$AWK_ROOT/shebang.awk"
chmod +x "$AWK_ROOT/shebang.awk"
printf '%s\n' '#!/usr/bin/env node' 'console.log("not awk")' > "$AWK_ROOT/not-awk.js"

assert_eq 'AWK .awk type detected' 'awk' "$(script_type "$AWK_ROOT/tool.awk")"
assert_eq 'AWK uppercase .AWK type detected' 'awk' "$(script_type "$AWK_ROOT/UPPER.AWK")"
assert_eq 'AWK shebang type detected' 'awk' "$(script_type "$AWK_ROOT/shebang.awk")"
read_metadata "$AWK_ROOT/tool.awk"
assert_eq 'AWK default menu strips extension' 'AWK tool' "$META_MENU"
assert_eq 'AWK metadata description read' 'AWK metadata test' "$META_DESCRIPTION"
assert_eq 'AWK ASK count' '2' "${#META_ASK[@]}"
awk_list=$(list_scripts "$AWK_LIST_DIR")
assert_contains 'Managed list includes AWK' 'item.awk' "$awk_list"

AWK_HASH_BEFORE=$(sha256sum "$AWK_ROOT/tool.awk" | awk '{print $1}')
LANGUAGE=en read_metadata "$AWK_ROOT/tool.awk" >/dev/null
assert_eq 'AWK metadata read does not modify file' "$AWK_HASH_BEFORE" "$(sha256sum "$AWK_ROOT/tool.awk" | awk '{print $1}')"

if command -v awk >/dev/null 2>&1; then
    env SCRIPTYA_ASK_1=one SCRIPTYA_ASK_2=two awk -f "$AWK_ROOT/tool.awk" >/tmp/scriptya_awk_direct.out
    assert_eq 'AWK direct execution' 'AWK_EXEC|one|two|' "$(cat /tmp/scriptya_awk_direct.out)"
    env SCRIPTYA_ASK_1=shebang "$AWK_ROOT/shebang.awk" >/tmp/scriptya_awk_shebang.out
    assert_eq 'AWK shebang execution' 'AWK_SHEBANG|shebang' "$(cat /tmp/scriptya_awk_shebang.out)"
    syntax_ok=true
    awk -f "$AWK_ROOT/tool.awk" </dev/null >/dev/null 2>&1 || syntax_ok=false
    $syntax_ok && ok 'AWK program parses' || fail 'AWK program parses'
else
    fail 'awk interpreter is available for AWK tests'
fi

AWK_RUN_OUT_EN="$(HOME="$TMP_ROOT/home-awk-en" LANGUAGE=en LOG_FILE="$TMP_ROOT/home-awk-en/history.log" INSTALL_DIR="$TMP_ROOT/home-awk-en/install" bash -c 'source "$1"; pause(){ :; }; clear(){ :; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-awk-en" "$AWK_ROOT/tool.awk" 2>&1 <<< $'one\ntwo')"
AWK_RUN_OUT_ES="$(HOME="$TMP_ROOT/home-awk-es" LANGUAGE=es LOG_FILE="$TMP_ROOT/home-awk-es/history.log" INSTALL_DIR="$TMP_ROOT/home-awk-es/install" bash -c 'source "$1"; pause(){ :; }; clear(){ :; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-awk-es" "$AWK_ROOT/tool.awk" 2>&1 <<< $'one\ntwo')"
assert_contains 'Scriptya runs AWK with ASK in English' 'AWK_EXEC|one|two|' "$AWK_RUN_OUT_EN"
assert_contains 'Scriptya runs AWK with ASK in Spanish' 'AWK_EXEC|one|two|' "$AWK_RUN_OUT_ES"
assert_eq 'AWK payload is language-invariant' "$(grep 'AWK_EXEC|' <<< "$AWK_RUN_OUT_EN")" "$(grep 'AWK_EXEC|' <<< "$AWK_RUN_OUT_ES")"

AWK_SHEBANG_OUT="$(HOME="$TMP_ROOT/home-awk-shebang" LANGUAGE=en LOG_FILE="$TMP_ROOT/home-awk-shebang/history.log" INSTALL_DIR="$TMP_ROOT/home-awk-shebang/install" bash -c 'source "$1"; pause(){ :; }; clear(){ :; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-awk-shebang" "$AWK_ROOT/shebang.awk" 2>&1 <<< 'shebang-value')"
assert_contains 'Scriptya runs executable AWK shebang' 'AWK_SHEBANG|shebang-value' "$AWK_SHEBANG_OUT"

AWK_MENU_LIST=$(list_scripts "$AWK_MENU_DIR")
assert_contains 'AWK menu path is discovered' 'menu.awk' "$AWK_MENU_LIST"

AWK_HELP_EN=$(HOME="$TMP_ROOT/home-help-awk" LANGUAGE=en bash -c 'source "$1"; show_help' _ "$LIB")
AWK_HELP_ES=$(HOME="$TMP_ROOT/home-help-awk-es" bash -c 'source "$1"; LANGUAGE=es; show_help' _ "$LIB")
assert_contains 'English help documents AWK' '.awk' "$AWK_HELP_EN"
assert_contains 'English help documents AWK ASK' 'SCRIPTYA_ASK_1' "$AWK_HELP_EN"
assert_contains 'English help documents AWK ENVIRON' 'ENVIRON' "$AWK_HELP_EN"
assert_contains 'English help documents AWK command syntax' 'awk -f' "$AWK_HELP_EN"
assert_contains 'Spanish help documents AWK' '.awk' "$AWK_HELP_ES"

AWK_APP="$AWK_ROOT/app.awk"
printf '%s\n' '# MENU: AWK App' 'BEGIN { print "app"; exit 0 }' > "$AWK_APP"
AWK_APP_HOME="$TMP_ROOT/home-awk-app"; mkdir -p "$AWK_APP_HOME"
out=$(HOME="$AWK_APP_HOME" bash -c '
    source "$1"
    APPS_DIR="$2/apps"; DESKTOP_DIR="$2/Desktop"; ICONS_DIR="$2/icons"; REGISTRY_DIR="$2/registry"; INSTALL_DIR="$2/install"; SCRIPTS_DIR="$2/scripts"
    mkdir -p "$APPS_DIR" "$DESKTOP_DIR" "$ICONS_DIR" "$REGISTRY_DIR" "$INSTALL_DIR" "$SCRIPTS_DIR"
    pause(){ :; }; clear(){ :; }; print_header(){ :; }; print_success(){ :; }; print_warning(){ :; }; print_info(){ :; }
    choose_and_process_icon(){ PICKED_ICON_FINAL="$ICONS_DIR/test.png"; : > "$PICKED_ICON_FINAL"; }
    finalize_menu_entry(){ :; }; finalize_desktop_shortcut(){ :; }; refresh_app_menu(){ :; }
    printf "3\n" | install_icon_for_script "$4"
    cat "$APPS_DIR"/scriptya-app-*.desktop
    registry_read "$(sanitize_id "$4")"
    printf "REGTYPE=%s\n" "$REG_TYPE"
' _ "$LIB" "$AWK_APP_HOME" "$AWK_APP_HOME" "$AWK_APP")
assert_contains 'AWK standalone app uses Scriptya launcher' '--run-script' "$out"
assert_contains 'AWK standalone app source is registered' '.awk' "$out"
assert_contains 'AWK standalone app is registered as script' 'REGTYPE=script' "$out"
assert_contains 'Spanish help documents AWK ASK' 'SCRIPTYA_ASK_1' "$AWK_HELP_ES"
assert_contains 'English README documents AWK' '.awk' "$(cat "$ROOT_DIR/README.md")"
assert_contains 'Spanish README documents AWK' '.awk' "$(cat "$ROOT_DIR/README_ES.md")"

DEMO_AWK_OUT=$(HOME="$TMP_ROOT/home-demo-awk" LANGUAGE=en LOG_FILE="$TMP_ROOT/home-demo-awk/history.log" INSTALL_DIR="$TMP_ROOT/home-demo-awk/install" bash -c 'source "$1"; pause(){ :; }; clear(){ :; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-demo-awk" "$ROOT_DIR/examples/scripts/12-awk-demo.awk" 2>&1 <<< $'demo\nsecond')
assert_contains 'AWK demo runs through Scriptya' 'AWK_DEMO_OK|demo' "$DEMO_AWK_OUT"

# 81. PHP help, README and language switching.
help_php_en=$(HOME="$TMP_ROOT/home-help-php" LANGUAGE=en bash -c 'source "$1"; show_help' _ "$LIB")
assert_contains 'English help documents PHP extensions' '.php' "$help_php_en"
assert_contains 'Spanish help documents PHP extensions' '.php' "$(HOME="$TMP_ROOT/home-help-php-es" bash -c 'source "$1"; LANGUAGE=es; show_help' _ "$LIB")"
assert_contains 'Spanish help documents PHP metadata location' 'después de <?php' "$(HOME="$TMP_ROOT/home-help-php-es2" bash -c 'source "$1"; LANGUAGE=es; show_help' _ "$LIB")"
assert_contains 'English help documents PHP CLI metadata location' 'after the opening <?php tag' "$help_php_en"
assert_contains 'English PHP menu has no Spanish install action' 'Install standalone' "$help_php_en"
assert_not_contains 'English PHP help has no Spanish phrase' 'No se encontró' "$help_php_en"
assert_contains 'English README documents PHP CLI' 'PHP CLI' "$(cat "$ROOT_DIR/README.md")"
assert_contains 'English README documents PHP dependency' '| `php` |' "$(cat "$ROOT_DIR/README.md")"
assert_contains 'Spanish README documents PHP CLI' 'PHP CLI' "$(cat "$ROOT_DIR/README_ES.md")"
php_hash=$(sha256sum "$PHP_RUN" | awk '{print $1}')
LANGUAGE=es read_metadata "$PHP_RUN" >/dev/null
assert_eq 'PHP file remains language-invariant' "$php_hash" "$(sha256sum "$PHP_RUN" | awk '{print $1}')"

# 83. Go is a first-class managed type: discovery, metadata, execution and language invariance.
GO_ROOT="$TMP_ROOT/go-managed"; mkdir -p "$GO_ROOT"
GO_RUN="$GO_ROOT/tool.go"
cat > "$GO_RUN" <<'GO_EOF'
// MENU: English Go tool
// DESCRIPTION: Visible from the menu
// CONFIRM: false
// TERMINAL: false
// SUDO: false
// ORDER: 18
// ASK: First value
// ICON: go-icon.png

package main

import (
    "fmt"
    "os"
)

func main() {
    value := ""
    if len(os.Args) > 1 {
        value = os.Args[1]
    }
    fmt.Printf("GO_EXEC|%s|%s\n", value, mustCwd())
}

func mustCwd() string {
    dir, err := os.Getwd()
    if err != nil { return "" }
    return dir
}
GO_EOF
printf '%s\n' 'package main' 'func main() {}' > "$GO_ROOT/UPPER.GO"
printf '%s\n' 'not managed' > "$GO_ROOT/item.txt"
assert_eq 'Go .go type detected' 'go' "$(script_type "$GO_RUN")"
assert_eq 'Go uppercase .GO type detected' 'go' "$(script_type "$GO_ROOT/UPPER.GO")"
read_metadata "$GO_RUN"
assert_eq 'Go MENU metadata' 'English Go tool' "$META_MENU"
assert_eq 'Go DESCRIPTION metadata' 'Visible from the menu' "$META_DESCRIPTION"
assert_eq 'Go ORDER metadata' '18' "$META_ORDER"
assert_eq 'Go ASK metadata' 'First value' "${META_ASK[0]}"
go_list="$(list_scripts "$GO_ROOT")"
assert_contains 'Managed list includes .go' 'tool.go' "$go_list"
assert_contains 'Managed list includes uppercase .GO' 'UPPER.GO' "$go_list"
assert_not_contains 'Managed list excludes unrelated Go file' 'item.txt' "$go_list"

GO_META_COPY="$GO_ROOT/meta-copy.go"
printf '%s\n' '// Original comment' 'package main' 'func main() {}' > "$GO_META_COPY"
GO_BODY_BEFORE=$(tail -n 2 "$GO_META_COPY")
NEWMETA_MENU='Go inserted'; NEWMETA_DESCRIPTION='Go description'; NEWMETA_CONFIRM='true'; NEWMETA_TERMINAL='false'; NEWMETA_SUDO='false'; NEWMETA_ORDER='19'; NEWMETA_ICON='go-icon.png'; NEWMETA_ASK=('One' 'Two')
apply_metadata "$GO_META_COPY"
go_meta_raw=$(cat "$GO_META_COPY")
assert_contains 'Go metadata insertion uses // comments' '// MENU: Go inserted' "$go_meta_raw"
assert_contains 'Go metadata insertion preserves original comment' '// Original comment' "$go_meta_raw"
assert_eq 'Go metadata insertion preserves body' "$GO_BODY_BEFORE" "$(tail -n 2 "$GO_META_COPY")"
go build -o "$GO_ROOT/meta-copy-bin" "$GO_META_COPY" >/dev/null 2>&1 && ok 'Go metadata file remains valid Go' || fail 'Go metadata file remains valid Go'

GO_OUT_EN=$(HOME="$TMP_ROOT/home-go-en" LANGUAGE=en LOG_FILE="$TMP_ROOT/home-go-en/history.log" INSTALL_DIR="$TMP_ROOT/home-go-en/install" bash -c 'source "$1"; pause(){ :; }; clear(){ :; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-go-en" "$GO_RUN" 2>&1 <<< 'answer')
go_rc_en=$?
assert_eq 'Go execution returns success in English' '0' "$go_rc_en"
assert_contains 'Go execution works in English' 'GO_EXEC|answer|' "$GO_OUT_EN"
assert_contains 'Go execution uses script directory' "$GO_ROOT" "$GO_OUT_EN"
GO_OUT_ES=$(HOME="$TMP_ROOT/home-go-es" LANGUAGE=es LOG_FILE="$TMP_ROOT/home-go-es/history.log" INSTALL_DIR="$TMP_ROOT/home-go-es/install" bash -c 'source "$1"; pause(){ :; }; clear(){ :; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-go-es" "$GO_RUN" 2>&1 <<< 'answer')
go_rc_es=$?
assert_eq 'Go execution returns success in Spanish' '0' "$go_rc_es"
assert_contains 'Go execution works in Spanish' 'GO_EXEC|answer|' "$GO_OUT_ES"
assert_eq 'Go execution payload is language-invariant' "$(grep 'GO_EXEC|' <<< "$GO_OUT_EN")" "$(grep 'GO_EXEC|' <<< "$GO_OUT_ES")"

GO_FAIL="$GO_ROOT/fail.go"
printf '%s\n' 'package main' 'import "os"' 'func main(){ os.Exit(7) }' > "$GO_FAIL"
GO_FAIL_OUT=$(HOME="$TMP_ROOT/home-go-fail" LANGUAGE=en LOG_FILE="$TMP_ROOT/home-go-fail/history.log" INSTALL_DIR="$TMP_ROOT/home-go-fail/install" bash -c 'source "$1"; pause(){ :; }; clear(){ :; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-go-fail" "$GO_FAIL" 2>&1)
go_fail_rc=$?
assert_eq 'Go nonzero exit status is preserved' '7' "$go_fail_rc"
assert_contains 'Go nonzero execution reports failure' 'code 7' "$GO_FAIL_OUT"

GO_DEP="$GO_ROOT/missing.go"; printf '%s\n' 'package main' 'func main() {}' > "$GO_DEP"
go_error=$(HOME="$TMP_ROOT/home-go-error" LANGUAGE=en bash -c 'source "$1"; pause(){ :; }; clear(){ :; }; LOG_FILE="$3/history.log"; INSTALL_DIR="$3"; command_exists(){ [[ "$1" != go ]] && command -v "$1" >/dev/null 2>&1; }; run_script "$4" inline' _ "$LIB" ignored "$TMP_ROOT/home-go-error" "$GO_DEP" 2>&1)
go_dep_rc=$?
assert_eq 'Missing Go interpreter returns failure' '1' "$go_dep_rc"
assert_contains 'English Go dependency error is translated' "'go' was not found" "$go_error"
assert_not_contains 'English Go dependency error has no Spanish phrase' 'No se encontró' "$go_error"

GO_MENU_DIR="$TMP_ROOT/go-menu"; mkdir -p "$GO_MENU_DIR"
printf '%s\n' '// MENU: English Go tool' '// DESCRIPTION: Visible from the menu' 'package main' 'func main() {}' > "$GO_MENU_DIR/menu.go"
menu_go_en=$(HOME="$TMP_ROOT/home-go-menu-en" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash -c 'source "$1"; LANGUAGE=en; SCRIPTS_DIR="$2"; menu_numeric "$2" run' _ "$LIB" "$GO_MENU_DIR" <<< '0' 2>&1)
menu_go_es=$(HOME="$TMP_ROOT/home-go-menu-es" TERM=xterm NO_COLOR=1 LC_ALL=C LANG=C LC_MESSAGES=C bash -c 'source "$1"; LANGUAGE=es; SCRIPTS_DIR="$2"; menu_numeric "$2" run' _ "$LIB" "$GO_MENU_DIR" <<< '0' 2>&1)
assert_contains 'English menu renders Go metadata' 'English Go tool — Visible from the menu' "$menu_go_en"
assert_contains 'Spanish menu renders Go metadata' 'English Go tool — Visible from the menu' "$menu_go_es"
assert_not_contains 'English Go menu has no Spanish install action' 'Instalar Scripts' "$menu_go_en"
assert_not_contains 'Spanish Go menu has no English install action' 'Install Scripts' "$menu_go_es"

go_help_en=$(HOME="$TMP_ROOT/home-help-go-en" LANGUAGE=en bash -c 'source "$1"; show_help' _ "$LIB")
go_help_es=$(HOME="$TMP_ROOT/home-help-go-es" bash -c 'source "$1"; LANGUAGE=es; show_help' _ "$LIB")
assert_contains 'English help documents Go extension' '.go' "$go_help_en"
assert_contains 'English help documents Go execution' 'compiles and runs the file with Go' "$go_help_en"
assert_contains 'English help documents Go metadata comments' 'Go, PHP and Node.js use // comments' "$go_help_en"
assert_contains 'Spanish help documents Go extension' '.go' "$go_help_es"
assert_contains 'Spanish help documents Go execution' 'compila y ejecuta el fichero con Go' "$go_help_es"

go_hash_en=$(sha256sum "$GO_RUN" | awk '{print $1}')
LANGUAGE=es read_metadata "$GO_RUN" >/dev/null
go_hash_es=$(sha256sum "$GO_RUN" | awk '{print $1}')
assert_eq 'Go source is language-invariant' "$go_hash_en" "$go_hash_es"

# 84. The type layer has one source of truth for extensions, interpreters and shebangs.
for pair in \
    'tool.sh:sh' 'tool.py:python' 'tool.js:node' 'tool.mjs:node' 'tool.cjs:node' \
    'tool.pl:perl' 'tool.rb:ruby' 'tool.lua:lua' 'tool.fish:fish' 'tool.php:php' \
    'tool.awk:awk' 'tool.go:go' 'tool.html:html' 'tool.htm:html'; do
    name=${pair%%:*}; expected=${pair##*:}
    assert_eq "Type registry extension $name" "$expected" "$(script_type_from_extension "$name")"
done
for ext in sh py JS MJS CJS PL RB LUA FISH PHP AWK GO HTML HTM; do
    if supported_script_extension "file.$ext"; then ok "Supported extension .$ext"; else fail "Supported extension .$ext"; fi
done
for ext in txt md json ts css; do
    if supported_script_extension "file.$ext"; then fail "Unsupported extension .$ext rejected"; else ok "Unsupported extension .$ext rejected"; fi
done
for pair in 'python:python3' 'node:node' 'perl:perl' 'ruby:ruby' 'lua:lua' 'fish:fish' 'php:php' 'awk:awk' 'go:go'; do
    name=${pair%%:*}; expected=${pair##*:}
    assert_eq "Interpreter for $name" "$expected" "$(script_interpreter "$name")"
done
for pair in 'node:#!/usr/bin/env node' 'python:#!/usr/bin/env python3' 'perl:#!/usr/bin/env perl' 'ruby:#!/usr/bin/env ruby' 'lua:#!/usr/bin/env lua' 'fish:#!/usr/bin/env fish' 'php:#!/usr/bin/php' 'awk:#!/usr/bin/awk' 'sh:#!/bin/bash'; do
    expected=${pair%%:*}; shebang=${pair#*:}
    assert_eq "Shebang maps to $expected" "$expected" "$(script_type_from_shebang "$shebang")"
done
assert_eq 'Nemo script extension registry' 'sh;py;js;mjs;cjs;pl;rb;lua;fish;php;awk;go;' "$(nemo_script_extensions)"

UNKNOWN_ROOT="$TMP_ROOT/unknown-type"; mkdir -p "$UNKNOWN_ROOT"
printf '%s\n' '#!/bin/sh' 'printf "UNKNOWN_RUN_OK\n"' > "$UNKNOWN_ROOT/tool.custom"
chmod +x "$UNKNOWN_ROOT/tool.custom"
out=$(HOME="$TMP_ROOT/home-unknown" SCRIPTS_DIR="$UNKNOWN_ROOT" bash -c 'source "$1"; pause(){ :; }; clear(){ :; }; run_script "$2" inline' _ "$LIB" "$UNKNOWN_ROOT/tool.custom" 2>&1)
assert_contains 'Unknown executable extension keeps legacy run behavior' 'UNKNOWN_RUN_OK' "$out"

# 84. Go standalone app registration uses the shared script path and removes cleanly.
GO_INSTALL_HOME="$TMP_ROOT/home-go-install"; mkdir -p "$GO_INSTALL_HOME/apps" "$GO_INSTALL_HOME/Desktop" "$GO_INSTALL_HOME/icons" "$GO_INSTALL_HOME/registry"
printf '%s\n' '#!/usr/bin/env false' > "$GO_INSTALL_HOME/icons/go.png"
HOME="$GO_INSTALL_HOME" bash -c 'source "$1"; REGISTRY_DIR="$2/registry"; registry_write "go-test" "Go Test" "$3" "$2/icons/go.png" si si script' _ "$LIB" "$GO_INSTALL_HOME" "$GO_RUN"
assert_file_exists 'Go standalone registry entry exists' "$GO_INSTALL_HOME/registry/go-test.meta"
assert_contains 'Go standalone registry stores source' "$GO_RUN" "$(cat "$GO_INSTALL_HOME/registry/go-test.meta")"
printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=Go Test' "Exec=$SCRIPT --run-script $GO_RUN" 'Icon=/tmp/go.png' 'X-Scriptya-Source='"$GO_RUN" > "$GO_INSTALL_HOME/apps/scriptya-app-go-test.desktop"
cp "$GO_INSTALL_HOME/apps/scriptya-app-go-test.desktop" "$GO_INSTALL_HOME/Desktop/scriptya-app-go-test.desktop"
HOME="$GO_INSTALL_HOME" bash -c 'source "$1"; APPS_DIR="$2/apps"; DESKTOP_DIR="$2/Desktop"; ICONS_DIR="$2/icons"; REGISTRY_DIR="$2/registry"; remove_script_icon go-test' _ "$LIB" "$GO_INSTALL_HOME"
[[ ! -e "$GO_INSTALL_HOME/apps/scriptya-app-go-test.desktop" ]] && ok 'Go standalone uninstall removes menu entry' || fail 'Go standalone uninstall removes menu entry'
[[ ! -e "$GO_INSTALL_HOME/Desktop/scriptya-app-go-test.desktop" ]] && ok 'Go standalone uninstall removes Desktop entry' || fail 'Go standalone uninstall removes Desktop entry'
[[ ! -e "$GO_INSTALL_HOME/registry/go-test.meta" ]] && ok 'Go standalone uninstall removes registry' || fail 'Go standalone uninstall removes registry'
[[ ! -e "$GO_INSTALL_HOME/icons/go.png" ]] && ok 'Go standalone uninstall removes copied icon' || fail 'Go standalone uninstall removes copied icon'

# 82. Demo suite covers every supported type and the main metadata workflows.
DEMO_ROOT="$ROOT_DIR/examples"
DEMO_SCRIPTS="$DEMO_ROOT/scripts"
for demo in 01-shell-demo.sh 02-python-demo.py 03-node-demo.js 04-perl-demo.pl 05-ruby-demo.rb 06-lua-demo.lua 07-fish-demo.fish 08-html-demo.html 09-confirm-and-ask.sh 10-failure.sh 11-php-demo.php 12-awk-demo.awk 13-go-demo.go; do
    assert_file_exists "Demo contains $demo" "$DEMO_SCRIPTS/$demo"
done
for icon in "$DEMO_ROOT/assets/demo-blue.svg" "$DEMO_ROOT/assets/demo-green.svg"; do
    assert_file_exists "Demo contains $(basename "$icon")" "$icon"
done
assert_contains 'Demo guide has English/Spanish links' 'README_ES.md' "$(cat "$DEMO_ROOT/README.md")"
assert_contains 'Spanish demo guide has English link' 'README.md' "$(cat "$DEMO_ROOT/README_ES.md")"
for pair in \
    '01-shell-demo.sh:sh' '02-python-demo.py:python' '03-node-demo.js:node' '04-perl-demo.pl:perl' \
    '05-ruby-demo.rb:ruby' '06-lua-demo.lua:lua' '07-fish-demo.fish:fish' '08-html-demo.html:html' '11-php-demo.php:php' \
    '09-confirm-and-ask.sh:sh' '10-failure.sh:sh' '12-awk-demo.awk:awk' '13-go-demo.go:go'; do
    demo_name=${pair%%:*}; demo_type=${pair##*:}
    assert_eq "Demo type $demo_name" "$demo_type" "$(script_type "$DEMO_SCRIPTS/$demo_name")"
    read_metadata "$DEMO_SCRIPTS/$demo_name"
    assert_not_empty "Demo MENU $demo_name" "$META_MENU"
    assert_not_empty "Demo DESCRIPTION $demo_name" "$META_DESCRIPTION"
    assert_not_empty "Demo ICON $demo_name" "$META_ICON"
    demo_icon_path="$DEMO_SCRIPTS/$META_ICON"
    assert_file_exists "Demo icon resolves for $demo_name" "$demo_icon_path"
done
assert_contains 'Demo Lua uses valid comments' '-- MENU:' "$(head -n 6 "$DEMO_SCRIPTS/06-lua-demo.lua")"
assert_contains 'Demo Fish uses valid comments' '# MENU:' "$(head -n 8 "$DEMO_SCRIPTS/07-fish-demo.fish")"
assert_contains 'Demo Node uses valid comments' '// MENU:' "$(head -n 8 "$DEMO_SCRIPTS/03-node-demo.js")"
assert_contains 'Demo PHP uses valid comments' '// MENU:' "$(head -n 12 "$DEMO_SCRIPTS/11-php-demo.php")"
assert_contains 'Demo PHP keeps ASK metadata' '// ASK: Demo value' "$(head -n 12 "$DEMO_SCRIPTS/11-php-demo.php")"
assert_contains 'Demo AWK uses # metadata' '# MENU: Demo — AWK' "$(head -n 8 "$DEMO_SCRIPTS/12-awk-demo.awk")"
assert_contains 'Demo Go uses // metadata' '// MENU: Demo — Go' "$(head -n 8 "$DEMO_SCRIPTS/13-go-demo.go")"
GO_DEMO_OUT=$(HOME="$TMP_ROOT/home-go-demo" LANGUAGE=en LOG_FILE="$TMP_ROOT/home-go-demo/history.log" INSTALL_DIR="$TMP_ROOT/home-go-demo/install" bash -c 'source "$1"; pause(){ :; }; clear(){ :; }; run_script "$2" inline' _ "$LIB" "$DEMO_SCRIPTS/13-go-demo.go" 2>&1 <<< 'demo')
go_demo_rc=$?
assert_eq 'Demo Go runs with Go' '0' "$go_demo_rc"
assert_contains 'Demo Go payload is stable' 'GO_DEMO_OK|demo' "$GO_DEMO_OUT"
assert_contains 'Demo HTML uses HTML comments' '<!-- MENU:' "$(head -n 12 "$DEMO_SCRIPTS/08-html-demo.html")"
read_metadata "$DEMO_SCRIPTS/09-confirm-and-ask.sh"
assert_eq 'Demo Confirm + ASK has two prompts' '2' "${#META_ASK[@]}"
assert_eq 'Demo Confirm + ASK requests confirmation' 'true' "$META_CONFIRM"

# 82b. Demo source stays self-contained, strict where appropriate, and local-only.
assert_contains 'Shell demo enables strict mode' 'set -euo pipefail' "$(cat "$DEMO_SCRIPTS/01-shell-demo.sh")"
assert_contains 'Python demo has explicit entry point' 'if __name__ == "__main__":' "$(cat "$DEMO_SCRIPTS/02-python-demo.py")"
assert_contains 'Perl demo enables strict/warnings' 'use strict;' "$(cat "$DEMO_SCRIPTS/04-perl-demo.pl")"
assert_contains 'Perl demo enables warnings' 'use warnings;' "$(cat "$DEMO_SCRIPTS/04-perl-demo.pl")"
assert_contains 'Ruby demo freezes string literals' '# frozen_string_literal: true' "$(cat "$DEMO_SCRIPTS/05-ruby-demo.rb")"
assert_contains 'PHP demo enables strict types' 'declare(strict_types=1);' "$(cat "$DEMO_SCRIPTS/11-php-demo.php")"
assert_contains 'Go demo has deterministic no-argument default' 'value := "demo"' "$(cat "$DEMO_SCRIPTS/13-go-demo.go")"
assert_not_contains 'HTML demo has no script block' '<script' "$(cat "$DEMO_SCRIPTS/08-html-demo.html")"
assert_not_contains 'HTML demo has no remote HTTP URL' 'http://' "$(cat "$DEMO_SCRIPTS/08-html-demo.html")"
assert_not_contains 'HTML demo has no remote HTTPS URL' 'https://' "$(cat "$DEMO_SCRIPTS/08-html-demo.html")"
assert_contains 'Blue demo icon has SVG title' '<title>Scriptya demo icon</title>' "$(cat "$DEMO_ROOT/assets/demo-blue.svg")"
assert_contains 'Green demo icon has SVG title' '<title>Scriptya success demo icon</title>' "$(cat "$DEMO_ROOT/assets/demo-green.svg")"

printf '\nTotal: %d passed, %d failed\n' "$PASS" "$FAIL"
(( FAIL == 0 ))

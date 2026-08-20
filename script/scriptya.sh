#!/bin/bash
#
# Copyright (C) 2026 Filonux
#
# Licencia:
#   Scriptya es software libre distribuido bajo los términos de la
#   GNU General Public License versión 3 (GPLv3).
#   Consulte el archivo LICENSE para obtener el texto completo de la
#   licencia.
#
# ------------------------------------------------------------------
# scriptya.sh
# ------------------------------------------------------------------
# Menú para ejecutar tus scripts personales, organizados en carpetas.
#
# Autor: Filonux
#
# Uso:
#   ./scriptya.sh              Abre el menú de scripts. Desde la
#                                     raíz del menú también puedes elegir
#                                     directamente "Instalar Scripts",
#                                     "Desinstalar Scripts" (ver abajo),
#                                     "Buscar Scripts" (para cambiar la
#                                     carpeta de scripts con el selector
#                                     de carpetas del sistema), "Cambiar
#                                     Icono" (el de Scriptya, el de un
#                                     script instalado, o el de
#                                     cualquier otro programa del
#                                     sistema) o "Ver Historial"
#                                     (últimas ejecuciones).
#   ./scriptya.sh --desktop    Crea un acceso directo .desktop
#                                     que ejecuta ESTE fichero tal cual
#                                     está, sin instalar nada
#   ./scriptya.sh --install    Instala en el sistema (comando
#                                     "scriptya", config, etc.)
#   ./scriptya.sh --icons      Instala scripts sueltos como si
#                                     fueran aplicaciones independientes
#                                     (menú de Cinnamon y/o Escritorio),
#                                     con icono personalizado. Es el
#                                     mismo asistente que "Instalar
#                                     Scripts" dentro del menú.
#   ./scriptya.sh --uninstall-icons
#                                     Ver / desinstalar scripts instalados
#                                     con --icons o "Instalar Scripts"
#                                     (uno, varios o todos)
#   ./scriptya.sh --uninstall  Desinstala lo creado por --install
#   ./scriptya.sh --update     Actualiza la copia instalada con
#                                     esta versión del fichero, sin
#                                     repetir el asistente de --install
#   ./scriptya.sh --help       Ayuda
#
# Metadatos opcionales dentro de cada script gestionado (van en las
# primeras líneas, como comentarios, justo tras el shebang):
#
#   #!/bin/bash
#   # MENU: Nombre bonito en el menú
#   # DESCRIPTION: Descripción corta
#   # CONFIRM: true|false     -> pide confirmación antes de ejecutar
#   # TERMINAL: true|false    -> lo abre en una terminal nueva (y avisa
#                                 con una notificación de escritorio
#                                 al terminar, si hay 'notify-send')
#   # SUDO: true|false        -> lo ejecuta con sudo
#   # ORDER: número           -> controla el orden en el menú (menor
#                                 aparece antes). Por defecto 500. Los
#                                 scripts sin ORDER se ordenan entre sí
#                                 alfabéticamente. Alternativa: nombrar
#                                 los ficheros con prefijo numérico
#                                 (01_backup.sh, 02_limpiar.sh), que ya
#                                 se respeta sin necesidad de ORDER.
#   # ASK: mensaje            -> antes de ejecutar, pide ese dato por
#                                 teclado y se lo pasa al script como
#                                 argumento posicional ($1, $2...).
#                                 Se puede repetir varias veces para
#                                 pedir varios datos, en orden.
#   # ICON: ruta/al/icono.png -> icono a usar con --icons (también
#                                 admite el nombre de un icono del
#                                 tema del sistema, p.ej. utilities-terminal)
#                                 Si no se indica, el asistente de
#                                 --icons deja elegir la imagen
#                                 navegando por carpetas, y la ajusta
#                                 automáticamente de tamaño y
#                                 transparencia (requiere ImageMagick)
#
# Todos los campos son opcionales. Si faltan, se usan valores por
# defecto razonables (nombre del fichero, sin confirmación, sin
# terminal nueva, sin sudo, orden alfabético, sin parámetros, icono
# genérico).
#
# Cada ejecución queda registrada en
# ~/.local/share/scriptya/history.log (fecha, resultado y
# script).
#
# Si tienes instalado 'fzf' se usará automáticamente un buscador
# interactivo; si no, se usa un menú numerado clásico en el que
# también puedes escribir texto para filtrar la lista por nombre.
# ------------------------------------------------------------------

set -uo pipefail

SY_VERSION="2.1.0"
SY_AUTHOR="Filonux"
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"

# Sin este trap, un Ctrl+C durante pause() (que lee con "read -s") mata
# el proceso sin restaurar el eco del terminal.
trap 'stty sane 2>/dev/null; echo; exit 130' INT

# get_desktop_dir -> ruta real del Escritorio del usuario. En sistemas
# en español (y otros idiomas) NO se llama "$HOME/Desktop" sino algo
# como "$HOME/Escritorio", según defina xdg-user-dirs. Usar siempre
# "$HOME/Desktop" a pelo hacía que los accesos directos se crearan en
# una carpeta que Nemo/Cinnamon nunca muestra como escritorio: parecía
# que "no se creaban" cuando en realidad se creaban en el sitio
# equivocado. xdg-user-dir viene instalado de serie en Linux Mint.
get_desktop_dir() {
    local d=""
    if command -v xdg-user-dir >/dev/null 2>&1; then
        d="$(xdg-user-dir DESKTOP 2>/dev/null)"
    fi
    [[ -z "$d" ]] && d="$HOME/Desktop"
    echo "$d"
}

# ============================================================
# RUTAS DE CONFIGURACIÓN / INSTALACIÓN
# ============================================================
CONFIG_DIR="$HOME/.config/scriptya"
CONFIG_FILE="$CONFIG_DIR/config.conf"

INSTALL_DIR="$HOME/.local/share/scriptya"
ICONS_DIR="$INSTALL_DIR/icons"
REGISTRY_DIR="$INSTALL_DIR/registry"
LOG_FILE="$INSTALL_DIR/history.log"
BIN_DIR="$HOME/.local/bin"
BIN_LINK="$BIN_DIR/scriptya"

APPS_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$APPS_DIR/scriptya.desktop"
DESKTOP_DIR="$(get_desktop_dir)"
DESKTOP_SHORTCUT="$DESKTOP_DIR/scriptya.desktop"

# Valores por defecto (pueden sobreescribirse en config.conf)
SCRIPTS_DIR="$HOME/Scripts"
TERMINAL="x-terminal-emulator"
SY_ICON="utilities-terminal"

# ============================================================
# COLORES / UTILIDADES DE PANTALLA
# ============================================================
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RESET="\033[0m"; C_BOLD="\033[1m"; C_DIM="\033[2m"
    C_RED="\033[31m"; C_GREEN="\033[32m"; C_YELLOW="\033[33m"; C_CYAN="\033[36m"
else
    C_RESET=""; C_BOLD=""; C_DIM=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_CYAN=""
fi

# hline [caracter] [ancho] -> línea horizontal repitiendo un carácter
# (por defecto "-" a 44 columnas), usada por print_header y los
# separadores de pantalla. Evita repetir la misma construcción con
# 'seq' en varios sitios del script.
hline() {
    local ch="${1:--}" width="${2:-44}"
    printf "%${width}s" "" | tr ' ' "$ch"
}

print_header() {
    local title="$1" width=44
    local line; line="$(hline '=' "$width")"
    local pad=$(( (width - ${#title}) / 2 ))
    (( pad < 0 )) && pad=0
    echo -e "${C_CYAN}${line}${C_RESET}"
    printf "%*s${C_BOLD}%s${C_RESET}\n" "$pad" "" "$title"
    echo -e "${C_CYAN}${line}${C_RESET}"
}

print_error()   { echo -e "${C_RED}✗ $*${C_RESET}" >&2; }
print_success() { echo -e "${C_GREEN}✓ $*${C_RESET}"; }
print_warning() { echo -e "${C_YELLOW}! $*${C_RESET}"; }
print_info()    { echo -e "${C_DIM}$*${C_RESET}"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# desktop_quote <ruta> -> imprime la ruta entre comillas dobles, con los
# caracteres especiales escapados, lista para usarse en la línea Exec=
# de un fichero .desktop. Sin esto, una ruta con espacios (p.ej. si el
# usuario tiene el script en "~/Mis Scripts/") rompe el acceso directo.
desktop_quote() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//\$/\\\$}"
    s="${s//\`/\\\`}"
    # El "%" tiene significado especial en Exec= (códigos de campo como
    # %f, %u...). Si la ruta lo contiene literalmente, hay que duplicarlo.
    s="${s//%/%%}"
    printf '"%s"' "$s"
}

# refresh_app_menu -> refresca la caché del menú de aplicaciones tras
# crear/borrar un .desktop en $APPS_DIR, si 'update-desktop-database'
# está instalado.
refresh_app_menu() {
    command_exists update-desktop-database && update-desktop-database "$APPS_DIR" 2>/dev/null
    return 0
}

# finalize_menu_entry <ruta.desktop> -> hace ejecutable una entrada del
# menú de aplicaciones y refresca la caché.
finalize_menu_entry() {
    chmod +x "$1"
    refresh_app_menu
}

# finalize_desktop_shortcut <ruta.desktop> -> hace ejecutable un acceso
# directo del Escritorio y lo marca "de confianza" con 'gio' si está
# disponible (evita el aviso de Nemo al primer doble clic).
finalize_desktop_shortcut() {
    chmod +x "$1"
    command_exists gio && gio set "$1" metadata::trusted true 2>/dev/null
    return 0
}

confirm_yn() {
    # confirm_yn "pregunta" -> 0 = sí, 1 = no (por defecto)
    local prompt="$1" answer
    read -r -p "$(echo -e "${C_YELLOW}${prompt}${C_RESET} [s/N]: ")" answer
    case "${answer,,}" in
        s|si|y|yes) return 0 ;;
    esac
    # "í" es lo único que "${var,,}" no garantiza pasar a minúscula en
    # locales sin UTF-8 bien configurado, así que sus 4 variantes de
    # mayús/minús se comprueban aparte, tal cual.
    case "$answer" in
        sí|Sí|sÍ|SÍ) return 0 ;;
    esac
    return 1
}

pause() {
    read -r -n 1 -s -p "$(echo -e "${C_DIM}Pulsa una tecla para continuar...${C_RESET}")"
    echo
}

# ============================================================
# CONFIGURACIÓN
# ============================================================
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
    fi
}

save_config() {
    mkdir -p "$CONFIG_DIR"
    # %q escapa el valor para que sea seguro de volver a leer con
    # "source": sin esto, una carpeta con comillas, "$" o backticks en
    # el nombre (posible al elegirla con el selector gráfico) rompía
    # config.conf o alteraba su significado al cargarlo.
    {
        echo "# Configuración de Scriptya"
        printf 'SCRIPTS_DIR=%q\n' "$SCRIPTS_DIR"
        printf 'TERMINAL=%q\n' "$TERMINAL"
        printf 'SY_ICON=%q\n' "$SY_ICON"
    } > "$CONFIG_FILE"
}

detect_terminal() {
    local t
    for t in x-terminal-emulator gnome-terminal xfce4-terminal mate-terminal konsole tilix alacritty xterm; do
        if command_exists "$t"; then
            echo "$t"
            return 0
        fi
    done
    echo "xterm"
}

# ============================================================
# METADATOS DE LOS SCRIPTS
# ============================================================
# read_metadata <ruta> -> rellena META_MENU, META_DESCRIPTION,
# META_CONFIRM, META_TERMINAL, META_SUDO, META_ICON, META_ORDER (número,
# 500 por defecto) y META_ASK (array, uno por cada "# ASK:" del script)
read_metadata() {
    local script="$1" base line key value
    base="$(basename "$script" .sh)"

    META_MENU="$base"
    META_DESCRIPTION=""
    META_CONFIRM="false"
    META_TERMINAL="false"
    META_SUDO="false"
    META_ICON=""
    META_ORDER="500"
    META_ASK=()

    [[ -f "$script" ]] || return 0

    while IFS= read -r line; do
        line="${line%$'\r'}"   # scripts editados en Windows (CRLF)
        [[ "$line" =~ ^#! ]] && continue
        # Las líneas en blanco (p.ej. una línea vacía de separación tras el
        # shebang, antes de los comentarios de metadatos) se ignoran sin
        # cortar el escaneo; solo una línea de código real lo interrumpe.
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^# ]] || break

        if [[ "$line" =~ ^#[[:space:]]*([A-Z]+):[[:space:]]*(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            case "$key" in
                MENU)        META_MENU="$value" ;;
                DESCRIPTION) META_DESCRIPTION="$value" ;;
                CONFIRM)     META_CONFIRM="${value,,}" ;;
                TERMINAL)    META_TERMINAL="${value,,}" ;;
                SUDO)        META_SUDO="${value,,}" ;;
                ICON)        META_ICON="$value" ;;
                ORDER)       [[ "$value" =~ ^-?[0-9]+$ ]] && META_ORDER="$value" ;;
                ASK)         META_ASK+=("$value") ;;
            esac
        fi
    done < <(head -n 20 "$script")
}

# ============================================================
# ESCANEO DE CARPETAS
# ============================================================
list_dirs() {
    find "$1" -mindepth 1 -maxdepth 1 -type d ! -name ".*" -print 2>/dev/null | sort
}

list_scripts() {
    find "$1" -mindepth 1 -maxdepth 1 -type f ! -name ".*" -name "*.sh" -print 2>/dev/null | sort
}

list_images() {
    find "$1" -mindepth 1 -maxdepth 1 -type f ! -name ".*" \
        \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.svg" \
           -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.webp" -o -iname "*.xpm" \) \
        -print 2>/dev/null | sort
}

# sorted_scripts <dir> -> como list_scripts, pero ordenando primero por
# el metadato opcional "# ORDER: n" (500 por defecto) y, a igual ORDER,
# alfabéticamente. Un prefijo numérico en el nombre del fichero
# (01_backup.sh, 02_limpiar.sh) ya funciona sin necesidad de ORDER,
# porque el criterio de desempate es el propio nombre.
sorted_scripts() {
    local dir="$1" s
    local -a raw=()
    while IFS= read -r s; do [[ -n "$s" ]] && raw+=("$s"); done < <(list_scripts "$dir")

    [[ ${#raw[@]} -eq 0 ]] && return 0

    for s in "${raw[@]}"; do
        read_metadata "$s"
        # Desplazamos ORDER a un rango siempre positivo para poder
        # ordenar como texto con zero-padding, aceptando valores
        # negativos (para forzar algo al principio del todo).
        printf '%09d\t%s\t%s\n' "$((META_ORDER + 1000000))" "$(basename "$s")" "$s"
    done | sort -t $'\t' -k1,1 -k2,2 | cut -f3-
}

# log_run <script> <status> <sudo_yn> -> añade una línea al histórico de
# ejecuciones ($LOG_FILE): fecha, código de salida, si se usó sudo y la
# ruta del script. Formato con tabuladores para poder hacer `cut`/`awk`
# sobre él fácilmente; nunca aborta el launcher si falla (por ejemplo,
# sin espacio en disco).
log_run() {
    local script="$1" status="$2" sudo_yn="$3"
    mkdir -p "$INSTALL_DIR" 2>/dev/null
    printf '%s\t%s\t%s\t%s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$status" "$sudo_yn" "$script" \
        >> "$LOG_FILE" 2>/dev/null
}

# notify_result <título> <status> -> aviso de escritorio con notify-send
# (estándar en Cinnamon) al terminar un script. Se usa sobre todo para
# TERMINAL: true, cuya ventana puede quedar oculta tras otras. Si
# notify-send no está instalado, no hace nada (no es un requisito).
notify_result() {
    command_exists notify-send || return 0
    local title="$1" status="$2"
    if [[ "$status" -eq 0 ]]; then
        notify-send -a "Scriptya" -i dialog-information \
            "$title" "Finalizado correctamente." 2>/dev/null
    else
        notify-send -a "Scriptya" -i dialog-error -u critical \
            "$title" "Terminó con código $status." 2>/dev/null
    fi
}

# rel_to_scripts_dir <ruta_absoluta> -> versión de la ruta relativa a
# $SCRIPTS_DIR, solo para mostrar en cabeceras (la ruta real que se usa
# internamente para find/cd sigue siendo siempre la absoluta). Evita
# que las cabeceras se corten en terminales estrechas cuando
# $SCRIPTS_DIR está anidado varios niveles (p.ej. dentro de un $HOME
# largo).
rel_to_scripts_dir() {
    local path="$1"
    if [[ "$path" == "$SCRIPTS_DIR" ]]; then
        echo "Inicio"
    elif [[ "$path" == "$SCRIPTS_DIR"/* ]]; then
        echo "${path#"$SCRIPTS_DIR"/}"
    else
        echo "$path"
    fi
}

# cleanup_orphaned_tmp -> borra restos de scripts temporales de una
# ejecución en terminal que se interrumpió (p.ej. Ctrl+C justo al abrir
# la ventana nueva, antes de que el propio temporal pudiera autoborrarse
# al terminar; ver run_script). Solo toca los de más de 15 minutos, para
# no arriesgarse a borrar uno que otra instancia de scriptya
# esté usando en ese preciso momento.
cleanup_orphaned_tmp() {
    find "${TMPDIR:-/tmp}" -maxdepth 1 -type f \
        -name 'scriptya.*.sh' -mmin +15 -delete 2>/dev/null
}

# ============================================================
# EJECUCIÓN DE SCRIPTS
# ============================================================
# run_and_report <script> <script_dir> <con_separador:true|false> <cmd...>
# Ejecuta <cmd...> con <script_dir> como cwd, imprime el resultado,
# registra la ejecución en el historial, notifica si el script pedía
# TERMINAL:true y hace pause(). Devuelve el código de salida de <cmd...>.
# Usa $META_SUDO/$META_MENU/$META_TERMINAL, ya rellenadas por
# read_metadata antes de llamar a run_script.
run_and_report() {
    local script="$1" script_dir="$2" con_sep="$3"
    shift 3

    if [[ ! -d "$script_dir" ]]; then
        print_error "La carpeta del script ya no existe: $script_dir"
        log_run "$script" "1" "$META_SUDO"
        pause
        return 1
    fi

    local sep=""
    if [[ "$con_sep" == "true" ]]; then
        sep="$(hline)"
        echo -e "${C_CYAN}${sep}${C_RESET}"
    fi
    ( cd -- "$script_dir" && "$@" )
    local status=$?
    if [[ "$con_sep" == "true" ]]; then
        echo -e "${C_CYAN}${sep}${C_RESET}"
    else
        echo
    fi
    if [[ $status -eq 0 ]]; then
        print_success "Script finalizado correctamente."
    else
        print_error "El script terminó con código $status."
    fi
    log_run "$script" "$status" "$META_SUDO"
    [[ "$META_TERMINAL" == "true" ]] && notify_result "$META_MENU" "$status"
    pause
    return "$status"
}

run_script() {
    local script="$1"
    local force_mode="${2:-}"   # "inline" -> ignora TERMINAL y ejecuta siempre
                                 # en la terminal actual (la usan los iconos
                                 # instalados con --icons, que ya abren su
                                 # propia terminal desde el .desktop)

    if [[ ! -f "$script" ]]; then
        print_error "El script ya no existe: $script"
        print_info "Si lo moviste o renombraste, reinstala su icono independiente."
        pause
        return 1
    fi

    read_metadata "$script"

    # Carpeta donde vive el script: se ejecuta con ese directorio como
    # cwd (no el que tuviera scriptya al arrancar), para que las
    # rutas relativas a ficheros vecinos (./config.txt, ./datos/...)
    # funcionen siempre igual, se lance el launcher desde donde se
    # lance. Se resuelve con cd+pwd para dejarla absoluta y canónica.
    local script_dir
    script_dir="$(cd -- "$(dirname -- "$script")" && pwd)" || script_dir="$(dirname -- "$script")"

    clear
    print_header "$META_MENU"
    [[ -n "$META_DESCRIPTION" ]] && echo -e "${C_DIM}$META_DESCRIPTION${C_RESET}"
    echo

    if [[ "$META_CONFIRM" == "true" ]]; then
        if ! confirm_yn "¿Ejecutar '$META_MENU'?"; then
            print_warning "Cancelado."
            pause
            return 1
        fi
        echo
    fi

    # Parámetros pedidos por el propio script (metadato "# ASK: ...",
    # repetible). Cada respuesta se pasa como argumento posicional, en
    # el mismo orden en que aparecen los ASK ($1, $2...).
    local -a ask_values=()
    if [[ ${#META_ASK[@]} -gt 0 ]]; then
        local ask_prompt ask_val
        for ask_prompt in "${META_ASK[@]}"; do
            read -r -p "$(echo -e "${C_YELLOW}${ask_prompt}${C_RESET}: ")" ask_val
            ask_values+=("$ask_val")
        done
        echo
    fi

    local -a cmd=()
    [[ "$META_SUDO" == "true" ]] && cmd+=(sudo)
    if [[ -x "$script" ]]; then
        cmd+=("$script")
    else
        cmd+=(bash "$script")
    fi
    [[ ${#ask_values[@]} -gt 0 ]] && cmd+=("${ask_values[@]}")

    if [[ "$META_TERMINAL" == "true" && "$force_mode" != "inline" ]]; then
        local term
        term="$TERMINAL"; command_exists "$term" || term="$(detect_terminal)"

        if ! command_exists "$term"; then
            print_warning "No se encontró ningún emulador de terminal instalado."
            print_info "Ejecutando aquí en su lugar:"
            echo
            run_and_report "$script" "$script_dir" "false" "${cmd[@]}"
            return $?
        fi

        # Los emuladores de terminal no son consistentes con "-e": gnome-terminal
        # (el que usa Cinnamon por defecto) espera UN solo argumento de texto y lo
        # trocea él mismo, mientras que xterm/konsole engullen varios argumentos
        # sueltos. Pasarle "bash" "-c" "..." como argumentos separados (como hacía
        # la versión anterior) rompe con gnome-terminal. Para evitar ese lío por
        # completo, generamos un script temporal de un solo uso y le pasamos a
        # "-e" solo su ruta: eso funciona igual con cualquiera de los dos estilos.
        local tmp_script
        tmp_script="$(mktemp "${TMPDIR:-/tmp}/scriptya.XXXXXX.sh")"
        {
            printf '#!/bin/bash\n'
            printf 'SY_LOG_FILE=%q\n' "$LOG_FILE"
            printf 'SY_INSTALL_DIR=%q\n' "$INSTALL_DIR"
            printf 'SY_SCRIPT_PATH=%q\n' "$script"
            printf 'SY_SCRIPT_SUDO=%q\n' "$META_SUDO"
            printf 'SY_SCRIPT_MENU=%q\n' "$META_MENU"
            printf 'if cd -- %q; then\n' "$script_dir"
            printf '    '
            printf '%q ' "${cmd[@]}"
            printf '\n    status=$?\nelse\n    '
            printf 'echo %q >&2\n' "La carpeta del script ya no existe: $script_dir"
            printf '    status=1\nfi\n'
            cat <<'INNER_EOF'
mkdir -p "$SY_INSTALL_DIR" 2>/dev/null
printf '%s\t%s\t%s\t%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$status" "$SY_SCRIPT_SUDO" "$SY_SCRIPT_PATH" >> "$SY_LOG_FILE" 2>/dev/null
if command -v notify-send >/dev/null 2>&1; then
    if [[ $status -eq 0 ]]; then
        notify-send -a "Scriptya" -i dialog-information "$SY_SCRIPT_MENU" "Finalizado correctamente." 2>/dev/null
    else
        notify-send -a "Scriptya" -i dialog-error -u critical "$SY_SCRIPT_MENU" "Terminó con código $status." 2>/dev/null
    fi
fi
echo
if [[ $status -eq 0 ]]; then
    printf '\033[32m✓ Script finalizado correctamente.\033[0m\n'
else
    printf '\033[31m✗ El script terminó con código %s.\033[0m\n' "$status"
fi
read -n 1 -s -r -p 'Pulsa una tecla para cerrar...'
echo
INNER_EOF
            printf 'rm -f -- %q\n' "$tmp_script"
        } > "$tmp_script"
        chmod +x "$tmp_script"

        if ! "$term" -e "$tmp_script" 2>/dev/null; then
            rm -f -- "$tmp_script" 2>/dev/null
            print_error "No se pudo abrir '$term'. Ejecutando aquí en su lugar:"
            echo
            run_and_report "$script" "$script_dir" "false" "${cmd[@]}"
            return $?
        fi
    else
        # Si el script pedía TERMINAL:true pero se ejecuta aquí "inline"
        # (p.ej. un icono independiente, cuyo .desktop ya abrió su propia
        # terminal), esa ventana puede quedar igualmente oculta: run_and_report
        # ya avisa con notify_result cuando corresponde.
        run_and_report "$script" "$script_dir" "true" "${cmd[@]}"
        return $?
    fi
}

# ============================================================
# HISTORIAL DE EJECUCIONES
# ============================================================
# show_history -> muestra las últimas ejecuciones registradas en
# $LOG_FILE (fecha, resultado, si usó sudo y script), la más reciente
# primero. Formato de cada línea del log (ver log_run): fecha, código
# de salida, sudo (true/false) y ruta del script, separados por
# tabuladores.
show_history() {
    clear
    print_header "Scriptya - Historial"
    echo

    if [[ ! -s "$LOG_FILE" ]]; then
        print_warning "Todavía no hay ninguna ejecución registrada."
        echo
        pause
        return 0
    fi

    local max_lines=50
    local total
    total="$(wc -l < "$LOG_FILE" 2>/dev/null)"
    total="${total//[[:space:]]/}"
    [[ -z "$total" ]] && total=0

    if (( total > max_lines )); then
        print_info "Mostrando las últimas $max_lines ejecuciones de $total (más reciente primero)."
    else
        print_info "Mostrando las $total ejecuciones registradas (más reciente primero)."
    fi
    echo

    local fecha status sudo_yn script marca nombre
    while IFS=$'\t' read -r fecha status sudo_yn script; do
        [[ -z "$fecha" ]] && continue
        if [[ "$status" == "0" ]]; then
            marca="${C_GREEN}✓${C_RESET}"
        else
            marca="${C_RED}✗ (código ${status:-?})${C_RESET}"
        fi
        nombre="$(basename -- "$script" 2>/dev/null)"
        [[ -z "$nombre" ]] && nombre="$script"
        [[ "$sudo_yn" == "true" ]] && nombre="🔒 $nombre"
        echo -e "  ${fecha}  ${marca}  ${nombre}"
    done < <(tac -- "$LOG_FILE" 2>/dev/null | head -n "$max_lines")

    echo
    if confirm_yn "¿Borrar todo el historial?"; then
        : > "$LOG_FILE" 2>/dev/null
        print_success "Historial borrado."
        echo
    fi
    pause
}

# ============================================================
# MENÚ NUMERADO (fallback sin fzf)
# ============================================================
menu_numeric() {
    local dir="$1"
    local mode="${2:-run}"
    local filter="${3:-}"
    local -a dirs=() scripts=() entries=() all_entries=() all_labels=()
    local d s i=1 idx sudo_badge

    while IFS= read -r d; do [[ -n "$d" ]] && dirs+=("$d"); done < <(list_dirs "$dir")
    while IFS= read -r s; do [[ -n "$s" ]] && scripts+=("$s"); done < <(sorted_scripts "$dir")

    for d in "${dirs[@]}"; do
        all_entries+=("dir:$d")
        all_labels+=("📁 $(basename "$d")")
    done
    for s in "${scripts[@]}"; do
        read_metadata "$s"
        all_entries+=("script:$s")
        sudo_badge=""
        [[ "$META_SUDO" == "true" ]] && sudo_badge="🔒 "
        if [[ -n "$META_DESCRIPTION" ]]; then
            all_labels+=("📄 ${sudo_badge}$META_MENU — $META_DESCRIPTION")
        else
            all_labels+=("📄 ${sudo_badge}$META_MENU")
        fi
    done

    # Las acciones del menú raíz entran en el mismo listado filtrable que
    # carpetas y scripts, para que buscar "historial" o "instalar"
    # funcione igual que en menu_fzf (donde el buscador de fzf ya las
    # encuentra sin este añadido).
    if [[ "$dir" == "$SCRIPTS_DIR" && "$mode" == "run" ]]; then
        all_entries+=("action:install_scripts");    all_labels+=("⚙️  Instalar Scripts")
        all_entries+=("action:uninstall_scripts");  all_labels+=("🗑️  Desinstalar Scripts")
        all_entries+=("action:change_icon");        all_labels+=("🎨  Cambiar Icono")
        all_entries+=("action:change_scripts_dir"); all_labels+=("🔍  Buscar Scripts")
        all_entries+=("action:view_history");       all_labels+=("📜  Ver Historial")
    fi

    clear
    print_header "SCRIPTYA"
    echo
    print_info "  $(rel_to_scripts_dir "$dir")"
    [[ -n "$filter" ]] && print_info "  Filtro: \"$filter\""
    echo

    # Filtro de texto (case-insensitive, subcadena) para cuando no hay
    # 'fzf' instalado: sin él, un menú numerado no tiene forma de
    # buscar, solo de contar filas.
    local filter_lc="${filter,,}" label_lc entry_type sep_shown="false"
    for idx in "${!all_entries[@]}"; do
        if [[ -n "$filter" ]]; then
            label_lc="${all_labels[$idx],,}"
            [[ "$label_lc" == *"$filter_lc"* ]] || continue
        fi
        entry_type="${all_entries[$idx]%%:*}"
        if [[ -z "$filter" && "$entry_type" == "action" && "$sep_shown" == "false" ]]; then
            echo -e "${C_DIM}$(hline)${C_RESET}"
            sep_shown="true"
        fi
        entries+=("${all_entries[$idx]}")
        echo -e "  $i) ${all_labels[$idx]}"
        ((i++))
    done

    if [[ ${#entries[@]} -eq 0 ]]; then
        if [[ -n "$filter" ]]; then
            print_warning "Sin resultados para \"$filter\"."
        else
            print_warning "No hay scripts ni carpetas aquí todavía."
        fi
        echo
    fi

    echo
    if [[ "$dir" == "$SCRIPTS_DIR" ]]; then
        echo "  0) Salir"
    else
        echo "  0) Atrás"
    fi
    if [[ -n "$filter" ]]; then
        print_info "  (escribe para cambiar el filtro, Intro en blanco lo quita)"
    else
        print_info "  (escribe texto para filtrar por nombre)"
    fi
    echo

    local choice
    if ! read -r -p "Selecciona una opción: " choice; then
        # EOF (Ctrl+D) o stdin cerrado: salir/retroceder en vez de
        # entrar en un bucle infinito reintentando una lectura que
        # ya nunca va a tener éxito.
        echo
        if [[ "$dir" == "$SCRIPTS_DIR" ]]; then NAV_ACTION="quit"; else NAV_ACTION="back"; fi
        return
    fi

    if [[ "$choice" == "0" ]]; then
        if [[ "$dir" == "$SCRIPTS_DIR" ]]; then NAV_ACTION="quit"; else NAV_ACTION="back"; fi
        return
    fi

    if [[ -z "$choice" ]]; then
        # Intro en blanco: quita el filtro (si no había, no cambia nada).
        NAV_ACTION="filter"; NAV_TARGET=""
        return
    fi

    # 10#$choice fuerza base 10: sin esto, un valor con cero delante
    # (p.ej. "008", al filtrar por un script "008_algo.sh") se
    # interpreta como octal y falla o selecciona la entrada equivocada.
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( 10#$choice >= 1 && 10#$choice <= ${#entries[@]} )); then
        local entry="${entries[$((10#$choice-1))]}"
        local type="${entry%%:*}" path="${entry#*:}"

        if [[ "$type" == "dir" ]]; then
            NAV_ACTION="enter"; NAV_TARGET="$path"
        elif [[ "$type" == "action" ]]; then
            NAV_ACTION="action"; NAV_TARGET="$path"
        else
            NAV_ACTION="run"; NAV_TARGET="$path"
        fi
        return
    fi

    if [[ "$choice" =~ ^[0-9]+$ ]]; then
        # Número fuera de rango: se prueba como texto de filtro, por si
        # el usuario busca algo que empieza por dígitos (p.ej. "2024_backup").
        NAV_ACTION="filter"; NAV_TARGET="$choice"
        return
    fi

    # Cualquier otro texto: se usa como filtro.
    NAV_ACTION="filter"; NAV_TARGET="$choice"
}

# ============================================================
# MENÚ CON fzf (buscador interactivo, si está instalado)
# ============================================================
menu_fzf() {
    local dir="$1"
    local mode="${2:-run}"
    local -a dirs=() scripts=() entries=() display=() lines=()
    local d s idx sel header sudo_badge

    while IFS= read -r d; do [[ -n "$d" ]] && dirs+=("$d"); done < <(list_dirs "$dir")
    while IFS= read -r s; do [[ -n "$s" ]] && scripts+=("$s"); done < <(sorted_scripts "$dir")

    for d in "${dirs[@]}"; do
        entries+=("dir:$d")
        display+=("📁  $(basename "$d")/")
    done

    for s in "${scripts[@]}"; do
        read_metadata "$s"
        entries+=("script:$s")
        sudo_badge=""
        [[ "$META_SUDO" == "true" ]] && sudo_badge="🔒 "
        if [[ -n "$META_DESCRIPTION" ]]; then
            display+=("📄  ${sudo_badge}$META_MENU   ($META_DESCRIPTION)")
        else
            display+=("📄  ${sudo_badge}$META_MENU")
        fi
    done

    if [[ "$dir" == "$SCRIPTS_DIR" && "$mode" == "run" ]]; then
        entries+=("action:install_scripts")
        display+=("⚙️   Instalar Scripts")
        entries+=("action:uninstall_scripts")
        display+=("🗑️   Desinstalar Scripts")
        entries+=("action:change_icon")
        display+=("🎨  Cambiar Icono")
        entries+=("action:change_scripts_dir")
        display+=("🔍  Buscar Scripts")
        entries+=("action:view_history")
        display+=("📜  Ver Historial")
    fi

    if [[ "$dir" != "$SCRIPTS_DIR" ]]; then
        entries+=("back:")
        display+=("⬅️   Atrás")
    fi

    if [[ ${#entries[@]} -eq 0 ]]; then
        clear
        print_header "SCRIPTYA"
        echo
        print_warning "No hay scripts ni carpetas aquí todavía."
        echo
        pause
        if [[ "$dir" == "$SCRIPTS_DIR" ]]; then NAV_ACTION="quit"; else NAV_ACTION="back"; fi
        return
    fi

    for idx in "${!entries[@]}"; do
        lines+=("$idx"$'\t'"${display[$idx]}")
    done

    local esc_hint="(Esc para salir)"
    [[ "$dir" != "$SCRIPTS_DIR" ]] && esc_hint="(Esc para volver)"
    header="Scriptya — $(rel_to_scripts_dir "$dir")   $esc_hint"
    sel="$(printf '%s\n' "${lines[@]}" | fzf --delimiter='\t' --with-nth=2.. \
        --header="$header" --prompt="> " --height=90% --reverse 2>/dev/null)"

    if [[ -z "$sel" ]]; then
        if [[ "$dir" == "$SCRIPTS_DIR" ]]; then NAV_ACTION="quit"; else NAV_ACTION="back"; fi
        return
    fi

    idx="${sel%%$'\t'*}"
    local entry="${entries[$idx]}"
    local type="${entry%%:*}" path="${entry#*:}"

    case "$type" in
        dir)    NAV_ACTION="enter";  NAV_TARGET="$path" ;;
        script) NAV_ACTION="run";    NAV_TARGET="$path" ;;
        action) NAV_ACTION="action"; NAV_TARGET="$path" ;;
        back)   NAV_ACTION="back" ;;
    esac
}

# ============================================================
# NAVEGACIÓN (pila de carpetas: entrar / atrás / ejecutar / salir)
# ============================================================
navigate() {
    local root_dir="$1"
    local mode="${2:-run}"   # "run"  -> comportamiento normal, ejecuta el script
                              # "pick" -> en vez de ejecutar, deja la ruta elegida
                              #           en PICKED_SCRIPT y termina (la usa el
                              #           instalador de iconos, --icons)
    local -a stack=("$root_dir")
    local current_dir
    local filter=""   # solo se usa con el menú numérico (fallback sin fzf)

    PICKED_SCRIPT=""

    while true; do
        current_dir="${stack[${#stack[@]}-1]}"

        if command_exists fzf; then
            menu_fzf "$current_dir" "$mode"
        else
            menu_numeric "$current_dir" "$mode" "$filter"
        fi

        case "$NAV_ACTION" in
            enter)
                stack+=("$NAV_TARGET")
                filter=""
                ;;
            run)
                if [[ "$mode" == "pick" ]]; then
                    PICKED_SCRIPT="$NAV_TARGET"
                    return 0
                fi
                run_script "$NAV_TARGET"
                ;;
            action)
                case "$NAV_TARGET" in
                    install_scripts)   pick_script_and_install_icon ;;
                    uninstall_scripts) manage_installed_icons ;;
                    change_icon)       pick_icon_target_and_change ;;
                    view_history)      show_history ;;
                    change_scripts_dir)
                        do_change_scripts_dir
                        # Por si se ha elegido una carpeta nueva: refresca la
                        # pila de navegación para apuntar a la $SCRIPTS_DIR
                        # actual (si no hubo cambios, sigue siendo la misma).
                        stack=("$SCRIPTS_DIR")
                        filter=""
                        ;;
                esac
                ;;
            filter)
                filter="$NAV_TARGET"
                ;;
            back)
                if [[ ${#stack[@]} -gt 1 ]]; then
                    stack=("${stack[@]:0:$((${#stack[@]}-1))}")
                    filter=""
                else
                    return 0
                fi
                ;;
            quit)
                return 0
                ;;
            *) ;;
        esac
    done
}

# ============================================================
# SCRIPTS DE EJEMPLO (se crean en el primer uso, si se acepta)
# ============================================================
create_example_scripts() {
    local dir="$1"
    mkdir -p "$dir"

    cat > "$dir/actualizar_sistema.sh" <<'EOF'
#!/bin/bash
# MENU: Actualizar sistema
# DESCRIPTION: Actualiza los paquetes del sistema (apt)
# CONFIRM: true
# TERMINAL: true
# SUDO: true

set -euo pipefail
echo "Actualizando lista de paquetes..."
apt update
echo "Actualizando paquetes instalados..."
apt upgrade -y
echo "Limpiando paquetes no necesarios..."
apt autoremove -y
echo "Sistema actualizado."
EOF

    mkdir -p "$dir/Backup"
    cat > "$dir/Backup/copia_documentos.sh" <<'EOF'
#!/bin/bash
# MENU: Copia de Documentos
# DESCRIPTION: Copia ~/Documentos a ~/Backups/FECHA
# CONFIRM: true
# TERMINAL: false
# SUDO: false

set -euo pipefail
ORIGEN="$(xdg-user-dir DOCUMENTS 2>/dev/null || echo "$HOME/Documentos")"
DESTINO="$HOME/Backups/$(date +%Y-%m-%d)"

if [[ ! -d "$ORIGEN" ]]; then
    echo "No existe la carpeta de origen: $ORIGEN"
    exit 1
fi

mkdir -p "$DESTINO"
cp -rv "$ORIGEN"/* "$DESTINO"/ 2>/dev/null || true
echo "Backup completado en: $DESTINO"
EOF

    chmod +x "$dir/actualizar_sistema.sh" "$dir/Backup/copia_documentos.sh"
}

# ============================================================
# SELECCIÓN DE CARPETA (navegando, sin escribir la ruta)
# ============================================================
# Mismo planteamiento que la selección de imagen para iconos, más abajo:
# selector gráfico nativo si hay 'zenity', y si no, un navegador en modo
# texto (con fzf si está disponible, o menú numerado si no).

# pick_folder_via_zenity [carpeta_inicial] -> si 'zenity' está instalado,
# abre el selector de carpetas gráfico nativo del sistema (el "menú de
# búsqueda de archivos" de toda la vida, en modo carpetas). Imprime la
# ruta elegida por stdout, o nada si se cancela.
pick_folder_via_zenity() {
    command_exists zenity || return 1
    local start_dir="${1:-$HOME}"
    zenity --file-selection \
        --directory \
        --title="Selecciona la carpeta de scripts" \
        --filename="${start_dir%/}/" 2>/dev/null
}

# browse_for_folder [carpeta_inicial] -> navegador en modo texto (con fzf
# si está disponible) que solo muestra subcarpetas. A diferencia de
# browse_for_image, aquí cualquier carpeta del recorrido es un destino
# válido (no solo las hojas), así que en cada nivel se ofrece la opción
# de quedarse con la carpeta actual. Deja el resultado en PICKED_FOLDER
# (vacío si se cancela).
browse_for_folder() {
    local -a stack=("${1:-$HOME}")
    PICKED_FOLDER=""

    while true; do
        local dir="${stack[${#stack[@]}-1]}"
        local -a dirs=() entries=() display=()
        local d i

        while IFS= read -r d; do [[ -n "$d" ]] && dirs+=("$d"); done < <(list_dirs "$dir")

        if command_exists fzf; then
            entries+=("select:$dir")
            display+=("✅  Usar esta carpeta ($dir)")
            for d in "${dirs[@]}"; do entries+=("dir:$d"); display+=("📁  $(basename "$d")/"); done
            [[ ${#stack[@]} -gt 1 ]] && { entries+=("back:"); display+=("⬅️   Atrás"); }
            entries+=("cancel:"); display+=("✗   Cancelar")

            local -a lines=()
            local idx sel
            for idx in "${!entries[@]}"; do lines+=("$idx"$'\t'"${display[$idx]}"); done
            sel="$(printf '%s\n' "${lines[@]}" | fzf --delimiter='\t' --with-nth=2.. \
                --header="Elige la carpeta de scripts — $dir" --prompt="> " \
                --height=90% --reverse 2>/dev/null)"
            [[ -z "$sel" ]] && return 0

            idx="${sel%%$'\t'*}"
            local entry="${entries[$idx]}" type path
            type="${entry%%:*}"; path="${entry#*:}"
            case "$type" in
                select) PICKED_FOLDER="$path"; return 0 ;;
                dir)    stack+=("$path") ;;
                back)   stack=("${stack[@]:0:$((${#stack[@]}-1))}") ;;
                cancel) return 0 ;;
            esac
        else
            clear
            print_header "Elegir carpeta"
            echo
            print_info "  $dir"
            echo
            echo "  1) ✅ Usar esta carpeta"
            entries+=("select:$dir")
            i=2
            for d in "${dirs[@]}"; do entries+=("dir:$d"); echo "  $i) 📁 $(basename "$d")"; ((i++)); done
            echo
            if [[ ${#stack[@]} -gt 1 ]]; then
                echo "  0) Atrás"
            else
                echo "  0) Cancelar"
            fi
            echo
            local choice
            if ! read -r -p "Opción: " choice; then
                return 0
            fi
            if [[ "$choice" == "0" || -z "$choice" ]]; then
                if [[ ${#stack[@]} -gt 1 ]]; then
                    stack=("${stack[@]:0:$((${#stack[@]}-1))}")
                    continue
                else
                    return 0
                fi
            fi
            if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( 10#$choice < 1 || 10#$choice > ${#entries[@]} )); then
                print_error "Opción no válida."
                pause
                continue
            fi
            local entry="${entries[$((10#$choice-1))]}" type path
            type="${entry%%:*}"; path="${entry#*:}"
            if [[ "$type" == "dir" ]]; then
                stack+=("$path")
            else
                PICKED_FOLDER="$path"
                return 0
            fi
        fi
    done
}

# pick_folder [carpeta_inicial] -> asistente combinado: usa el selector
# gráfico si hay 'zenity' instalado; si no, o si se cancela sin elegir
# nada, cae al navegador en modo texto. Deja el resultado en
# PICKED_FOLDER (vacío si se cancela en ambos).
# OJO: a propósito NO se envuelve en "$(...)" al llamarla, ni ella
# envuelve a su vez a browse_for_folder en "$(...)": browse_for_folder
# es interactiva y su menú se imprime por stdout, así que capturar la
# salida de la función entera capturaría también el menú, no solo la
# ruta elegida. Por eso se comunica el resultado con una variable
# global, igual que hace browse_for_image con PICKED_IMAGE.
pick_folder() {
    local start="${1:-$HOME}"
    PICKED_FOLDER=""

    if command_exists zenity; then
        local picked
        picked="$(pick_folder_via_zenity "$start")"
        if [[ -n "$picked" ]]; then
            PICKED_FOLDER="$picked"
            return 0
        fi
    fi

    browse_for_folder "$start"
}

# ============================================================
# BUSCAR SCRIPTS (cambiar la carpeta de scripts desde el menú)
# ============================================================
# do_change_scripts_dir -> opción "🔍 Buscar Scripts" del menú principal.
# Abre el selector de carpetas (el clásico diálogo gráfico de 'zenity'
# si está instalado; si no, el navegador en modo texto de pick_folder)
# para localizar dónde están guardados los scripts y usarla como nueva
# $SCRIPTS_DIR. El cambio se guarda en config.conf para que persista
# entre ejecuciones.
do_change_scripts_dir() {
    clear
    print_header "Buscar Scripts"
    echo
    print_info "  Carpeta actual: $SCRIPTS_DIR"
    echo

    pick_folder "$SCRIPTS_DIR"
    local new_dir="$PICKED_FOLDER"
    [[ "$new_dir" != "/" ]] && new_dir="${new_dir%/}"

    if [[ -z "$new_dir" ]]; then
        print_warning "No se seleccionó ninguna carpeta."
        echo
        pause
        return 0
    fi

    if [[ "$new_dir" == "$SCRIPTS_DIR" ]]; then
        print_info "Sigue siendo la misma carpeta de scripts."
        echo
        pause
        return 0
    fi

    if [[ ! -d "$new_dir" ]]; then
        print_error "La carpeta '$new_dir' no existe."
        echo
        pause
        return 1
    fi

    echo
    if confirm_yn "¿Usar '$new_dir' como carpeta de scripts?"; then
        SCRIPTS_DIR="$new_dir"
        save_config
        print_success "Carpeta de scripts actualizada."
    else
        print_info "Cancelado."
    fi
    echo
    pause
}

# ============================================================
# INSTALADOR
# ============================================================
do_install() {
    clear
    print_header "Scriptya - Instalación"
    echo
    echo "¿Dónde están tus scripts?"
    echo
    echo "  1) ~/Scripts"
    echo "  2) Buscar la carpeta navegando"
    echo "  3) Escribir la ruta a mano"
    echo "  4) Salir"
    echo
    local opt
    read -r -p "Opción: " opt

    local new_scripts_dir
    case "$opt" in
        1) new_scripts_dir="$HOME/Scripts" ;;
        2)
            pick_folder "$HOME"
            new_scripts_dir="$PICKED_FOLDER"
            if [[ -z "$new_scripts_dir" ]]; then
                print_warning "No se seleccionó ninguna carpeta."
                return 1
            fi
            ;;
        3)
            local custom_path
            read -r -p "Introduce la ruta: " custom_path
            if [[ -z "$custom_path" ]]; then
                print_error "No has escrito ninguna ruta."
                return 1
            fi
            new_scripts_dir="${custom_path/#\~/$HOME}"
            ;;
        4) echo "Instalación cancelada."; return 0 ;;
        *) print_error "Opción no válida."; return 1 ;;
    esac
    # Ruta absoluta siempre: si se escribió una ruta relativa a mano
    # (opción 3), guardarla tal cual en config.conf la dejaría atada al
    # directorio desde el que se lanzó --install, y "scriptya" dejaría
    # de encontrarla al ejecutarse después desde cualquier otra carpeta.
    [[ "$new_scripts_dir" != /* ]] && new_scripts_dir="$PWD/$new_scripts_dir"
    [[ "$new_scripts_dir" != "/" ]] && new_scripts_dir="${new_scripts_dir%/}"

    if [[ ! -d "$new_scripts_dir" ]]; then
        echo
        if confirm_yn "La carpeta '$new_scripts_dir' no existe. ¿Crearla?"; then
            # Se comprueba el resultado real (mkdir puede fallar por
            # permisos, ruta inválida, etc.) en vez de asumir éxito.
            if mkdir -p "$new_scripts_dir" 2>/dev/null && [[ -d "$new_scripts_dir" ]]; then
                print_success "Carpeta creada."
            else
                print_error "No se pudo crear '$new_scripts_dir'. Abortando."
                return 1
            fi
        else
            print_error "Se necesita una carpeta de scripts válida. Abortando."
            return 1
        fi
    fi
    SCRIPTS_DIR="$new_scripts_dir"

    echo
    local want_examples="no"
    if [[ -z "$(list_dirs "$SCRIPTS_DIR")$(list_scripts "$SCRIPTS_DIR")" ]]; then
        if confirm_yn "La carpeta está vacía. ¿Crear un par de scripts de ejemplo?"; then
            want_examples="si"
        fi
    fi

    echo
    echo "¿Crear acceso directo?"
    echo
    echo "  1) Sí"
    echo "  2) No"
    local opt_shortcut
    read -r -p "Opción: " opt_shortcut
    local create_shortcut="no"
    [[ "$opt_shortcut" == "1" ]] && create_shortcut="si"

    echo
    echo "¿Añadir al menú de Linux Mint?"
    echo
    echo "  1) Sí"
    echo "  2) No"
    local opt_menu
    read -r -p "Opción: " opt_menu
    local add_menu="no"
    [[ "$opt_menu" == "1" ]] && add_menu="si"

    echo
    print_header "Instalando..."
    echo

    mkdir -p "$INSTALL_DIR"
    # Si ya se está ejecutando la copia instalada (p.ej. el asistente saltó
    # solo porque se borró $SCRIPTS_DIR y se relanzó "scriptya" sin
    # argumentos), "cp" sobre sí mismo falla con "are the same file" y
    # ensuciaba la salida aunque el resto de la instalación funcionara bien.
    if [[ "$SCRIPT_PATH" -ef "$INSTALL_DIR/scriptya.sh" ]]; then
        chmod +x "$INSTALL_DIR/scriptya.sh"
        print_success "El launcher ya estaba instalado"
    elif cp "$SCRIPT_PATH" "$INSTALL_DIR/scriptya.sh" 2>/dev/null; then
        chmod +x "$INSTALL_DIR/scriptya.sh"
        print_success "Copiando launcher"
    else
        print_error "No se pudo copiar el launcher a '$INSTALL_DIR'. Abortando instalación."
        return 1
    fi

    if [[ "$want_examples" == "si" ]]; then
        create_example_scripts "$SCRIPTS_DIR"
        print_success "Creando scripts de ejemplo"
    fi

    TERMINAL="$(detect_terminal)"
    save_config
    print_success "Guardando configuración"
    print_success "Creando ~/.config/scriptya"

    mkdir -p "$BIN_DIR"
    ln -sf "$INSTALL_DIR/scriptya.sh" "$BIN_LINK"

    local icon="$SY_ICON"

    if [[ "$create_shortcut" == "si" ]]; then
        mkdir -p "$(dirname "$DESKTOP_SHORTCUT")"
        cat > "$DESKTOP_SHORTCUT" <<EOF
[Desktop Entry]
Type=Application
Name=Scriptya
Comment=Ejecuta tus scripts personales
Exec=$(desktop_quote "$BIN_LINK")
Icon=$icon
Terminal=true
Categories=Utility;
EOF
        finalize_desktop_shortcut "$DESKTOP_SHORTCUT"
        print_success "Creando acceso directo"
    fi

    if [[ "$add_menu" == "si" ]]; then
        mkdir -p "$APPS_DIR"
        cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Scriptya
Comment=Ejecuta tus scripts personales organizados en carpetas
Exec=$(desktop_quote "$BIN_LINK")
Icon=$icon
Terminal=true
Categories=Utility;System;
EOF
        finalize_menu_entry "$DESKTOP_FILE"
        print_success "Añadido al menú de Linux Mint"
    fi

    echo
    print_success "Instalación completada"
    echo

    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        print_warning "$BIN_DIR no está en tu PATH."
        echo "Añade esta línea a tu ~/.bashrc y reinicia la terminal:"
        echo
        echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo
    fi

    echo "Ya puedes ejecutar Scriptya escribiendo:"
    echo -e "    ${C_BOLD}scriptya${C_RESET}"
    echo

    if confirm_yn "¿Quieres instalar iconos personalizados para alguno de tus scripts ahora?"; then
        do_manage_icons
    fi

    pause
}

# ============================================================
# ICONOS PERSONALIZADOS PARA SCRIPTS SUELTOS (--icons)
# ============================================================
# Permite instalar un script individual como si fuera una aplicación
# aparte: crea un fichero .desktop propio (en el menú de Cinnamon y/o
# en el Escritorio) con su propio icono, en vez de tener que pasar
# siempre por el menú de Scriptya.
#
# El .desktop generado llama a "scriptya --run-script <ruta>",
# así que sigue respetando los metadatos del script (CONFIRM, SUDO...).

# sanitize_id <ruta> -> identificador estable y único para un script,
# usado para nombrar su fichero .desktop y su icono copiado. Se basa en
# la ruta completa (no solo el nombre) para que dos scripts con el
# mismo nombre en carpetas distintas no choquen entre sí.
sanitize_id() {
    local path="$1" base slug hash
    base="$(basename "$path" .sh)"
    slug="$(echo "$base" | tr -c 'A-Za-z0-9_-' '_')"
    hash="$(echo -n "$path" | cksum | cut -d' ' -f1)"
    echo "${slug}-${hash}"
}

# unique_icon_tag -> sufijo corto y (prácticamente) irrepetible para el
# NOMBRE del fichero de icono. OJO: esto es distinto de sanitize_id, que
# debe permanecer estable para reconocer que es "el mismo script". Ver
# el porqué en install_icon_for_script: reutilizar siempre el mismo
# nombre de fichero para el icono es lo que causaba que, al desinstalar
# un script y volverlo a instalar con un icono distinto, Cinnamon/Nemo
# siguieran mostrando el icono antiguo (lo tienen cacheado por ruta de
# fichero, no por contenido).
unique_icon_tag() {
    local t
    t="$(date +%s%N 2>/dev/null)"
    [[ "$t" =~ ^[0-9]+$ ]] || t="$$"
    echo "${t}_${RANDOM}"
}

# launcher_exec_path -> ruta del scriptya que deben usar los
# .desktop generados: la copia instalada si existe (sobrevive aunque
# se mueva o borre el original), o si no, este mismo fichero.
launcher_exec_path() {
    if [[ -x "$INSTALL_DIR/scriptya.sh" ]]; then
        echo "$INSTALL_DIR/scriptya.sh"
    else
        echo "$SCRIPT_PATH"
    fi
}

# ------------------------------------------------------------
# REGISTRO de scripts instalados como aplicaciones independientes
# ------------------------------------------------------------
# Cada script instalado (vía "Instalar Scripts" / --icons) guarda una
# ficha en $REGISTRY_DIR/<id>.meta con 5 líneas: NAME, SOURCE, ICON,
# MENU(si/no), DESKTOP(si/no). Es la única fuente de verdad para
# listar y desinstalar: así funciona igual si el acceso se creó solo
# en el menú, solo en el escritorio, o en ambos (antes, si solo se
# creaba en el escritorio, no había forma de encontrarlo para
# desinstalarlo después).
registry_write() {
    # registry_write <id> <name> <source> <icon> <menu_yn> <desktop_yn>
    mkdir -p "$REGISTRY_DIR"
    printf '%s\n%s\n%s\n%s\n%s\n' "$2" "$3" "$4" "$5" "$6" > "$REGISTRY_DIR/$1.meta"
}

# registry_read <id> -> si existe, rellena REG_NAME/REG_SOURCE/REG_ICON/
# REG_MENU/REG_DESKTOP y devuelve 0. Si no existe, devuelve 1.
registry_read() {
    local f="$REGISTRY_DIR/$1.meta"
    REG_NAME=""; REG_SOURCE=""; REG_ICON=""; REG_MENU="no"; REG_DESKTOP="no"
    [[ -f "$f" ]] || return 1
    {
        IFS= read -r REG_NAME
        IFS= read -r REG_SOURCE
        IFS= read -r REG_ICON
        IFS= read -r REG_MENU
        IFS= read -r REG_DESKTOP
    } < "$f"
    return 0
}

# Lista los identificadores de todos los scripts instalados como apps
list_installed_script_icons() {
    find "$REGISTRY_DIR" -maxdepth 1 -type f -name "*.meta" 2>/dev/null \
        | sed -e 's#.*/##' -e 's#\.meta$##' | sort
}

# remove_script_icon <id> -> quita .desktop (menú y escritorio), icono
# copiado y la ficha del registro para ese id
remove_script_icon() {
    local id="$1" reg_icon=""

    # Leemos el registro ANTES de borrar nada: así sabemos la ruta EXACTA
    # del fichero de icono que se instaló (incluye el sufijo único que
    # le añade install_icon_for_script en cada instalación).
    if registry_read "$id"; then
        reg_icon="$REG_ICON"
    fi

    rm -f "$APPS_DIR/scriptya-app-${id}.desktop" 2>/dev/null
    rm -f "$DESKTOP_DIR/scriptya-app-${id}.desktop" 2>/dev/null
    # Por si el icono se creó con una versión anterior que sí usaba
    # "$HOME/Desktop" a pelo, se limpia también por si acaso.
    [[ "$DESKTOP_DIR" != "$HOME/Desktop" ]] && rm -f "$HOME/Desktop/scriptya-app-${id}.desktop" 2>/dev/null

    # Borra el fichero de icono exacto que quedó registrado (si vive
    # dentro de nuestra carpeta de iconos; si era un icono del tema del
    # sistema, p.ej. "utilities-terminal", REG_ICON no es una ruta y no
    # hay nada que borrar aquí).
    if [[ -n "$reg_icon" && "$reg_icon" == "$ICONS_DIR"/* ]]; then
        rm -f -- "$reg_icon" 2>/dev/null
    fi
    # Y, por si acaso, cualquier resto suelto con ese id: cubre tanto el
    # patrón "${id}.ext" (versiones antiguas de este script, antes de
    # que el nombre del icono llevara sufijo único) como el patrón
    # "${id}-<sufijo>.ext" actual, para no dejar basura acumulada tras
    # varias reinstalaciones.
    rm -f "$ICONS_DIR/${id}".* "$ICONS_DIR/${id}"-*.* 2>/dev/null

    rm -f "$REGISTRY_DIR/${id}.meta" 2>/dev/null
    refresh_app_menu
}

# set_desktop_icon <fichero.desktop> <icono> -> sustituye (o añade) la
# línea Icon= solo dentro de [Desktop Entry], sin tocar el resto. Un
# .desktop de terceros puede traer secciones [Desktop Action ...] con
# su propio Icon (p.ej. "Nueva ventana"); quitar todos los Icon= del
# fichero y añadir uno al final, a lo bruto, pisaría esos o lo dejaría
# fuera de la sección correcta.
set_desktop_icon() {
    local file="$1" icon="$2" tmp line in_entry="false" written="false"
    [[ -f "$file" ]] || return 1
    tmp="$(mktemp)" || return 1

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^\[.+\]$ ]]; then
            if [[ "$in_entry" == "true" && "$written" == "false" ]]; then
                printf 'Icon=%s\n' "$icon" >> "$tmp"
                written="true"
            fi
            [[ "$line" == "[Desktop Entry]" ]] && in_entry="true" || in_entry="false"
            printf '%s\n' "$line" >> "$tmp"
            continue
        fi
        [[ "$in_entry" == "true" && "$line" == "Icon="* ]] && continue
        printf '%s\n' "$line" >> "$tmp"
    done < "$file"

    [[ "$in_entry" == "true" && "$written" == "false" ]] && printf 'Icon=%s\n' "$icon" >> "$tmp"
    mv -f "$tmp" "$file"
}

# ------------------------------------------------------------
# SELECCIÓN DE IMAGEN PARA EL ICONO (navegando, sin escribir la ruta)
# ------------------------------------------------------------

# pick_icon_via_zenity -> si 'zenity' está instalado, abre el selector
# de ficheros gráfico nativo (con vista de carpetas real) filtrado a
# imágenes. Imprime la ruta elegida por stdout, o nada si se cancela.
pick_icon_via_zenity() {
    command_exists zenity || return 1
    local start_dir="$HOME/"
    if command_exists xdg-user-dir; then
        local pics; pics="$(xdg-user-dir PICTURES 2>/dev/null)"
        [[ -n "$pics" && -d "$pics" ]] && start_dir="$pics/"
    fi
    zenity --file-selection \
        --title="Selecciona la imagen del icono" \
        --file-filter="Imágenes | *.png *.jpg *.jpeg *.svg *.gif *.bmp *.webp *.xpm" \
        --filename="$start_dir" 2>/dev/null
}

# browse_for_image [carpeta_inicial] -> navegador en modo texto (con
# fzf si está disponible) que solo muestra subcarpetas e imágenes, para
# elegir el fichero de icono sin tener que escribir la ruta a mano.
# Deja el resultado en PICKED_IMAGE (vacío si se cancela).
browse_for_image() {
    local -a stack=("${1:-$HOME}")
    PICKED_IMAGE=""

    while true; do
        local dir="${stack[${#stack[@]}-1]}"
        local -a dirs=() imgs=() entries=() display=()
        local d f i=1

        while IFS= read -r d; do [[ -n "$d" ]] && dirs+=("$d"); done < <(list_dirs "$dir")
        while IFS= read -r f; do [[ -n "$f" ]] && imgs+=("$f"); done < <(list_images "$dir")

        if command_exists fzf; then
            for d in "${dirs[@]}"; do entries+=("dir:$d");  display+=("📁  $(basename "$d")/"); done
            for f in "${imgs[@]}"; do entries+=("img:$f");  display+=("🖼️  $(basename "$f")"); done
            [[ ${#stack[@]} -gt 1 ]] && { entries+=("back:"); display+=("⬅️   Atrás"); }
            entries+=("cancel:"); display+=("✗   Cancelar")

            local -a lines=()
            local idx sel
            for idx in "${!entries[@]}"; do lines+=("$idx"$'\t'"${display[$idx]}"); done
            sel="$(printf '%s\n' "${lines[@]}" | fzf --delimiter='\t' --with-nth=2.. \
                --header="Elige una imagen para el icono — $dir" --prompt="> " \
                --height=90% --reverse 2>/dev/null)"
            [[ -z "$sel" ]] && return 0

            idx="${sel%%$'\t'*}"
            local entry="${entries[$idx]}" type path
            type="${entry%%:*}"; path="${entry#*:}"
            case "$type" in
                dir)    stack+=("$path") ;;
                img)    PICKED_IMAGE="$path"; return 0 ;;
                back)   stack=("${stack[@]:0:$((${#stack[@]}-1))}") ;;
                cancel) return 0 ;;
            esac
        else
            clear
            print_header "Elegir icono"
            echo
            print_info "  $dir"
            echo
            for d in "${dirs[@]}"; do entries+=("dir:$d"); echo "  $i) 📁 $(basename "$d")"; ((i++)); done
            for f in "${imgs[@]}"; do entries+=("img:$f"); echo "  $i) 🖼️  $(basename "$f")"; ((i++)); done
            if [[ ${#dirs[@]} -eq 0 && ${#imgs[@]} -eq 0 ]]; then
                print_warning "No hay carpetas ni imágenes aquí."
            fi
            echo
            if [[ ${#stack[@]} -gt 1 ]]; then
                echo "  0) Atrás"
            else
                echo "  0) Cancelar"
            fi
            echo
            local choice
            if ! read -r -p "Opción: " choice; then
                return 0
            fi
            if [[ "$choice" == "0" || -z "$choice" ]]; then
                if [[ ${#stack[@]} -gt 1 ]]; then
                    stack=("${stack[@]:0:$((${#stack[@]}-1))}")
                    continue
                else
                    return 0
                fi
            fi
            if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( 10#$choice < 1 || 10#$choice > ${#entries[@]} )); then
                print_error "Opción no válida."
                pause
                continue
            fi
            local entry="${entries[$((10#$choice-1))]}" type path
            type="${entry%%:*}"; path="${entry#*:}"
            if [[ "$type" == "dir" ]]; then
                stack+=("$path")
            else
                PICKED_IMAGE="$path"
                return 0
            fi
        fi
    done
}

# ------------------------------------------------------------
# PROCESADO DE LA IMAGEN DEL ICONO (tamaño + transparencia)
# ------------------------------------------------------------
# process_icon_image <origen> <destino.png> -> encaja la imagen en un
# lienzo cuadrado de 256x256 (sin deformarla) y gestiona la
# transparencia:
#   - Si el original ya tiene transparencia real (algún píxel no
#     opaco), se conserva tal cual.
#   - Si no tiene transparencia y las 4 esquinas comparten un color
#     uniforme (fondo liso, típico en logos/iconos descargados de la
#     web), ese color se convierte en transparente.
#   - Si no hay un fondo uniforme detectable (foto, ilustración
#     compleja...) se deja el fondo tal cual y solo se ajusta el
#     tamaño: esto no es una herramienta de recorte de fondos para
#     fotografías, solo resuelve el caso típico de icono con fondo
#     liso.
# Necesita ImageMagick ('convert'/'identify'). Devuelve 1 si no está
# instalado o si el procesado falla, sin tocar nada.
process_icon_image() {
    local src="$1" dest="$2"
    command_exists convert || return 1
    command_exists identify || return 1

    local tmp
    tmp="$(mktemp --suffix=.png)" || return 1

    # %[opaque] indica si TODOS los píxeles son opacos. Es mejor señal
    # que %A (canal alfa presente): muchos PNG llevan canal alfa aunque
    # estén 100% opacos, y con %A se daban por "ya transparentes" sin
    # quitarles el fondo, que es justo el caso que más nos interesa.
    local is_opaque
    is_opaque="$(identify -format "%[opaque]" "$src" 2>/dev/null | head -n1)"

    if [[ "$is_opaque" == "false" ]]; then
        # Ya tiene transparencia real: se conserva tal cual.
        convert "$src" -resize 256x256 -background none -gravity center \
            -extent 256x256 "$tmp" 2>/dev/null
    else
        local w h c1 c2 c3 c4
        w="$(identify -format "%w" "$src" 2>/dev/null)"
        h="$(identify -format "%h" "$src" 2>/dev/null)"
        if [[ -n "$w" && -n "$h" ]]; then
            c1="$(convert "$src" -format "%[pixel:p{0,0}]" info: 2>/dev/null)"
            c2="$(convert "$src" -format "%[pixel:p{$((w-1)),0}]" info: 2>/dev/null)"
            c3="$(convert "$src" -format "%[pixel:p{0,$((h-1))}]" info: 2>/dev/null)"
            c4="$(convert "$src" -format "%[pixel:p{$((w-1)),$((h-1))}]" info: 2>/dev/null)"
        fi

        if [[ -n "$c1" && "$c1" == "$c2" && "$c1" == "$c3" && "$c1" == "$c4" ]]; then
            convert "$src" -fuzz 8% -transparent "$c1" \
                -resize 256x256 -background none -gravity center \
                -extent 256x256 "$tmp" 2>/dev/null
        else
            convert "$src" -resize 256x256 -background none -gravity center \
                -extent 256x256 "$tmp" 2>/dev/null
        fi
    fi

    if [[ -s "$tmp" ]]; then
        mv -f "$tmp" "$dest"
        echo "$dest"
        return 0
    fi
    rm -f "$tmp"
    return 1
}

# choose_and_process_icon <script|""> <id> [icono_actual] -> asistente
# interactivo para elegir la imagen del icono (metadatos ICON:,
# navegando, ruta escrita o icono del tema) y procesarla igual que en
# la instalación. Deja el resultado en PICKED_ICON_FINAL. La usan
# install_icon_for_script y las funciones "Cambiar Icono"; a estas
# últimas se les pasa además <icono_actual>, que se usa como valor por
# defecto en vez del genérico para no perderlo si el usuario cancela o
# no elige nada.
choose_and_process_icon() {
    local script="$1" id="$2" current="${3:-utilities-terminal}"
    PICKED_ICON_FINAL="$current"

    local icon_value=""
    if [[ -n "$script" ]]; then
        read_metadata "$script"
        if [[ -n "$META_ICON" ]]; then
            echo "El script indica este icono en sus metadatos:"
            echo "  $META_ICON"
            if confirm_yn "¿Usarlo?"; then
                icon_value="$META_ICON"
            fi
            echo
        fi
    fi

    if [[ -z "$icon_value" ]]; then
        echo "¿Cómo quieres elegir el icono?"
        echo
        echo "  1) Buscar una imagen navegando por carpetas"
        echo "  2) Escribir la ruta a una imagen, o el nombre de un icono"
        echo "     del tema del sistema (p.ej. utilities-terminal)"
        if [[ "$#" -ge 3 ]]; then
            echo "  3) Dejar el icono actual"
        else
            echo "  3) Usar el icono genérico"
        fi
        local opt_icon_src
        read -r -p "Opción [1]: " opt_icon_src
        opt_icon_src="${opt_icon_src:-1}"
        echo

        case "$opt_icon_src" in
            1)
                local picked=""
                if command_exists zenity; then
                    picked="$(pick_icon_via_zenity)"
                fi
                if [[ -z "$picked" ]]; then
                    local start="$HOME"
                    if command_exists xdg-user-dir; then
                        local pics; pics="$(xdg-user-dir PICTURES 2>/dev/null)"
                        [[ -n "$pics" && -d "$pics" ]] && start="$pics"
                    fi
                    browse_for_image "$start"
                    picked="$PICKED_IMAGE"
                fi
                if [[ -n "$picked" ]]; then
                    icon_value="$picked"
                elif [[ "$#" -ge 3 ]]; then
                    print_warning "No se seleccionó ninguna imagen; se mantiene el icono actual."
                else
                    print_warning "No se seleccionó ninguna imagen; se usará el icono genérico."
                fi
                ;;
            2)
                read -r -p "Icono: " icon_value
                ;;
            *) icon_value="" ;;
        esac
        echo
    fi

    # Ruta relativa a una imagen (típicamente venida de "# ICON:" en los
    # metadatos, o escrita a mano): se interpreta relativa a la carpeta
    # del script, no al directorio desde el que se lanzó scriptya.
    if [[ -n "$icon_value" && -n "$script" && "$icon_value" != /* && "$icon_value" != "~"* ]]; then
        case "${icon_value,,}" in
            *.png|*.jpg|*.jpeg|*.svg|*.gif|*.bmp|*.webp|*.xpm)
                local script_dir_for_icon
                script_dir_for_icon="$(cd -- "$(dirname -- "$script")" && pwd)" || script_dir_for_icon="$(dirname -- "$script")"
                icon_value="$script_dir_for_icon/$icon_value"
                ;;
        esac
    fi

    [[ -z "$icon_value" ]] && return 0

    local icon_path="${icon_value/#\~/$HOME}"
    if [[ ! -f "$icon_path" ]]; then
        # No es un fichero existente: se asume nombre de icono del tema
        # del sistema (p.ej. "folder" o "utilities-terminal").
        PICKED_ICON_FINAL="$icon_value"
        return 0
    fi

    mkdir -p "$ICONS_DIR"
    local ext_lower icon_tag
    ext_lower="$(echo "${icon_path##*.}" | tr '[:upper:]' '[:lower:]')"
    # Sufijo único en el NOMBRE del fichero (id se mantiene estable): así
    # Cinnamon/Nemo nunca sirven una miniatura cacheada de un icono
    # anterior con el mismo nombre.
    icon_tag="$(unique_icon_tag)"

    if [[ "$ext_lower" == "svg" ]]; then
        local dest="$ICONS_DIR/${id}-${icon_tag}.svg"
        if cp -f "$icon_path" "$dest" 2>/dev/null; then
            PICKED_ICON_FINAL="$dest"
            print_success "Icono copiado a $ICONS_DIR"
        else
            print_warning "No se pudo copiar el icono; se usará uno genérico."
        fi
        return 0
    fi

    local processed=""
    if command_exists convert; then
        processed="$(process_icon_image "$icon_path" "$ICONS_DIR/${id}-${icon_tag}.png")"
    fi
    if [[ -n "$processed" && -f "$processed" ]]; then
        PICKED_ICON_FINAL="$processed"
        print_success "Icono ajustado (tamaño y transparencia) y copiado a $ICONS_DIR"
        return 0
    fi

    local dest="$ICONS_DIR/${id}-${icon_tag}.${ext_lower}"
    if cp -f "$icon_path" "$dest" 2>/dev/null; then
        PICKED_ICON_FINAL="$dest"
        print_success "Icono copiado a $ICONS_DIR"
        command_exists convert || print_info "Instala 'imagemagick' (sudo apt install imagemagick) para que el icono se ajuste automáticamente de tamaño y transparencia."
    else
        print_warning "No se pudo copiar el icono; se usará uno genérico."
    fi
}

# install_icon_for_script <ruta-al-script> -> asistente interactivo
# para crear el acceso directo con icono de un script concreto.
install_icon_for_script() {
    local script="$1"
    read_metadata "$script"

    local id desktop_file
    id="$(sanitize_id "$script")"
    desktop_file="$APPS_DIR/scriptya-app-${id}.desktop"

    clear
    print_header "Instalar icono"
    echo
    echo -e "Script: ${C_BOLD}$META_MENU${C_RESET}"
    [[ -n "$META_DESCRIPTION" ]] && echo -e "${C_DIM}$META_DESCRIPTION${C_RESET}"
    echo -e "${C_DIM}$script${C_RESET}"
    echo

    if registry_read "$id"; then
        print_warning "Este script ya está instalado como aplicación independiente."
        if ! confirm_yn "¿Reemplazarlo?"; then
            print_info "Cancelado."
            pause
            return 0
        fi
        remove_script_icon "$id"
        echo
    fi

    choose_and_process_icon "$script" "$id"
    local icon_final="$PICKED_ICON_FINAL"

    echo
    echo "¿Dónde quieres el acceso?"
    echo
    echo "  1) Solo en el menú de aplicaciones de Linux Mint"
    echo "  2) Solo en el Escritorio"
    echo "  3) Ambos (menú + Escritorio) — recomendado"
    local opt_where
    read -r -p "Opción [3]: " opt_where
    opt_where="${opt_where:-3}"
    # Cualquier respuesta no reconocida cae al valor por defecto (3):
    # sin esto, una opción inválida no creaba ningún acceso (ni menú ni
    # Escritorio) pero el asistente informaba éxito igualmente.
    [[ "$opt_where" =~ ^[123]$ ]] || opt_where="3"

    local launcher entry
    launcher="$(launcher_exec_path)"
    entry="$(cat <<EOF
[Desktop Entry]
Type=Application
Name=$META_MENU
Comment=${META_DESCRIPTION:-Script personal}
Exec=$(desktop_quote "$launcher") --run-script $(desktop_quote "$script")
Icon=$icon_final
Terminal=true
Categories=Utility;
X-Scriptya-Source=$script
EOF
)"

    local menu_yn="no" desktop_yn="no"

    echo
    if [[ "$opt_where" == "1" || "$opt_where" == "3" ]]; then
        mkdir -p "$APPS_DIR"
        echo "$entry" > "$desktop_file"
        finalize_menu_entry "$desktop_file"
        print_success "Añadido al menú de aplicaciones"
        menu_yn="si"
    fi

    if [[ "$opt_where" == "2" || "$opt_where" == "3" ]]; then
        mkdir -p "$DESKTOP_DIR"
        local desk_file="$DESKTOP_DIR/scriptya-app-${id}.desktop"
        echo "$entry" > "$desk_file"
        finalize_desktop_shortcut "$desk_file"
        print_success "Acceso directo creado en el Escritorio"
        desktop_yn="si"
    fi

    registry_write "$id" "$META_MENU" "$script" "$icon_final" "$menu_yn" "$desktop_yn"

    echo
    print_success "'$META_MENU' instalado como aplicación independiente"
    echo
    pause
}

# change_icon_for_script <id> -> sustituye el icono de un script ya
# instalado como aplicación independiente, sin tocar su nombre ni su
# ubicación (menú/Escritorio). Actualiza los .desktop que existan de
# verdad en disco (no solo según el registro, por si alguno se borró a
# mano) para que el cambio se vea igual en el menú y en el Escritorio.
change_icon_for_script() {
    local id="$1"
    registry_read "$id" || { print_error "No se encuentra en el registro."; pause; return 1; }

    clear
    print_header "Cambiar icono"
    echo
    echo -e "Script: ${C_BOLD}${REG_NAME:-$id}${C_RESET}"
    echo -e "${C_DIM}${REG_SOURCE}${C_RESET}"
    echo -e "Icono actual: ${C_DIM}${REG_ICON:-utilities-terminal}${C_RESET}"
    echo

    local old_icon="$REG_ICON"
    choose_and_process_icon "$REG_SOURCE" "$id" "$old_icon"
    local icon_final="$PICKED_ICON_FINAL"

    local menu_file="$APPS_DIR/scriptya-app-${id}.desktop"
    local desk_file="$DESKTOP_DIR/scriptya-app-${id}.desktop"
    local updated="no"
    if [[ -f "$menu_file" ]]; then
        set_desktop_icon "$menu_file" "$icon_final"
        finalize_menu_entry "$menu_file"
        updated="si"
    fi
    if [[ -f "$desk_file" ]]; then
        set_desktop_icon "$desk_file" "$icon_final"
        finalize_desktop_shortcut "$desk_file"
        updated="si"
    fi

    if [[ "$updated" == "no" ]]; then
        print_error "No se encontró ningún acceso directo de este script para actualizar."
        pause
        return 1
    fi

    # Limpieza del icono anterior: solo si vivía en nuestra carpeta de
    # iconos y ha cambiado de fichero (un nombre de icono del tema, o el
    # mismo fichero elegido de nuevo, no se tocan).
    if [[ -n "$old_icon" && "$old_icon" == "$ICONS_DIR"/* && "$old_icon" != "$icon_final" ]]; then
        rm -f -- "$old_icon" 2>/dev/null
    fi

    registry_write "$id" "$REG_NAME" "$REG_SOURCE" "$icon_final" "$REG_MENU" "$REG_DESKTOP"

    echo
    print_success "Icono actualizado."
    echo
    pause
}

# change_main_icon -> sustituye el icono principal de Scriptya (el que
# llevan el acceso directo del Escritorio y la entrada del menú de
# aplicaciones, creados por --install o --desktop). Actualiza ya mismo
# los que existan en disco y guarda la elección en config.conf para que
# también se use la próxima vez que se creen.
change_main_icon() {
    clear
    print_header "Cambiar icono"
    echo
    echo -e "Aplicación: ${C_BOLD}Scriptya${C_RESET} ${C_DIM}(Escritorio + menú)${C_RESET}"
    echo -e "Icono actual: ${C_DIM}${SY_ICON:-utilities-terminal}${C_RESET}"
    echo

    local old_icon="$SY_ICON"
    choose_and_process_icon "" "_scriptya_self" "$old_icon"
    local icon_final="$PICKED_ICON_FINAL"

    local updated="no"
    if [[ -f "$DESKTOP_FILE" ]]; then
        set_desktop_icon "$DESKTOP_FILE" "$icon_final"
        finalize_menu_entry "$DESKTOP_FILE"
        updated="si"
    fi
    if [[ -f "$DESKTOP_SHORTCUT" ]]; then
        set_desktop_icon "$DESKTOP_SHORTCUT" "$icon_final"
        finalize_desktop_shortcut "$DESKTOP_SHORTCUT"
        updated="si"
    fi

    if [[ -n "$old_icon" && "$old_icon" == "$ICONS_DIR"/* && "$old_icon" != "$icon_final" ]]; then
        rm -f -- "$old_icon" 2>/dev/null
    fi

    SY_ICON="$icon_final"
    save_config

    echo
    if [[ "$updated" == "si" ]]; then
        print_success "Icono actualizado (Escritorio y/o menú)."
    else
        print_success "Icono guardado."
        print_info "Se usará la próxima vez que crees el acceso directo (--install o --desktop)."
    fi
    echo
    pause
}

# ------------------------------------------------------------
# ICONO DE CUALQUIER OTRO PROGRAMA INSTALADO EN EL SISTEMA
# ------------------------------------------------------------
# A diferencia de lo anterior (Scriptya y los scripts instalados con
# él), esto cubre cualquier aplicación con entrada de menú: Firefox,
# GIMP, LibreOffice... venga de un .deb, un Flatpak o un Snap.

# list_installed_apps -> escanea las carpetas estándar de ficheros
# .desktop (sistema y usuario) e imprime "ruta<TAB>nombre" de cada
# aplicación visible. Si el mismo fichero existe en varias carpetas, se
# queda con el de más prioridad (usuario > sistema), igual que hace el
# propio escritorio. Descarta las entradas ocultas (NoDisplay/Hidden) y
# las que ya gestiona Scriptya (esas van aparte, para no duplicarlas).
list_installed_apps() {
    local -a dirs=("$APPS_DIR") xdg_split=()
    IFS=':' read -ra xdg_split <<< "${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    local xdg_dir
    for xdg_dir in "${xdg_split[@]}"; do
        [[ -n "$xdg_dir" ]] && dirs+=("${xdg_dir%/}/applications")
    done
    dirs+=(
        "/var/lib/snapd/desktop/applications"
        "$HOME/.local/share/flatpak/exports/share/applications"
        "/var/lib/flatpak/exports/share/applications"
    )

    local -A seen=()
    local dir f base name type nodisplay hidden
    for dir in "${dirs[@]}"; do
        [[ -d "$dir" ]] || continue
        while IFS= read -r f; do
            [[ -n "$f" ]] || continue
            base="$(basename "$f")"
            [[ -n "${seen[$base]:-}" ]] && continue
            seen[$base]="1"
            case "$base" in
                scriptya-app-*.desktop|scriptya.desktop) continue ;;
            esac

            nodisplay="$(grep -m1 '^NoDisplay=' "$f" 2>/dev/null | cut -d= -f2-)"
            hidden="$(grep -m1 '^Hidden=' "$f" 2>/dev/null | cut -d= -f2-)"
            [[ "${nodisplay,,}" == "true" || "${hidden,,}" == "true" ]] && continue
            type="$(grep -m1 '^Type=' "$f" 2>/dev/null | cut -d= -f2-)"
            [[ -n "$type" && "$type" != "Application" ]] && continue

            name="$(grep -m1 '^Name=' "$f" 2>/dev/null | cut -d= -f2-)"
            [[ -z "$name" ]] && name="${base%.desktop}"
            printf '%s\t%s\n' "$f" "$name"
        done < <(find "$dir" -maxdepth 1 -type f -name "*.desktop" 2>/dev/null)
    done | sort -t $'\t' -k2,2 -f
}

# pick_installed_app -> deja elegir cualquier aplicación instalada, con
# búsqueda (fzf si está instalado; si no, lista numerada con filtro de
# texto, igual que el resto del programa sin fzf). Deja el resultado en
# PICKED_APP_FILE (ruta al .desktop) y PICKED_APP_NAME, vacíos si se
# cancela.
pick_installed_app() {
    local -a files=() names=()
    local f n
    while IFS=$'\t' read -r f n; do
        [[ -n "$f" ]] || continue
        files+=("$f"); names+=("$n")
    done < <(list_installed_apps)

    PICKED_APP_FILE=""; PICKED_APP_NAME=""

    if [[ ${#files[@]} -eq 0 ]]; then
        clear
        print_header "Cambiar icono"
        echo
        print_warning "No se encontró ninguna aplicación instalada."
        echo
        pause
        return 0
    fi

    if command_exists fzf; then
        local -a lines=()
        local idx sel
        for idx in "${!files[@]}"; do
            lines+=("$idx"$'\t'"${names[$idx]}")
        done
        sel="$(printf '%s\n' "${lines[@]}" | fzf --delimiter='\t' --with-nth=2.. \
            --header="Elige una aplicación instalada (Esc para cancelar)" --prompt="> " \
            --height=90% --reverse 2>/dev/null)"
        [[ -z "$sel" ]] && return 0
        idx="${sel%%$'\t'*}"
        PICKED_APP_FILE="${files[$idx]}"
        PICKED_APP_NAME="${names[$idx]}"
        return 0
    fi

    local filter="" filter_lc idx choice
    while true; do
        clear
        print_header "Elegir aplicación"
        echo
        [[ -n "$filter" ]] && print_info "  Filtro: \"$filter\""
        echo

        local -a shown=()
        local i=1
        filter_lc="${filter,,}"
        for idx in "${!files[@]}"; do
            if [[ -n "$filter" ]]; then
                [[ "${names[$idx],,}" == *"$filter_lc"* ]] || continue
            fi
            shown+=("$idx")
            echo "  $i) ${names[$idx]}"
            ((i++))
        done
        [[ ${#shown[@]} -eq 0 ]] && print_warning "Sin resultados para \"$filter\"."

        echo
        echo "  0) Volver"
        if [[ -n "$filter" ]]; then
            print_info "  (escribe para cambiar el filtro, Intro en blanco lo quita)"
        else
            print_info "  (escribe texto para filtrar por nombre)"
        fi
        echo

        if ! read -r -p "Selecciona una opción: " choice; then
            echo; return 0
        fi
        [[ "$choice" == "0" ]] && return 0

        if [[ -z "$choice" ]]; then
            filter=""
            continue
        fi

        if [[ "$choice" =~ ^[0-9]+$ ]] && (( 10#$choice >= 1 && 10#$choice <= ${#shown[@]} )); then
            idx="${shown[$((10#$choice-1))]}"
            PICKED_APP_FILE="${files[$idx]}"
            PICKED_APP_NAME="${names[$idx]}"
            return 0
        fi

        filter="$choice"
    done
}

# change_icon_for_installed_app <ruta.desktop> <nombre> -> cambia el
# icono de una aplicación instalada que Scriptya no gestiona. La
# mayoría de esos .desktop viven en carpetas del sistema
# (/usr/share/applications y similares) y no se pueden escribir sin
# root; en vez de pedir sudo, se usa el mismo mecanismo que ya usa
# Cinnamon/Nemo para overrides por usuario: una copia en $APPS_DIR con
# el mismo nombre de fichero, que tiene prioridad sobre la del sistema
# sin tocarla ni necesitar permisos sobre ella. Si el .desktop ya
# estaba en $APPS_DIR (app solo de usuario, o un override de una
# ejecución anterior de esto mismo), se edita directamente ahí.
change_icon_for_installed_app() {
    local src_file="$1" app_name="$2"
    local base target current_icon
    base="$(basename "$src_file")"
    target="$APPS_DIR/$base"

    clear
    print_header "Cambiar icono"
    echo
    echo -e "Aplicación: ${C_BOLD}${app_name}${C_RESET}"
    echo -e "${C_DIM}${src_file}${C_RESET}"
    current_icon="$(grep -m1 '^Icon=' "$src_file" 2>/dev/null | cut -d= -f2-)"
    echo -e "Icono actual: ${C_DIM}${current_icon:-(ninguno)}${C_RESET}"
    echo
    if [[ "$src_file" != "$target" ]]; then
        print_info "Es una app del sistema: el nuevo icono se guarda en una copia"
        print_info "personal (sin root); el original no se toca."
        echo
    fi

    local id; id="app-$(sanitize_id "$src_file")"
    choose_and_process_icon "" "$id" "$current_icon"
    local icon_final="$PICKED_ICON_FINAL"

    mkdir -p "$APPS_DIR"
    if [[ "$src_file" != "$target" ]] && ! cp -f "$src_file" "$target" 2>/dev/null; then
        print_error "No se pudo crear la copia en $APPS_DIR."
        pause
        return 1
    fi

    set_desktop_icon "$target" "$icon_final"
    finalize_menu_entry "$target"

    # Igual que change_icon_for_script: si el icono anterior era un
    # fichero nuestro (dentro de ICONS_DIR) y ha cambiado, se borra para
    # no acumular restos en cada cambio de icono.
    if [[ -n "$current_icon" && "$current_icon" == "$ICONS_DIR"/* && "$current_icon" != "$icon_final" ]]; then
        rm -f -- "$current_icon" 2>/dev/null
    fi

    echo
    print_success "Icono de '${app_name}' actualizado."
    echo
    pause
}

# Recorre las carpetas de scripts para elegir uno e instalarle un icono
pick_script_and_install_icon() {
    if [[ ! -d "$SCRIPTS_DIR" ]]; then
        print_error "No existe la carpeta de scripts: $SCRIPTS_DIR"
        pause
        return 1
    fi

    navigate "$SCRIPTS_DIR" "pick"
    [[ -n "$PICKED_SCRIPT" ]] && install_icon_for_script "$PICKED_SCRIPT"
}

# Lista los scripts instalados como apps independientes y deja elegir a
# cuál cambiarle el icono (llama a change_icon_for_script con el id)
pick_installed_icon_and_change() {
    local -a ids=()
    while IFS= read -r x; do [[ -n "$x" ]] && ids+=("$x"); done < <(list_installed_script_icons)

    clear
    print_header "Cambiar icono"
    echo

    if [[ ${#ids[@]} -eq 0 ]]; then
        print_warning "No hay ningún script instalado como aplicación todavía."
        echo
        pause
        return 0
    fi

    local i=1 id
    for id in "${ids[@]}"; do
        registry_read "$id"
        echo -e "  $i) ${C_BOLD}${REG_NAME:-$id}${C_RESET}"
        ((i++))
    done
    echo
    echo "  0) Volver"
    echo

    local n
    read -r -p "¿A cuál le cambias el icono?: " n
    if [[ -z "$n" || "$n" == "0" ]]; then
        return 0
    fi
    if ! [[ "$n" =~ ^[0-9]+$ ]] || (( 10#$n < 1 || 10#$n > ${#ids[@]} )); then
        print_error "Opción no válida."
        pause
        return 0
    fi

    change_icon_for_script "${ids[$((10#$n-1))]}"
}

# pick_icon_target_and_change -> entrada de "🎨 Cambiar Icono" desde el
# menú raíz: el icono principal de Scriptya, un script ya instalado, o
# cualquier otra aplicación del sistema (vía pick_installed_app). Un
# único sitio para cambiar cualquier icono, sea de quien sea.
pick_icon_target_and_change() {
    local -a ids=()
    while IFS= read -r x; do [[ -n "$x" ]] && ids+=("$x"); done < <(list_installed_script_icons)

    clear
    print_header "Cambiar icono"
    echo
    echo -e "  1) ${C_BOLD}Scriptya${C_RESET} ${C_DIM}(icono principal: Escritorio y menú)${C_RESET}"

    local i=2 id
    for id in "${ids[@]}"; do
        registry_read "$id"
        echo -e "  $i) ${REG_NAME:-$id}"
        ((i++))
    done
    local other_n=$i
    echo -e "  $other_n) ${C_DIM}Otro programa instalado en el sistema...${C_RESET}"
    local total=$other_n
    echo
    echo "  0) Volver"
    echo

    local n
    read -r -p "¿A cuál le cambias el icono?: " n
    if [[ -z "$n" || "$n" == "0" ]]; then
        return 0
    fi
    if ! [[ "$n" =~ ^[0-9]+$ ]] || (( 10#$n < 1 || 10#$n > total )); then
        print_error "Opción no válida."
        pause
        return 0
    fi

    if [[ "$n" == "1" ]]; then
        change_main_icon
    elif [[ "$n" == "$other_n" ]]; then
        pick_installed_app
        [[ -n "$PICKED_APP_FILE" ]] && change_icon_for_installed_app "$PICKED_APP_FILE" "$PICKED_APP_NAME"
    else
        change_icon_for_script "${ids[$((10#$n-2))]}"
    fi
}

# Lista los scripts instalados como apps independientes y permite
# desinstalar uno, varios o todos
manage_installed_icons() {
    local -a ids=()
    while IFS= read -r x; do [[ -n "$x" ]] && ids+=("$x"); done < <(list_installed_script_icons)

    clear
    print_header "Scripts instalados"
    echo

    if [[ ${#ids[@]} -eq 0 ]]; then
        print_warning "No hay ningún script instalado como aplicación todavía."
        echo
        pause
        return 0
    fi

    local i=1 id where
    for id in "${ids[@]}"; do
        registry_read "$id"
        if [[ "$REG_MENU" == "si" && "$REG_DESKTOP" == "si" ]]; then
            where="Menú + Escritorio"
        elif [[ "$REG_DESKTOP" == "si" ]]; then
            where="Escritorio"
        else
            where="Menú"
        fi
        echo -e "  $i) ${C_BOLD}${REG_NAME:-$id}${C_RESET} ${C_DIM}($where)${C_RESET}"
        [[ -n "$REG_SOURCE" ]] && echo -e "     ${C_DIM}$REG_SOURCE${C_RESET}"
        ((i++))
    done
    echo
    print_info "Puedes marcar varios separados por espacios (p.ej. 1 3), o escribir 'todos'."
    echo "  0) Volver"
    echo

    local input
    read -r -p "Desinstalar: " input

    if [[ -z "$input" || "$input" == "0" ]]; then
        return 0
    fi

    local -a targets=()
    if [[ "${input,,}" == "todos" || "${input,,}" == "all" ]]; then
        targets=("${ids[@]}")
    else
        local n
        for n in $input; do
            if ! [[ "$n" =~ ^[0-9]+$ ]] || (( 10#$n < 1 || 10#$n > ${#ids[@]} )); then
                print_error "Opción no válida: $n"
                pause
                return 0
            fi
            targets+=("${ids[$((10#$n-1))]}")
        done
    fi

    if [[ ${#targets[@]} -eq 0 ]]; then
        print_warning "No se ha marcado ningún script."
        pause
        return 0
    fi

    echo
    echo "Se desinstalará:"
    local t
    for t in "${targets[@]}"; do
        registry_read "$t"
        echo "  - ${REG_NAME:-$t}"
    done
    echo

    if confirm_yn "¿Continuar?"; then
        for t in "${targets[@]}"; do
            remove_script_icon "$t"
        done
        print_success "Script(s) desinstalado(s)."
    else
        print_info "Cancelado."
    fi
    pause
}

# Menú principal de gestión de scripts instalados como apps (--icons)
# Nota: esto mismo también está disponible directamente en el menú
# principal del launcher como "Instalar Scripts" / "Desinstalar
# Scripts"; este submenú se conserva como acceso rápido vía --icons.
do_manage_icons() {
    while true; do
        clear
        print_header "Instalar Scripts"
        echo
        echo "Instala scripts sueltos como aplicaciones independientes, con"
        echo "su propio icono, en el menú de Cinnamon y/o en el Escritorio."
        echo
        echo "  1) Instalar un script (elegir cuál, icono y ubicación)"
        echo "  2) Ver / desinstalar scripts ya instalados"
        echo "  3) Cambiar el icono de un script ya instalado"
        echo "  4) Volver"
        echo
        local opt
        read -r -p "Opción: " opt
        case "$opt" in
            1) pick_script_and_install_icon ;;
            2) manage_installed_icons ;;
            3) pick_installed_icon_and_change ;;
            4|"") return 0 ;;
            *) print_error "Opción no válida."; pause ;;
        esac
    done
}

# ============================================================
# ACCESO DIRECTO SIN INSTALAR
# ============================================================
# Crea un .desktop que ejecuta ESTE fichero (scriptya.sh) desde
# la ubicación en la que se encuentre ahora mismo. No copia nada, no
# crea comando en el PATH, no toca la configuración: es solo una forma
# rápida de tener un icono de doble clic sin pasar por --install.
do_make_desktop() {
    clear
    print_header "Scriptya - Acceso directo"
    echo
    echo "Esto crea un acceso directo (.desktop) que ejecuta este mismo"
    echo "fichero desde donde está ahora:"
    echo
    echo "    $SCRIPT_PATH"
    echo
    echo "No instala nada ni copia ficheros. Si mueves o borras este"
    echo "script, el acceso directo dejará de funcionar."
    echo
    echo "¿Dónde quieres crear el acceso directo?"
    echo
    echo "  1) Escritorio ($DESKTOP_DIR)"
    echo "  2) Menú de aplicaciones de Linux Mint"
    echo "  3) Ambos"
    echo "  4) Cancelar"
    echo
    local opt
    read -r -p "Opción: " opt

    local want_desktop="no" want_menu="no"
    case "$opt" in
        1) want_desktop="si" ;;
        2) want_menu="si" ;;
        3) want_desktop="si"; want_menu="si" ;;
        *) echo "Cancelado."; return 0 ;;
    esac

    local icon="$SY_ICON"
    local entry
    entry="$(cat <<EOF
[Desktop Entry]
Type=Application
Name=Scriptya
Comment=Ejecuta tus scripts personales organizados en carpetas
Exec=$(desktop_quote "$SCRIPT_PATH")
Icon=$icon
Terminal=true
Categories=Utility;
EOF
)"

    echo
    if [[ "$want_desktop" == "si" ]]; then
        mkdir -p "$(dirname "$DESKTOP_SHORTCUT")"
        echo "$entry" > "$DESKTOP_SHORTCUT"
        finalize_desktop_shortcut "$DESKTOP_SHORTCUT"
        print_success "Acceso directo creado en el Escritorio"
    fi

    if [[ "$want_menu" == "si" ]]; then
        mkdir -p "$APPS_DIR"
        echo "$entry" > "$DESKTOP_FILE"
        finalize_menu_entry "$DESKTOP_FILE"
        print_success "Añadido al menú de aplicaciones de Linux Mint"
    fi

    echo
    print_info "Puedes borrar el acceso directo cuando quieras;"
    print_info "el script original no se modifica ni se mueve."
    echo
    pause
}

# ============================================================
# ACTUALIZAR LA COPIA INSTALADA (sin repetir el asistente completo)
# ============================================================
do_update() {
    clear
    print_header "Scriptya - Actualizar"
    echo

    if [[ ! -x "$INSTALL_DIR/scriptya.sh" ]]; then
        print_error "No hay ninguna instalación existente (usa --install primero)."
        echo
        return 1
    fi

    if [[ "$SCRIPT_PATH" -ef "$INSTALL_DIR/scriptya.sh" ]]; then
        print_warning "Ya estás ejecutando la copia instalada."
        print_info "Ejecuta --update desde el scriptya.sh original (la fuente"
        print_info "que descargaste o editaste), no desde el comando 'scriptya'."
        echo
        return 1
    fi

    if ! cp "$SCRIPT_PATH" "$INSTALL_DIR/scriptya.sh" 2>/dev/null; then
        print_error "No se pudo actualizar la copia instalada."
        echo
        return 1
    fi
    chmod +x "$INSTALL_DIR/scriptya.sh"
    print_success "Copia instalada actualizada."
    print_info "  Origen:  $SCRIPT_PATH"
    print_info "  Destino: $INSTALL_DIR/scriptya.sh"
    echo
}

# ============================================================
# DESINSTALADOR
# ============================================================
do_uninstall() {
    clear
    print_header "Scriptya - Desinstalación"
    echo
    echo "Se eliminará:"
    echo "  - $INSTALL_DIR"
    echo "  - $BIN_LINK"
    echo "  - $DESKTOP_FILE"
    echo "  - $DESKTOP_SHORTCUT"
    echo
    echo "Tus scripts personales NO se tocarán."
    echo

    if ! confirm_yn "¿Continuar?"; then
        echo "Cancelado."
        return 0
    fi

    # Importante: comprobamos y gestionamos los scripts instalados como
    # aplicaciones independientes ANTES de borrar $INSTALL_DIR, porque
    # ahí es donde vive el registro que los rastrea.
    local -a icon_ids=()
    while IFS= read -r f; do [[ -n "$f" ]] && icon_ids+=("$f"); done < <(list_installed_script_icons)

    if [[ ${#icon_ids[@]} -gt 0 ]]; then
        print_warning "También hay ${#icon_ids[@]} script(s) instalado(s) como aplicación independiente."
        print_info "Si no los desinstalas ahora, dejarán de funcionar (necesitan este launcher instalado)."
        if confirm_yn "¿Desinstalarlos también?"; then
            local f
            for f in "${icon_ids[@]}"; do
                remove_script_icon "$f"
            done
            print_success "Scripts independientes desinstalados."
        fi
        echo
    fi

    rm -rf "$INSTALL_DIR"
    rm -f "$BIN_LINK" "$DESKTOP_FILE" "$DESKTOP_SHORTCUT"
    refresh_app_menu
    print_success "Scriptya desinstalado."
    echo

    if confirm_yn "¿Eliminar también la configuración guardada?"; then
        rm -rf "$CONFIG_DIR"
        print_success "Configuración eliminada."
    fi
}

# ============================================================
# AYUDA
# ============================================================
show_help() {
    cat <<EOF
Scriptya $SY_VERSION — por $SY_AUTHOR

Uso:
  scriptya.sh              Abre el menú de scripts. Al final del
                                  menú principal encontrarás también
                                  "Instalar Scripts", "Desinstalar
                                  Scripts", "Buscar Scripts" (para
                                  cambiar de carpeta de scripts con el
                                  selector de carpetas del sistema) y
                                  "Cambiar Icono" (el de Scriptya, el
                                  de un script instalado, o el de
                                  cualquier otro programa del sistema).
  scriptya.sh --desktop    Crea un acceso directo .desktop que
                                  ejecuta este fichero tal cual está,
                                  sin instalar nada
  scriptya.sh --install    Instala en el sistema (comando
                                  "scriptya", config, etc.)
  scriptya.sh --icons      Instala scripts sueltos como apps
                                  independientes (menú de Cinnamon y/o
                                  Escritorio) con icono personalizado.
                                  Igual que "Instalar Scripts" del menú.
  scriptya.sh --uninstall-icons
                                  Ver / desinstalar scripts instalados
                                  como apps independientes (uno, varios
                                  o todos). Igual que "Desinstalar
                                  Scripts" del menú.
  scriptya.sh --uninstall  Desinstala lo creado por --install
  scriptya.sh --update     Actualiza la copia instalada con esta
                                  versión del fichero, sin repetir el
                                  asistente de --install
  scriptya.sh --help       Muestra esta ayuda

Metadatos que puedes añadir en tus scripts (opcional):
  # MENU: Nombre bonito
  # DESCRIPTION: Descripción corta
  # CONFIRM: true|false
  # TERMINAL: true|false       (avisa con notificación de escritorio
                               al terminar, si hay 'notify-send')
  # SUDO: true|false
  # ORDER: número              (menor aparece antes; 500 por defecto)
  # ASK: mensaje                (repetible; pide un dato y lo pasa como
                               argumento posicional, en orden)
  # ICON: ruta/al/icono.png   (o nombre de icono del tema del sistema;
                               si se omite, se puede elegir navegando)

Cada ejecución queda registrada en:
  ~/.local/share/scriptya/history.log

Si no tienes 'fzf' instalado, en el menú numerado puedes escribir texto
en vez de un número para filtrar la lista por nombre.
EOF
}

# ============================================================
# MAIN
# ============================================================
main() {
    # Restos de ejecuciones en terminal interrumpidas a medio abrir
    # (Ctrl+C); solo toca temporales de más de 15 minutos, así que es
    # seguro llamarlo en cada arranque.
    cleanup_orphaned_tmp

    case "${1:-}" in
        --desktop|--shortcut) load_config; do_make_desktop; exit $? ;;
        --install)   load_config; do_install; exit $? ;;
        --icons)     load_config; do_manage_icons; exit $? ;;
        --uninstall-icons) load_config; manage_installed_icons; exit $? ;;
        --run-script)
            if [[ -z "${2:-}" ]]; then
                print_error "Uso: scriptya --run-script <ruta-al-script>"
                exit 1
            fi
            load_config
            run_script "$2" "inline"
            exit $?
            ;;
        --uninstall) load_config; do_uninstall; exit $? ;;
        --update)    do_update; exit $? ;;
        -h|--help)   show_help; exit 0 ;;
        --version)   echo "scriptya $SY_VERSION — por $SY_AUTHOR"; exit 0 ;;
        "")          ;;
        *)           print_error "Opción desconocida: $1"; echo; show_help; exit 1 ;;
    esac

    load_config

    if [[ ! -d "$SCRIPTS_DIR" ]]; then
        clear
        print_warning "Todavía no está configurada la carpeta de scripts."
        echo
        if confirm_yn "¿Ejecutar el asistente de instalación ahora?"; then
            do_install
            load_config
        elif ! mkdir -p "$SCRIPTS_DIR" 2>/dev/null || [[ ! -d "$SCRIPTS_DIR" ]]; then
            print_error "No se pudo crear '$SCRIPTS_DIR'."
            pause
        fi
    fi

    navigate "$SCRIPTS_DIR"
    clear
    echo -e "${C_CYAN}Hasta luego 👋${C_RESET}"
}

main "$@"

#!/bin/bash
#
# Copyright (C) 2026 Filonux
#
# Licencia:
#   Scriptya es software libre distribuido bajo los términos de la
#   GNU General Public License versión 3 (GPLv3).
#   Consulta el archivo LICENSE para obtener el texto completo de la
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
#                                     "Cambiar Icono" (el de Scriptya, el
#                                     de un script instalado, el de una
#                                     página web nueva vía "Icono para
#                                     HTML", o el de cualquier otro
#                                     programa del sistema), "Insertar
#                                     Metadatos", "Buscar Scripts" (para
#                                     cambiar la carpeta de scripts con
#                                     el selector de carpetas del
#                                     sistema), "Integración con Nemo"
#                                     (si está instalado) o "Ver
#                                     Historial" (últimas ejecuciones).
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
#   ./scriptya.sh --version    Muestra la versión
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

SY_VERSION="2.3.0"
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

# Integración con Nemo (opcional, ver más abajo)
NEMO_ACTIONS_DIR="$HOME/.local/share/nemo/actions"
BRAND_ICON_FILE="$ICONS_DIR/scriptya-brand.png"

# Valores por defecto (pueden sobreescribirse en config.conf)
SCRIPTS_DIR="$HOME/Scripts"
TERMINAL="x-terminal-emulator"
# El icono de marca (ver ensure_brand_icon_file, más abajo) es el que
# se usa por defecto en una instalación nueva. Si el usuario ya tenía
# config.conf de una versión anterior, ese valor guardado prevalece
# (load_config se ejecuta después y sobreescribe esta variable).
SY_ICON="$BRAND_ICON_FILE"

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
# crear/borrar un .desktop en $APPS_DIR. BUG real detectado:
# 'update-desktop-database' solo reconstruye asociaciones MIME (qué
# programa abre qué tipo de fichero), no el menú de aplicaciones -por
# eso el icono de Scriptya se creaba bien pero no aparecía en el menú de
# Cinnamon, mientras que el acceso directo del Escritorio sí, al
# refrescarse este por su cuenta-. La orden que de verdad fuerza a
# releer las entradas nuevas es 'xdg-desktop-menu forceupdate'.
refresh_app_menu() {
    command_exists update-desktop-database && update-desktop-database "$APPS_DIR" 2>/dev/null
    command_exists xdg-desktop-menu && xdg-desktop-menu forceupdate 2>/dev/null
    return 0
}

# finalize_menu_entry <ruta.desktop> -> hace ejecutable una entrada del
# menú de aplicaciones y refresca la caché.
finalize_menu_entry() {
    chmod +x "$1"
    refresh_app_menu
}

# finalize_desktop_shortcut <ruta.desktop> -> hace ejecutable un acceso
# directo del Escritorio y lo marca "de confianza" con 'gio' (evita el
# aviso de "Permitir lanzamiento" de Nemo, que mientras tanto muestra el
# nombre crudo del fichero y el icono genérico en vez de Name=/Icon=).
# 'gio set' puede devolver éxito (exit 0) sin que el marcado llegue a
# aplicarse de verdad (p.ej. el servicio de metadatos de gvfs tarda un
# instante en arrancar tras crearse el fichero); por eso no basta con
# mirar el código de salida, hay que releer el atributo con 'gio info'
# para confirmarlo, con varios reintentos antes de avisar.
is_marked_trusted() {
    gio info -a metadata::trusted "$1" 2>/dev/null | grep -q 'metadata::trusted: true'
}

finalize_desktop_shortcut() {
    local f="$1" intentos=0
    chmod +x "$f"

    if ! command_exists gio; then
        print_info "Instala 'libglib2.0-bin' (comando 'gio') para evitar el aviso de"
        print_info "permiso de tu gestor de archivos al abrir accesos directos nuevos."
        return 0
    fi

    while (( intentos < 6 )); do
        gio set "$f" metadata::trusted true >/dev/null 2>&1
        is_marked_trusted "$f" && return 0
        ((intentos++))
        sleep 0.3
    done

    print_warning "No se pudo marcar '$(basename -- "$f")' como 'de confianza'."
    print_info "Es un aviso de tu gestor de archivos, no de Scriptya: si al abrirlo pide"
    print_info "permiso, clic derecho sobre el icono > 'Permitir lanzamiento' (una vez)."
    print_info "Si el aviso no desaparece nunca, prueba en una terminal:"
    print_info "  rm -rf ~/.local/share/gvfs-metadata"
    print_info "y cierra sesión y vuelve a entrar (arregla una base de metadatos dañada,"
    print_info "un fallo conocido de Nemo)."
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
            # ORDER se guarda sin ceros a la izquierda: sorted_scripts hace
            # aritmética con él y bash trataría "018" como octal inválido.
            case "$key" in
                MENU)        META_MENU="$value" ;;
                DESCRIPTION) META_DESCRIPTION="$value" ;;
                CONFIRM)     META_CONFIRM="${value,,}" ;;
                TERMINAL)    META_TERMINAL="${value,,}" ;;
                SUDO)        META_SUDO="${value,,}" ;;
                ICON)        META_ICON="$value" ;;
                ORDER)       [[ "$value" =~ ^(-?)0*([0-9]+)$ ]] && META_ORDER="${BASH_REMATCH[1]}${BASH_REMATCH[2]}" ;;
                ASK)         META_ASK+=("$value") ;;
            esac
        fi
    done < "$script"
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

# list_html_files <dir> -> ficheros .html/.htm de una carpeta, para el
# asistente "Icono para HTML" (igual que list_images pero para webs).
list_html_files() {
    find "$1" -mindepth 1 -maxdepth 1 -type f ! -name ".*" \
        \( -iname "*.html" -o -iname "*.htm" \) -print 2>/dev/null | sort
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
        all_entries+=("action:insert_metadata");    all_labels+=("📝  Insertar Metadatos")
        all_entries+=("action:change_scripts_dir"); all_labels+=("🔍  Buscar Scripts")
        if command_exists nemo; then
            all_entries+=("action:nemo_integration"); all_labels+=("🖱️  Integración con Nemo")
        fi
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
        entries+=("action:insert_metadata")
        display+=("📝  Insertar Metadatos")
        entries+=("action:change_scripts_dir")
        display+=("🔍  Buscar Scripts")
        if command_exists nemo; then
            entries+=("action:nemo_integration")
            display+=("🖱️  Integración con Nemo")
        fi
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
                    insert_metadata)   pick_script_and_insert_metadata ;;
                    nemo_integration)  do_toggle_nemo_integration ;;
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
    SY_ICON="$(resolve_icon "$SY_ICON")"
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

    resync_installed_launchers

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
    slug="$(printf '%s' "$base" | tr -c 'A-Za-z0-9_-' '_')"
    hash="$(echo -n "$path" | cksum | cut -d' ' -f1)"
    echo "${slug}-${hash}"
}

# is_html_path <ruta> -> cierto si la extensión es .html/.htm (como
# list_html_files, sin distinguir mayúsculas).
is_html_path() {
    local ext="${1##*.}"
    ext="${ext,,}"
    [[ "$ext" == "html" || "$ext" == "htm" ]]
}

# registry_id_for <ruta> -> id de registro para esa ruta, con el mismo
# criterio (prefijo "html-") que usa install_icon_for_html. La usan
# nemo_uninstall_script y nemo_change_icon_script para reconocer un
# HTML ya instalado; antes recalculaban el id con sanitize_id a secas
# y nunca coincidía con lo que guarda install_icon_for_html.
registry_id_for() {
    if is_html_path "$1"; then
        echo "html-$(sanitize_id "$1")"
    else
        sanitize_id "$1"
    fi
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
    # registry_write <id> <name> <source> <icon> <menu_yn> <desktop_yn> [tipo:script|html]
    mkdir -p "$REGISTRY_DIR"
    printf '%s\n%s\n%s\n%s\n%s\n%s\n' "$2" "$3" "$4" "$5" "$6" "${7:-script}" > "$REGISTRY_DIR/$1.meta"
}

# registry_read <id> -> si existe, rellena REG_NAME/REG_SOURCE/REG_ICON/
# REG_MENU/REG_DESKTOP/REG_TYPE y devuelve 0. Si no existe, devuelve 1.
# REG_TYPE ("script" o "html") es compatible con fichas antiguas de 5
# líneas, sin ese campo: si falta, se asume "script".
registry_read() {
    local f="$REGISTRY_DIR/$1.meta"
    REG_NAME=""; REG_SOURCE=""; REG_ICON=""; REG_MENU="no"; REG_DESKTOP="no"; REG_TYPE="script"
    [[ -f "$f" ]] || return 1
    {
        IFS= read -r REG_NAME
        IFS= read -r REG_SOURCE
        IFS= read -r REG_ICON
        IFS= read -r REG_MENU
        IFS= read -r REG_DESKTOP
        IFS= read -r REG_TYPE
    } < "$f"
    [[ -z "$REG_TYPE" ]] && REG_TYPE="script"
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

# set_desktop_field <fichero.desktop> <campo> <valor> -> sustituye (o
# añade) una línea "<campo>=<valor>" solo dentro de [Desktop Entry], sin
# tocar el resto. Un .desktop de terceros puede traer secciones
# [Desktop Action ...] con su propio campo del mismo nombre (p.ej. Icon
# en "Nueva ventana"); quitar todas las líneas de golpe y añadir una al
# final, a lo bruto, pisaría esas u otras secciones.
set_desktop_field() {
    local file="$1" field="$2" value="$3" tmp line in_entry="false" written="false"
    [[ -f "$file" ]] || return 1
    tmp="$(mktemp)" || return 1

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^\[.+\]$ ]]; then
            if [[ "$in_entry" == "true" && "$written" == "false" ]]; then
                printf '%s=%s\n' "$field" "$value" >> "$tmp"
                written="true"
            fi
            [[ "$line" == "[Desktop Entry]" ]] && in_entry="true" || in_entry="false"
            printf '%s\n' "$line" >> "$tmp"
            continue
        fi
        [[ "$in_entry" == "true" && "$line" == "$field="* ]] && continue
        printf '%s\n' "$line" >> "$tmp"
    done < "$file"

    [[ "$in_entry" == "true" && "$written" == "false" ]] && printf '%s=%s\n' "$field" "$value" >> "$tmp"
    mv -f "$tmp" "$file"
}

set_desktop_icon() { set_desktop_field "$1" "Icon" "$2"; }

# resync_installed_launchers -> tras (re)instalar o actualizar, reescribe
# el Exec= de los .desktop de scripts ya instalados (--icons) con la ruta
# ACTUAL del launcher, y refresca las acciones de Nemo si están activas.
# BUG real: un icono creado ANTES de tener Scriptya instalado apunta al
# .sh suelto original; si esa copia se mueve o se borra tras instalar
# (el motivo típico para hacerlo), el icono se quedaba roto aunque
# Scriptya siguiera disponible.
resync_installed_launchers() {
    local launcher; launcher="$(launcher_exec_path)"
    local id menu_file desk_file new_exec menu_touched="false"

    while IFS= read -r id; do
        [[ -z "$id" ]] && continue
        registry_read "$id" || continue
        [[ "$REG_TYPE" == "html" ]] && continue   # Exec=xdg-open..., no usa el launcher

        new_exec="$(desktop_quote "$launcher") --run-script $(desktop_quote "$REG_SOURCE")"
        menu_file="$APPS_DIR/scriptya-app-${id}.desktop"
        desk_file="$DESKTOP_DIR/scriptya-app-${id}.desktop"

        if [[ -f "$menu_file" ]]; then
            set_desktop_field "$menu_file" "Exec" "$new_exec"
            chmod +x "$menu_file"
            menu_touched="true"
        fi
        [[ -f "$desk_file" ]] && { set_desktop_field "$desk_file" "Exec" "$new_exec"; finalize_desktop_shortcut "$desk_file"; }
    done < <(list_installed_script_icons)

    [[ "$menu_touched" == "true" ]] && refresh_app_menu
    nemo_integration_enabled && write_nemo_actions
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

# browse_for_leaf <carpeta_inicial> <list_fn> <etiqueta> <emoji> ->
# navegador genérico en modo texto (con fzf si está disponible) que
# muestra subcarpetas y los ficheros que devuelva <list_fn> (una
# función tipo list_images/list_html_files). Solo un fichero es un
# destino válido (a diferencia de browse_for_folder, aquí las carpetas
# solo sirven para entrar en ellas). Deja el resultado en PICKED_LEAF
# (vacío si se cancela). La usan browse_for_image y browse_for_html.
browse_for_leaf() {
    local list_fn="$2" label="$3" emoji="${4:-📄}"
    local -a stack=("${1:-$HOME}")
    PICKED_LEAF=""

    while true; do
        local dir="${stack[${#stack[@]}-1]}"
        local -a dirs=() items=() entries=() display=()
        local d f i=1

        while IFS= read -r d; do [[ -n "$d" ]] && dirs+=("$d"); done < <(list_dirs "$dir")
        while IFS= read -r f; do [[ -n "$f" ]] && items+=("$f"); done < <("$list_fn" "$dir")

        if command_exists fzf; then
            for d in "${dirs[@]}"; do entries+=("dir:$d");  display+=("📁  $(basename "$d")/"); done
            for f in "${items[@]}"; do entries+=("item:$f"); display+=("$emoji  $(basename "$f")"); done
            [[ ${#stack[@]} -gt 1 ]] && { entries+=("back:"); display+=("⬅️   Atrás"); }
            entries+=("cancel:"); display+=("✗   Cancelar")

            local -a lines=()
            local idx sel
            for idx in "${!entries[@]}"; do lines+=("$idx"$'\t'"${display[$idx]}"); done
            sel="$(printf '%s\n' "${lines[@]}" | fzf --delimiter='\t' --with-nth=2.. \
                --header="Elige $label — $dir" --prompt="> " \
                --height=90% --reverse 2>/dev/null)"
            [[ -z "$sel" ]] && return 0

            idx="${sel%%$'\t'*}"
            local entry="${entries[$idx]}" type path
            type="${entry%%:*}"; path="${entry#*:}"
            case "$type" in
                dir)    stack+=("$path") ;;
                item)   PICKED_LEAF="$path"; return 0 ;;
                back)   stack=("${stack[@]:0:$((${#stack[@]}-1))}") ;;
                cancel) return 0 ;;
            esac
        else
            clear
            print_header "Elegir $label"
            echo
            print_info "  $dir"
            echo
            for d in "${dirs[@]}"; do entries+=("dir:$d"); echo "  $i) 📁 $(basename "$d")"; ((i++)); done
            for f in "${items[@]}"; do entries+=("item:$f"); echo "  $i) $emoji $(basename "$f")"; ((i++)); done
            if [[ ${#dirs[@]} -eq 0 && ${#items[@]} -eq 0 ]]; then
                print_warning "No hay carpetas ni nada de eso aquí."
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
                PICKED_LEAF="$path"
                return 0
            fi
        fi
    done
}

# browse_for_image [carpeta_inicial] -> como browse_for_leaf, filtrado
# a imágenes. Deja el resultado en PICKED_IMAGE.
browse_for_image() {
    browse_for_leaf "${1:-$HOME}" list_images "una imagen" "🖼️"
    PICKED_IMAGE="$PICKED_LEAF"
}

# browse_for_html [carpeta_inicial] -> como browse_for_leaf, filtrado a
# ficheros .html/.htm. Deja el resultado en PICKED_HTML.
browse_for_html() {
    browse_for_leaf "${1:-$HOME}" list_html_files "un fichero HTML" "🌐"
    PICKED_HTML="$PICKED_LEAF"
}

# pick_html_via_zenity [carpeta_inicial] -> selector gráfico nativo (si
# hay 'zenity'), filtrado a ficheros HTML.
pick_html_via_zenity() {
    command_exists zenity || return 1
    zenity --file-selection \
        --title="Selecciona el fichero HTML" \
        --file-filter="HTML | *.html *.htm" \
        --filename="${1:-$HOME}/" 2>/dev/null
}

# pick_html [carpeta_inicial] -> selector combinado: 'zenity' si está
# instalado; si no, o si se cancela sin elegir nada, el navegador de
# texto. Deja el resultado en PICKED_HTML.
pick_html() {
    local start="${1:-$HOME}"
    PICKED_HTML=""
    if command_exists zenity; then
        local picked; picked="$(pick_html_via_zenity "$start")"
        if [[ -n "$picked" ]]; then
            PICKED_HTML="$picked"
            return 0
        fi
    fi
    browse_for_html "$start"
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
        # Formas habituales al teclear/pegar la ruta a mano: comillas
        # envolventes, "\ " de un autocompletado de bash pegado tal
        # cual, o un retorno de carro final. Se prueba una versión
        # limpia antes de rendirse y tratarlo como icono del tema.
        local cleaned="${icon_value%$'\r'}"
        if [[ "$cleaned" == \"*\" && "$cleaned" == *\" ]]; then
            cleaned="${cleaned#\"}"; cleaned="${cleaned%\"}"
        elif [[ "$cleaned" == \'*\' && "$cleaned" == *\' ]]; then
            cleaned="${cleaned#\'}"; cleaned="${cleaned%\'}"
        fi
        cleaned="${cleaned//\\ / }"
        cleaned="${cleaned/#\~/$HOME}"
        if [[ "$cleaned" != "$icon_path" && -f "$cleaned" ]]; then
            icon_path="$cleaned"
        else
            # No es un fichero existente: se asume nombre de icono del
            # tema del sistema (p.ej. "folder" o "utilities-terminal").
            PICKED_ICON_FINAL="$icon_value"
            return 0
        fi
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

# install_icon_for_html <ruta.html> -> asistente para dar icono propio
# a un proyecto/página HTML: crea un acceso directo que lo abre con el
# navegador predeterminado (xdg-open) mostrando ESE icono en vez del
# genérico del navegador. Usa el mismo registro que los scripts, así
# que "Cambiar Icono" y "Desinstalar Scripts" ya lo reconocen solo.
install_icon_for_html() {
    local html="$1"
    local id desktop_file name default_name
    id="$(registry_id_for "$html")"
    desktop_file="$APPS_DIR/scriptya-app-${id}.desktop"

    clear
    print_header "Icono para HTML"
    echo
    echo -e "${C_DIM}$html${C_RESET}"
    echo

    if registry_read "$id"; then
        print_warning "Este fichero ya está instalado como aplicación independiente."
        if ! confirm_yn "¿Reemplazarlo?"; then
            print_info "Cancelado."
            pause
            return 0
        fi
        remove_script_icon "$id"
        echo
    fi

    command_exists xdg-open || print_warning "No se encontró 'xdg-open' (paquete xdg-utils); instálalo para que el acceso abra bien el navegador."

    default_name="$(basename "$html")"
    default_name="${default_name%.*}"
    read -r -p "Nombre para el menú [$default_name]: " name
    name="${name:-$default_name}"
    echo

    # "$html" (no "") para que una ruta de icono relativa se resuelva
    # junto al HTML, igual que install_icon_for_script; sin 3er arg
    # para que muestre "Usar el icono genérico" (instalación nueva).
    choose_and_process_icon "$html" "$id"
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
    [[ "$opt_where" =~ ^[123]$ ]] || opt_where="3"

    local entry
    entry="$(cat <<EOF
[Desktop Entry]
Type=Application
Name=$name
Comment=Página o proyecto web
Exec=xdg-open $(desktop_quote "$html")
Icon=$icon_final
Terminal=false
Categories=Network;
X-Scriptya-Source=$html
X-Scriptya-Type=html
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

    registry_write "$id" "$name" "$html" "$icon_final" "$menu_yn" "$desktop_yn" "html"

    echo
    print_success "'$name' instalado con icono propio"
    echo
    pause
}

# pick_html_and_install_icon -> navega el sistema de ficheros para
# elegir un .html/.htm y lanzarle el asistente de icono propio.
pick_html_and_install_icon() {
    local start="$SCRIPTS_DIR"
    [[ -d "$start" ]] || start="$HOME"
    pick_html "$start"
    [[ -n "$PICKED_HTML" ]] && install_icon_for_html "$PICKED_HTML"
}

# change_icon_for_script <id> -> sustituye el icono de un script ya
# instalado como aplicación independiente, sin tocar su nombre ni su
# ubicación (menú/Escritorio). Actualiza los .desktop que existan de
# verdad en disco (no solo según el registro, por si alguno se borró a
# mano) para que el cambio se vea igual en el menú y en el Escritorio.
change_icon_for_script() {
    local id="$1"
    registry_read "$id" || { print_error "No se encuentra en el registro."; pause; return 1; }
    local label="Script"
    [[ "$REG_TYPE" == "html" ]] && label="Página web"

    clear
    print_header "Cambiar icono"
    echo
    echo -e "$label: ${C_BOLD}${REG_NAME:-$id}${C_RESET}"
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
    # mismo fichero elegido de nuevo, no se tocan). El icono de marca de
    # Scriptya nunca se borra aquí: es un recurso compartido (lo usa
    # también la integración con Nemo), no un icono desechable de este
    # script en concreto.
    if [[ -n "$old_icon" && "$old_icon" == "$ICONS_DIR"/* \
          && "$old_icon" != "$icon_final" && "$old_icon" != "$BRAND_ICON_FILE" ]]; then
        rm -f -- "$old_icon" 2>/dev/null
    fi

    registry_write "$id" "$REG_NAME" "$REG_SOURCE" "$icon_final" "$REG_MENU" "$REG_DESKTOP" "$REG_TYPE"

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
    SY_ICON="$(resolve_icon "$SY_ICON")"

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

    # El icono de marca ($BRAND_ICON_FILE) nunca se borra aquí aunque
    # viva dentro de $ICONS_DIR: a diferencia de los iconos generados
    # para un script o aplicación concretos, este se comparte con la
    # integración con Nemo (y es el valor por defecto de una instalación
    # nueva), así que borrarlo al cambiarlo rompería esas otras partes.
    if [[ -n "$old_icon" && "$old_icon" == "$ICONS_DIR"/* \
          && "$old_icon" != "$icon_final" && "$old_icon" != "$BRAND_ICON_FILE" ]]; then
        rm -f -- "$old_icon" 2>/dev/null
    fi

    SY_ICON="$icon_final"
    save_config

    # El menú contextual de Nemo usa su propia copia de este icono (ver
    # nemo_action_icon); si la integración está activa, se regenera
    # aquí para que el cambio se refleje también ahí, no solo en el
    # Escritorio/menú de aplicaciones.
    local nemo_synced="no"
    if nemo_integration_enabled; then
        write_nemo_actions
        nemo_synced="si"
    fi

    echo
    if [[ "$updated" == "si" ]]; then
        if [[ "$nemo_synced" == "si" ]]; then
            print_success "Icono actualizado (Escritorio, menú y Nemo)."
        else
            print_success "Icono actualizado (Escritorio y/o menú)."
        fi
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
    local base target desk_file current_icon
    base="$(basename "$src_file")"
    target="$APPS_DIR/$base"
    desk_file="$DESKTOP_DIR/$base"

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

    # Si la app también tiene acceso directo en el Escritorio (p.ej. "Añadir
    # al escritorio" desde el menú de Cinnamon), se actualiza igual para que
    # no se quede con el icono antiguo.
    if [[ -f "$desk_file" ]]; then
        set_desktop_icon "$desk_file" "$icon_final"
        finalize_desktop_shortcut "$desk_file"
    fi

    # Igual que change_icon_for_script: si el icono anterior era un
    # fichero nuestro (dentro de ICONS_DIR) y ha cambiado, se borra para
    # no acumular restos en cada cambio de icono. El icono de marca de
    # Scriptya se excluye por ser un recurso compartido (ver change_main_icon).
    if [[ -n "$current_icon" && "$current_icon" == "$ICONS_DIR"/* \
          && "$current_icon" != "$icon_final" && "$current_icon" != "$BRAND_ICON_FILE" ]]; then
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

# pick_icon_target_and_change -> entrada de "🎨 Cambiar Icono" desde el
# menú raíz: el icono principal de Scriptya, un script ya instalado,
# dar de alta el icono de una página web (HTML) nueva, o cualquier
# otra aplicación del sistema (vía pick_installed_app). Un único sitio
# para todo lo relacionado con iconos, sea de quien sea.
pick_icon_target_and_change() {
    local -a ids=()
    while IFS= read -r x; do [[ -n "$x" ]] && ids+=("$x"); done < <(list_installed_script_icons)

    clear
    print_header "Cambiar icono"
    echo
    echo -e "  1) ${C_BOLD}Scriptya${C_RESET} ${C_DIM}(icono principal: Escritorio y menú)${C_RESET}"

    local i=2 id badge
    for id in "${ids[@]}"; do
        registry_read "$id"
        badge="📄"; [[ "$REG_TYPE" == "html" ]] && badge="🌐"
        echo -e "  $i) $badge ${REG_NAME:-$id}"
        ((i++))
    done
    local html_n=$i
    echo -e "  $html_n) ${C_DIM}Icono para una página web (HTML)...${C_RESET}"
    ((i++))
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

    if (( 10#$n == 1 )); then
        change_main_icon
    elif (( 10#$n == html_n )); then
        # No cambia el icono de nada existente: da de alta una página
        # web nueva como aplicación independiente, con su propio icono
        # (mismo asistente que antes vivía suelto en el menú raíz).
        pick_html_and_install_icon
    elif (( 10#$n == other_n )); then
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

    local i=1 id where badge
    for id in "${ids[@]}"; do
        registry_read "$id"
        if [[ "$REG_MENU" == "si" && "$REG_DESKTOP" == "si" ]]; then
            where="Menú + Escritorio"
        elif [[ "$REG_DESKTOP" == "si" ]]; then
            where="Escritorio"
        else
            where="Menú"
        fi
        badge="📄"; [[ "$REG_TYPE" == "html" ]] && badge="🌐"
        echo -e "  $i) $badge ${C_BOLD}${REG_NAME:-$id}${C_RESET} ${C_DIM}($where)${C_RESET}"
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
        echo "Instala scripts sueltos (o proyectos HTML) como aplicaciones"
        echo "independientes, con su propio icono, en el menú de Cinnamon"
        echo "y/o en el Escritorio."
        echo
        echo "  1) Instalar un script (elegir cuál, icono y ubicación)"
        echo "  2) Ver / desinstalar lo ya instalado"
        echo "  3) Cambiar Icono (incluye HTML, Scriptya u otro programa)"
        echo "  4) Volver"
        echo
        local opt
        read -r -p "Opción: " opt
        case "$opt" in
            1) pick_script_and_install_icon ;;
            2) manage_installed_icons ;;
            3) pick_icon_target_and_change ;;
            4|"") return 0 ;;
            *) print_error "Opción no válida."; pause ;;
        esac
    done
}

# ============================================================
# INSERTAR METADATOS (plantilla simple para un script existente)
# ============================================================
# Rellena los metadatos opcionales (MENU, DESCRIPTION, CONFIRM,
# TERMINAL, SUDO, ORDER, ICON, ASK) de un script ya existente sin
# editarlo a mano. Solo sustituye esas líneas al principio del fichero
# (tras el shebang); cualquier otro comentario que hubiera se conserva.

# metadata_line_key <línea> -> si es un metadato reconocido ("# CLAVE:
# valor"), imprime CLAVE; si no, no imprime nada. La usa apply_metadata
# para separar metadatos (que se regeneran) de otros comentarios (que
# se conservan tal cual, p.ej. una cabecera de copyright).
metadata_line_key() {
    local line="${1%$'\r'}"
    [[ "$line" =~ ^#[[:space:]]*([A-Z]+):[[:space:]]*.*$ ]] || return 0
    case "${BASH_REMATCH[1]}" in
        MENU|DESCRIPTION|CONFIRM|TERMINAL|SUDO|ORDER|ASK|ICON) echo "${BASH_REMATCH[1]}" ;;
    esac
}

# script_has_metadata <script> -> 0 si el script tiene ya alguna línea
# de metadatos reconocida en la cabecera; 1 si no. Decide si al elegir
# un script se ofrece editar/eliminar o se pasa directo a insertar.
script_has_metadata() {
    local script="$1" line
    [[ -f "$script" ]] || return 1
    while IFS= read -r line; do
        line="${line%$'\r'}"
        [[ "$line" =~ ^#! ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^# ]] || break
        [[ -n "$(metadata_line_key "$line")" ]] && return 0
    done < "$script"
    return 1
}

# apply_metadata <script> -> escribe en <script> el bloque de metadatos
# preparado en las variables NEWMETA_* (las rellena
# insert_metadata_wizard). Un campo vacío, o un booleano en "false", no
# genera línea: es su valor por defecto y los metadatos son opcionales.
apply_metadata() {
    local script="$1"
    local -a lines=() other_header=() new_meta=()
    local shebang="" i=0 body_start line key m h a

    mapfile -t lines < "$script"
    [[ "${lines[0]:-}" =~ ^#! ]] && { shebang="${lines[0]}"; i=1; }

    body_start=$i
    while (( body_start < ${#lines[@]} )); do
        line="${lines[$body_start]%$'\r'}"
        [[ -z "$line" || "$line" =~ ^# ]] || break
        ((body_start++))
    done

    for (( ; i < body_start; i++ )); do
        key="$(metadata_line_key "${lines[$i]}")"
        [[ -z "$key" ]] && other_header+=("${lines[$i]}")
    done

    [[ -n "$NEWMETA_MENU" ]]            && new_meta+=("# MENU: $NEWMETA_MENU")
    [[ -n "$NEWMETA_DESCRIPTION" ]]     && new_meta+=("# DESCRIPTION: $NEWMETA_DESCRIPTION")
    [[ "$NEWMETA_CONFIRM" == "true" ]]  && new_meta+=("# CONFIRM: true")
    [[ "$NEWMETA_TERMINAL" == "true" ]] && new_meta+=("# TERMINAL: true")
    [[ "$NEWMETA_SUDO" == "true" ]]     && new_meta+=("# SUDO: true")
    [[ -n "$NEWMETA_ORDER" && "$NEWMETA_ORDER" != "500" ]] && new_meta+=("# ORDER: $NEWMETA_ORDER")
    [[ -n "$NEWMETA_ICON" ]]            && new_meta+=("# ICON: $NEWMETA_ICON")
    for a in "${NEWMETA_ASK[@]}"; do new_meta+=("# ASK: $a"); done

    {
        [[ -n "$shebang" ]] && printf '%s\n' "$shebang"
        for m in "${new_meta[@]}"; do printf '%s\n' "$m"; done
        for h in "${other_header[@]}"; do printf '%s\n' "$h"; done
        for (( ; body_start < ${#lines[@]}; body_start++ )); do
            printf '%s\n' "${lines[$body_start]}"
        done
    } > "${script}.sy_tmp" || return 1

    # El temporal nace con permisos por defecto, no con los del script
    # original: sin esto, un script con +x lo perdía solo por pasar por
    # este asistente.
    chmod --reference="$script" "${script}.sy_tmp" 2>/dev/null
    mv -f "${script}.sy_tmp" "$script"
}

# sync_installed_metadata <script> -> si <script> ya está instalado como
# aplicación independiente (--icons), refleja su MENU/DESCRIPTION
# actuales en el .desktop (menú y/o Escritorio) y en el registro. BUG
# real: editar los metadatos de un script ya instalado no cambiaba su
# nombre en el menú/acceso directo hasta reinstalar el icono a mano.
sync_installed_metadata() {
    local script="$1" id
    id="$(registry_id_for "$script")"
    registry_read "$id" || return 0

    read_metadata "$script"
    local menu_file="$APPS_DIR/scriptya-app-${id}.desktop"
    local desk_file="$DESKTOP_DIR/scriptya-app-${id}.desktop"
    local comment="${META_DESCRIPTION:-Script personal}"

    if [[ -f "$menu_file" ]]; then
        set_desktop_field "$menu_file" "Name" "$META_MENU"
        set_desktop_field "$menu_file" "Comment" "$comment"
        finalize_menu_entry "$menu_file"
    fi
    if [[ -f "$desk_file" ]]; then
        set_desktop_field "$desk_file" "Name" "$META_MENU"
        set_desktop_field "$desk_file" "Comment" "$comment"
        finalize_desktop_shortcut "$desk_file"
    fi

    registry_write "$id" "$META_MENU" "$REG_SOURCE" "$REG_ICON" "$REG_MENU" "$REG_DESKTOP" "$REG_TYPE"
}

# insert_metadata_wizard <script> -> plantilla simple: pregunta por cada
# campo (valor actual entre corchetes; Intro lo deja igual, "-" lo
# vacía) y guarda el resultado con apply_metadata.
insert_metadata_wizard() {
    local script="$1"
    if [[ ! -w "$script" ]]; then
        print_error "No tienes permiso de escritura sobre: $script"
        pause
        return 1
    fi

    read_metadata "$script"

    clear
    print_header "Insertar Metadatos"
    echo
    echo -e "Script: ${C_DIM}$script${C_RESET}"
    print_info "Intro para dejar el valor actual. Escribe - para vaciarlo."
    echo

    local v def a
    read -r -p "Nombre en el menú [$META_MENU]: " v
    NEWMETA_MENU="${v:-$META_MENU}"; [[ "$v" == "-" ]] && NEWMETA_MENU=""

    read -r -p "Descripción [$META_DESCRIPTION]: " v
    NEWMETA_DESCRIPTION="${v:-$META_DESCRIPTION}"; [[ "$v" == "-" ]] && NEWMETA_DESCRIPTION=""
    echo

    def=2; [[ "$META_CONFIRM" == "true" ]] && def=1
    echo "¿Pedir confirmación antes de ejecutar?  1) Sí   2) No"
    read -r -p "Opción [$def]: " v; v="${v:-$def}"
    [[ "$v" == "1" ]] && NEWMETA_CONFIRM="true" || NEWMETA_CONFIRM="false"

    def=2; [[ "$META_TERMINAL" == "true" ]] && def=1
    echo "¿Abrirlo en una terminal nueva?  1) Sí   2) No"
    read -r -p "Opción [$def]: " v; v="${v:-$def}"
    [[ "$v" == "1" ]] && NEWMETA_TERMINAL="true" || NEWMETA_TERMINAL="false"

    def=2; [[ "$META_SUDO" == "true" ]] && def=1
    echo "¿Ejecutarlo con sudo?  1) Sí   2) No"
    read -r -p "Opción [$def]: " v; v="${v:-$def}"
    [[ "$v" == "1" ]] && NEWMETA_SUDO="true" || NEWMETA_SUDO="false"
    echo

    read -r -p "Orden en el menú (número; 500 = por defecto) [$META_ORDER]: " v
    [[ "$v" == "-" ]] && v="500"
    if [[ -n "$v" && ! "$v" =~ ^-?[0-9]+$ ]]; then
        print_warning "No es un número; se mantiene $META_ORDER."
        v=""
    fi
    NEWMETA_ORDER="${v:-$META_ORDER}"

    read -r -p "Icono, ruta o nombre del tema [$META_ICON]: " v
    NEWMETA_ICON="${v:-$META_ICON}"; [[ "$v" == "-" ]] && NEWMETA_ICON=""
    echo

    NEWMETA_ASK=("${META_ASK[@]}")
    if [[ ${#META_ASK[@]} -gt 0 ]]; then
        echo "Datos pedidos por teclado antes de ejecutar (ASK):"
        for a in "${META_ASK[@]}"; do echo "  - $a"; done
    else
        echo "Datos pedidos por teclado antes de ejecutar (ASK): ninguno."
    fi
    if confirm_yn "¿Editarlos?"; then
        NEWMETA_ASK=()
        print_info "Escribe cada uno y pulsa Intro; línea en blanco para terminar."
        while true; do
            read -r -p "  ASK: " a
            [[ -z "$a" ]] && break
            NEWMETA_ASK+=("$a")
        done
    fi

    echo
    print_header "Resumen"
    echo
    [[ -n "$NEWMETA_MENU" ]]        && echo "  MENU: $NEWMETA_MENU"
    [[ -n "$NEWMETA_DESCRIPTION" ]] && echo "  DESCRIPTION: $NEWMETA_DESCRIPTION"
    echo "  CONFIRM: $NEWMETA_CONFIRM   TERMINAL: $NEWMETA_TERMINAL   SUDO: $NEWMETA_SUDO"
    [[ "$NEWMETA_ORDER" != "500" ]] && echo "  ORDER: $NEWMETA_ORDER"
    [[ -n "$NEWMETA_ICON" ]] && echo "  ICON: $NEWMETA_ICON"
    for a in "${NEWMETA_ASK[@]}"; do echo "  ASK: $a"; done
    echo

    if ! confirm_yn "¿Guardar estos metadatos en el script?"; then
        print_info "Cancelado."
        pause
        return 0
    fi

    if apply_metadata "$script"; then
        print_success "Metadatos guardados."
        sync_installed_metadata "$script"
    else
        print_error "No se pudieron guardar los metadatos."
    fi
    echo
    pause
}

# remove_metadata_wizard <script> -> "deshacer": confirma y borra de
# golpe el bloque de metadatos reconocidos (MENU/DESCRIPTION/CONFIRM/
# TERMINAL/SUDO/ORDER/ICON/ASK), reutilizando apply_metadata con las
# NEWMETA_* vacías/por defecto (así no generan línea), sin tocar el
# resto de la cabecera ni del script.
remove_metadata_wizard() {
    local script="$1"
    if [[ ! -w "$script" ]]; then
        print_error "No tienes permiso de escritura sobre: $script"
        pause
        return 1
    fi

    if ! confirm_yn "¿Eliminar los metadatos de este script?"; then
        print_info "Cancelado."
        pause
        return 0
    fi

    NEWMETA_MENU=""
    NEWMETA_DESCRIPTION=""
    NEWMETA_CONFIRM="false"
    NEWMETA_TERMINAL="false"
    NEWMETA_SUDO="false"
    NEWMETA_ORDER="500"
    NEWMETA_ICON=""
    NEWMETA_ASK=()

    if apply_metadata "$script"; then
        print_success "Metadatos eliminados."
        sync_installed_metadata "$script"
    else
        print_error "No se pudieron eliminar los metadatos."
    fi
    echo
    pause
}

# metadata_action_menu <script> -> el script ya tiene metadatos:
# elegir entre editarlos (asistente de siempre) o quitarlos de golpe
# ("deshacer"), sin repetir la plantilla completa solo para vaciarla.
metadata_action_menu() {
    local script="$1" opt
    clear
    print_header "Metadatos"
    echo
    echo -e "Script: ${C_DIM}$script${C_RESET}"
    print_info "Este script ya tiene metadatos."
    echo
    echo "  1) Editar metadatos"
    echo "  2) Eliminar metadatos (deshacer)"
    echo "  3) Cancelar"
    echo
    read -r -p "Opción: " opt
    case "$opt" in
        1) insert_metadata_wizard "$script" ;;
        2) remove_metadata_wizard "$script" ;;
        *) print_info "Cancelado."; pause ;;
    esac
}

# Recorre las carpetas de scripts para elegir uno; si ya tiene
# metadatos deja elegir entre editarlos o eliminarlos, y si no tiene
# ninguno pasa directo al asistente para insertarlos.
pick_script_and_insert_metadata() {
    if [[ ! -d "$SCRIPTS_DIR" ]]; then
        print_error "No existe la carpeta de scripts: $SCRIPTS_DIR"
        pause
        return 1
    fi
    navigate "$SCRIPTS_DIR" "pick"
    [[ -z "$PICKED_SCRIPT" ]] && return 0

    if script_has_metadata "$PICKED_SCRIPT"; then
        metadata_action_menu "$PICKED_SCRIPT"
    else
        insert_metadata_wizard "$PICKED_SCRIPT"
    fi
}

# ============================================================
# INTEGRACIÓN CON NEMO (menú del botón derecho, opcional y reversible)
# ============================================================
# Añade 4 acciones al menú contextual de Nemo (Lanzar, Instalar,
# Desinstalar, Cambiar icono) con el icono ACTUAL de Scriptya (el de
# marca, o el que el usuario haya puesto con "Cambiar Icono"; ver
# nemo_action_icon), visibles según el tipo de fichero (ver
# write_nemo_actions más abajo). Vive por completo en
# ~/.local/share/nemo/actions (nada del sistema); se desactiva en
# cualquier momento desde este mismo menú, sin dejar rastro.

# Icono de marca de Scriptya en base64 (PNG 128x128): valor por
# defecto de SY_ICON, para que el fichero siga siendo autocontenido y
# no dependa de tener un .png suelto al lado. Se escribe a disco (en
# $BRAND_ICON_FILE) solo la primera vez que hace falta de verdad: al
# instalar, crear acceso directo, activar Nemo o cambiar el icono (ver
# ensure_brand_icon_file).
SY_BRAND_ICON_B64="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"

nemo_integration_enabled() { [[ -f "$NEMO_ACTIONS_DIR/scriptya-run.nemo_action" ]]; }

# write_nemo_action <fichero> <nombre> <comentario> <flag> <extensiones>
# <icono> -> genera una acción de Nemo que llama a "scriptya <flag> %F",
# visible en cualquier fichero que cumpla <extensiones> (a propósito no
# se restringe más; ver write_nemo_actions). <icono> ya viene resuelto
# por nemo_action_icon: nunca se usa $BRAND_ICON_FILE directamente aquí.
# Quote=double es necesario para que Nemo entrecomille %F al
# sustituirlo: sin esto, un script en una ruta con espacios (p.ej. "Mis
# Scripts/x.sh") llegaba partido en varios argumentos.
write_nemo_action() {
    local file="$1" name="$2" comment="$3" flag="$4" ext="$5" icon="$6" launcher
    launcher="$(launcher_exec_path)"
    {
        echo "[Nemo Action]"
        echo "Name=$name"
        echo "Comment=$comment"
        echo "Exec=$(desktop_quote "$launcher") $flag %F"
        echo "Icon-Name=$icon"
        echo "Selection=s"
        echo "Extensions=$ext"
        echo "Quote=double"
    } > "$file"
}

# ensure_brand_icon_file -> escribe a disco (en $BRAND_ICON_FILE) el
# icono de marca de Scriptya, decodificando el PNG embebido en base64
# más arriba, si todavía no existe. Es la MISMA imagen que usa el
# icono principal de Scriptya por defecto (ver SY_ICON) y la
# integración con Nemo, para no duplicar la extracción ni arriesgarse
# a que uno de los dos sitios se quede con el icono genérico del tema.
# Se llama de forma perezosa (do_install, do_make_desktop,
# change_main_icon, write_nemo_actions) en vez de una sola vez al
# arrancar, para no escribir nada en disco si el usuario nunca instala
# ni activa la integración con Nemo.
ensure_brand_icon_file() {
    [[ -s "$BRAND_ICON_FILE" ]] && return 0
    mkdir -p "$ICONS_DIR"
    base64 -d <<< "$SY_BRAND_ICON_B64" > "$BRAND_ICON_FILE" 2>/dev/null
    [[ -s "$BRAND_ICON_FILE" ]]
}

# resolve_icon <valor> -> devuelve un icono utilizable en Icon= con
# garantías. BUG real detectado: SY_ICON (el icono actual, guardado en
# config.conf) puede quedar apuntando a un fichero que ya no existe -p.ej.
# tras "--uninstall" conservando la configuración, que recuerda la RUTA
# de un icono personalizado pero cuyo fichero vivía dentro de
# $INSTALL_DIR y se borró con él-. Antes, do_install/do_make_desktop
# solo regeneraban el icono si SY_ICON era EXACTAMENTE el de marca, así
# que esa ruta colgante se escribía tal cual en el siguiente Icon=: el
# acceso directo/entrada de menú apuntaban a la nada y el escritorio los
# mostraba con icono roto/genérico (y por eso "no se reconocía" como una
# aplicación instalada de verdad). Aquí, si <valor> es una ruta
# (empieza por "/") pero el fichero no existe, o si <valor> está vacío,
# se cae al icono de marca. Un nombre de icono del tema (sin "/", p.ej.
# "utilities-terminal") se devuelve tal cual: no hay fichero que comprobar.
resolve_icon() {
    local val="${1:-}"
    if [[ -n "$val" && "$val" != /* ]]; then
        echo "$val"
        return 0
    fi
    if [[ -n "$val" && -f "$val" ]]; then
        echo "$val"
        return 0
    fi
    ensure_brand_icon_file
    echo "$BRAND_ICON_FILE"
}

# nemo_action_icon -> valor listo para el "Icon-Name=" de las 4
# acciones de Nemo, a partir del icono ACTUAL de Scriptya ($SY_ICON, o
# el de marca si aún no hay ninguno). Muchas versiones de Nemo NO
# resuelven "Icon-Name" como ruta absoluta (solo nombres del tema del
# sistema); por eso antes el icono embebido dejaba de verse en cuanto
# se activaba la integración. La forma fiable, documentada por el
# propio Nemo, es copiar la imagen DENTRO de la carpeta de acciones y
# referenciarla como "<fichero>": así Nemo la busca ahí sin depender
# del tema. Si el icono actual ya es un nombre del tema (p.ej.
# "utilities-terminal", no una ruta a un fichero), se usa tal cual.
nemo_action_icon() {
    local icon="${SY_ICON:-$BRAND_ICON_FILE}"
    [[ "$icon" == "$BRAND_ICON_FILE" ]] && ensure_brand_icon_file
    [[ -f "$icon" ]] || { echo "$icon"; return 0; }

    mkdir -p "$NEMO_ACTIONS_DIR"
    rm -f "$NEMO_ACTIONS_DIR"/scriptya-icon.* 2>/dev/null
    local ext="${icon##*.}"
    ext="${ext,,}"
    if cp -f "$icon" "$NEMO_ACTIONS_DIR/scriptya-icon.$ext" 2>/dev/null; then
        echo "<scriptya-icon.$ext>"
    else
        echo "$icon"
    fi
}

# write_nemo_actions -> (re)genera los 4 .nemo_action con el icono
# actual (nemo_action_icon). Instalar/Desinstalar/Cambiar icono se ven
# SIEMPRE en todo .sh/.html/.htm, sin intentar adivinar de antemano si
# ya estaba instalado: esa detección dependía de que Nemo comparase
# rutas al vuelo (Files=) y fallaba a menudo, dejando p.ej. solo
# "Instalar" visible en un script ya instalado, o sin ninguna forma de
# cambiarle el icono. Cada acción resuelve el estado real al
# ejecutarse y avisa si no aplica (nemo_install_script,
# nemo_uninstall_script, nemo_change_icon_script). Lanzar sigue siendo
# solo .sh: abrir un HTML no pasa por Scriptya, ya lo hace el navegador
# con doble clic.
write_nemo_actions() {
    ensure_brand_icon_file
    mkdir -p "$NEMO_ACTIONS_DIR"
    local icon; icon="$(nemo_action_icon)"

    write_nemo_action "$NEMO_ACTIONS_DIR/scriptya-run.nemo_action" \
        "Lanzar con Scriptya" "Ejecuta este script con Scriptya" "--nemo-run" "sh;" "$icon"
    write_nemo_action "$NEMO_ACTIONS_DIR/scriptya-install.nemo_action" \
        "Instalar con Scriptya" "Lo instala como aplicación independiente" "--nemo-install" "sh;html;htm;" "$icon"
    write_nemo_action "$NEMO_ACTIONS_DIR/scriptya-uninstall.nemo_action" \
        "Desinstalar de Scriptya" "Quita su icono de aplicación independiente" "--nemo-uninstall" "sh;html;htm;" "$icon"
    write_nemo_action "$NEMO_ACTIONS_DIR/scriptya-change-icon.nemo_action" \
        "Cambiar icono (Scriptya)" "Cambia el icono de este script o página" "--nemo-change-icon" "sh;html;htm;" "$icon"

    reload_nemo
}

enable_nemo_integration() { write_nemo_actions; }

# reload_nemo -> fuerza a que Nemo recoja YA los .nemo_action nuevos.
# Nemo no siempre relee una acción reescrita con el mismo nombre hasta
# reiniciar, y son DOS procesos distintos: "nemo" (ventanas; -q la
# cierra y se relanza sola al abrir una carpeta) y "nemo-desktop"
# (iconos y menú del Escritorio; vive todo el rato y si solo se mata
# NO vuelve por sí sola). Sin relanzar esta segunda, el Escritorio se
# quedaba con el menú de antes -o sin iconos- hasta el siguiente inicio
# de sesión: era la causa real de que "Desinstalar" pareciera no
# aparecer nunca y de que reactivar la integración no sirviera de nada.
# Todo en segundo plano para no bloquear el asistente.
reload_nemo() {
    command_exists nemo || return 0
    (
        pgrep -x nemo >/dev/null 2>&1 && nemo -q >/dev/null 2>&1
        # Solo relanzamos nemo-desktop si YA estaba corriendo: si el
        # usuario no usa iconos de Escritorio, no se lo activamos nosotros.
        if pgrep -x nemo-desktop >/dev/null 2>&1; then
            killall nemo-desktop >/dev/null 2>&1
            sleep 0.3
            nohup nemo-desktop >/dev/null 2>&1 </dev/null &
            disown
        fi
    ) >/dev/null 2>&1 &
    disown
}

disable_nemo_integration() {
    # $BRAND_ICON_FILE NO se borra aquí: lo comparte el icono principal
    # de Scriptya (ver ensure_brand_icon_file). Borrarlo dejaría el
    # acceso directo/menú sin icono aunque Scriptya siga instalado. La
    # copia exclusiva de las acciones de Nemo (scriptya-icon.*, ver
    # nemo_action_icon) sí se borra, para no dejar rastro.
    rm -f "$NEMO_ACTIONS_DIR"/scriptya-run.nemo_action \
          "$NEMO_ACTIONS_DIR"/scriptya-install.nemo_action \
          "$NEMO_ACTIONS_DIR"/scriptya-uninstall.nemo_action \
          "$NEMO_ACTIONS_DIR"/scriptya-change-icon.nemo_action \
          "$NEMO_ACTIONS_DIR"/scriptya-icon.*
    reload_nemo
}

# print_nemo_matrix -> tabla de qué ve el usuario en Nemo según el
# fichero; la usa do_toggle_nemo_integration en sus dos estados
# (activada/desactivada) para no repetir el mismo texto dos veces.
print_nemo_matrix() {
    echo "  .sh   sin instalar -> Lanzar, Instalar"
    echo "  .sh   instalado    -> Lanzar, Desinstalar, Cambiar icono"
    echo "  .html sin instalar -> Cambiar icono, Instalar"
    echo "  .html instalado    -> Cambiar icono, Desinstalar"
}

# do_toggle_nemo_integration -> opción "🖱️ Integración con Nemo" del
# menú principal: activa o desactiva las 4 acciones de golpe.
do_toggle_nemo_integration() {
    clear
    print_header "Integración con Nemo"
    echo

    if nemo_integration_enabled; then
        print_success "Actualmente ACTIVADA."
        echo
        echo "Botón derecho en Nemo, según el fichero:"
        print_nemo_matrix
        echo
        if confirm_yn "¿Desactivarla?"; then
            disable_nemo_integration
            print_success "Integración con Nemo desactivada."
            print_info "Nemo (y los iconos del Escritorio) se reinician solos para reflejarlo."
        else
            print_info "Sin cambios."
        fi
    else
        echo "Añade al botón derecho de Nemo, según el fichero:"
        print_nemo_matrix
        echo
        print_info "No toca nada del sistema; es reversible desde aquí mismo."
        echo
        if ! command_exists nemo; then
            print_warning "No se detecta Nemo instalado; aun así puedes activarla."
            echo
        fi
        if confirm_yn "¿Activarla?"; then
            enable_nemo_integration
            print_success "Integración con Nemo activada."
            print_info "Nemo (y los iconos del Escritorio) se reinician solos para reflejarlo."
        else
            print_info "Cancelado."
        fi
    fi
    echo
    pause
}

# open_terminal_running <cmd...> -> abre <cmd...> en una terminal nueva
# (las acciones de Nemo no dan ninguna); si no hay terminal disponible,
# lo ejecuta aquí mismo. Las funciones que invoca ya hacen su propio
# pause() al terminar, así que no hace falta añadir otro aquí.
open_terminal_running() {
    local term tmp
    term="$TERMINAL"; command_exists "$term" || term="$(detect_terminal)"
    if ! command_exists "$term"; then
        "$@"
        return $?
    fi
    tmp="$(mktemp "${TMPDIR:-/tmp}/scriptya.XXXXXX.sh")" || { "$@"; return $?; }
    { printf '#!/bin/bash\n'; printf '%q ' "$@"; printf '\nrm -f -- %q\n' "$tmp"; } > "$tmp"
    chmod +x "$tmp"
    if ! "$term" -e "$tmp" 2>/dev/null; then
        rm -f -- "$tmp"
        "$@"
        return $?
    fi
}

# nemo_uninstall_script <ruta> -> acción "Desinstalar de Scriptya":
# quita el script de la lista de aplicaciones independientes si lo
# estaba (no toca el fichero del script en sí).
nemo_uninstall_script() {
    local script="$1" id
    id="$(registry_id_for "$script")"
    clear
    print_header "Desinstalar de Scriptya"
    echo
    if ! registry_read "$id"; then
        print_warning "Este script no está instalado como aplicación independiente."
        echo
        pause
        return 0
    fi
    echo -e "Se desinstalará: ${C_BOLD}${REG_NAME:-$id}${C_RESET}"
    echo -e "${C_DIM}$script${C_RESET}"
    echo
    if confirm_yn "¿Continuar?"; then
        remove_script_icon "$id"
        print_success "Desinstalado."
    else
        print_info "Cancelado."
    fi
    echo
    pause
}

# nemo_change_icon_script <ruta> -> acción "Cambiar icono (Scriptya)":
# si el script ya está instalado como aplicación independiente le
# cambia el icono; si no, ofrece instalarlo primero (sin instalar no
# hay ningún .desktop al que aplicarle un icono).
nemo_change_icon_script() {
    local script="$1" id label="script"
    id="$(registry_id_for "$script")"
    if registry_read "$id"; then
        change_icon_for_script "$id"
        return 0
    fi
    is_html_path "$script" && label="página"
    clear
    print_header "Cambiar icono"
    echo
    print_warning "Este $label no está instalado como aplicación independiente."
    print_info "Necesita estarlo para poder darle un icono propio."
    echo
    if confirm_yn "¿Instalarlo ahora?"; then
        if is_html_path "$script"; then
            install_icon_for_html "$script"
        else
            install_icon_for_script "$script"
        fi
    else
        pause
    fi
}

# nemo_install_script <ruta> -> acción "Instalar con Scriptya": igual
# despacho por tipo que ya usan nemo_uninstall_script y
# nemo_change_icon_script (antes esto SIEMPRE llamaba a
# install_icon_for_script, así que un .html instalado desde Nemo
# terminaba con un acceso directo que intentaba "ejecutarlo" como
# script en vez de abrirlo con el navegador).
nemo_install_script() {
    local target="$1"
    if is_html_path "$target"; then
        install_icon_for_html "$target"
    else
        install_icon_for_script "$target"
    fi
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

    local icon; icon="$(resolve_icon "$SY_ICON")"
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
    resync_installed_launchers
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
    nemo_integration_enabled && echo "  - Integración con Nemo (menú contextual)"
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

    # La integración con Nemo vive fuera de $INSTALL_DIR (en
    # ~/.local/share/nemo/actions): si no se desactiva aquí, el menú
    # contextual sobrevive apuntando a un launcher ya borrado.
    if nemo_integration_enabled; then
        disable_nemo_integration
        print_success "Integración con Nemo desactivada."
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
                                  Scripts", "Cambiar Icono" (el de
                                  Scriptya, el de un script instalado,
                                  el de una página web nueva vía
                                  "Icono para HTML", o el de cualquier
                                  otro programa del sistema), "Insertar
                                  Metadatos", "Buscar Scripts" (para
                                  cambiar de carpeta de scripts con el
                                  selector de carpetas del sistema),
                                  "Integración con Nemo" (si está
                                  instalado) o "Ver Historial"
                                  (últimas ejecuciones).
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
  scriptya.sh --version    Muestra la versión
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
        --install-script)
            if [[ -z "${2:-}" ]]; then
                print_error "Uso: scriptya --install-script <ruta-al-script>"
                exit 1
            fi
            load_config
            nemo_install_script "$2"
            exit $?
            ;;
        --uninstall-script)
            if [[ -z "${2:-}" ]]; then
                print_error "Uso: scriptya --uninstall-script <ruta-al-script>"
                exit 1
            fi
            load_config
            nemo_uninstall_script "$2"
            exit $?
            ;;
        --change-icon-script)
            if [[ -z "${2:-}" ]]; then
                print_error "Uso: scriptya --change-icon-script <ruta-al-script>"
                exit 1
            fi
            load_config
            nemo_change_icon_script "$2"
            exit $?
            ;;
        --nemo-run|--nemo-install|--nemo-uninstall|--nemo-change-icon)
            # Puntos de entrada que usan las 4 acciones de Nemo (ver
            # INTEGRACIÓN CON NEMO): abren una terminal nueva, porque
            # Nemo no da ninguna, y dentro reutilizan los flags de
            # arriba para no duplicar lógica.
            if [[ -z "${2:-}" ]]; then
                print_error "Uso: scriptya $1 <ruta-al-script>"
                exit 1
            fi
            load_config
            local sub_flag="--run-script"
            case "$1" in
                --nemo-install)      sub_flag="--install-script" ;;
                --nemo-uninstall)    sub_flag="--uninstall-script" ;;
                --nemo-change-icon)  sub_flag="--change-icon-script" ;;
            esac
            open_terminal_running "$(launcher_exec_path)" "$sub_flag" "$2"
            exit $?
            ;;
        --uninstall) load_config; do_uninstall; exit $? ;;
        --update)    load_config; do_update; exit $? ;;
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

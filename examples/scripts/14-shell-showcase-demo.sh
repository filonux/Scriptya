#!/usr/bin/env bash
# MENU: Demo — Shell Showcase
# DESCRIPTION: Colorful boxed dashboard, small table and a progress bar
# CONFIRM: false
# TERMINAL: false
# SUDO: false
# ORDER: 140
# ICON: ../assets/demo-blue.svg

set -uo pipefail

c_reset=$'\e[0m'; c_bold=$'\e[1m'; c_dim=$'\e[2m'
c_cyan=$'\e[36m'; c_green=$'\e[32m'; c_yellow=$'\e[33m'

# draw_box <título> <línea1> [línea2 ...] -> caja Unicode que se ajusta
# al contenido más ancho, en vez de un ancho fijo que se rompería con
# textos largos o con acentos/traducciones.
draw_box() {
    local title="$1"; shift
    local -a lines=("$title" "$@")
    local width=0 line
    for line in "${lines[@]}"; do
        (( ${#line} > width )) && width=${#line}
    done
    local pad=$((width + 2))
    printf '%b╔' "$c_cyan"
    printf '═%.0s' $(seq 1 "$pad")
    printf '╗\n'
    printf '║ %s%-*s%s ║\n' "$c_bold" "$width" "$title" "${c_reset}${c_cyan}"
    printf '╠'
    printf '═%.0s' $(seq 1 "$pad")
    printf '╣\n'
    for line in "${@}"; do
        printf '║ %-*s ║\n' "$width" "$line"
    done
    printf '╚'
    printf '═%.0s' $(seq 1 "$pad")
    printf '╝%b\n' "$c_reset"
}

value=${1:-demo}

draw_box "S C R I P T Y A" \
    "Panel de estado — demo local, sin red" \
    "Valor recibido: $value"
echo

printf '%bDatos del sistema%b\n' "$c_yellow" "$c_reset"
rows=(
    "Usuario|${USER:-desconocido}"
    "Equipo|$(hostname 2>/dev/null || echo desconocido)"
    "Fecha|$(date '+%Y-%m-%d %H:%M' 2>/dev/null)"
    "Shell|${SHELL:-desconocido}"
    "Kernel|$(uname -sr 2>/dev/null || echo desconocido)"
)
for row in "${rows[@]}"; do
    IFS='|' read -r label val <<< "$row"
    printf '  %b%-9s%b %s\n' "$c_green" "$label" "$c_reset" "$val"
done
echo

printf '%bProgreso%b  ' "$c_yellow" "$c_reset"
for _ in $(seq 1 24); do
    printf '█'
    sleep 0.02
done
printf ' 100%%\n\n'

printf '%b%bSHELL_SHOWCASE_DEMO_OK%b\n' "$c_bold" "$c_green" "$c_reset"

#!/usr/bin/env bash
# MENU: System Glance
# DESCRIPTION: A colorful one-look dashboard: uptime, memory and disk space
# CONFIRM: false
# TERMINAL: false
# SUDO: false
# ORDER: 180
# ICON: ../assets/showcase-gauge.svg

set -euo pipefail

if [[ -n "${NO_COLOR:-}" ]]; then
    c_cyan=""; c_green=""; c_yellow=""; c_red=""; c_dim=""; c_bold=""; c_reset=""
else
    c_cyan=$'\033[36m'; c_green=$'\033[32m'; c_yellow=$'\033[33m'
    c_red=$'\033[31m'; c_dim=$'\033[2m'; c_bold=$'\033[1m'; c_reset=$'\033[0m'
fi

# bar <porcentaje> -> barra de 20 bloques, verde/amarillo/rojo según el nivel.
bar() {
    local pct="$1" filled color i out=""
    filled=$(( pct * 20 / 100 ))
    (( filled > 20 )) && filled=20
    color="$c_green"; (( pct >= 60 )) && color="$c_yellow"; (( pct >= 85 )) && color="$c_red"
    for ((i = 0; i < 20; i++)); do
        if (( i < filled )); then out+="█"; else out+="░"; fi
    done
    printf '%s%s%s %3d%%\n' "$color" "$out" "$c_reset" "$pct"
}

echo -e "${c_bold}${c_cyan}Scriptya · System Glance${c_reset}"
echo "$(hostname 2>/dev/null || echo host) · $(date '+%Y-%m-%d %H:%M')"
echo

if command -v uptime >/dev/null 2>&1; then
    echo -e "${c_dim}Uptime${c_reset}    $(uptime -p 2>/dev/null || uptime)"
fi
read -r load1 _ < /proc/loadavg 2>/dev/null || load1="?"
cpus="$(nproc 2>/dev/null || echo '?')"
echo -e "${c_dim}Load avg${c_reset}  ${load1} ${c_dim}(1 min, ${cpus} CPU cores)${c_reset}"
echo

if [[ -r /proc/meminfo ]]; then
    mem_total_kb=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
    mem_avail_kb=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
    mem_used_kb=$(( mem_total_kb - mem_avail_kb ))
    mem_pct=$(( mem_total_kb > 0 ? mem_used_kb * 100 / mem_total_kb : 0 ))
    printf "%sMemory%s    " "$c_dim" "$c_reset"
    bar "$mem_pct"
    printf '           %s used of %s\n' "$(( mem_used_kb / 1024 ))MB" "$(( mem_total_kb / 1024 ))MB"
    echo
fi

if command -v df >/dev/null 2>&1; then
    read -r _ _ _ _ disk_pct _ < <(df -kP "$HOME" | tail -n 1)
    disk_pct="${disk_pct%%%}"
    printf "%sDisk (%s)%s " "$c_dim" "$HOME" "$c_reset"
    bar "${disk_pct:-0}"
fi

echo
echo -e "${c_dim}One script, zero setup: this is what Scriptya puts one click away.${c_reset}"
printf 'SYSTEM_GLANCE_OK\n'

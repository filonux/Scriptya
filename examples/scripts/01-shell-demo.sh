#!/usr/bin/env bash
# MENU: Demo — Shell
# DESCRIPTION: Baseline shell example with metadata, icon and argument passing
# CONFIRM: false
# TERMINAL: false
# SUDO: false
# ORDER: 10
# ICON: ../assets/demo-blue.svg

set -euo pipefail

value=${1:-demo}
printf 'SHELL_DEMO_OK|%s\n' "$value"

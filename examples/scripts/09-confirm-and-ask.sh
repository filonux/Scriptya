#!/usr/bin/env bash
# MENU: Demo — Confirm + ASK
# DESCRIPTION: Exercises confirmation and two ASK values
# CONFIRM: true
# TERMINAL: false
# SUDO: false
# ORDER: 90
# ASK: First value
# ASK: Second value
# ICON: ../assets/demo-green.svg

set -euo pipefail

first=${1:-}
second=${2:-}
printf 'CONFIRM_ASK_DEMO_OK|%s|%s\n' "$first" "$second"

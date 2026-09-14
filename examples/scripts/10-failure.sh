#!/usr/bin/env bash
# MENU: Demo — Failure and history
# DESCRIPTION: Deliberately exits with code 7 to test error handling and history
# CONFIRM: false
# TERMINAL: false
# SUDO: false
# ORDER: 100
# ICON: ../assets/demo-green.svg

set -euo pipefail

printf 'EXPECTED_FAILURE|7\n'
exit 7

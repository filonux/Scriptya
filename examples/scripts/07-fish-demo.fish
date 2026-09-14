#!/usr/bin/env fish
# MENU: Demo — Fish
# DESCRIPTION: Fish example with metadata, shebang and argument passing
# CONFIRM: false
# TERMINAL: false
# SUDO: false
# ORDER: 70
# ICON: ../assets/demo-blue.svg

set value demo
if test (count $argv) -gt 0
    set value $argv[1]
end
printf 'FISH_DEMO_OK|%s\n' "$value"

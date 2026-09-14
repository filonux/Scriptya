#!/usr/bin/env lua
-- MENU: Demo — Lua
-- DESCRIPTION: Lua example with metadata, shebang and argument passing
-- CONFIRM: false
-- TERMINAL: false
-- SUDO: false
-- ORDER: 60
-- ICON: ../assets/demo-blue.svg

local value = arg[1] or "demo"
print("LUA_DEMO_OK|" .. value)

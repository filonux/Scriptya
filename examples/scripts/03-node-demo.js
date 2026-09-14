#!/usr/bin/env node
// MENU: Demo — Node.js
// DESCRIPTION: Node.js example with metadata, shebang and argument passing
// CONFIRM: false
// TERMINAL: false
// SUDO: false
// ORDER: 30
// ICON: ../assets/demo-blue.svg

'use strict';

const value = process.argv[2] || 'demo';
console.log(`NODE_DEMO_OK|${value}`);

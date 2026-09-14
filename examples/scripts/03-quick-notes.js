#!/usr/bin/env node
// MENU: Quick Notes
// DESCRIPTION: Jots down a timestamped note next to the script and shows recent ones
// CONFIRM: false
// TERMINAL: false
// SUDO: false
// ORDER: 200
// ASK: What do you want to remember?
// ICON: ../assets/showcase-notepad.svg

'use strict';

const fs = require('fs');
const path = require('path');

const noColor = !!process.env.NO_COLOR;
const bold = noColor ? '' : '\x1b[1m';
const amber = noColor ? '' : '\x1b[33m';
const dim = noColor ? '' : '\x1b[2m';
const reset = noColor ? '' : '\x1b[0m';

const note = (process.argv[2] || '').trim();
const notesFile = path.join(__dirname, 'showcase-notes.txt');

console.log(`${bold}${amber}Scriptya · Quick Notes${reset}`);
console.log(`${dim}Stored locally in showcase-notes.txt, right next to this script.${reset}\n`);

if (note) {
    const stamp = new Date().toISOString().replace('T', ' ').slice(0, 16);
    fs.appendFileSync(notesFile, `${stamp}  ${note}\n`);
    console.log(`Saved: "${note}"\n`);
} else {
    console.log(`${dim}(No note entered this time — showing what is already there.)${reset}\n`);
}

let lines = [];
if (fs.existsSync(notesFile)) {
    lines = fs.readFileSync(notesFile, 'utf8').split('\n').filter(Boolean);
}

if (lines.length === 0) {
    console.log(`${dim}No notes yet. Run it again with a note to start the list.${reset}`);
} else {
    console.log(`${dim}Last ${Math.min(5, lines.length)} note(s):${reset}`);
    lines.slice(-5).forEach((line) => console.log(`  ${line}`));
}

console.log(`\nQUICK_NOTES_OK|${lines.length}`);

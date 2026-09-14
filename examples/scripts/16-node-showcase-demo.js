#!/usr/bin/env node
// MENU: Demo — Node.js Showcase
// DESCRIPTION: Boxed banner, bar chart and progress bar using only Node core
// CONFIRM: false
// TERMINAL: false
// SUDO: false
// ORDER: 160
// ICON: ../assets/demo-blue.svg

'use strict';

const RESET = '\x1b[0m', BOLD = '\x1b[1m', DIM = '\x1b[2m';
const CYAN = '\x1b[36m', GREEN = '\x1b[32m', YELLOW = '\x1b[33m', MAGENTA = '\x1b[35m';

// box(titulo, ...lineas) -> caja Unicode que se ajusta al contenido
// más ancho, en vez de un ancho fijo que se rompería con textos
// largos o con acentos/traducciones.
function box(title, ...lines) {
  const width = Math.max(title.length, ...lines.map((l) => l.length));
  const pad = (s) => s + ' '.repeat(width - s.length);
  const rule = '═'.repeat(width + 2);
  const out = [
    `${CYAN}╔${rule}╗`,
    `║ ${BOLD}${pad(title)}${RESET}${CYAN} ║`,
    `╠${rule}╣`,
    ...lines.map((l) => `║ ${pad(l)} ║`),
    `╚${rule}╝${RESET}`,
  ];
  return out.join('\n');
}

function barChart(data) {
  const top = Math.max(...Object.values(data)) || 1;
  for (const [label, value] of Object.entries(data)) {
    const filled = Math.round((value / top) * 24);
    const bar = '█'.repeat(filled) + '░'.repeat(24 - filled);
    console.log(`  ${label.padEnd(10)}${MAGENTA}${bar}${RESET} ${value}`);
  }
}

function sleep(ms) {
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
}

function progressBar(steps = 24) {
  for (let i = 0; i <= steps; i++) {
    const filled = '█'.repeat(i) + '░'.repeat(steps - i);
    const pct = Math.floor((i * 100) / steps);
    process.stdout.write(`\r  ${YELLOW}Cargando${RESET} ${filled} ${String(pct).padStart(3)}%`);
    sleep(20);
  }
  process.stdout.write('\n');
}

function main() {
  const value = process.argv[2] || 'demo';

  console.log(box('N O D E . J S', 'Panel de estado — demo local, sin red', `Valor recibido: ${value}`));
  console.log();

  console.log(`${YELLOW}Lenguajes preferidos (encuesta ficticia)${RESET}`);
  barChart({ Python: 24, Shell: 18, JavaScript: 15, Go: 8 });
  console.log();

  progressBar();
  console.log();

  console.log(`${DIM}Node.js ${process.version} · sin dependencias externas${RESET}`);
  console.log(`${BOLD}${GREEN}NODE_SHOWCASE_DEMO_OK${RESET}`);
}

main();

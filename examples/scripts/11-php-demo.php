#!/usr/bin/env php
<?php
// MENU: Demo — PHP CLI
// DESCRIPTION: PHP CLI example with metadata, shebang and argument passing
// CONFIRM: false
// TERMINAL: false
// SUDO: false
// ORDER: 110
// ASK: Demo value
// ICON: ../assets/demo-blue.svg

declare(strict_types=1);

$value = $argv[1] ?? 'demo';
printf("PHP_DEMO_OK|%s\n", $value);

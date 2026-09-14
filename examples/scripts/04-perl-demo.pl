#!/usr/bin/env perl
# MENU: Demo — Perl
# DESCRIPTION: Perl example with metadata, shebang and argument passing
# CONFIRM: false
# TERMINAL: false
# SUDO: false
# ORDER: 40
# ICON: ../assets/demo-blue.svg

use strict;
use warnings;

my $value = @ARGV ? $ARGV[0] : 'demo';
print "PERL_DEMO_OK|$value\n";

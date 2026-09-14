#!/usr/bin/env ruby
# MENU: Demo — Ruby
# DESCRIPTION: Ruby example with metadata, shebang and argument passing
# CONFIRM: false
# TERMINAL: false
# SUDO: false
# ORDER: 50
# ICON: ../assets/demo-blue.svg

# frozen_string_literal: true

value = ARGV.fetch(0, 'demo')
puts "RUBY_DEMO_OK|#{value}"

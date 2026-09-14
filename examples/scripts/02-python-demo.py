#!/usr/bin/env python3
# MENU: Demo — Python
# DESCRIPTION: Python example with metadata, shebang and argument passing
# CONFIRM: false
# TERMINAL: false
# SUDO: false
# ORDER: 20
# ICON: ../assets/demo-blue.svg

import sys


def main() -> int:
    value = sys.argv[1] if len(sys.argv) > 1 else "demo"
    print(f"PYTHON_DEMO_OK|{value}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

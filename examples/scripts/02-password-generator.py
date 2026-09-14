#!/usr/bin/env python3
# MENU: Secure Password
# DESCRIPTION: Asks two quick questions and generates a strong random password
# CONFIRM: false
# TERMINAL: false
# SUDO: false
# ORDER: 190
# ASK: Password length (8-64)
# ASK: Include symbols? (y/n)
# ICON: ../assets/showcase-key.svg

import math
import secrets
import string
import sys

C_BOLD, C_DIM, C_VIOLET, C_RESET = "\033[1m", "\033[2m", "\033[35m", "\033[0m"
if "NO_COLOR" in __import__("os").environ:
    C_BOLD = C_DIM = C_VIOLET = C_RESET = ""


def strength_label(bits: float) -> str:
    if bits < 40:
        return "weak — fine for a demo, not for a real account"
    if bits < 70:
        return "reasonable for everyday accounts"
    return "strong enough for sensitive accounts"


def main() -> int:
    args = sys.argv[1:]
    length_raw = args[0] if len(args) > 0 else "16"
    symbols_raw = args[1] if len(args) > 1 else "y"

    try:
        length = int(length_raw.strip())
    except ValueError:
        length = 16
    length = max(8, min(length, 64))

    alphabet = string.ascii_letters + string.digits
    wants_symbols = symbols_raw.strip().lower().startswith(("y", "s", "1"))
    if wants_symbols:
        alphabet += "!@#$%^&*()-_=+"

    password = "".join(secrets.choice(alphabet) for _ in range(length))
    bits = length * math.log2(len(alphabet))

    print(f"{C_BOLD}{C_VIOLET}Scriptya · Secure Password{C_RESET}")
    print(f"{C_DIM}Generated locally, never sent anywhere.{C_RESET}\n")
    print(f"  {C_BOLD}{password}{C_RESET}\n")
    print(f"{C_DIM}Length:{C_RESET}  {length} characters")
    print(f"{C_DIM}Symbols:{C_RESET} {'yes' if wants_symbols else 'no'}")
    print(f"{C_DIM}Estimate:{C_RESET} ~{bits:.0f} bits of entropy — {strength_label(bits)}")
    print(f"\nPASSWORD_DEMO_OK|{length}|{'y' if wants_symbols else 'n'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

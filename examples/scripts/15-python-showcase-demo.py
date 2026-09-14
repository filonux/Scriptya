#!/usr/bin/env python3
# MENU: Demo — Python Showcase
# DESCRIPTION: Boxed banner, bar chart and progress bar using only the stdlib
# CONFIRM: false
# TERMINAL: false
# SUDO: false
# ORDER: 150
# ICON: ../assets/demo-blue.svg

import sys
import time

RESET, BOLD, DIM = "\033[0m", "\033[1m", "\033[2m"
CYAN, GREEN, YELLOW, MAGENTA = "\033[36m", "\033[32m", "\033[33m", "\033[35m"


def box(title: str, *lines: str) -> str:
    """Caja Unicode que se ajusta al contenido más ancho."""
    width = max(len(title), *(len(line) for line in lines), 0)
    top = f"{CYAN}╔{'═' * (width + 2)}╗"
    head = f"║ {BOLD}{title:<{width}}{RESET}{CYAN} ║"
    sep = f"╠{'═' * (width + 2)}╣"
    body = [f"║ {line:<{width}} ║" for line in lines]
    bottom = f"╚{'═' * (width + 2)}╝{RESET}"
    return "\n".join([top, head, sep, *body, bottom])


def bar_chart(data) -> None:
    top = max(data.values()) or 1
    for label, value in data.items():
        filled = round((value / top) * 24)
        bar = "█" * filled + "░" * (24 - filled)
        print(f"  {label:<10}{MAGENTA}{bar}{RESET} {value}")


def progress_bar(steps: int = 24) -> None:
    for i in range(steps + 1):
        filled = "█" * i + "░" * (steps - i)
        print(f"\r  {YELLOW}Cargando{RESET} {filled} {i * 100 // steps:3d}%", end="", flush=True)
        time.sleep(0.02)
    print()


def main() -> int:
    value = sys.argv[1] if len(sys.argv) > 1 else "demo"

    print(box("P Y T H O N", "Panel de estado — demo local, sin red", f"Valor recibido: {value}"))
    print()

    print(f"{YELLOW}Lenguajes preferidos (encuesta ficticia){RESET}")
    bar_chart({"Python": 24, "Shell": 18, "JavaScript": 15, "Go": 8})
    print()

    progress_bar()
    print()

    print(f"{DIM}Python {sys.version.split()[0]} · sin dependencias externas{RESET}")
    print(f"{BOLD}{GREEN}PYTHON_SHOWCASE_DEMO_OK{RESET}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

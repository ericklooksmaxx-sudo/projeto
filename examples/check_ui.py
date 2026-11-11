"""Mostra quais bibliotecas de interface estão disponíveis e onde cada uma roda."""
import importlib
import os

LIBS = [
    # (módulo, nome, onde roda)
    ("curses", "curses (nativo)", "terminal"),
    ("rich", "Rich", "terminal"),
    ("textual", "Textual", "terminal"),
    ("prompt_toolkit", "prompt_toolkit", "terminal"),
    ("urwid", "urwid", "terminal"),
    ("blessed", "blessed", "terminal"),
    ("questionary", "questionary", "terminal"),
    ("tkinter", "Tkinter", "Termux:X11"),
    ("PyQt5", "PyQt5", "Termux:X11"),
    ("PyQt6", "PyQt6", "Termux:X11"),
    ("gi", "GTK (PyGObject)", "Termux:X11"),
    ("flask", "Flask", "navegador"),
    ("nicegui", "NiceGUI", "navegador"),
]


def main() -> None:
    width = max(len(n) for _, n, _ in LIBS)
    for module, name, where in LIBS:
        try:
            importlib.import_module(module)
            mark = "\033[32m✔\033[0m"
        except Exception:
            mark = "\033[2m·\033[0m"
        print(f" {mark} {name:<{width}}  {where}")
    if not os.environ.get("DISPLAY"):
        print("\nDica: para apps gráficos use 'tx11 python examples/tk_demo.py'.")


if __name__ == "__main__":
    main()

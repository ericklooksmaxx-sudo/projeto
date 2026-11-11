"""Menu interativo com Rich + questionary — bom ponto de partida para ferramentas CLI.

Rode: python examples/rich_menu.py
"""
import platform
import shutil

import questionary
from rich.console import Console
from rich.markup import escape
from rich.panel import Panel
from rich.table import Table

console = Console()


def show_info() -> None:
    table = Table(title="Sistema", show_header=False, border_style="cyan")
    table.add_row("Arquitetura", platform.machine())
    table.add_row("Python", platform.python_version())
    usage = shutil.disk_usage("/")
    table.add_row("Disco livre", f"{usage.free / 2**30:.1f} GiB")
    console.print(table)


def main() -> None:
    console.print(Panel.fit("[bold magenta]termux-plus[/] · menu de exemplo", border_style="magenta"))
    while True:
        choice = questionary.select(
            "O que você quer fazer?",
            choices=["Ver informações do sistema", "Dizer olá", "Sair"],
        ).ask()
        if choice is None or choice == "Sair":
            break
        if choice.startswith("Ver"):
            show_info()
        else:
            name = questionary.text("Seu nome:").ask() or "mundo"
            console.print(f"[green]Olá, {escape(name)}![/]", highlight=False)


if __name__ == "__main__":
    main()

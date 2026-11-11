"""Painel do sistema feito com Textual — funciona direto no terminal do Termux.

Rode: python examples/textual_demo.py   (q para sair, d para tema claro/escuro)
"""
import os
import platform
import shutil
import subprocess

from textual.app import App, ComposeResult
from textual.containers import Grid
from textual.widgets import DataTable, Footer, Header, Static


def battery() -> str:
    """Usa termux-battery-status (pacote termux-api) se estiver disponível."""
    if not shutil.which("termux-battery-status"):
        return "instale termux-api"
    try:
        import json

        out = subprocess.run(
            ["termux-battery-status"], capture_output=True, text=True, timeout=5, check=True
        ).stdout
        data = json.loads(out)
        return f"{data.get('percentage', '?')}% ({data.get('status', '?').lower()})"
    except (subprocess.SubprocessError, ValueError, OSError):
        return "indisponível"


def disk() -> str:
    usage = shutil.disk_usage(os.path.expanduser("~"))
    return f"{usage.free / 2**30:.1f} GiB livres de {usage.total / 2**30:.1f} GiB"


class Card(Static):
    DEFAULT_CSS = """
    Card { border: round $accent; padding: 0 1; height: 5; }
    """


class SystemPanel(App):
    TITLE = "termux-plus"
    SUB_TITLE = "painel do sistema"
    BINDINGS = [("q", "quit", "Sair"), ("d", "toggle_dark", "Tema"), ("r", "refresh", "Atualizar")]
    CSS = """
    Grid { grid-size: 2; grid-gutter: 1; padding: 1; height: auto; }
    DataTable { height: 1fr; margin: 0 1; }
    """

    def compose(self) -> ComposeResult:
        yield Header()
        with Grid():
            yield Card(id="cpu")
            yield Card(id="mem")
            yield Card(id="disk")
            yield Card(id="bat")
        yield DataTable(id="procs")
        yield Footer()

    def on_mount(self) -> None:
        table = self.query_one(DataTable)
        table.add_columns("PID", "Comando")
        self.action_refresh()
        self.set_interval(5, self.action_refresh)

    def action_refresh(self) -> None:
        load = os.getloadavg() if hasattr(os, "getloadavg") else (0, 0, 0)
        self.query_one("#cpu", Card).update(
            f"[b]CPU[/b]\n{platform.machine()} · {os.cpu_count()} núcleos\ncarga {load[0]:.2f}"
        )
        mem = "?"
        try:
            with open("/proc/meminfo") as f:
                info = dict(line.split(":", 1) for line in f)
            avail = int(info["MemAvailable"].split()[0]) / 2**20
            total = int(info["MemTotal"].split()[0]) / 2**20
            mem = f"{avail:.1f} GiB livres de {total:.1f} GiB"
        except (OSError, KeyError, ValueError):
            pass
        self.query_one("#mem", Card).update(f"[b]Memória[/b]\n{mem}")
        self.query_one("#disk", Card).update(f"[b]Armazenamento[/b]\n{disk()}")
        self.query_one("#bat", Card).update(f"[b]Bateria[/b]\n{battery()}")

        table = self.query_one(DataTable)
        table.clear()
        for pid in sorted((p for p in os.listdir("/proc") if p.isdigit()), key=int)[-50:]:
            try:
                with open(f"/proc/{pid}/cmdline", "rb") as f:
                    cmd = f.read().replace(b"\0", b" ").decode(errors="replace").strip()
            except OSError:
                continue
            if cmd:
                table.add_row(pid, cmd[:80])


if __name__ == "__main__":
    SystemPanel().run()

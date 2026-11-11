#!/data/data/com.termux/files/usr/bin/bash
# Instala bibliotecas Python para criar interfaces no Termux.
#
#  Camada 1 – Interfaces de terminal (TUI): funcionam direto no Termux.
#      rich, textual, prompt_toolkit, urwid, blessed, questionary, curses (nativo)
#  Camada 2 – Interfaces gráficas (GUI): precisam do app Termux:X11.
#      tkinter, PyQt5/PyQt6, GTK (PyGObject)
#  Camada 3 – Interfaces web: abrem no navegador do celular.
#      Flask, NiceGUI (opcional)
#
# Uso: bash scripts/gui.sh [--tui] [--x11] [--web]   (sem opções = --tui)
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$here/lib.sh"

TUI=0; X11=0; WEB=0
for a in "$@"; do
	case "$a" in
		--tui) TUI=1 ;;
		--x11) X11=1 ;;
		--web) WEB=1 ;;
		--all) TUI=1; X11=1; WEB=1 ;;
		-h|--help) sed -n '2,13p' "$0"; exit 0 ;;
		*) die "Opção desconhecida: $a" ;;
	esac
done
((TUI + X11 + WEB)) || TUI=1

require_termux
pkg_install python python-pip

if [[ "$TUI" == 1 ]]; then
	title "Interfaces de terminal (TUI)"
	# Todas são puras em Python, então o pip é o caminho certo aqui.
	pip_install rich textual prompt_toolkit urwid blessed questionary
fi

if [[ "$X11" == 1 ]]; then
	title "Interfaces gráficas via Termux:X11"
	enable_repo x11-repo
	pkg_install termux-x11-nightly xorg-xrandr openbox aterm
	pkg_install python-tkinter
	pkg_install pyqt5 pyqt6
	pkg_install gtk3 pygobject
	run install -Dm755 "$here/../bin/tx11" "${PREFIX:-/usr}/bin/tx11"
	ok "Comando 'tx11' instalado. Rode: tx11 python examples/tk_demo.py"
	warn "Instale também o app Termux:X11 (APK em github.com/termux/termux-x11/releases)."
fi

if [[ "$WEB" == 1 ]]; then
	title "Interfaces web"
	pip_install flask nicegui
	ok "Servidores web devem escutar em 127.0.0.1 (veja examples/web_demo.py)."
fi

title "Verificação"
if [[ "$DRY_RUN" != 1 ]]; then
	python "$here/../examples/check_ui.py" || true
fi

print_failures

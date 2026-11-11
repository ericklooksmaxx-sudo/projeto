#!/data/data/com.termux/files/usr/bin/bash
# termux-plus — instalador com menu.
#
#   bash install.sh                 menu interativo
#   bash install.sh ml gui ui       instala direto os módulos escolhidos
#   DRY_RUN=1 bash install.sh all   mostra o que seria feito, sem executar
#
# Módulos: ml, llm, gui, x11, web, ui, audit, all
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$here/scripts/lib.sh"

banner() {
	printf '%s' "$C_CYAN$C_BOLD"
	cat <<'EOF'
  _                                         _
 | |_ ___ _ __ _ __ ___  _   ___  __  _ __ | |_   _ ___
 | __/ _ \ '__| '_ ` _ \| | | \ \/ / | '_ \| | | | / __|
 | ||  __/ |  | | | | | | |_| |>  <  | |_) | | |_| \__ \
  \__\___|_|  |_| |_| |_|\__,_/_/\_\ | .__/|_|\__,_|___/
                                     |_|
EOF
	printf '%s' "$C_RESET"
}

run_module() {
	case "$1" in
		ml)    bash "$here/scripts/ml.sh" --full ;;
		llm)   bash "$here/scripts/ml.sh" --llm ;;
		gui)   bash "$here/scripts/gui.sh" --tui ;;
		x11)   bash "$here/scripts/gui.sh" --x11 ;;
		web)   bash "$here/scripts/gui.sh" --web ;;
		ui)    bash "$here/scripts/ui.sh" ;;
		audit) bash "$here/scripts/audit.sh" ;;
		all)   for m in ui gui ml audit; do run_module "$m" || warn "Módulo $m terminou com avisos"; done ;;
		*)     die "Módulo desconhecido: $1 (use: ml llm gui x11 web ui audit all)" ;;
	esac
}

if (($#)); then
	[[ "$1" == -h || "$1" == --help ]] && { sed -n '2,9p' "$0"; exit 0; }
	for m in "$@"; do run_module "$m"; done
	exit 0
fi

banner
OPTIONS=(
	"ui    Interface: teclas extras, tema, prompt com git"
	"ml    IA: PyTorch, NumPy, SciPy, pandas, ONNX, OpenCV"
	"llm   Modelos de linguagem locais: llama.cpp, ollama"
	"gui   Interfaces de terminal: Rich, Textual, urwid..."
	"x11   Interfaces gráficas: Tkinter, PyQt, GTK (Termux:X11)"
	"web   Interfaces web: Flask, NiceGUI"
	"audit Auditoria de segurança"
	"all   ui + gui + ml + audit"
	"sair"
)
PS3=$'\n'"Escolha um número: "
select opt in "${OPTIONS[@]}"; do
	[[ -n "${opt:-}" ]] || { warn "Opção inválida"; continue; }
	mod="${opt%% *}"
	[[ "$mod" == sair ]] && break
	run_module "$mod" || warn "Módulo $mod terminou com avisos"
	echo
done

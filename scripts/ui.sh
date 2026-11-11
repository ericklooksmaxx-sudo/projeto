#!/data/data/com.termux/files/usr/bin/bash
# Melhora a interface do Termux: teclas extras, tema de cores, prompt e atalhos.
# Faz backup de tudo antes de alterar. Desfazer: bash scripts/ui.sh --restore
#
# Uso: bash scripts/ui.sh [--theme dracula|nord|gruvbox|catppuccin] [--restore]
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"
# shellcheck source=scripts/lib.sh
source "$here/lib.sh"

THEME="catppuccin"; RESTORE=0
while (($#)); do
	case "$1" in
		--theme) THEME="${2:?informe o nome do tema}"; shift ;;
		--restore) RESTORE=1 ;;
		-h|--help) sed -n '2,6p' "$0"; exit 0 ;;
		*) die "Opção desconhecida: $1" ;;
	esac
	shift
done

HOME_DIR="${HOME:?}"
TDIR="$HOME_DIR/.termux"
BASHRC="$HOME_DIR/.bashrc"
MARK_BEGIN="# >>> termux-plus >>>"
MARK_END="# <<< termux-plus <<<"

reload() {
	if command -v termux-reload-settings >/dev/null 2>&1; then
		run termux-reload-settings
	else
		warn "Feche e abra o Termux para aplicar."
	fi
}

latest_backup() { find "$(dirname "$1")" -maxdepth 1 -name "$(basename "$1").bak.*" 2>/dev/null | sort | tail -n1; }

if [[ "$RESTORE" == 1 ]]; then
	title "Restaurando configuração anterior"
	for f in "$TDIR/termux.properties" "$TDIR/colors.properties"; do
		b=$(latest_backup "$f")
		if [[ -n "$b" ]]; then run cp -p -- "$b" "$f"; ok "Restaurado $f"; else run rm -f -- "$f"; fi
	done
	if [[ -f "$BASHRC" ]]; then
		run sed -i "/^$MARK_BEGIN\$/,/^$MARK_END\$/d" "$BASHRC"
		ok "Bloco termux-plus removido do .bashrc"
	fi
	reload
	exit 0
fi

theme_file="$root/config/themes/$THEME.properties"
if [[ ! -f "$theme_file" ]]; then
	themes=("$root"/config/themes/*.properties)
	themes=("${themes[@]##*/}")
	die "Tema '$THEME' não existe. Opções: ${themes[*]%.properties}"
fi

title "Interface do Termux"
run mkdir -p "$TDIR"

backup_file "$TDIR/termux.properties"
run cp -- "$root/config/termux.properties" "$TDIR/termux.properties"
ok "Teclas extras e comportamento configurados"

backup_file "$TDIR/colors.properties"
run cp -- "$theme_file" "$TDIR/colors.properties"
ok "Tema: $THEME"

# Adiciona (ou atualiza) um bloco delimitado no .bashrc, sem duplicar.
run touch "$BASHRC"
if [[ "$DRY_RUN" != 1 ]]; then
	backup_file "$BASHRC"
	sed -i "/^$MARK_BEGIN\$/,/^$MARK_END\$/d" "$BASHRC"
	{
		echo "$MARK_BEGIN"
		echo "export TERMUX_PLUS_DIR=\"$root\""
		echo "[ -f \"$root/config/bashrc.sh\" ] && . \"$root/config/bashrc.sh\""
		echo "$MARK_END"
	} >>"$BASHRC"
fi
ok "Prompt, aliases e funções adicionados ao .bashrc"

# Utilitários usados pelo prompt e aliases (opcionais).
pkg_install git ncurses-utils

reload
ok "Pronto! Abra uma nova sessão para ver o prompt novo."

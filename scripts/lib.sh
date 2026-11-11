#!/data/data/com.termux/files/usr/bin/bash
# shellcheck shell=bash
# Funções compartilhadas pelos scripts do termux-plus.
# Este arquivo é carregado com "source"; não execute diretamente.

# --- Cores (desligadas quando a saída não é um terminal ou NO_COLOR está definido)
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
	C_RESET=$'\e[0m'; C_BOLD=$'\e[1m'; C_DIM=$'\e[2m'
	C_RED=$'\e[31m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'
	C_BLUE=$'\e[34m'; C_CYAN=$'\e[36m'
else
	C_RESET=''; C_BOLD=''; C_DIM=''; C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_CYAN=''
fi
export C_RESET C_BOLD C_DIM C_RED C_GREEN C_YELLOW C_BLUE C_CYAN

info()  { printf '%s==>%s %s\n' "${C_BLUE}${C_BOLD}" "$C_RESET" "$*"; }
ok()    { printf '%s ✔%s  %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()  { printf '%s ⚠%s  %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()   { printf '%s ✖%s  %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die()   { err "$*"; exit 1; }
title() { printf '\n%s%s%s\n%s\n' "${C_CYAN}${C_BOLD}" "$*" "$C_RESET" "${C_DIM}$(printf '%*s' "${#1}" '' | tr ' ' '─')${C_RESET}"; }

# DRY_RUN=1 mostra os comandos sem executá-los (útil para testes e para revisar).
DRY_RUN="${DRY_RUN:-0}"

run() {
	if [[ "$DRY_RUN" == 1 ]]; then
		printf '%s[dry-run]%s %s\n' "$C_DIM" "$C_RESET" "$*"
		return 0
	fi
	"$@"
}

# Detecta se estamos dentro do Termux.
is_termux() {
	[[ -n "${TERMUX_VERSION:-}" ]] || [[ "${PREFIX:-}" == */com.termux/files/usr ]]
}

require_termux() {
	if ! is_termux && [[ "$DRY_RUN" != 1 && "${TERMUX_PLUS_FORCE:-0}" != 1 ]]; then
		die "Este script foi feito para o Termux. Use DRY_RUN=1 para simular ou TERMUX_PLUS_FORCE=1 para forçar."
	fi
}

# Confirmação interativa. ASSUME_YES=1 responde "sim" automaticamente.
confirm() {
	local prompt="${1:-Continuar?}" reply
	[[ "${ASSUME_YES:-0}" == 1 ]] && return 0
	[[ -t 0 ]] || return 1
	read -r -p "$prompt [s/N] " reply
	[[ "$reply" =~ ^([sSyY]|sim|Sim|yes)$ ]]
}

# Verifica se um pacote apt já está instalado.
pkg_installed() {
	dpkg -s "$1" >/dev/null 2>&1
}

# Atualiza a lista de pacotes no máximo uma vez por execução.
_PKG_UPDATED=0
pkg_update_once() {
	[[ "$_PKG_UPDATED" == 1 ]] && return 0
	info "Atualizando lista de pacotes"
	run pkg update -y || warn "Falha ao atualizar a lista; tentando continuar"
	_PKG_UPDATED=1
}

# Instala pacotes, pulando os já instalados e tentando novamente em caso de
# falha de rede. Pacotes que falham são registrados em FAILED_PKGS em vez de
# abortar o script inteiro.
FAILED_PKGS=()
pkg_install() {
	local missing=() p attempt
	for p in "$@"; do
		if [[ "$DRY_RUN" != 1 ]] && pkg_installed "$p"; then
			ok "$p já instalado"
		else
			missing+=("$p")
		fi
	done
	((${#missing[@]})) || return 0
	pkg_update_once
	info "Instalando: ${missing[*]}"
	for attempt in 1 2 3; do
		if run pkg install -y "${missing[@]}"; then
			return 0
		fi
		warn "Tentativa $attempt falhou; aguardando antes de tentar de novo"
		sleep $((attempt * 3))
	done
	# Última chance: instala um por um para descobrir qual pacote falhou.
	for p in "${missing[@]}"; do
		run pkg install -y "$p" || { err "Falhou: $p"; FAILED_PKGS+=("$p"); }
	done
}

# pip dentro do Termux: nunca use "pip install --upgrade pip" (quebra o pacote
# python-pip do apt). Sempre use "python -m pip" para garantir o Python certo.
FAILED_PIP=()
pip_install() {
	local p
	for p in "$@"; do
		info "pip: $p"
		run python -m pip install --disable-pip-version-check --no-input "$p" \
			|| { err "pip falhou: $p"; FAILED_PIP+=("$p"); }
	done
}

# Habilita repositórios extras (x11-repo, tur-repo) se ainda não estiverem.
enable_repo() {
	local repo="$1"
	if [[ "$DRY_RUN" != 1 ]] && pkg_installed "$repo"; then
		ok "Repositório $repo já habilitado"
		return 0
	fi
	pkg_install "$repo"
	_PKG_UPDATED=0
}

print_failures() {
	if ((${#FAILED_PKGS[@]} + ${#FAILED_PIP[@]})); then
		title "Itens que falharam"
		((${#FAILED_PKGS[@]})) && err "pkg: ${FAILED_PKGS[*]}"
		((${#FAILED_PIP[@]})) && err "pip: ${FAILED_PIP[*]}"
		warn "Rode novamente mais tarde ou veja a seção 'Problemas comuns' do README."
		return 1
	fi
	ok "Tudo instalado sem erros"
}

# Faz backup de um arquivo antes de sobrescrevê-lo.
backup_file() {
	local f="$1"
	[[ -e "$f" ]] || return 0
	local dest
	dest="$f.bak.$(date +%Y%m%d-%H%M%S)"
	run cp -p -- "$f" "$dest" && ok "Backup: $dest"
}

# shellcheck shell=bash
# termux-plus — prompt, aliases e funções. Carregado pelo ~/.bashrc.

# Só em shells interativos.
[[ $- == *i* ]] || return 0

# --- Histórico mais útil
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
# Comandos começando com espaço não vão para o histórico (bom para tokens).
shopt -s histappend checkwinsize cdspell 2>/dev/null

# --- Prompt: diretório, branch do git, venv do Python e status do último comando
__tp_git_branch() {
	local b
	b=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null) || return
	b=${b//\\/\\\\}  # escapa "\" para não virar sequência do prompt
	printf ' \001\e[35m\002 %s\001\e[0m\002' "$b"
}
__tp_venv() {
	[[ -n "${VIRTUAL_ENV:-}" ]] && printf '\001\e[33m\002(%s)\001\e[0m\002 ' "${VIRTUAL_ENV##*/}"
}
__tp_prompt() {
	local st=$?
	local arrow='\[\e[32m\]❯\[\e[0m\]'
	((st != 0)) && arrow="\[\e[31m\]$st ❯\[\e[0m\]"
	# Encurta /data/data/com.termux/files/home para ~
	PS1="\n$(__tp_venv)\[\e[1;34m\]\w\[\e[0m\]$(__tp_git_branch)\n$arrow "
}
PROMPT_COMMAND="__tp_prompt${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
# Evita que um nome de branch malicioso seja interpretado como comando no PS1.
shopt -u promptvars 2>/dev/null

# --- Aliases
alias ls='ls --color=auto -F'
alias ll='ls -lah'
alias la='ls -A'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias py='python'
alias up='pkg update && pkg upgrade'
alias venv='python -m venv --system-site-packages .venv && . .venv/bin/activate'
alias audit='bash "${TERMUX_PLUS_DIR:-$HOME/projeto}/scripts/audit.sh"'

# --- Funções
# ip-local → IPs do aparelho na rede
ip-local() { ifconfig 2>/dev/null | awk '/inet /{print $2}' | grep -v '^127\.'; }

# mkcd pasta  → cria e entra
mkcd() { mkdir -p -- "$1" && cd -- "$1" || return; }

# serve [porta] → servidor HTTP só no próprio celular (não expõe na Wi-Fi)
serve() { python -m http.server "${1:-8000}" --bind 127.0.0.1; }

# extract arquivo → descompacta qualquer formato comum
extract() {
	case "$1" in
		*.tar.gz|*.tgz) tar xzf "$1" ;;
		*.tar.xz) tar xJf "$1" ;;
		*.tar.bz2) tar xjf "$1" ;;
		*.tar) tar xf "$1" ;;
		*.zip) unzip "$1" ;;
		*.gz) gunzip "$1" ;;
		*.7z) 7z x "$1" ;;
		*) echo "Formato não suportado: $1" >&2; return 1 ;;
	esac
}

# Mensagem de boas-vindas curta (desative com: export TERMUX_PLUS_QUIET=1)
if [[ -z "${TERMUX_PLUS_QUIET:-}" && -z "${__TP_GREETED:-}" ]]; then
	export __TP_GREETED=1
	printf '\e[2m%s · bash %s · %s\e[0m\n' \
		"$(uname -m)" "${BASH_VERSION%%(*}" "$(df -h "$HOME" 2>/dev/null | awk 'NR==2{print $4" livres"}')"
fi

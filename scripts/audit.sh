#!/data/data/com.termux/files/usr/bin/bash
# shellcheck disable=SC2088  # "~" aparece só como texto nas mensagens
# Auditoria de segurança da instalação do Termux.
#
# Só LÊ a configuração; não altera nada. Para cada problema mostra como corrigir.
# Código de saída: 0 = nada grave, 1 = há itens de risco ALTO.
#
# Uso: bash scripts/audit.sh
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$here/lib.sh"

PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"
PROPS="$HOME_DIR/.termux/termux.properties"
[[ -f "$PROPS" ]] || PROPS="${XDG_CONFIG_HOME:-$HOME_DIR/.config}/termux/termux.properties"

HIGH=0; MED=0; LOW=0
high() { HIGH=$((HIGH + 1)); printf '%s[ALTO]%s  %s\n        %s→ %s%s\n' "${C_RED}${C_BOLD}" "$C_RESET" "$1" "$C_DIM" "$2" "$C_RESET"; }
med()  { MED=$((MED + 1));   printf '%s[MÉDIO]%s %s\n        %s→ %s%s\n' "$C_YELLOW" "$C_RESET" "$1" "$C_DIM" "$2" "$C_RESET"; }
low()  { LOW=$((LOW + 1));   printf '%s[BAIXO]%s %s\n        %s→ %s%s\n' "$C_CYAN" "$C_RESET" "$1" "$C_DIM" "$2" "$C_RESET"; }
pass() { ok "$1"; }

# Lê "chave = valor" de um arquivo .properties, ignorando comentários.
prop() {
	[[ -f "$PROPS" ]] || return 1
	grep -E "^[[:space:]]*$1[[:space:]]*=" "$PROPS" | tail -n1 | cut -d= -f2- | tr -d '[:space:]'
}

title "1. Permissão para apps externos"
# allow-external-apps=true deixa QUALQUER app com a permissão RUN_COMMAND
# executar comandos arbitrários dentro do Termux.
if [[ "$(prop allow-external-apps)" == "true" ]]; then
	high "allow-external-apps=true em $PROPS" \
		"Remova a linha (ou use false) e rode termux-reload-settings, a menos que você precise de Tasker/Termux:Widget externos."
else
	pass "allow-external-apps desligado"
fi

title "2. Servidor SSH"
SSHD_CONF="$PREFIX/etc/ssh/sshd_config"
if [[ -f "$SSHD_CONF" ]]; then
	sshd_opt() { grep -iE "^[[:space:]]*$1[[:space:]]" "$SSHD_CONF" | tail -n1 | awk '{print tolower($2)}'; }
	if [[ "$(sshd_opt PasswordAuthentication)" != "no" ]]; then
		med "sshd aceita login por senha" \
			"Use chaves: ssh-copy-id, depois 'PasswordAuthentication no' em $SSHD_CONF."
	else
		pass "sshd só aceita chaves"
	fi
	if [[ "$(sshd_opt PermitEmptyPasswords)" == "yes" ]]; then
		high "sshd permite senha vazia" "Defina 'PermitEmptyPasswords no' em $SSHD_CONF."
	fi
	if pgrep -x sshd >/dev/null 2>&1; then
		low "sshd está rodando agora" "Pare com 'pkill sshd' quando não estiver usando (ele fica exposto na rede Wi-Fi)."
	fi
else
	pass "OpenSSH server não configurado"
fi

title "3. Chaves e diretório ~/.ssh"
if [[ -d "$HOME_DIR/.ssh" ]]; then
	perm=$(stat -c '%a' "$HOME_DIR/.ssh" 2>/dev/null || echo "?")
	if [[ "$perm" == 700 ]]; then
		pass "~/.ssh com permissão 700"
	else
		med "~/.ssh com permissão $perm" "chmod 700 ~/.ssh"
	fi
	for k in "$HOME_DIR"/.ssh/id_*; do
		[[ -f "$k" && "$k" != *.pub ]] || continue
		perm=$(stat -c '%a' "$k" 2>/dev/null || echo "?")
		[[ "$perm" == 600 || "$perm" == 400 ]] || med "Chave privada $k com permissão $perm" "chmod 600 '$k'"
		# Se conseguimos ler a chave com senha vazia, ela não tem senha.
		if command -v ssh-keygen >/dev/null && ssh-keygen -y -P '' -f "$k" >/dev/null 2>&1; then
			low "Chave $k não tem senha" "ssh-keygen -p -f '$k' para proteger com senha."
		fi
	done
	if [[ -f "$HOME_DIR/.ssh/authorized_keys" ]]; then
		n=$(grep -cvE '^\s*(#|$)' "$HOME_DIR/.ssh/authorized_keys" || true)
		low "$n chave(s) em authorized_keys" "Revise se todas ainda devem ter acesso."
	fi
else
	pass "Sem ~/.ssh"
fi

title "4. Repositórios de pacotes"
SOURCES=("$PREFIX/etc/apt/sources.list")
for f in "$PREFIX"/etc/apt/sources.list.d/*; do [[ -f "$f" ]] && SOURCES+=("$f"); done
bad_src=0
for f in "${SOURCES[@]}"; do
	[[ -f "$f" ]] || continue
	if grep -qE '^[^#]*trusted=yes' "$f"; then
		high "Repositório sem verificação de assinatura em $f" "Remova 'trusted=yes'; pacotes podem ser trocados por um atacante."
		bad_src=1
	fi
	if grep -qE '^[^#]*deb[[:space:]]+(\[[^]]*\][[:space:]]+)?http://' "$f"; then
		med "Repositório usando HTTP sem criptografia em $f" "Troque por https:// ou rode termux-change-repo."
		bad_src=1
	fi
done
((bad_src)) || pass "Repositórios usam HTTPS e assinatura"

title "5. Atualizações pendentes"
if command -v apt >/dev/null 2>&1; then
	n=$(apt list --upgradable 2>/dev/null | grep -c '/' || true)
	if ((n > 0)); then
		med "$n pacote(s) desatualizado(s)" "pkg upgrade"
	else
		pass "Pacotes em dia (com base no último 'pkg update')"
	fi
fi

title "6. Arquivos com permissão de escrita para todos"
mapfile -t ww < <(find "$HOME_DIR" -xdev \( -path "$HOME_DIR/storage" -prune \) -o \
	\( -perm -0002 ! -type l -print \) 2>/dev/null | head -n 20)
if ((${#ww[@]})); then
	med "${#ww[@]} arquivo(s) graváveis por qualquer usuário em \$HOME (mostrando até 20)" "chmod o-w <arquivo>"
	printf '        %s\n' "${ww[@]}"
else
	pass "Nenhum arquivo gravável por todos em \$HOME"
fi

title "7. Scripts de inicialização automática"
for d in "$HOME_DIR/.termux/boot" "$HOME_DIR/.shortcuts" "$HOME_DIR/.termux/tasker"; do
	[[ -d "$d" ]] || continue
	n=$(find "$d" -type f | wc -l)
	((n)) && low "$n script(s) em $d rodam sem você digitar nada" "Revise o conteúdo: ls -la '$d'"
done
pass "Verificação de autostart concluída"

title "8. Segredos expostos"
secret_re='(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{50,}|sk-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'
found=0
for f in "$HOME_DIR/.bash_history" "$HOME_DIR/.zsh_history" "$HOME_DIR/.python_history" "$HOME_DIR/.bashrc" "$HOME_DIR/.profile"; do
	[[ -f "$f" ]] || continue
	if grep -qE "$secret_re" "$f" 2>/dev/null; then
		# Não imprime o segredo, só o arquivo.
		high "Possível token/chave em $f" "Revogue o token no serviço e remova a linha do arquivo."
		found=1
	fi
done
((found)) || pass "Nenhum token conhecido nos históricos"

title "9. Serviços escutando na rede"
if command -v ss >/dev/null 2>&1; then
	mapfile -t listen < <(ss -Hltn 2>/dev/null | awk '{print $4}' | grep -vE '^(127\.|\[::1\]|::1)' || true)
	if ((${#listen[@]})); then
		med "Portas abertas para a rede: ${listen[*]}" "Faça o serviço escutar em 127.0.0.1 ou pare-o quando não usar."
	else
		pass "Nenhuma porta aberta para fora (ou o Android bloqueou a consulta)"
	fi
else
	low "Não foi possível listar portas" "pkg install iproute2"
fi

title "10. Armazenamento compartilhado"
if [[ -L "$HOME_DIR/storage/shared" ]]; then
	low "~/storage dá acesso aos arquivos do celular" "Não guarde chaves, .env ou bancos de dados em ~/storage: outros apps podem ler."
fi
pass "Verificação de armazenamento concluída"

title "Resumo"
printf '%sAlto: %d%s   %sMédio: %d%s   %sBaixo: %d%s\n' \
	"$C_RED" "$HIGH" "$C_RESET" "$C_YELLOW" "$MED" "$C_RESET" "$C_CYAN" "$LOW" "$C_RESET"
((HIGH == 0))

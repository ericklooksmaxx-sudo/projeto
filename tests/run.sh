#!/usr/bin/env bash
# Testes que rodam em qualquer Linux (sem Termux), usando um HOME/PREFIX falsos
# e comandos "pkg"/"dpkg" simulados.
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

pass=0; fail=0
check() {
	local name="$1"; shift
	if "$@"; then echo "ok   - $name"; pass=$((pass + 1)); else echo "FAIL - $name"; fail=$((fail + 1)); fi
}

# --- Ambiente falso
fakebin="$tmp/bin"; mkdir -p "$fakebin"
cat >"$fakebin/pkg" <<EOF
#!/usr/bin/env bash
echo "pkg \$*" >>"$tmp/pkg.log"
EOF
printf '#!/usr/bin/env bash\nexit 1\n' >"$fakebin/dpkg"   # nada instalado
printf '#!/usr/bin/env bash\nexit 0\n' >"$fakebin/termux-reload-settings"
chmod +x "$fakebin"/*
export PATH="$fakebin:$PATH" NO_COLOR=1 TERMUX_PLUS_FORCE=1

newhome() { export HOME="$tmp/home$1" PREFIX="$tmp/prefix$1"; mkdir -p "$HOME" "$PREFIX/etc/apt/sources.list.d"; }

# 1. Dry-run de todos os módulos não executa nada.
newhome 1
: >"$tmp/pkg.log"
out=$(DRY_RUN=1 bash "$root/install.sh" ml llm gui x11 web 2>&1)
check "dry-run não chama pkg" test ! -s "$tmp/pkg.log"
check "dry-run lista python-torch" grep -q 'python-torch' <<<"$out"
check "dry-run lista textual" grep -q 'textual' <<<"$out"
check "dry-run lista python-tkinter" grep -q 'python-tkinter' <<<"$out"

# 2. ui.sh cria configs, é idempotente e o --restore desfaz.
newhome 2
echo 'echo antigo' >"$HOME/.bashrc"
bash "$root/scripts/ui.sh" --theme nord >/dev/null 2>&1
bash "$root/scripts/ui.sh" --theme nord >/dev/null 2>&1
check "termux.properties criado" test -f "$HOME/.termux/termux.properties"
check "tema nord aplicado" cmp -s "$HOME/.termux/colors.properties" "$root/config/themes/nord.properties"
check "bloco no .bashrc não duplica" test "$(grep -c '>>> termux-plus >>>' "$HOME/.bashrc")" = 1
check "conteúdo original do .bashrc mantido" grep -q 'echo antigo' "$HOME/.bashrc"
check "bashrc.sh carrega sem erro" bash -ic "source '$HOME/.bashrc'; __tp_prompt; [[ -n \$PS1 ]]" </dev/null >/dev/null 2>&1
bash "$root/scripts/ui.sh" --restore >/dev/null 2>&1
check "--restore remove o bloco" test "$(grep -c 'termux-plus' "$HOME/.bashrc")" = 0
check "tema inválido falha" bash -c "! bash '$root/scripts/ui.sh' --theme nao-existe >/dev/null 2>&1"

# 3. Auditoria detecta problemas conhecidos.
newhome 3
mkdir -p "$HOME/.termux"
echo 'allow-external-apps = true' >"$HOME/.termux/termux.properties"
echo 'deb [trusted=yes] http://exemplo.invalid/ stable main' >"$PREFIX/etc/apt/sources.list"
echo 'export TOKEN=ghp_abcdefghijklmnopqrstuvwxyz0123456789' >"$HOME/.bash_history"
out=$(bash "$root/scripts/audit.sh" 2>&1); rc=$?
check "auditoria retorna erro com risco alto" test "$rc" = 1
check "detecta allow-external-apps" grep -q 'allow-external-apps=true' <<<"$out"
check "detecta trusted=yes" grep -q 'sem verificação de assinatura' <<<"$out"
check "detecta repositório HTTP" grep -q 'HTTP sem criptografia' <<<"$out"
check "detecta token no histórico" grep -q 'Possível token' <<<"$out"
check "não imprime o token" bash -c "! grep -q ghp_abc <<<\"\$1\"" _ "$out"

# 4. Auditoria limpa passa.
newhome 4
mkdir -p "$HOME/.termux"
cp "$root/config/termux.properties" "$HOME/.termux/"
echo 'deb https://packages.termux.dev/apt/termux-main stable main' >"$PREFIX/etc/apt/sources.list"
bash "$root/scripts/audit.sh" >/dev/null 2>&1; rc=$?
check "auditoria limpa retorna 0" test "$rc" = 0

# 5. Exemplos Python compilam.
check "exemplos compilam" python3 -m py_compile "$root"/examples/*.py

echo
echo "$pass passaram, $fail falharam"
((fail == 0))

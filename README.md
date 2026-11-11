# termux-plus

Kit para deixar o [Termux](https://github.com/termux) mais seguro, mais bonito e pronto para
IA e criação de interfaces em Python.

| Módulo  | O que faz |
|---------|-----------|
| `ui`    | Teclas extras em 2 linhas, 4 temas de cores, prompt com branch do git / venv / código de erro, aliases úteis |
| `ml`    | PyTorch, torchvision, torchaudio, NumPy, SciPy, pandas, Pillow, Matplotlib, ONNX Runtime, OpenCV, TFLite |
| `llm`   | llama.cpp e ollama para rodar modelos de linguagem no celular |
| `gui`   | Interfaces de terminal: Rich, Textual, prompt_toolkit, urwid, blessed, questionary |
| `x11`   | Interfaces gráficas: Tkinter, PyQt5, PyQt6, GTK (PyGObject) via Termux:X11 + comando `tx11` |
| `web`   | Interfaces web: Flask, NiceGUI |
| `audit` | Auditoria de segurança (só leitura) com instruções de correção |

## Instalação

```bash
pkg install git
git clone https://github.com/ericklooksmaxx-sudo/projeto ~/projeto
cd ~/projeto
bash install.sh            # menu
bash install.sh ui gui ml  # direto
DRY_RUN=1 bash install.sh all   # só mostra o que faria
```

Desfazer as mudanças de interface: `bash scripts/ui.sh --restore`.
Trocar tema: `bash scripts/ui.sh --theme dracula` (catppuccin, dracula, nord, gruvbox).

## PyTorch no Termux

**Não use `pip install torch`.** O PyPI não tem pacotes para Android, então o pip tenta compilar
o PyTorch inteiro e falha. O Termux mantém versões prontas:

```bash
pkg install python-torch python-torchvision python-torchaudio
python examples/check_ml.py   # testa tudo e treina uma rede XOR pequena
```

O mesmo vale para NumPy, SciPy, pandas, Pillow e OpenCV — sempre `pkg install python-...`.
Para ambientes virtuais, use `python -m venv --system-site-packages .venv` (o alias `venv`
já faz isso) para que o venv enxergue esses pacotes.

## Bibliotecas de interface

| Onde roda | Bibliotecas | Exemplo |
|-----------|-------------|---------|
| Terminal (direto no Termux) | Rich, Textual, prompt_toolkit, urwid, blessed, questionary, curses | `python examples/textual_demo.py`, `python examples/rich_menu.py` |
| Janela gráfica (app Termux:X11) | Tkinter, PyQt5, PyQt6, GTK | `tx11 python examples/tk_demo.py` |
| Navegador do celular | Flask, NiceGUI | `python examples/web_demo.py` → http://127.0.0.1:5000 |

Para apps gráficos, instale também o app **Termux:X11** (APK em
<https://github.com/termux/termux-x11/releases>). O comando `tx11` liga o servidor X, abre o app
e roda seu programa. `python examples/check_ui.py` mostra o que está instalado.

## Segurança

`bash scripts/audit.sh` (ou o alias `audit`) verifica:

1. `allow-external-apps=true` — deixa outros apps executarem comandos no Termux
2. `sshd` com login por senha / senha vazia, e se ele está rodando
3. Permissões de `~/.ssh` e chaves privadas sem senha
4. Repositórios com `trusted=yes` (sem verificação de assinatura) ou HTTP
5. Pacotes desatualizados
6. Arquivos graváveis por todos em `$HOME`
7. Scripts que rodam sozinhos (`~/.termux/boot`, atalhos, Tasker)
8. Tokens (GitHub, AWS, OpenAI, Slack, chaves privadas) esquecidos no histórico — mostra só o arquivo, nunca o segredo
9. Portas abertas para a rede
10. Dados sensíveis em `~/storage` (lido por outros apps)

Escolhas seguras que o kit já faz:

- `termux.properties` vem com `allow-external-apps = false`.
- `tx11` **não** usa `-ac` (muitos tutoriais usam, o que desliga o controle de acesso do X) e desativa TCP.
- `serve` e `examples/web_demo.py` escutam só em `127.0.0.1` e nunca ligam o modo debug do Flask
  (o depurador do Werkzeug permite executar código remotamente).
- O prompt desliga `promptvars`, então um nome de branch malicioso não executa comandos.
- Toda configuração alterada ganha backup `*.bak.<data>`.

## Problemas comuns

- **`pkg install` falha / mirror lento** → `termux-change-repo` e escolha outro mirror.
- **`pip install numpy` (ou torch, scipy…) demora horas e falha** → use `pkg install python-numpy`.
- **Não use `pip install --upgrade pip`** — quebra o pacote `python-pip` do Termux.
- **App gráfico abre tela preta** → abra o app Termux:X11 manualmente; confirme `echo $DISPLAY` = `:0`.
- **Processo morto em segundo plano** → Android 12+ mata processos ("phantom process killer");
  rode `termux-wake-lock` e veja a wiki do Termux.

## Testes

```bash
bash tests/run.sh     # roda em qualquer Linux, com pkg/HOME simulados
```

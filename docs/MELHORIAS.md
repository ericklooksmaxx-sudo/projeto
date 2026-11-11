# Melhorias neste fork do Termux

Este documento resume o que foi alterado em relação ao `termux-app` original.

## 1. Correções de segurança

| Componente | Problema | Correção |
|---|---|---|
| `TermuxDocumentsProvider` (seletor de arquivos do Android) | `isChildDocument()` usava `startsWith()`. Um app com acesso a uma pasta (ex.: `~/projetos`) podia ler e apagar qualquer arquivo do Termux com um id como `~/projetos/../.ssh/id_rsa`, ou acessar a pasta vizinha `~/projetos-privado`. | Os caminhos são normalizados e comparados por componente (`DocumentPathUtils.isPathInside`). Ids de documento fora de `$HOME` são recusados. |
| `TermuxDocumentsProvider.createDocument()` | O nome do novo arquivo podia conter `../`, criando arquivos fora da pasta pedida. O id da pasta pai não era validado. | Nome validado (sem `/`, `.` ou `..`) e a pasta pai passa pela mesma validação. |
| `FileReceiverActivity` (compartilhar arquivo com o Termux) | O nome do arquivo vem do app que compartilha. Um nome como `../../usr/etc/bash.bashrc` sobrescrevia arquivos de inicialização do shell (execução de código) se o usuário só tocasse em "Abrir". | O nome sugerido mantém só o último componente, e o salvamento recusa nomes com `/`, `.` ou `..`. O stream também é fechado ao cancelar. |
| `TermuxOpenReceiver.ContentProvider` | `openFile()` validava o caminho canônico mas abria o caminho original (TOCTOU: um link simbólico podia ser trocado entre a checagem e a abertura). A checagem de prefixo também aceitava `/data/data/com.termux/files-outro`. `query()` não fazia nenhuma checagem e revelava nome e tamanho de qualquer arquivo. | O arquivo canônico já validado é o que é aberto, a comparação é por componente e `query()` aplica as mesmas regras (incluindo `allow-external-apps`). |

## 2. Correções de bugs

- Busca no seletor de arquivos nunca encontrava nada quando o termo tinha letras maiúsculas.
- `NullPointerException` ao listar ou buscar pastas sem permissão de leitura (`listFiles()` retornando `null`).
- Tamanho de arquivos maiores que 2 GiB aparecia negativo (`(int) file.length()`).
- Arquivos sem extensão eram tratados como se o nome inteiro fosse a extensão ao detectar o tipo MIME.
- Relatórios de mouse SGR eram formatados com o idioma do sistema; em árabe ou persa os números saíam com dígitos não ASCII e os programas não conseguiam ler os cliques.

## 3. Suporte a bibliotecas Python de interface

O emulador de terminal ganhou os modos que bibliotecas como **Textual**, **Rich**, **prompt_toolkit**, **urwid** e também vim/neovim/tmux usam:

- **Saída sincronizada (DECSET 2026):** a tela só é redesenhada quando o programa termina de atualizá-la, o que elimina o "piscar" em apps Textual e no `rich.live`. Há um limite de 150 ms caso o programa trave no meio da atualização.
- **Eventos de foco (DECSET 1004):** o programa é avisado quando o Termux ganha ou perde o foco.
- **Rastreamento de mouse "any-event" (DECSET 1003):** era ignorado. Agora arrastar o dedo funciona em apps que só pedem esse modo (Textual, urwid), por exemplo em barras de rolagem e sliders.

Testes foram adicionados em `terminal-emulator/src/test/.../DecSetTest.java`.

## 4. Ambiente Python, PyTorch e bibliotecas de interface

Há um novo botão **`</>` Ambiente Python** no topo da gaveta lateral (deslize da esquerda), e o item **Ambiente Python** no menu de toque longo do terminal. Ele abre uma lista do que instalar:

| Perfil | O que instala |
|---|---|
| Interfaces de terminal | rich, textual, prompt_toolkit, urwid, npyscreen, pytermgui, asciimatics, blessed, questionary (e `curses`, que já vem com o Python) |
| PyTorch | `python-torch` e NumPy (só em aparelhos 64 bits; torchvision/torchaudio quando existirem no repositório) |
| Ciência de dados | NumPy, SciPy, pandas, matplotlib, Pillow, scikit-learn |
| Interfaces no navegador | Flask, PyWebIO (abra com `termux-open-url http://localhost:8080`) |
| Interfaces gráficas | tkinter, PyQt5 e pygame via o app Termux:X11 |

A instalação roda numa nova sessão de terminal, então dá para acompanhar o progresso. O mesmo instalador fica disponível no shell:

```sh
termux-python-setup                # Python + interfaces de terminal + PyTorch
termux-python-setup all            # tudo
termux-python-setup data web       # perfis específicos
termux-python-setup --check        # mostra o que já está instalado
termux-python-setup --examples     # recria os exemplos em ~/python-examples
```

### Por que o app não traz o PyTorch dentro do APK

O PyTorch e as bibliotecas científicas são programas nativos que precisam combinar exatamente com a versão do Python instalada no Termux. Não existem pacotes do PyTorch para Android no PyPI (`pip install torch` não funciona no Termux), então o instalador usa os pacotes já compilados dos repositórios do Termux (`pkg install python-torch`) e ativa o `tur-repo` se necessário. Bibliotecas que são só código Python são instaladas com `pip` quando não existem no repositório. Colocar tudo isso no APK deixaria o app com centenas de MB e quebraria a cada atualização do Python.

### Exemplos criados em `~/python-examples`

- `rich_demo.py`: tabela, barra de progresso e cores 24 bits.
- `textual_demo.py`: contador com botões (toque ou teclas `+`/`-`, `q` para sair).
- `torch_demo.py`: treina uma rede mínima para aprender `y = 2x + 1`.
- `web_demo.py`: formulário no navegador com PyWebIO.
- `tk_demo.py`: janela tkinter (precisa do Termux:X11).

## 5. Interface

- Botões de **Ambiente Python** e **Ajuda** no cabeçalho da gaveta lateral, ao lado de Configurações, com dicas (tooltips).
- Textos das novas funções traduzidos para português do Brasil (`values-pt-rBR`).

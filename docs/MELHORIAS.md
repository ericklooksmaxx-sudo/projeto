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

## 4. Ambiente Python, PyTorch e bibliotecas

Há um botão **`</>` Ambiente Python** no topo da gaveta lateral (deslize da esquerda) e o item **Ambiente Python** no menu de toque longo do terminal. Ele abre uma lista do que instalar. A instalação roda numa nova sessão de terminal, então dá para acompanhar o progresso. O mesmo instalador está no shell:

```sh
termux-python-setup                # Python + interfaces de terminal + PyTorch
termux-python-setup gui ml llm     # perfis específicos (veja abaixo)
termux-python-setup all            # tudo
termux-python-setup --check        # mostra o que já está instalado
termux-python-setup --examples     # recria os exemplos em ~/python-examples
```

| Perfil | O que instala | De onde vem |
|---|---|---|
| `ui` | rich, textual, prompt_toolkit, urwid, npyscreen, pytermgui, asciimatics, blessed, questionary | pip (puro Python) |
| `torch` | PyTorch, torchvision, torchaudio (só 64 bits) | pacotes `python-torch*` do Termux |
| `data` | NumPy, SciPy, pandas, matplotlib, Pillow | pacotes do Termux |
| `web` | Flask, PyWebIO | pip |
| `gui` | tkinter, **CustomTkinter, Kivy, PyQt5/6, PySide6, Flet**, pygame + a janela flutuante | veja a seção 5 |
| `ml` | **TensorFlow Lite** (`tflite_runtime`) e **ONNX Runtime** | pacotes `python-tflite-runtime` e `python-onnxruntime` do Termux |
| `llm` | **llama.cpp** com backends Vulkan e OpenCL, `termux-llm`, módulo `termux_llm` (`--ollama` instala o Ollama) | pacotes `llama-cpp*` e `ollama*` do Termux |

### O que o repositório `termux-packages` já tem (e o que não tem)

Pesquisei o `termux/termux-packages` e o `termux-user-repository` (TUR) antes de escrever qualquer coisa. Boa parte do que se faz com "gambiarras" já existe pronta, então o instalador usa os pacotes oficiais em vez de recompilar:

| Pedido | Situação |
|---|---|
| PyTorch | Existe (`python-torch`, `-torchvision`, `-torchaudio`). |
| TensorFlow Lite | Existe (`python-tflite-runtime`). |
| **TensorFlow completo** | **Não existe e não dá para instalar no Android**: o Google não publica wheels para Android e não compila aqui. Use TF Lite, ONNX Runtime ou PyTorch. |
| ONNX Runtime | Existe (`onnxruntime` e `python-onnxruntime`). |
| llama.cpp com Vulkan/OpenCL | Existe (`llama-cpp` + `llama-cpp-backend-vulkan` + `llama-cpp-backend-opencl`, carregados em tempo de execução). |
| Ollama | Existe (`ollama` + `ollama-backend-vulkan`). |
| CustomTkinter | Python puro, instalado com pip sobre o `python-tkinter` do Termux. |
| Kivy | Existe no TUR (`python-kivy`). Se não houver, o instalador compila com pip. |
| PyQt5 / PyQt6 | Existem (`pyqt5`, `pyqt6`). |
| **PySide6** | **Não existe para Android** (as wheels oficiais são para glibc). O app traz uma **camada de compatibilidade sobre o PyQt6**: `import PySide6.QtWidgets` funciona, com `Signal`/`Slot`/`Property`, `Qt.AlignCenter` e `exec_()`. Não é o PySide6 de verdade: `QUiLoader` e `shiboken6` não existem. |
| Flet | Python puro, em modo web. Precisa do `pydantic-core`, que é compilado com Rust (o instalador instala o Rust se necessário e leva alguns minutos). |
| **Dear PyGui** | **Não dá**: o PyPI só tem wheels para glibc e não há pacote-fonte. Não instalado, e o instalador avisa. |

## 5. Janela flutuante (popup) para apps com interface

Apps com janela (Tk, CustomTkinter, Kivy, Qt) precisam de um servidor gráfico, e o Android não tem um. O app resolve isso com uma **janela flutuante sobre outros apps** (permissão "Sobrepor a outros apps"):

```
app Python ──► Xvnc (TigerVNC) ──► websockify ──► noVNC numa página local ──► janela flutuante do Termux
```

- A janela tem barra de título (arraste para mover) com os botões **recarregar**, **ocultar** (vira uma bolha que você arrasta e toca para voltar), **tela cheia** e **fechar**, e uma alça no canto para **redimensionar**.
- Um teclado virtual (botão no canto) envia o texto ao app.
- Fechar a janela encerra o app, e o app terminando fecha a janela.
- Apps web (Flet e qualquer servidor local) abrem direto, sem VNC.

```sh
termux-gui-run python ~/python-examples/tk_demo.py              # Tk, CustomTkinter, Kivy, Qt, pygame
termux-gui-run flet run ~/python-examples/flet_demo.py          # Flet
termux-gui-run --web 8501 streamlit run app.py --server.port 8501
termux-gui-popup http://127.0.0.1:8080 --title Chat --fullscreen   # qualquer página local
termux-gui-popup --hide|--show|--close|--status [--id NOME]
```

A permissão é pedida ao escolher o perfil "gui" e também no menu de toque longo ("Janelas flutuantes").

**Segurança da janela flutuante** (ela é desenhada sobre outros apps, então foi tratada como um alvo de phishing):
- Só abre `http://127.0.0.1`, `http://localhost` e `http://[::1]`. A checagem rejeita truques como `http://127.0.0.1@site.com`, barras invertidas, caracteres de controle e portas inválidas (6 testes unitários).
- A navegação dentro da janela também é bloqueada para fora do aparelho, inclusive redirecionamentos.
- O serviço não é exportado: só comandos executados dentro do Termux o controlam.
- O servidor VNC escuta só em loopback e exige uma **senha aleatória por sessão**, para que outros apps do celular não consigam conectar. O download do noVNC é verificado por SHA-256.
- Tráfego http sem TLS é permitido apenas para loopback (`network_security_config.xml`).
- O arquivo `index.html` e a senha ficam fora dos logs.

## 6. LLMs locais (`termux-llm`)

```sh
termux-llm setup                      # llama.cpp + backends Vulkan e OpenCL (--ollama para o Ollama)
termux-llm doctor                     # dispositivo, RAM, núcleos rápidos, GPUs detectadas
termux-llm models                     # modelos prontos (Qwen2.5, Llama 3.2, Gemma 3, SmolLM2, Phi-3.5)
termux-llm pull qwen2.5-1.5b          # baixa o GGUF (retomável; também hf:dono/repo/arquivo.gguf ou URL https)
termux-llm serve qwen2.5-1.5b --popup # servidor + chat web numa janela flutuante
termux-llm chat                       # conversa no terminal
termux-llm bench                      # mede CPU, Vulkan e OpenCL e guarda o mais rápido
termux-llm ollama start|stop|run ...
```

O que ele resolve:
- Instala o backend certo e descobre os dispositivos pelo `--list-devices` do próprio llama.cpp.
- Usa só os **núcleos rápidos** do celular (núcleos pequenos atrapalham o llama.cpp).
- Backend `auto`: na primeira execução com GPU disponível, **mede** CPU, Vulkan e OpenCL e guarda o mais rápido (a GPU só vence se for pelo menos 10% mais rápida). Em celulares a GPU nem sempre ganha: o OpenCL é ajustado para Adreno com modelos Q4_0, e os drivers Vulkan variam.
- Servidor compatível com a API da OpenAI em `http://127.0.0.1:8080/v1`, ouvindo só no loopback.
- Módulo Python sem dependências:

```python
from termux_llm import LLM
with LLM("qwen2.5-1.5b") as llm:
    print(llm.chat("Explique o Vulkan em uma frase"))
```

## 7. Interface

- Botões de **Ambiente Python** e **Ajuda** no topo da gaveta lateral, ao lado de Configurações, com dicas (tooltips).
- Item **Janelas flutuantes** no menu de toque longo.
- Textos novos em português do Brasil (`values-pt-rBR`).

## 8. Limites conhecidos

Nada disto foi testado num celular de verdade. Foi testado: a janela por trás do popup (Xvnc + noVNC + Chromium, com cliques, teclado virtual, CustomTkinter e encerramento), o `termux-llm` e o `termux_llm` com programas de teste no lugar do llama.cpp, a camada PySide6 sobre o PyQt6 real, e a compilação e os testes do app. **Não foi testado**: o serviço da janela flutuante no Android (permissão, arrastar, tela cheia, bolha), o `am` chamando o serviço, e as instalações reais (nomes de pacote conferidos no repositório, mas não instalados).

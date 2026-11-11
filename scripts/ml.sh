#!/data/data/com.termux/files/usr/bin/bash
# Instala bibliotecas de IA / ciência de dados no Termux.
#
# Por que usar "pkg" e não "pip" para PyTorch, NumPy etc.?
#   O PyPI não publica wheels para Android/Bionic. "pip install torch" tenta
#   compilar tudo do zero e falha (ou leva horas). O Termux mantém pacotes
#   pré-compilados (python-torch, python-numpy...), que é o caminho suportado.
#
# Uso: bash scripts/ml.sh [--full] [--llm]
#   --full  inclui OpenCV (requer x11-repo) e TFLite
#   --llm   inclui llama.cpp e ollama para rodar modelos de linguagem locais
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$here/lib.sh"

FULL=0; LLM=0
for a in "$@"; do
	case "$a" in
		--full) FULL=1 ;;
		--llm) LLM=1 ;;
		-h|--help) sed -n '2,12p' "$0"; exit 0 ;;
		*) die "Opção desconhecida: $a" ;;
	esac
done

require_termux
title "Bibliotecas de IA e ciência de dados"

# Base de compilação: necessária para pacotes pip que tenham extensões em C.
pkg_install python python-pip build-essential cmake ninja binutils patchelf

# Pilha científica pré-compilada.
pkg_install python-numpy python-scipy python-pandas python-pillow matplotlib libopenblas

# PyTorch e companhia.
pkg_install python-torch python-torchvision python-torchaudio

# Runtimes de inferência leves (bons para celulares).
pkg_install python-onnxruntime

if [[ "$FULL" == 1 ]]; then
	pkg_install python-tflite-runtime
	enable_repo x11-repo
	pkg_install opencv-python
fi

if [[ "$LLM" == 1 ]]; then
	pkg_install llama-cpp ollama
fi

# Pacotes puros em Python (sem código nativo) que funcionam bem via pip.
pip_install tqdm einops safetensors

title "Verificação"
if [[ "$DRY_RUN" != 1 ]]; then
	python "$here/../examples/check_ml.py" || warn "Algumas bibliotecas não importaram; veja acima."
fi

print_failures

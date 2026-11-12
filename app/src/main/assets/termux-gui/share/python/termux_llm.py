"""Easy local LLMs in Termux: a tiny client for the llama.cpp server started by ``termux-llm``.

Only the standard library is used, so it works right after ``termux-python-setup llm``::

    from termux_llm import LLM

    with LLM("qwen2.5-1.5b") as llm:          # starts the server if needed
        print(llm.chat("Explain Vulkan in one sentence"))
        for piece in llm.chat("Tell me a joke", stream=True):
            print(piece, end="", flush=True)

The server speaks the OpenAI API, so ``llm.openai_client()`` returns a ready-to-use client when the
``openai`` package is installed. From a shell: ``python -m termux_llm "your question"``.
"""

from __future__ import annotations

import json
import shutil
import subprocess
import time
import urllib.error
import urllib.request
from typing import Dict, Iterator, List, Optional, Union

__all__ = ["LLM", "LLMError"]

Message = Dict[str, str]


class LLMError(RuntimeError):
    """Raised when the server cannot be started or returns an error."""


class LLM:
    """Client for a local llama.cpp server, which it can also start through ``termux-llm serve``.

    :param model: preset name, file name or path of a GGUF model (see ``termux-llm models``).
        ``None`` uses the only downloaded model.
    :param backend: ``auto``, ``cpu``, ``vulkan`` or ``opencl``.
    :param port: port of the local server.
    :param ctx: context size in tokens.
    :param start: start the server when it is not running.
    :param startup_timeout: seconds to wait for the server to become ready.
    """

    def __init__(self, model: Optional[str] = None, backend: str = "auto", port: int = 8080,
                 ctx: int = 4096, start: bool = True, startup_timeout: float = 120.0) -> None:
        if not 0 < int(port) < 65536:
            raise ValueError("invalid port")
        self.model = model
        self.backend = backend
        self.port = int(port)
        self.ctx = int(ctx)
        self.start = start
        self.startup_timeout = startup_timeout
        self._started_here = False

    # -- server management --------------------------------------------------------------------

    @property
    def host(self) -> str:
        return "http://127.0.0.1:%d" % self.port

    @property
    def base_url(self) -> str:
        """Base URL of the OpenAI compatible API."""
        return self.host + "/v1"

    def is_running(self) -> bool:
        try:
            with urllib.request.urlopen(self.host + "/health", timeout=2) as response:
                return response.status == 200
        except (urllib.error.URLError, OSError, ValueError):
            return False

    def ensure_running(self) -> None:
        """Start the server with ``termux-llm serve --bg`` if it is not running."""
        if self.is_running():
            return
        if not self.start:
            raise LLMError("the server is not running on port %d" % self.port)
        exe = shutil.which("termux-llm")
        if exe is None:
            raise LLMError("termux-llm was not found, run: termux-python-setup llm")
        command = [exe, "serve", "--bg", "--port", str(self.port), "--ctx", str(self.ctx),
                   "--backend", self.backend]
        if self.model:
            command.append(self.model)
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode != 0:
            raise LLMError("could not start the server:\n" + (result.stderr or result.stdout).strip())
        self._started_here = True
        deadline = time.monotonic() + self.startup_timeout
        while time.monotonic() < deadline:
            if self.is_running():
                return
            time.sleep(0.5)
        raise LLMError("the server did not become ready in %.0f seconds" % self.startup_timeout)

    def stop(self) -> None:
        """Stop the server (only if this object started it)."""
        if self._started_here:
            exe = shutil.which("termux-llm")
            if exe:
                subprocess.run([exe, "stop"], capture_output=True)
            self._started_here = False

    def __enter__(self) -> "LLM":
        self.ensure_running()
        return self

    def __exit__(self, *exc_info) -> None:
        self.stop()

    # -- inference ----------------------------------------------------------------------------

    def _post(self, path: str, payload: dict, stream: bool = False):
        self.ensure_running()
        request = urllib.request.Request(
            self.base_url + path, data=json.dumps(payload).encode("utf-8"),
            headers={"Content-Type": "application/json"}, method="POST")
        try:
            return urllib.request.urlopen(request, timeout=600)
        except urllib.error.HTTPError as error:
            raise LLMError("server error %d: %s" % (error.code, error.read().decode("utf-8", "replace")))
        except (urllib.error.URLError, OSError) as error:
            raise LLMError("could not reach the server: %s" % error)

    @staticmethod
    def _messages(prompt: Union[str, List[Message]], system: Optional[str]) -> List[Message]:
        if isinstance(prompt, str):
            messages: List[Message] = [{"role": "user", "content": prompt}]
        else:
            messages = list(prompt)
        if system:
            messages.insert(0, {"role": "system", "content": system})
        return messages

    def chat(self, prompt: Union[str, List[Message]], *, system: Optional[str] = None,
             stream: bool = False, temperature: float = 0.7, max_tokens: int = 512,
             **options) -> Union[str, Iterator[str]]:
        """Chat completion. ``prompt`` is a string or a list of ``{"role", "content"}`` messages.

        Returns the answer as a string, or an iterator of text pieces when ``stream=True``.
        """
        payload = {"messages": self._messages(prompt, system), "temperature": temperature,
                   "max_tokens": max_tokens, "stream": stream}
        payload.update(options)
        response = self._post("/chat/completions", payload, stream=stream)
        if not stream:
            with response:
                data = json.loads(response.read().decode("utf-8"))
            return data["choices"][0]["message"]["content"]
        return self._iter_stream(response)

    @staticmethod
    def _iter_stream(response) -> Iterator[str]:
        with response:
            for raw in response:
                line = raw.decode("utf-8", "replace").strip()
                if not line.startswith("data:"):
                    continue
                data = line[5:].strip()
                if data == "[DONE]":
                    return
                try:
                    delta = json.loads(data)["choices"][0].get("delta", {})
                except (ValueError, KeyError, IndexError):
                    continue
                piece = delta.get("content")
                if piece:
                    yield piece

    def complete(self, prompt: str, *, max_tokens: int = 256, temperature: float = 0.7, **options) -> str:
        """Plain text completion (no chat template)."""
        payload = {"prompt": prompt, "max_tokens": max_tokens, "temperature": temperature}
        payload.update(options)
        with self._post("/completions", payload) as response:
            data = json.loads(response.read().decode("utf-8"))
        return data["choices"][0]["text"]

    def openai_client(self):
        """An ``openai.OpenAI`` client for the local server (needs ``pip install openai``)."""
        try:
            from openai import OpenAI
        except ImportError:
            raise LLMError("the openai package is not installed: pip install openai")
        self.ensure_running()
        return OpenAI(base_url=self.base_url, api_key="none")


def main(argv: Optional[List[str]] = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(prog="python -m termux_llm", description="Ask the local LLM a question.")
    parser.add_argument("question", nargs="+")
    parser.add_argument("--model", help="model name or path (default: the downloaded one)")
    parser.add_argument("--backend", default="auto", choices=["auto", "cpu", "vulkan", "opencl"])
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args(argv)
    try:
        llm = LLM(args.model, backend=args.backend, port=args.port)
        for piece in llm.chat(" ".join(args.question), stream=True):
            print(piece, end="", flush=True)
        print()
    except LLMError as error:
        print("termux_llm: %s" % error)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

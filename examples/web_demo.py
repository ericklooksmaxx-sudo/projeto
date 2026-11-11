"""Interface web mínima com Flask, aberta no navegador do celular.

Rode: python examples/web_demo.py   e abra http://127.0.0.1:5000

Por padrão escuta só em 127.0.0.1: outros aparelhos na mesma Wi-Fi NÃO
conseguem acessar. Use --lan apenas em redes confiáveis.
"""
import argparse
import html
import platform

from flask import Flask, request

app = Flask(__name__)

PAGE = """<!doctype html>
<html lang="pt-br"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>termux-plus</title>
<style>
 body {{ font-family: system-ui, sans-serif; max-width: 32rem; margin: 2rem auto; padding: 0 1rem;
        background: #1e1e2e; color: #cdd6f4; }}
 input, button {{ font-size: 1.1rem; padding: .6rem; width: 100%; margin: .3rem 0; border-radius: .5rem;
        border: 1px solid #585b70; background: #313244; color: inherit; box-sizing: border-box; }}
 button {{ background: #89b4fa; color: #1e1e2e; font-weight: 600; }}
</style>
<h1>Olá do Termux</h1>
<p>Rodando em {machine} com Python {py}.</p>
<form method="post"><input name="nome" placeholder="Seu nome"><button>Enviar</button></form>
<p>{msg}</p>
"""


@app.route("/", methods=["GET", "POST"])
def index() -> str:
    msg = ""
    if request.method == "POST":
        # html.escape evita XSS ao mostrar texto digitado pelo usuário.
        msg = f"Olá, {html.escape(request.form.get('nome', '')[:100])}!"
    return PAGE.format(machine=platform.machine(), py=platform.python_version(), msg=msg)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--lan", action="store_true", help="aceitar conexões da rede local")
    parser.add_argument("--port", type=int, default=5000)
    args = parser.parse_args()
    # debug=False: o depurador do Werkzeug permite executar código remotamente.
    app.run(host="0.0.0.0" if args.lan else "127.0.0.1", port=args.port, debug=False)

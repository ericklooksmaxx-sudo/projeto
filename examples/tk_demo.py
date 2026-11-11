"""Exemplo de interface gráfica com Tkinter no Termux:X11.

Instale:  bash scripts/gui.sh --x11
Rode:     tx11 python examples/tk_demo.py
"""
import tkinter as tk
from tkinter import messagebox, ttk


def main() -> None:
    root = tk.Tk()
    root.title("termux-plus · Tkinter")
    # Telas de celular têm alta densidade: aumenta a escala para os botões serem tocáveis.
    root.tk.call("tk", "scaling", 2.5)

    frame = ttk.Frame(root, padding=20)
    frame.grid(sticky="nsew")
    root.columnconfigure(0, weight=1)
    root.rowconfigure(0, weight=1)

    ttk.Label(frame, text="Seu nome:").grid(row=0, column=0, sticky="w")
    name = tk.StringVar()
    entry = ttk.Entry(frame, textvariable=name)
    entry.grid(row=1, column=0, sticky="ew", pady=5)
    entry.focus()

    def greet() -> None:
        messagebox.showinfo("Olá", f"Olá, {name.get() or 'mundo'}!")

    ttk.Button(frame, text="Cumprimentar", command=greet).grid(row=2, column=0, sticky="ew")
    ttk.Button(frame, text="Sair", command=root.destroy).grid(row=3, column=0, sticky="ew", pady=5)
    frame.columnconfigure(0, weight=1)
    root.bind("<Return>", lambda _e: greet())
    root.mainloop()


if __name__ == "__main__":
    main()

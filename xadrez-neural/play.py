"""Jogue contra a rede neural treinada.

Interativo (você digita lances em SAN ou UCI, ex.: e4, Nf3, e2e4):
    python play.py --rede alfa --cor brancas
Um lance por chamada (útil para scripts): passe todos os lances até agora e
a rede responde com o lance dela:
    python play.py --rede alfa --lances "e4 e5 Nf3"

--profundidade 1 = só a rede escolhe, exatamente como no treino (padrão).
--profundidade 2/3 = a rede avalia as posições no fim de uma busca minimax.
"""
import argparse
import os

import chess
import numpy as np
import torch

from core import ValueNet, encode, expand

HERE = os.path.dirname(os.path.abspath(__file__))


def load(name):
    net = ValueNet()
    ck = torch.load(os.path.join(HERE, "checkpoints", f"{name.lower()}.pt"))
    net.load_state_dict(ck["net"])
    net.eval()
    return net


def child_scores(net, board):
    moves, rows, term = expand(board)
    feats = encode(np.array([r[0] for r in rows], dtype=np.uint64),
                   [r[1] for r in rows], [r[2] for r in rows])
    s = -net.value(feats)
    for j, t in enumerate(term):
        if t is not None:
            s[j] = 2.0 if t == 1.0 else 0.0
    return moves, s


def negamax(net, board, depth, alpha=-9.0, beta=9.0):
    moves, s = child_scores(net, board)
    if depth == 1:
        i = int(np.argmax(s))
        return float(s[i]), moves[i]
    best, best_m = -9.0, moves[int(np.argmax(s))]
    for i in np.argsort(-s):  # melhores primeiro, ajuda a poda
        m = moves[i]
        if s[i] >= 2.0:
            return 2.0, m
        board.push(m)
        over = board.is_game_over(claim_draw=True)
        board.pop()
        if over:
            val = float(s[i])
        else:
            board.push(m)
            val = -negamax(net, board, depth - 1, -beta, -alpha)[0]
            board.pop()
        if val > best:
            best, best_m = val, m
        alpha = max(alpha, val)
        if alpha >= beta:
            break
    return best, best_m


def parse(board, txt):
    try:
        return board.parse_san(txt)
    except ValueError:
        return board.parse_uci(txt)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rede", default="alfa")
    ap.add_argument("--cor", default="brancas", choices=["brancas", "pretas"])
    ap.add_argument("--profundidade", type=int, default=1)
    ap.add_argument("--lances", default=None, help="lances até agora; a rede responde 1 lance")
    args = ap.parse_args()
    net = load(args.rede)

    if args.lances is not None:
        board = chess.Board()
        for t in args.lances.split():
            board.push(parse(board, t))
        if board.is_game_over(claim_draw=True):
            print(board.unicode(borders=True, empty_square="·"))
            print("Fim de jogo:", board.result(claim_draw=True))
            return
        val, m = negamax(net, board, args.profundidade)
        san = board.san(m)
        board.push(m)
        print(board.unicode(borders=True, empty_square="·", orientation=board.turn))
        print(f"Rede joga: {san}   (avaliação dela: {val:+.2f})")
        if board.is_game_over(claim_draw=True):
            print("Fim de jogo:", board.result(claim_draw=True))
        return

    board = chess.Board()
    me = chess.WHITE if args.cor == "brancas" else chess.BLACK
    while not board.is_game_over(claim_draw=True):
        print(board.unicode(borders=True, empty_square="·", orientation=me))
        if board.turn == me:
            try:
                board.push(parse(board, input("Seu lance: ").strip()))
            except (ValueError, AssertionError):
                print("Lance inválido.")
        else:
            val, m = negamax(net, board, args.profundidade)
            print(f"Rede joga: {board.san(m)}   (avaliação: {val:+.2f})")
            board.push(m)
    print(board.unicode(borders=True, empty_square="·", orientation=me))
    print("Resultado:", board.result(claim_draw=True))


if __name__ == "__main__":
    main()

"""Núcleo: codificação do tabuleiro, rede neural de avaliação e escolha de lances.

A rede não recebe NENHUM conhecimento de xadrez além das regras (via python-chess):
nada de valor das peças, nada de tabelas de posição. Ela vê apenas onde estão as peças
(do ponto de vista de quem joga) e aprende a avaliar posições jogando.
"""
import random

import chess
import numpy as np
import torch
import torch.nn as nn

N_FEATURES = 12 * 64 + 4  # 12 planos de peças + 4 direitos de roque

# máscaras dos direitos de roque (torre na casa de origem)
_CR = (chess.BB_H1, chess.BB_A1, chess.BB_H8, chess.BB_A8)
_OWN_FIRST = np.array([6, 7, 8, 9, 10, 11, 0, 1, 2, 3, 4, 5])


def board_row(b: chess.Board):
    """Representação compacta: 12 bitboards (brancas P..K, pretas P..K), roques, vez."""
    w, bl = b.occupied_co
    p, n, bi, r, q, k = b.pawns, b.knights, b.bishops, b.rooks, b.queens, b.kings
    return (p & w, n & w, bi & w, r & w, q & w, k & w,
            p & bl, n & bl, bi & bl, r & bl, q & bl, k & bl), b.castling_rights, b.turn


def encode(masks, castling, turn):
    """masks (K,12) uint64, castling (K,) int, turn (K,) bool -> (K, 772) uint8.

    Sempre do ponto de vista de quem tem a vez: primeiro as próprias peças,
    e se for a vez das pretas o tabuleiro é espelhado verticalmente.
    """
    masks = np.ascontiguousarray(masks, dtype=np.uint64)
    K = masks.shape[0]
    bits = np.unpackbits(masks.view(np.uint8), bitorder="little").reshape(K, 12, 8, 8)
    black = ~np.asarray(turn, dtype=bool)
    if black.any():
        bits[black] = bits[black][:, _OWN_FIRST, ::-1, :]
    cr = np.asarray(castling, dtype=np.uint64)
    c = np.stack([(cr & np.uint64(m)) != 0 for m in _CR], axis=1).astype(np.uint8)  # wK wQ bK bQ
    c[black] = c[black][:, [2, 3, 0, 1]]
    return np.concatenate([bits.reshape(K, 768), c], axis=1)


def encode_boards(boards):
    rows = [board_row(b) for b in boards]
    return encode(np.array([r[0] for r in rows], dtype=np.uint64),
                  [r[1] for r in rows], [r[2] for r in rows])


class ValueNet(nn.Module):
    """Posição -> valor em [-1, 1] para quem tem a vez (+1 = vitória certa)."""

    def __init__(self, hidden=(512, 128)):
        super().__init__()
        layers, d = [], N_FEATURES
        for h in hidden:
            layers += [nn.Linear(d, h), nn.ReLU()]
            d = h
        layers += [nn.Linear(d, 1), nn.Tanh()]
        self.net = nn.Sequential(*layers)

    def forward(self, x):
        return self.net(x).squeeze(-1)

    @torch.no_grad()
    def value(self, feats_u8):
        if len(feats_u8) == 0:
            return np.zeros(0, dtype=np.float32)
        return self(torch.from_numpy(feats_u8).float()).numpy()


def expand(board: chess.Board):
    """Gera todos os lances legais e os dados das posições resultantes.

    Retorna (moves, rows, terminal) onde terminal[i] = +1 se o lance dá xeque-mate
    (o jogador que lança vence), 0 se o lance afoga (empate), None caso contrário.
    Isso são apenas as REGRAS do jogo; nenhum conhecimento estratégico.
    """
    moves = list(board.legal_moves)
    rows, terminal = [], []
    push, pop = board.push, board.pop
    for m in moves:
        push(m)
        rows.append(board_row(board))
        t = None
        if not any(board.generate_legal_moves()):
            t = 1.0 if board.is_check() else 0.0
        terminal.append(t)
        pop()
    return moves, rows, terminal


def material(board: chess.Board, color):
    vals = {chess.PAWN: 1, chess.KNIGHT: 3, chess.BISHOP: 3, chess.ROOK: 5, chess.QUEEN: 9}
    s = 0
    for pt, v in vals.items():
        s += v * (len(board.pieces(pt, color)) - len(board.pieces(pt, not color)))
    return s


def pick(scores, temperature, rng=random):
    """Escolhe um índice: greedy se temperature==0, senão softmax(scores/T)."""
    scores = np.asarray(scores, dtype=np.float64)
    if temperature <= 0:
        best = np.flatnonzero(scores >= scores.max() - 1e-9)
        return int(rng.choice(list(best)))
    z = (scores - scores.max()) / temperature
    p = np.exp(z)
    p /= p.sum()
    return int(np.searchsorted(np.cumsum(p), rng.random() * p.sum() * 0.999999))


def game_result(board: chess.Board, max_plies):
    """None se o jogo continua; senão o resultado para quem TEM A VEZ (-1 mate, 0 empate)."""
    if not any(board.generate_legal_moves()):
        return -1.0 if board.is_check() else 0.0
    if (board.is_insufficient_material() or board.halfmove_clock >= 100
            or board.is_repetition(3) or board.ply() >= max_plies):
        return 0.0
    return None

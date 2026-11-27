"""Duas redes neurais (Alfa e Beta) aprendem xadrez do zero jogando uma contra a outra.

Aprendizado por reforço puro (tentativa e erro), estilo TD-Gammon:
  * cada rede avalia as posições depois de cada lance legal e escolhe (com alguma
    exploração aleatória) o lance que leva à posição que ela acha melhor;
  * no fim da partida, o resultado (vitória +1 / empate 0 / derrota -1) é propagado
    para trás com TD(lambda): cada posição aprende a "prever" o que veio depois.
Nenhum conhecimento de xadrez é fornecido além das regras do jogo.

Uso:  python train.py --hours 3          (retoma automaticamente do último checkpoint)
"""
import argparse
import json
import os
import random
import time

import chess
import chess.pgn
import numpy as np
import torch

from core import ValueNet, board_row, encode, encode_boards, expand, game_result, material, pick

HERE = os.path.dirname(os.path.abspath(__file__))
CKPT = os.path.join(HERE, "checkpoints")


# ----------------------------------------------------------------------------- agentes
class NetAgent:
    def __init__(self, name, net, lam, lr):
        self.name, self.net, self.lam = name, net, lam
        self.opt = torch.optim.Adam(net.parameters(), lr=lr)
        self.buf_x = np.zeros((0, 772), dtype=np.uint8)
        self.buf_y = np.zeros(0, dtype=np.float32)
        self.steps = 0

    def scores(self, expansions):
        rows = [r for _, rs, _ in expansions for r in rs]
        feats = encode(np.array([r[0] for r in rows], dtype=np.uint64),
                       [r[1] for r in rows], [r[2] for r in rows])
        v = -self.net.value(feats)  # valor do filho é do ponto de vista do adversário
        out, i = [], 0
        for moves, _, term in expansions:
            s = v[i:i + len(moves)].copy()
            i += len(moves)
            for j, t in enumerate(term):
                if t is not None:
                    s[j] = 2.0 if t == 1.0 else 0.0  # mate em 1 / afogamento (regras)
            out.append(s)
        return out


class RandomAgent:
    name = "Aleatório"

    def scores(self, expansions):
        return [np.random.rand(len(m)) for m, _, _ in expansions]


class MaterialAgent:
    """Referência fixa: olha 1 lance à frente e só conta material (P=1 C=B=3 T=5 D=9)."""
    name = "Materialista"

    def scores(self, expansions, boards=None):
        raise NotImplementedError  # precisa do tabuleiro; tratado em play_batch


# ----------------------------------------------------------------------------- partidas
def material_scores(board, moves, term):
    me = board.turn
    s = np.empty(len(moves))
    for j, m in enumerate(moves):
        if term[j] is not None:
            s[j] = 100.0 if term[j] == 1.0 else 0.0
            continue
        board.push(m)
        s[j] = material(board, me) + random.random() * 0.01
        board.pop()
    return s


def play_batch(pairs, max_plies, temp_fn):
    """Joga várias partidas em paralelo. pairs = [(agente_brancas, agente_pretas), ...].

    temp_fn(ply, agente) -> temperatura de exploração.
    Retorna lista de dicts com posições (formato compacto), resultado e lances.
    """
    games = []
    for w, b in pairs:
        board = chess.Board()
        games.append(dict(board=board, white=w, black=b, rows=[board_row(board)],
                          moves=[], result=None, truncated=False))
    active = list(range(len(games)))
    while active:
        exps = {i: expand(games[i]["board"]) for i in active}
        by_agent = {}
        for i in active:
            g = games[i]
            ag = g["white"] if g["board"].turn else g["black"]
            by_agent.setdefault(id(ag), (ag, []))[1].append(i)
        choice = {}
        for ag, idxs in by_agent.values():
            if isinstance(ag, MaterialAgent):
                sc = [material_scores(games[i]["board"], *(exps[i][0], exps[i][2])) for i in idxs]
            else:
                sc = ag.scores([exps[i] for i in idxs])
            for i, s in zip(idxs, sc):
                choice[i] = pick(s, temp_fn(games[i]["board"].ply(), ag))
        still = []
        for i in active:
            g, (moves, rows, _) = games[i], exps[i]
            k = choice[i]
            g["board"].push(moves[k])
            g["moves"].append(moves[k])
            g["rows"].append(rows[k])
            r = game_result(g["board"], max_plies)
            if r is None:
                still.append(i)
            else:
                g["result"] = r  # do ponto de vista de quem tem a vez na posição final
                g["truncated"] = g["board"].ply() >= max_plies and r == 0.0 and \
                    any(g["board"].generate_legal_moves()) and not (
                        g["board"].is_insufficient_material() or g["board"].halfmove_clock >= 100
                        or g["board"].is_repetition(3))
        active = still
    return games


def white_score(g):
    """1 se brancas venceram, 0.5 empate, 0 derrota."""
    if g["result"] == 0.0:
        return 0.5
    loser_white = g["board"].turn == chess.WHITE  # quem tem a vez na posição de mate perdeu
    return 0.0 if loser_white else 1.0


# ----------------------------------------------------------------------------- aprendizado
def td_targets(agent, game_list):
    """Alvos TD(lambda) para todas as posições das partidas, usando a própria rede."""
    xs, ys = [], []
    for g in game_list:
        rows = g["rows"]
        x = encode(np.array([r[0] for r in rows], dtype=np.uint64),
                   [r[1] for r in rows], [r[2] for r in rows])
        v = agent.net.value(x)
        T = len(rows) - 1
        G = np.empty(T + 1, dtype=np.float32)
        G[T] = v[T] if g["truncated"] else g["result"]
        lam = agent.lam
        for t in range(T - 1, -1, -1):
            G[t] = -((1 - lam) * v[t + 1] + lam * G[t + 1])
        xs.append(x)
        ys.append(G)
    return np.concatenate(xs), np.concatenate(ys)


def learn(agent, game_list, buf_size, batch, reuse):
    x, y = td_targets(agent, game_list)
    agent.buf_x = np.concatenate([agent.buf_x, x])[-buf_size:]
    agent.buf_y = np.concatenate([agent.buf_y, y])[-buf_size:]
    n_steps = max(1, int(len(x) * reuse / batch))
    losses = []
    for _ in range(n_steps):
        idx = np.random.randint(0, len(agent.buf_y), size=batch)
        xb = torch.from_numpy(agent.buf_x[idx]).float()
        yb = torch.from_numpy(agent.buf_y[idx])
        loss = torch.mean((agent.net(xb) - yb) ** 2)
        agent.opt.zero_grad()
        loss.backward()
        agent.opt.step()
        losses.append(loss.item())
    agent.steps += n_steps
    return float(np.mean(losses))


# ----------------------------------------------------------------------------- avaliação
PROBES = {  # o que a rede "acha" de estar com uma peça a mais (posição inicial sem a peça do rival)
    "peão": "rnbqkbnr/pppp1ppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
    "cavalo": "r1bqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
    "bispo": "rn1qkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
    "torre": "1nbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQk - 0 1",
    "dama": "rnb1kbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
}


def probe(agent):
    boards = [chess.Board()] + [chess.Board(f) for f in PROBES.values()]
    v = agent.net.value(encode_boards(boards))
    out = {"inicial": round(float(v[0]), 3)}
    out.update({k: round(float(x), 3) for k, x in zip(PROBES, v[1:])})
    return out


def match(a, b, n, max_plies, opening_plies=6):
    """n partidas a x b alternando cores; aberturas aleatórias, depois sem exploração."""
    pairs = [(a, b) if i % 2 == 0 else (b, a) for i in range(n)]
    games = play_batch(pairs, max_plies, lambda ply, ag: 1.0 if ply < opening_plies else 0.0)
    w = d = l = 0
    for g in games:
        s = white_score(g) if g["white"] is a else 1 - white_score(g)
        w += s == 1.0
        d += s == 0.5
        l += s == 0.0
    return dict(v=int(w), e=int(d), d=int(l)), games


def to_pgn(g, event):
    game = chess.pgn.Game()
    game.headers.update(Event=event, White=g["white"].name, Black=g["black"].name,
                        Result=g["board"].result(claim_draw=True) if g["result"] != 0.0 or not g["truncated"]
                        else "1/2-1/2")
    node = game
    for m in g["moves"]:
        node = node.add_variation(m)
    return str(game)


# ----------------------------------------------------------------------------- principal
def save(agents, state):
    os.makedirs(CKPT, exist_ok=True)
    for ag in agents:
        torch.save(dict(net=ag.net.state_dict(), opt=ag.opt.state_dict(), steps=ag.steps,
                        lam=ag.lam), os.path.join(CKPT, f"{ag.name.lower()}.pt.tmp"))
        os.replace(os.path.join(CKPT, f"{ag.name.lower()}.pt.tmp"),
                   os.path.join(CKPT, f"{ag.name.lower()}.pt"))
    with open(os.path.join(CKPT, "state.json"), "w") as f:
        json.dump(state, f)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--hours", type=float, default=1.0)
    ap.add_argument("--parallel", type=int, default=128, help="partidas simultâneas por rodada")
    ap.add_argument("--max-plies", type=int, default=300)
    ap.add_argument("--eval-every", type=int, default=10, help="rodadas entre avaliações")
    ap.add_argument("--threads", type=int, default=4)
    args = ap.parse_args()
    torch.set_num_threads(args.threads)

    alfa = NetAgent("Alfa", ValueNet(), lam=0.7, lr=5e-4)
    beta = NetAgent("Beta", ValueNet(), lam=0.9, lr=5e-4)
    state = dict(round=0, games=0, positions=0, seconds=0.0, alfa_wins=0, beta_wins=0, draws=0)
    if os.path.exists(os.path.join(CKPT, "state.json")):
        state = json.load(open(os.path.join(CKPT, "state.json")))
        for ag in (alfa, beta):
            ck = torch.load(os.path.join(CKPT, f"{ag.name.lower()}.pt"))
            ag.net.load_state_dict(ck["net"])
            ag.opt.load_state_dict(ck["opt"])
            ag.steps = ck["steps"]
        print(f"Retomando da rodada {state['round']} ({state['games']} partidas)")

    os.makedirs(CKPT, exist_ok=True)
    log = open(os.path.join(HERE, "log.jsonl"), "a")
    rand, mat = RandomAgent(), MaterialAgent()
    t_end = time.time() + args.hours * 3600

    while time.time() < t_end:
        t0 = time.time()
        r = state["round"]
        # exploração: mais aleatória no começo da partida e no começo do treino
        # epsilon-greedy: joga o lance que acha melhor, mas às vezes tenta um aleatório
        eps = max(0.05, 0.2 * (0.99 ** r))

        def temp(ply, ag, eps=eps):
            return 100.0 if ply < 4 or random.random() < eps else 0.0

        n = args.parallel
        pairs = [(alfa, beta) if i % 2 == 0 else (beta, alfa) for i in range(n)]
        games = play_batch(pairs, args.max_plies, temp)
        la = learn(alfa, games, buf_size=400_000, batch=1024, reuse=8)
        lb = learn(beta, games, buf_size=400_000, batch=1024, reuse=8)

        a_w = b_w = dr = mates = 0
        for g in games:
            s = white_score(g) if g["white"] is alfa else 1 - white_score(g)
            a_w += s == 1.0
            b_w += s == 0.0
            dr += s == 0.5
            mates += g["result"] == -1.0
        npos = sum(len(g["rows"]) for g in games)
        state["round"] += 1
        state["games"] += n
        state["positions"] += npos
        state["alfa_wins"] += a_w
        state["beta_wins"] += b_w
        state["draws"] += dr
        state["seconds"] += time.time() - t0
        rec = dict(kind="train", round=state["round"], games=state["games"], alfa_v=a_w, beta_v=b_w,
                   empates=dr, mates=mates, plies_medio=round(npos / n, 1), loss_alfa=round(la, 4),
                   loss_beta=round(lb, 4), eps=round(eps, 3), seg=round(time.time() - t0, 1))
        print(json.dumps(rec, ensure_ascii=False), flush=True)
        log.write(json.dumps(rec, ensure_ascii=False) + "\n")

        if state["round"] % args.eval_every == 0:
            t1 = time.time()
            ev = dict(kind="eval", round=state["round"], games=state["games"])
            res, gms = match(alfa, beta, 40, args.max_plies)
            ev["alfa_x_beta"] = res
            with open(os.path.join(CKPT, "ultima_partida_alfa_x_beta.pgn"), "w") as f:
                f.write(to_pgn(gms[0], f"Alfa x Beta após {state['games']} partidas"))
            for ag in (alfa, beta):
                ev[f"{ag.name}_x_aleatorio"] = match(ag, rand, 20, args.max_plies)[0]
                ev[f"{ag.name}_x_materialista"] = match(ag, mat, 40, args.max_plies)[0]
                ev[f"{ag.name}_sonda"] = probe(ag)
            ev["seg"] = round(time.time() - t1, 1)
            print(json.dumps(ev, ensure_ascii=False), flush=True)
            log.write(json.dumps(ev, ensure_ascii=False) + "\n")
            log.flush()
            save((alfa, beta), state)
    save((alfa, beta), state)
    print("Fim do treino:", json.dumps(state))


if __name__ == "__main__":
    main()

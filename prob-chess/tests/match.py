#!/usr/bin/env python3
"""Arbitro de partidas entre dois motores UCI.

As regras sao aplicadas por tests/ref.py -- um gerador de lances ingenuo,
escrito de forma independente do motor em C. Se o motor devolver um lance
ilegal, ele perde a partida: o arbitro nao confia no jogador.
"""
import subprocess, sys, argparse, collections
import ref

class UCI:
    def __init__(self, cmd, name):
        self.name = name
        self.p = subprocess.Popen(cmd, shell=True, stdin=subprocess.PIPE,
                                  stdout=subprocess.PIPE, text=True, bufsize=1)
        self.send("uci"); self.wait("uciok")
        self.send("isready"); self.wait("readyok")
    def send(self, s):
        self.p.stdin.write(s + "\n"); self.p.stdin.flush()
    def wait(self, tok):
        while True:
            l = self.p.stdout.readline()
            if not l: raise RuntimeError(self.name + " morreu")
            if l.startswith(tok): return l.strip()
    def bestmove(self, moves, ms):
        self.send("position startpos" + (" moves " + " ".join(moves) if moves else ""))
        self.send("go movetime %d" % ms)
        return self.wait("bestmove").split()[1]
    def quit(self):
        try: self.send("quit"); self.p.wait(timeout=3)
        except Exception: self.p.kill()

def result_of(p, moves):
    lg = ref.legal(p)
    if not lg:
        if ref.attacked(p, ref.ksq(p, p.stm), ref.BL if p.stm == ref.WH else ref.WH):
            return ("0-1" if p.stm == ref.WH else "1-0"), "mate"
        return "1/2-1/2", "afogado"
    if p.hm >= 100: return "1/2-1/2", "50 lances"
    return None, None

def play(a, b, ms, maxply, verbose):
    p = ref.P("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
    moves, seen = [], collections.Counter()
    for ply in range(maxply):
        r, why = result_of(p, moves)
        if r: return r, why, moves
        eng = a if p.stm == ref.WH else b
        mv = eng.bestmove(moves, ms)
        cand = [m for m in ref.legal(p) if ref.nm(m) == mv or
                (len(mv) == 4 and ref.nm(m)[:4] == mv and len(ref.nm(m)) == 4)]
        if not cand:
            return ("0-1" if p.stm == ref.WH else "1-0"), eng.name + " jogou lance ilegal " + mv, moves
        m = cand[0]
        pc = p.b[m[0]]
        cap = p.b[m[1]] is not None
        p = ref.make(p, m)
        p.hm = 0 if (pc.upper() == 'P' or cap) else p.hm + 1
        moves.append(mv)
        key = (tuple(p.b), p.stm, tuple(sorted(p.cr)), p.ep)
        seen[key] += 1
        if seen[key] >= 3: return "1/2-1/2", "repeticao", moves
        if verbose: print("   %3d. %s" % (ply + 1, mv), flush=True)
    return "1/2-1/2", "limite de lances", moves

ap = argparse.ArgumentParser()
ap.add_argument("cmd_a"); ap.add_argument("cmd_b")
ap.add_argument("--games", type=int, default=4)
ap.add_argument("--ms", type=int, default=1000)
ap.add_argument("--maxply", type=int, default=250)
ap.add_argument("-v", action="store_true")
o = ap.parse_args()

score = {"A": 0.0, "B": 0.0}
for g in range(o.games):
    a = UCI(o.cmd_a, "A"); b = UCI(o.cmd_b, "B")
    wa, wb = (a, b) if g % 2 == 0 else (b, a)
    r, why, mv = play(wa, wb, o.ms, o.maxply, o.v)
    pts = {"1-0": (1.0, 0.0), "0-1": (0.0, 1.0), "1/2-1/2": (0.5, 0.5)}[r]
    sa = pts[0] if wa is a else pts[1]
    score["A"] += sa; score["B"] += 1.0 - sa
    print("jogo %d: %s (%s, %d lances) brancas=%s  -> A %.1f" %
          (g + 1, r, why, len(mv), wa.name, sa), flush=True)
    a.quit(); b.quit()
print("\nPLACAR  A=%.1f  B=%.1f  de %d" % (score["A"], score["B"], o.games))

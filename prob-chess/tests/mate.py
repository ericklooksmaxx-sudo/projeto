# Verificador exaustivo e independente de mate forcado.
# Atacante so tenta xeques (correto para PROVAR que existe mate);
# defensor tenta TODOS os lances. Sem heuristicas, sem poda.
import sys, ref

def in_check(p, c):
    k = ref.ksq(p, c)
    return k is not None and ref.attacked(p, k, ref.BL if c == ref.WH else ref.WH)

def gives_check(p, mv):
    q = ref.make(p, mv)
    return in_check(q, q.stm)

def attacker_mates(p, plies):
    """True se quem joga da mate forcado em <= (plies+1)//2 lances."""
    if plies <= 0: return None
    us = p.stm
    for mv in ref.legal(p):
        if not gives_check(p, mv): continue
        q = ref.make(p, mv)
        rep = ref.legal(q)
        if not rep:
            return [ref.nm(mv)]           # xeque-mate
        if plies == 1: continue
        ok = True; worst = None
        for d in rep:
            r = ref.make(q, d)
            sub = attacker_mates(r, plies - 2)
            if sub is None: ok = False; break
            if worst is None or len(sub) > len(worst): worst = [ref.nm(d)] + sub
        if ok:
            return [ref.nm(mv)] + (worst or [])
    return None

if __name__ == '__main__':
    fen = sys.argv[1]; n = int(sys.argv[2])
    p = ref.P(fen)
    for plies in range(1, 2 * n, 2):
        r = attacker_mates(p, plies)
        if r:
            print("MATE EM %d: %s" % ((plies + 1) // 2, " ".join(r))); sys.exit(0)
    print("sem mate forcado em %d" % n)

def full_first(p, plies):
    """Mate forcado permitindo QUALQUER primeiro lance do atacante
    (os seguintes restritos a xeques). Correto para PROVAR a existencia."""
    for mv in ref.legal(p):
        q = ref.make(p, mv)
        rep = ref.legal(q)
        if not rep:
            if in_check(q, q.stm): return [ref.nm(mv)]
            continue
        if plies == 1: continue
        ok, worst = True, None
        for d in rep:
            r = ref.make(q, d)
            sub = attacker_mates(r, plies - 2)
            if sub is None: ok = False; break
            if worst is None or len(sub) > len(worst): worst = [ref.nm(d)] + sub
        if ok: return [ref.nm(mv)] + (worst or [])
    return None

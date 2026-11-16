"""Randomised equivalence tests for luraph_deob.structure.

A random flat goto-program is executed by a tiny evaluator, then structured,
and executed again: the observable trace (calls to ``log``) must match."""
import random
import sys
import unittest

from luraph_deob import luau_ast as A
from luraph_deob import structure as S


class _Goto(Exception):
    def __init__(self, label):
        self.label = label


class _Break(Exception):
    pass


class _Continue(Exception):
    pass


class _Return(Exception):
    pass


class OutOfFuel(Exception):
    pass


class Machine:
    def __init__(self, fuel=3000):
        self.env = {}
        self.log = []
        self.fuel = fuel

    def ev(self, e):
        t = type(e)
        if t is A.Number:
            return e.value
        if t is A.TrueE:
            return True
        if t is A.FalseE:
            return False
        if t is A.Nil:
            return None
        if t is A.Name:
            return self.env.get(e.name, 0)
        if t is A.Paren:
            return self.ev(e.expr)
        if t is A.UnOp:
            v = self.ev(e.operand)
            return (not (v is not None and v is not False)) if e.op == "not" else -v
        if t is A.BinOp:
            a, b = self.ev(e.left), self.ev(e.right)
            return {"+": lambda: a + b, "-": lambda: a - b, "<": lambda: a < b, "<=": lambda: a <= b,
                    "==": lambda: a == b, "~=": lambda: a != b, ">": lambda: a > b, ">=": lambda: a >= b}[e.op]()
        raise AssertionError(t)

    def tick(self):
        self.fuel -= 1
        if self.fuel < 0:
            raise OutOfFuel()

    def block(self, stmts):
        i = 0
        while i < len(stmts):
            try:
                self.stmt(stmts[i])
                i += 1
            except _Goto as g:
                for j, s in enumerate(stmts):
                    if type(s) is A.Label and s.name == g.label:
                        i = j + 1
                        break
                else:
                    raise

    def stmt(self, s):
        self.tick()
        t = type(s)
        if t is A.Assign:
            vals = [self.ev(v) for v in s.values]
            for tg, v in zip(s.targets, vals):
                self.env[tg.name] = v
        elif t is A.CallStat:
            self.log.append(self.ev(s.call.args[0]))
        elif t is A.If:
            for c, b in s.clauses:
                v = self.ev(c)
                if v is not None and v is not False:
                    self.block(b)
                    return
            if s.orelse is not None:
                self.block(s.orelse)
        elif t is A.While:
            while True:
                v = self.ev(s.cond)
                if v is None or v is False:
                    break
                try:
                    self.block(s.body)
                except _Break:
                    break
                except _Continue:
                    continue
                self.tick()
        elif t is A.Do:
            self.block(s.body)
        elif t is A.Break:
            raise _Break()
        elif t is A.Continue:
            raise _Continue()
        elif t is A.Goto:
            raise _Goto(s.label)
        elif t is A.Label:
            pass
        elif t is A.Return:
            self.log.append(("ret", [self.ev(v) for v in s.values]))
            raise _Return()
        elif t is A.Local:
            pass
        else:
            raise AssertionError(t)

    def run(self, stmts):
        try:
            self.block(stmts)
        except _Return:
            pass
        except OutOfFuel:
            self.log.append("fuel")
        return self.log


def V(n):
    return A.Name(n)


def N(x):
    return A.Number(x)


def random_program(rng, nblocks, nvars=3, structured_bias=0.0):
    """Flat program: labelled blocks of simple stmts ending in goto/if-goto/return."""
    stmts = []
    for i in range(nblocks):
        stmts.append(A.Label("B%d" % i))
        for _ in range(rng.randint(0, 2)):
            v = "v%d" % rng.randint(1, nvars)
            kind = rng.random()
            if kind < 0.4:
                stmts.append(A.Assign([V(v)], [A.BinOp("+", V(v), N(rng.randint(1, 3)))]))
            elif kind < 0.6:
                stmts.append(A.Assign([V(v)], [N(rng.randint(0, 4))]))
            else:
                stmts.append(A.CallStat(A.Call(V("log"), [A.BinOp("+", V(v), N(100 * i))])))
        r = rng.random()
        if i == nblocks - 1 or r < 0.08:
            stmts.append(A.Return([V("v1")]))
        elif r < 0.45:
            t = rng.randrange(nblocks)
            stmts.append(A.Goto("B%d" % t))
        else:
            t1, t2 = rng.randrange(nblocks), rng.randrange(nblocks)
            op = rng.choice(["<", "<=", "==", "~="])
            c = A.BinOp(op, V("v%d" % rng.randint(1, nvars)), N(rng.randint(0, 5)))
            stmts.append(A.If([(c, [A.Goto("B%d" % t1)])], [A.Goto("B%d" % t2)]))
    return stmts


class StructureTests(unittest.TestCase):
    def check(self, seed, nblocks):
        rng = random.Random(seed)
        prog = random_program(rng, nblocks)
        before = Machine().run(prog)
        stats = {}
        out = S.structure_body([copy_stmt(s) for s in prog], stats)
        after = Machine().run(out)
        if "fuel" in before or "fuel" in after:
            n = min(len(before), len(after)) - 1
            before, after = before[:n], after[:n]
        self.assertEqual(before, after, "seed=%d n=%d\n%s" % (seed, nblocks, A.to_source(A.Block(out))))
        return stats

    def test_random(self):
        agg = {}
        for seed in range(600):
            for n in (3, 5, 8, 12):
                for k, v in self.check(seed, n).items():
                    if not isinstance(v, int):
                        continue
                    agg[k] = agg.get(k, 0) + v
        print("modes:", agg, file=sys.stderr)
        self.assertTrue(agg.get("structured", 0) > 0)


def copy_stmt(s):
    from luraph_deob.simplify import copy
    return copy(s)


if __name__ == "__main__":
    unittest.main()

"""Pipeline driver."""

import sys

from .parser import parse
from .printer import to_source
from . import fold, unwrap, cff, emufold, cleanup

try:
    from . import vm
except ImportError:  # pragma: no cover
    vm = None


class Report(object):
    def __init__(self):
        self.steps = []

    def add(self, what):
        self.steps.append(what)


def deobfuscate_ast(chunk, report=None, max_rounds=12, verbose=False):
    report = report or Report()
    envs = set()

    def log(msg):
        report.add(msg)
        if verbose:
            sys.stderr.write("[deobf] %s\n" % msg)

    for rnd in range(max_rounds):
        progress = False
        fold.fold(chunk)
        if unwrap.beta_reduce(chunk):
            progress = True
        if unwrap.unwrap(chunk):
            log("removed function wrapper (WrapInFunction)")
            progress = True
        if emufold.remove_antitamper(chunk):
            log("removed AntiTamper")
            progress = True
        if emufold.emulate_fold(chunk):
            log("decoded constants (string pool / ConstantArray / EncryptStrings)")
            progress = True
        n, e = cff.undo_cff(chunk)
        if n:
            envs |= e
            log("unflattened %d Cff dispatcher(s)" % n)
            progress = True
            chunk.body = cleanup.env_to_globals(chunk, envs).body
        if vm is not None:
            k, e = vm.devirtualize(chunk)
            envs |= e
            if k:
                log("devirtualized %d VM program(s)" % k)
                progress = True
        if cleanup.simplify(chunk):
            progress = True
        if not progress:
            break
    chunk = cleanup.env_to_globals(chunk, envs)
    cleanup.finish(chunk)
    return chunk, report


def deobfuscate(src, verbose=False):
    chunk = parse(src)
    chunk, report = deobfuscate_ast(chunk, verbose=verbose)
    return to_source(chunk), report

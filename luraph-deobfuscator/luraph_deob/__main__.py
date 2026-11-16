import argparse
import sys

from .pipeline import deobfuscate


def main(argv=None):
    ap = argparse.ArgumentParser(prog="luraph_deob", description="Static deobfuscator for Luraph v15.2 (Luau)")
    ap.add_argument("input", help="obfuscated .lua file")
    ap.add_argument("-o", "--output", help="output file (default: stdout)")
    ap.add_argument("--budget", type=int, default=150000, help="abstract-execution steps per function")
    ap.add_argument("-q", "--quiet", action="store_true")
    ap.add_argument("--debug", action="store_true", help="verbose exploration log")
    a = ap.parse_args(argv)
    src = open(a.input, "rb").read()
    log = lambda *x: print(*x, file=sys.stderr, flush=True)
    res = deobfuscate(src, log=log, func_budget=a.budget, verbose=("debug" if a.debug else not a.quiet))
    if a.output:
        with open(a.output, "w", encoding="latin-1") as f:
            f.write(res.source)
    else:
        sys.stdout.write(res.source)
    return 0


if __name__ == "__main__":
    sys.exit(main())

"""Command line interface: python -m prometheus_deobf input.lua [-o output.lua]"""

import argparse
import sys

from .deobfuscate import deobfuscate


def main(argv=None):
    ap = argparse.ArgumentParser(prog="prometheus-deobf",
                                 description="Static deobfuscator for scripts protected with Prometheus (Lua).")
    ap.add_argument("input", help="obfuscated Lua file ('-' for stdin)")
    ap.add_argument("-o", "--output", help="where to write the result (default: stdout)")
    ap.add_argument("-v", "--verbose", action="store_true", help="print the layers that were removed")
    args = ap.parse_args(argv)
    if args.input == "-":
        src = sys.stdin.buffer.read().decode("latin-1")
    else:
        with open(args.input, "rb") as f:
            src = f.read().decode("latin-1")
    out, report = deobfuscate(src, verbose=args.verbose)
    if args.output:
        with open(args.output, "wb") as f:
            f.write(out.encode("latin-1"))
    else:
        sys.stdout.write(out)
    if args.verbose:
        for s in report.steps:
            sys.stderr.write("  - %s\n" % s)


if __name__ == "__main__":
    main()

"""CLI for the dynamic dumper: ``python -m luraph_deob.dump script.lua -o out.lua``."""
import argparse
import os
import sys

from .envlog import dump


def main(argv=None):
    ap = argparse.ArgumentParser(prog="luraph_deob.dump",
                                 description="Run a (Luraph-)obfuscated script in a sandboxed Roblox-like emulator "
                                             "and write the recorded environment interactions as readable Lua")
    ap.add_argument("input")
    ap.add_argument("-o", "--output", help="output file (default: stdout)")
    ap.add_argument("--timeout", type=float, default=120.0, help="wall-clock budget in seconds")
    ap.add_argument("--max-events", type=int, default=200000)
    ap.add_argument("--no-callbacks", action="store_true", help="do not run callbacks registered by the script")
    a = ap.parse_args(argv)
    res = dump(open(a.input, "rb").read(), timeout=a.timeout, max_events=a.max_events,
               run_callbacks=not a.no_callbacks)
    if a.output:
        with open(a.output, "w", encoding="latin-1") as f:
            f.write(res.source)
        base, _ = os.path.splitext(a.output)
        for i, c in enumerate(res.chunks, 1):
            with open("%s.chunk%d.lua" % (base, i), "wb") as f:
                f.write(c)
    else:
        sys.stdout.write(res.source)
    print("[dump] events=%d chunks=%d %.1fs%s%s" % (res.events, len(res.chunks), res.seconds,
          " TIMEOUT" if res.timed_out else "", (" error=" + res.error) if res.error else ""), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())

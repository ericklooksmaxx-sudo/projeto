#!/usr/bin/env python3
"""Deobfuscate WeAreDevs samples (*.wad.lua) and compare with what the obfuscated program prints.

    python3 tests/wad_roundtrip.py SAMPLES_DIR [--lua lua5.1] [name ...]

The reference is the *obfuscated* program's own output (the WeAreDevs obfuscator is not always
semantics preserving, so the original source is not the right oracle).
"""

import argparse
import glob
import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from prometheus_deobf import deobfuscate  # noqa: E402


def run(lua, path):
    try:
        p = subprocess.run([lua, path], capture_output=True, timeout=30)
        # error messages carry the script path and line numbers: not comparable between files
        out = re.sub(rb"[^\s:]*\.lua:\d+:", b"SCRIPT:", p.stdout)
        return out, p.stderr.decode("latin-1")
    except subprocess.TimeoutExpired:
        return b"", "timeout"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dir")
    ap.add_argument("--lua", default="lua5.1")
    ap.add_argument("--orig", action="append", default=[],
                    help="directory with the original NAME.lua files (the result may match them instead)")
    ap.add_argument("names", nargs="*")
    args = ap.parse_args()
    files = sorted(glob.glob(os.path.join(args.dir, "*.wad.lua")))
    if args.names:
        files = [f for f in files if os.path.basename(f)[:-8] in args.names]
    out_dir = os.path.join(args.dir, "out")
    os.makedirs(out_dir, exist_ok=True)
    ok = 0
    for f in files:
        name = os.path.basename(f)[:-8]
        expected, _ = run(args.lua, f)
        t0 = time.time()
        try:
            res, report = deobfuscate(open(f, "rb").read().decode("latin-1"))
        except Exception as ex:  # noqa
            print("FAIL %-34s crash %r" % (name, ex))
            continue
        dst = os.path.join(out_dir, name + ".lua")
        open(dst, "wb").write(res.encode("latin-1"))
        got, err = run(args.lua, dst)
        lines = res.count("\n")
        matches = None
        if got == expected:
            matches = "obfuscated"
        else:
            for d in args.orig:
                o = os.path.join(d, name + ".lua")
                if os.path.exists(o) and run(args.lua, o)[0] == got:
                    matches = "original"
                    break
        if matches:
            ok += 1
            print("ok   %-34s %5.1fs %4d lines  (= %s)" % (name, time.time() - t0, lines, matches))
        else:
            print("FAIL %-34s %4d lines  %s" % (name, lines, err.strip().splitlines()[0][:110] if err.strip() else "output differs"))
    print("\n%d/%d passed" % (ok, len(files)))
    return 0 if ok == len(files) else 1


if __name__ == "__main__":
    sys.exit(main())

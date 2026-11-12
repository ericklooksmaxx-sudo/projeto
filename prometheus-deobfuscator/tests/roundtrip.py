#!/usr/bin/env python3
"""Round-trip test: obfuscate with Prometheus, deobfuscate, compare program output.

Usage:
    python3 tests/roundtrip.py --prometheus /path/to/Prometheus [--lua lua5.1] [--presets Weak,Medium] [files...]

For every Lua file (default: Prometheus' own tests/*.lua) and every preset:
  1. run the original file                      -> expected output
  2. obfuscate it with the Prometheus CLI       -> obfuscated file
  3. deobfuscate it (statically, this project)  -> recovered file
  4. run the recovered file and compare output with (1)
"""

import argparse
import glob
import os
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

from prometheus_deobf import deobfuscate  # noqa: E402


def run_lua(lua, path, timeout=30):
    try:
        p = subprocess.run([lua, path], capture_output=True, timeout=timeout, cwd=os.path.dirname(path))
        return p.returncode, p.stdout, p.stderr
    except subprocess.TimeoutExpired:
        return -1, b"", b"timeout"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--prometheus", required=True, help="path to the Prometheus checkout")
    ap.add_argument("--lua", default="lua5.1")
    ap.add_argument("--presets", default="Minify,Weak,Cff,Vmify,Medium,Strong")
    ap.add_argument("--keep", help="directory where obfuscated/recovered files are kept")
    ap.add_argument("files", nargs="*")
    args = ap.parse_args()
    files = args.files or sorted(glob.glob(os.path.join(args.prometheus, "tests", "*.lua")))
    presets = args.presets.split(",")
    work = args.keep or tempfile.mkdtemp(prefix="deobf-")
    os.makedirs(work, exist_ok=True)
    cli = os.path.join(args.prometheus, "src", "cli.lua")
    total = ok = 0
    failures = []
    for f in files:
        base = os.path.splitext(os.path.basename(f))[0]
        rc, expected, err = run_lua(args.lua, f)
        if rc != 0:
            print("skip %s (original fails)" % base)
            continue
        for preset in presets:
            total += 1
            obf = os.path.join(work, "%s.%s.obf.lua" % (base, preset))
            rec = os.path.join(work, "%s.%s.deobf.lua" % (base, preset))
            subprocess.run([args.lua, cli, "--preset", preset, "--nocolors", f, "--out", obf],
                           capture_output=True, cwd=args.prometheus)
            if not os.path.exists(obf):
                print("skip %s/%s (obfuscation failed)" % (base, preset))
                total -= 1
                continue
            t0 = time.time()
            try:
                src = open(obf, "rb").read().decode("latin-1")
                out, report = deobfuscate(src)
                open(rec, "wb").write(out.encode("latin-1"))
            except Exception as ex:  # noqa
                failures.append((base, preset, "crash: %r" % ex))
                print("FAIL %-36s %-7s crash %r" % (base, preset, ex))
                continue
            dt = time.time() - t0
            rc2, got, err2 = run_lua(args.lua, rec)
            if got == expected:
                ok += 1
                print("ok   %-36s %-7s %5.1fs %5d -> %4d lines" % (base, preset, dt, src.count("\n") + 1,
                                                                  out.count("\n")))
            else:
                failures.append((base, preset, err2.decode("latin-1")[:200]))
                print("FAIL %-36s %-7s %s" % (base, preset, err2.decode("latin-1").strip()[:160]))
    print("\n%d/%d passed" % (ok, total))
    return 0 if ok == total else 1


if __name__ == "__main__":
    sys.exit(main())

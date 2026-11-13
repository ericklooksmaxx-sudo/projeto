#!/usr/bin/env python3
"""Generate WeAreDevs-obfuscated samples through their public API.

    python3 tests/wad_samples.py OUTDIR file1.lua file2.lua ...

Each input is POSTed to https://wearedevs.net/api/obfuscate (only the script text is sent) and
the result is written to OUTDIR/<name>.wad.lua.  The script is run before and after with `lua`
so broken samples are reported.
"""

import json
import os
import subprocess
import sys
import time
import urllib.request

URL = "https://wearedevs.net/api/obfuscate"


def obfuscate(src, retries=3):
    data = json.dumps({"script": src}).encode("utf-8")
    last = None
    for k in range(retries):
        req = urllib.request.Request(URL, data=data,
                                     headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                body = json.loads(r.read().decode("utf-8"))
            if body.get("success"):
                return body["obfuscated"]
            last = body
        except Exception as ex:  # noqa
            last = ex
        time.sleep(2 * (k + 1))
    raise RuntimeError("obfuscation failed: %r" % (last,))


def run(lua, path):
    p = subprocess.run([lua, path], capture_output=True, timeout=60)
    return p.returncode, p.stdout


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    lua = os.environ.get("LUA", "lua5.1")
    for f in sys.argv[2:]:
        name = os.path.splitext(os.path.basename(f))[0]
        dst = os.path.join(out, name + ".wad.lua")
        if os.path.exists(dst):
            continue
        src = open(f, "rb").read().decode("latin-1")
        rc, expected = run(lua, f)
        if rc != 0:
            print("skip %s (original fails)" % name)
            continue
        try:
            obf = obfuscate(src)
        except Exception as ex:  # noqa
            print("FAIL %s: %s" % (name, ex))
            continue
        with open(dst, "wb") as fh:
            fh.write(obf.encode("latin-1", "replace"))
        rc2, got = run(lua, dst)
        print("%-36s %6d -> %7d bytes  %s" % (name, len(src), len(obf), "ok" if got == expected else "MISMATCH"))
        time.sleep(1)


if __name__ == "__main__":
    main()

"""End-to-end pipeline: loader capture -> abstract VM execution -> lifting."""
from __future__ import annotations

import time
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional

from . import absvm, lifter, loader
from . import luau_ast as A
from . import structure
from .postprocess import postprocess


@dataclass
class Result:
    source: str
    stats: Dict[str, Any] = field(default_factory=dict)
    strings: List[bytes] = field(default_factory=list)
    report: List[str] = field(default_factory=list)


def deobfuscate(src: bytes, log=print, func_budget=150000, verbose=True) -> Result:
    t0 = time.time()
    report = []

    def say(msg):
        report.append(msg)
        if verbose:
            log(msg)

    say("[1/5] emulating the Luraph loader (sandboxed)...")
    cap = loader.capture(src, verbose=False)
    say("      VM found: %d dispatch loops, modes %s; main proto entry captured (%.1fs)" % (
        len(cap.vm.loops), [l.mode for l in cap.vm.loops], cap.elapsed))
    say("      opcodes per mode: %s" % {l.mode: len(l.handlers) for l in cap.vm.loops})
    say("[2/5] abstract execution of the VM (decrypting instructions, resolving control flow)...")
    ex = absvm.Explorer(cap, log=(lambda *a: log(*a)) if verbose == "debug" else (lambda *a: None))
    ex.func_budget = func_budget
    ex.explore()
    nf = len(ex.funcs)
    ninsn = sum(len(fi.code) for fi in ex.funcs.values())
    say("      %d functions, %d instructions recovered (%.1fs)" % (nf, ninsn, time.time() - t0))
    for fi in ex.funcs.values():
        if fi.failures:
            say("      note: function@%d: %s" % (fi.entry, "; ".join(sorted(set(fi.failures))[:3])))
    say("[3/5] lifting to Lua...")
    lc = lifter.LiftContext(ex)
    main_fn = lifter.FunctionLifter(lc, ex.main, 0, {}).lift()
    say("[4/5] structuring control flow (registers -> locals, goto -> if/while)...")
    sstats: Dict[str, Any] = {}
    try:
        structured = structure.structure_program(main_fn.body, sstats)
    except Exception as e:  # never let structuring crash the whole run
        say("      note: structuring failed (%s: %s); keeping flat output" % (type(e).__name__, str(e)[:80]))
        structured = main_fn.body
        sstats = {"error": 1}
    say("      functions structured: %d | flat (irreducible): %d | aliased: %d" % (
        sstats.get("structured", 0), sstats.get("flat", 0), sstats.get("aliased", 0)))
    say("[5/5] simplifying...")
    body = postprocess(structured, lc)
    header = [
        A.Comment("Deobfuscated by luraph-deob (Luraph v15.2 static deobfuscator)"),
        A.Comment("functions: %d | instructions: %d | lifted nodes: %d | unresolved jumps: %d" % (
            nf, ninsn, lc.stats["nodes"], lc.stats["unresolved"])),
    ]
    out = A.to_source(A.Block(header + body))
    stats = dict(lc.stats)
    stats.update(functions_explored=nf, instructions=ninsn, seconds=round(time.time() - t0, 1))
    return Result(out, stats, [], report)

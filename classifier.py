import sys
import os
import time
import math
import json
import pickle
import random
import re
from typing import Dict, Any, List, Optional

import fingerprint

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_FILE = os.path.join(BASE_DIR, "weights.model")
JSON_MODEL_FILE = os.path.join(BASE_DIR, "weights.json")

# ── Tier 1: Certain ───────────────────────────────────────────────
CERTAIN_OPENERS = [
    "This is a lock for",
    "No question about it:",
    "The fingerprint is unmistakable —",
    "Every marker points to",
    "This one is clearly",
]
CERTAIN_MIDDLES = [
    " — the signature match is exact.",
    ", and the pattern stack is a perfect fit.",
    "; the structural markers leave no room for doubt.",
    ", with a textbook fingerprint across the payload.",
    "; the detector is fully aligned on this one.",
]

# ── Tier 2: Pretty sure ───────────────────────────────────────────
SURE_OPENERS = [
    "This looks like",
    "The evidence leans toward",
    "My read is",
    "Most signs point to",
    "This is most likely",
]
SURE_MIDDLES = [
    ", with a strong pattern match behind it.",
    "; the markers line up well.",
    ", though a second signature is still in play.",
    " — confidence is high, not absolute.",
    ", and the structural clues agree.",
]

# ── Tier 3: Unsure ────────────────────────────────────────────────
UNSURE_OPENERS = [
    "This could be",
    "I'd lean toward",
    "A reasonable guess is",
    "The shape suggests",
    "It may be",
    "Possibly",
]
UNSURE_MIDDLES = [
    ", but the signals are only partly there.",
    "; I wouldn't call it certain.",
    ", though another family could explain it.",
    " — the match is thin.",
    ", so treat this as a rough read.",
    "; the payload is ambiguous.",
]

# ── Tier 4: Clueless ──────────────────────────────────────────────
CLUELESS_OPENERS = [
    "I can't make a reliable call here; maybe",
    "The evidence is too weak to name it, possibly",
    "This one is genuinely unclear, maybe",
    "I'm guessing at this point:",
    "No solid match; perhaps",
]
CLUELESS_MIDDLES = [
    " — the model is split across several families.",
    ", but the signature is barely there.",
    "; don't rely on this result.",
    " — too many markers are missing.",
    ", and the confidence is very low.",
]

_cached_model = None

def get_model():
    global _cached_model
    if _cached_model is not None:
        return _cached_model

    candidate_files = [
        JSON_MODEL_FILE,
        MODEL_FILE,
    ]

    for p in candidate_files:
        if os.path.isfile(p):
            try:
                if p.endswith(".json"):
                    with open(p, "r", encoding="utf-8") as f:
                        _cached_model = json.load(f)
                        return _cached_model
                else:
                    with open(p, "rb") as f:
                        _cached_model = pickle.load(f)
                        return _cached_model
            except Exception:
                pass

    return None

def format_name(raw_name: str) -> str:
    name = raw_name.lower().strip()
    if name == "clean":
        return "Unobfuscated (Clean)"
    if name == "moonsec":
        return "MoonSec V3"
    if name == "ironbrew":
        return "IronBrew 2"
    if name == "prometheus":
        return "Prometheus"
    if name == "wearedevs":
        return "WeAreDevs (Prometheus Fork)"
    if name == "luaobfuscator":
        return "LuaObfuscator (Chaotic Good)"
    if name == "luraph":
        return "Luraph / Luarmor"
    if name == "xen":
        return "Synapse Xen"
    return raw_name.capitalize()


def analyze_vm_signals(content: str) -> Dict[str, Any]:
    """Small, dependency-free port of Clyde's VM dispatch/pool checks.

    The detector uses this only as a secondary hint.  It never overrides an
    explicit obfuscator signature; it just makes a low-confidence verdict more
    informative when the payload clearly contains a bytecode interpreter.
    """
    window = content[:500_000]
    lower = window.lower()
    signals: List[str] = []
    score = 0

    # Large numeric tables are the usual opcode/constant pools in Lua VMs.
    pool_hits = 0
    for match in re.finditer(r"\{[\s,0-9.eE+\-]{400,}\}", window):
        body = match.group(0)
        if body.count(",") >= 64:
            pool_hits += 1
            if pool_hits >= 2:
                break
    if pool_hits:
        signals.append("numeric pools")
        score += 2 if pool_hits >= 2 else 1

    # Dispatch loops: a while/for body that immediately fans out into several
    # if/elseif branches is the classic interpreter shape.
    dispatch_hits = 0
    for match in re.finditer(r"\b(while|for)\b[\s\S]{0,2500}?\bdo\b", window, re.IGNORECASE):
        chunk = window[match.end(): match.end() + 3500]
        branches = len(re.findall(r"\b(if|elseif)\b", chunk, re.IGNORECASE))
        if branches >= 4:
            dispatch_hits += 1
            if dispatch_hits >= 2:
                break
    if dispatch_hits:
        signals.append("dispatch branches")
        score += 2 if dispatch_hits >= 2 else 1

    # Interpreter vocabulary.  Require several different terms so normal
    # gameplay code using "stack" or "pc" does not trigger it.
    vocab = [
        "opcode", "instruction", "dispatch", "bytecode", "program counter",
        "stack pointer", "vm_", "proto", "upvalue",
    ]
    vocab_hits = sum(1 for term in vocab if term in lower)
    if vocab_hits >= 3:
        signals.append("interpreter vocabulary")
        score += 1

    # Bytecode/loader plumbing.
    plumbing = [
        "getfenv", "setfenv", "string.char", "table.concat", "loadstring",
        "select(\"#\"", "select('#", "bit32", "bit.bxor",
    ]
    plumbing_hits = sum(1 for term in plumbing if term in lower)
    if plumbing_hits >= 3:
        signals.append("bytecode plumbing")
        score += 1

    return {"score": score, "signals": signals}


def build_verdict(name: str, confidence: float, gap: float) -> str:
    display = format_name(name)
    if confidence > 80 and gap > 30:
        opener = random.choice(CERTAIN_OPENERS)
        middle = random.choice(CERTAIN_MIDDLES)
    elif confidence > 60 or gap > 15:
        opener = random.choice(SURE_OPENERS)
        middle = random.choice(SURE_MIDDLES)
    elif confidence > 35 or gap > 8:
        opener = random.choice(UNSURE_OPENERS)
        middle = random.choice(UNSURE_MIDDLES)
    else:
        opener = random.choice(CLUELESS_OPENERS)
        middle = random.choice(CLUELESS_MIDDLES)
    return f"{opener} {display}{middle}"

def predict_probabilities(content: str, model_data: dict) -> Dict[str, float]:
    """Pure Python inference engine reproducing TF-IDF + LogisticRegression with 0 external dependencies."""
    vocab = model_data.get("vocab", {})
    idf = model_data.get("idf", [])
    classes = model_data.get("classes", [])
    coef = model_data.get("coef", [])
    intercept = model_data.get("intercept", [])

    text = content[:30000]
    ngrams = {}
    n_len = len(text)
    for n in (2, 3, 4):
        for i in range(n_len - n + 1):
            gram = text[i:i+n]
            if gram in vocab:
                ngrams[gram] = ngrams.get(gram, 0) + 1

    vec = {}
    norm_sq = 0.0
    for gram, count in ngrams.items():
        idx = vocab[gram]
        val = (1.0 + math.log(count)) * idf[idx]
        vec[idx] = val
        norm_sq += val * val

    if norm_sq > 0:
        norm = math.sqrt(norm_sq)
        for idx in vec:
            vec[idx] /= norm

    scores = []
    for c_idx in range(len(classes)):
        score = intercept[c_idx]
        for f_idx, val in vec.items():
            score += coef[c_idx][f_idx] * val
        scores.append(score)

    max_s = max(scores) if scores else 0.0
    exp_s = [math.exp(s - max_s) for s in scores]
    sum_exp = sum(exp_s) or 1.0
    return {classes[i].lower(): (exp_s[i] / sum_exp) * 100.0 for i in range(len(classes))}

def detect_advanced(content: str, model_data: dict) -> List[Dict[str, Any]]:
    # If legacy sklearn pipeline exists
    if isinstance(model_data, dict) and "pipeline" in model_data:
        try:
            pipeline = model_data['pipeline']
            probs = pipeline.predict_proba([content[:30000]])[0]
            classes = list(pipeline.classes_)
            results_dict = {classes[i].lower(): float(probs[i] * 100) for i in range(len(classes))}
        except Exception:
            results_dict = predict_probabilities(content, model_data)
    else:
        results_dict = predict_probabilities(content, model_data)

    # Signature scanning uses a much larger window than the model: some real
    # samples carry long clean preambles before the obfuscated payload.
    lower_content = content[:1_000_000].lower()
    header = content[:3000].lower()
    compact_header = header.replace(" ", "")

    # Explicit headers are the strongest evidence and win over generic tokens.
    header_winner = None
    if (
        "protected using luraph" in header
        or "generated using luraph" in header
        or "luraph obfuscator" in header
        or "lura.ph" in header
        or "lrm-" in header
    ):
        header_winner = "luraph"
    elif (
        "protected with moonsec" in header
        or "protected_by_moonsecv" in header
        or "moonsecv2" in header
        or "moonsecv3" in header
    ):
        header_winner = "moonsec"
    elif "ironbrew3:tm:" in header or "generated using ironbrew" in header:
        header_winner = "ironbrew"
    elif (
        "luaobfuscator.com" in header
        or "localv0=string.char;localv1=string.byte" in compact_header
    ):
        header_winner = "luaobfuscator"
    elif "wearedevs.net/obfuscator" in header or "wearedevs obfuscator" in header:
        # WeAreDevs is a Prometheus fork and shares most of its bytecode
        # structure. Its own banner is the only reliable way to tell them
        # apart, so it must be checked before the generic Prometheus markers.
        header_winner = "wearedevs"
    elif "psu obfuscator" in header or "prometheus obfuscator" in header:
        header_winner = "prometheus"
    elif "synapse xen" in header or "synapsexen_" in header:
        header_winner = "xen"

    # Content-wide fallbacks use only distinctive, hard-to-forge markers.
    # Note: Xen payloads frequently contain jokes such as "luraph better then
    # xen bros", so a bare "luraph" token must never decide the class.
    signature_winner = header_winner
    if signature_winner is None:
        if "synapse xen" in lower_content or "synapsexen_" in lower_content:
            signature_winner = "xen"
        elif (
            "api.luarmor.net" in lower_content
            or "protected using luraph" in lower_content
            or "generated using luraph" in lower_content
        ):
            signature_winner = "luraph"
        elif (
            "protected with moonsec" in lower_content
            or "protected_by_moonsecv" in lower_content
        ):
            signature_winner = "moonsec"
        elif "ironbrew3:tm:" in lower_content or "generated using ironbrew" in lower_content:
            signature_winner = "ironbrew"
        elif "wearedevs.net/obfuscator" in lower_content:
            signature_winner = "wearedevs"

    if signature_winner:
        results_dict = {
            k: v * 0.02 for k, v in results_dict.items() if k != signature_winner
        }
        results_dict[signature_winner] = max(
            results_dict.get(signature_winner, 0.0), 96.0
        )

    # Clean code heuristic check (no obfuscator tell-tales, short readable file)
    is_obf_marker = any(
        m in lower_content
        for m in ["moonsec", "ironbrew", "luraph", "prometheus", "wearedevs",
                  "luaobfuscator", "xen", "bitxor", "newproxy"]
    )
    lines = content.strip().splitlines()
    max_line = max((len(line) for line in lines), default=0)
    if not signature_winner and not is_obf_marker and max_line < 300:
        if len(lines) <= 15:
            results_dict["clean"] = max(results_dict.get("clean", 0), 85.0)
        elif len(lines) >= 10:
            # Readable, multi-line source with no obfuscator marker: obfuscator
            # outputs are almost always a handful of enormous lines.
            results_dict["clean"] = max(results_dict.get("clean", 0), 80.0)

    total = sum(results_dict.values())
    if total > 0:
        results = [
            {"name": k, "confidence": float(round((v / total) * 100, 2))}
            for k, v in results_dict.items()
        ]
    else:
        results = [{"name": k, "confidence": float(v)} for k, v in results_dict.items()]

    results.sort(key=lambda x: x["confidence"], reverse=True)
    return results

def detect_obf(content: str) -> Dict[str, float]:
    model_data = get_model()
    if not model_data:
        return {"unobfuscated": 1.0}
    results = detect_advanced(content, model_data)
    return {format_name(r['name']): r['confidence'] / 100.0 for r in results}

def detect_full(content: str) -> Dict[str, Any]:
    model_data = get_model()
    if not model_data:
        return {
            "verdict": "The detector model is unavailable right now.",
            "top": {"name": "unobfuscated", "confidence": 100.0},
            "second": None,
            "confidence": 100.0,
            "gap": 0.0,
            "results": [],
            "display_name": "Unobfuscated (Clean)",
            "vm_signals": {"score": 0, "signals": []},
        }

    results = detect_advanced(content, model_data)
    top = results[0]
    second = results[1] if len(results) > 1 else None
    confidence = top['confidence']
    gap = (confidence - second['confidence']) if second else confidence
    verdict = build_verdict(top['name'], confidence, gap)
    vm_signals = analyze_vm_signals(content)
    if vm_signals["score"] >= 4 and confidence < 70:
        verdict += " VM dispatch patterns are also present in the payload."

    return {
        "verdict": verdict,
        "top": top,
        "second": second,
        "confidence": confidence,
        "gap": gap,
        "results": results,
        "display_name": format_name(top['name']),
        "vm_signals": vm_signals,
    }

# Names the signature detector uses when nothing is obfuscated (or when it cannot tell).
_NOT_OBFUSCATED = ("Clean (Unobfuscated)", "Empty", "Minified / Darklua")


def detect_by_signature(content: str) -> Dict[str, Any]:
    """Signature-based verdict. Needs no model file; same keys the commands read from detect_full()."""
    res = fingerprint.detect_obfuscation(content)
    name = res.get("name") or "Unknown / Custom"
    confidence = float(res.get("confidence") or 0.0)
    if name in _NOT_OBFUSCATED:
        verdict = f"Likely {name}"
    elif name == "Unknown / Custom":
        verdict = "No known obfuscator signature found"
    else:
        verdict = f"Obfuscated with {name}"
    return {
        "verdict": verdict,
        "name": name,
        "display_name": name,
        "confidence": confidence,
        "features": res.get("features") or [],
        "details": res.get("details") or "",
    }


def detect_best(content: str) -> Dict[str, Any]:
    """What `.detect` answers with: the ML model when its file is installed, signatures otherwise.

    detect_full() on its own answers "Clean, 100%" for every script when the model file is missing,
    so it must never be the only detector.
    """
    if get_model():
        return detect_full(content)
    return detect_by_signature(content)


def print_feedback(top, second, confidence, gap):
    print("\n" + "-" * 40)
    verdict = build_verdict(top['name'], confidence, gap)
    print(f"[verdict] {verdict}")
    print(f"[best match] {format_name(top['name'])}  ({confidence:.1f}%)")
    if second:
        print(f"[runner-up] {format_name(second['name'])}  ({second['confidence']:.1f}%)")
    print("-" * 40)

def main():
    if len(sys.argv) < 2:
        print("Usage: python classifier.py <file.lua>")
        return

    target_file = sys.argv[1]
    if not os.path.exists(target_file):
        print(f"Error: File {target_file} not found.")
        return

    model_data = get_model()
    if not model_data:
        print(f"Error: model file '{MODEL_FILE}' not found. Run train.py first.")
        return

    start_time = time.time()
    try:
        with open(target_file, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
    except Exception as e:
        print(f"[!] Error reading file: {e}")
        return

    results = detect_advanced(content, model_data)
    end_time = time.time()

    if not results or results[0]['confidence'] < 0.1:
        print("[!] No reliable match found.")
        return

    top = results[0]
    second = results[1] if len(results) > 1 else None
    confidence = top['confidence']
    gap = (confidence - second['confidence']) if second else confidence

    print_feedback(top, second, confidence, gap)
    print(f"  Prediction took: {(end_time - start_time) * 1000:.2f}ms")

if __name__ == "__main__":
    main()

import re
from typing import Dict, Any, List

def detect_obfuscation(content: str) -> Dict[str, Any]:
    if not content or not content.strip():
        return {
            "name": "Empty",
            "confidence": 0,
            "features": ["No code provided"],
            "details": "The provided file or input is empty.",
            "color": 0x808080
        }

    features: List[str] = []
    scores: Dict[str, float] = {
        "MoonSec V3": 0.0,
        "MoonSec V2": 0.0,
        "IronBrew 2 / AztupBrew": 0.0,
        "Prometheus / PSU": 0.0,
        "LuaObfuscator": 0.0,
        "Luraph / Luarmor": 0.0,
        "Xen / Synapse Xen": 0.0,
        "Goofyscator": 0.0,
        "Minified / Darklua": 0.0,
        "Clean (Unobfuscated)": 0.0
    }

    # 1. MOONSEC V3 & V2
    if re.search(r"This file was protected with MoonSec V3", content, re.IGNORECASE):
        scores["MoonSec V3"] += 95
        features.append("Explicit MoonSec V3 protection banner detected")
    if re.search(r"\(\[\[This file was protected with MoonSec V3[A-Za-z0-9_#\s]+\]\]\):gsub", content):
        scores["MoonSec V3"] += 50
        features.append("MoonSec V3 bytecode decompressor via gsub")
    if re.search(r"=_ENV;\s*[a-zA-Z0-9_]+='", content):
        scores["MoonSec V3"] += 45
        features.append("Characteristic MoonSec V3 _ENV loader structure")
    if re.search(r"MSecAntiTamper", content) or re.search(r"debug\.info\(.*linedefined", content):
        scores["MoonSec V3"] += 25
        features.append("MoonSec anti-tamper module detected")
    if re.search(r"This file was protected with MoonSec V2", content, re.IGNORECASE):
        scores["MoonSec V2"] += 95
        features.append("Explicit MoonSec V2 protection banner detected")

    # 2. IRONBREW 2 / AZTUPBREW
    if re.search(r"return\s+[a-zA-Z0-9_]+\s*\(\s*[a-zA-Z0-9_]+\s*\(\s*\)\s*,", content):
        scores["IronBrew 2 / AztupBrew"] += 80
        features.append("Standard IronBrew 2 dispatcher wrapper pattern (return fn(fn(), ...))")
    if re.search(r"IronBrew", content, re.IGNORECASE) or re.search(r"AztupBrew", content, re.IGNORECASE):
        scores["IronBrew 2 / AztupBrew"] += 90
        features.append("IronBrew / AztupBrew marker detected")
    if re.search(r"BitXor|BitAnd|Bit32|bit\.bxor", content) and re.search(r"\{[0-9,\s]{50,}\}", content):
        scores["IronBrew 2 / AztupBrew"] += 35
        features.append("Virtual opcode table with bitwise operations (IronBrew VM)")

    # 3. PROMETHEUS / PSU
    if re.search(r"newproxy,...metatable,...metatable,select,", content) or re.search(r"newproxy,setmetatable,getmetatable,select,\{...\}\)end\)\(...\)", content):
        scores["Prometheus / PSU"] += 90
        features.append("Prometheus initialization preamble detected")
    if re.search(r"PROMETHEUS", content, re.IGNORECASE):
        scores["Prometheus / PSU"] += 90
        features.append("Prometheus signature tag detected")
    if re.search(r"newproxy\s*\(\s*true\s*\)", content) and re.search(r"getmetatable", content):
        scores["Prometheus / PSU"] += 25
        features.append("Anti-tamper proxy using newproxy(true)")

    # 4. LUAOBFUSCATOR.COM
    if re.search(r"local\s+v0\s*=\s*string\.char;\s*local\s+v1\s*=\s*string\.byte;\s*local\s+v2\s*=\s*string\.sub", content):
        scores["LuaObfuscator"] += 95
        features.append("LuaObfuscator.com Chaotic Good signature")
    if re.search(r"luaobfuscator\.com", content, re.IGNORECASE):
        scores["LuaObfuscator"] += 90
        features.append("LuaObfuscator.com watermark detected")
    if re.search(r"local\s+function\s+v7\s*\(", content) and "string.char" in content:
        scores["LuaObfuscator"] += 35
        features.append("LuaObfuscator string decoding routine")

    # 5. LURAPH / LUARMOR
    if re.search(r"LURAPH|Luraph Script|LuraphVM", content, re.IGNORECASE):
        scores["Luraph / Luarmor"] += 95
        features.append("Luraph virtual machine signature detected")
    if re.search(r"api\.luarmor\.net|luarmor\.net|LRM-", content):
        scores["Luraph / Luarmor"] += 95
        features.append("Luarmor / LRM API loader detected")
    if re.search(r"\(does your environment support load/loadstring\?\)", content):
        scores["Luraph / Luarmor"] += 80
        features.append("Typical Luraph/Luarmor environment support check")

    # 6. XEN / SYNAPSE XEN
    if re.search(r"Synapse Xen|Xen Obfuscator|Xen2", content, re.IGNORECASE):
        scores["Xen / Synapse Xen"] += 95
        features.append("Synapse Xen Obfuscator watermark detected")

    # 7. GOOFYSCATOR
    if re.search(r"goofyscator", content, re.IGNORECASE) or "obfuscated @ discord.gg/25ms" in content:
        scores["Goofyscator"] += 90
        features.append("Goofyscator watermark detected")

    # 8. MINIFIED / DARKLUA
    lines = content.strip().split("\n")
    avg_line_length = len(content) / max(len(lines), 1)
    if len(lines) <= 3 and len(content) > 300:
        scores["Minified / Darklua"] += 40
        features.append("Compressed code in few long lines (Minified)")
    if re.search(r"__darklua", content) or re.search(r"\bdarklua\b", content, re.IGNORECASE):
        scores["Minified / Darklua"] += 85
        features.append("Darklua metadata found")

    # 9. CHECK FOR CLEAN / UNOBFUSCATED
    readable_words = len(re.findall(r"\b(function|local|return|if|then|else|end|for|while|do|print)\b", content))
    max_obf_score = max(v for k, v in scores.items() if k != "Clean (Unobfuscated)")
    if readable_words >= 3 and max_obf_score < 20:
        scores["Clean (Unobfuscated)"] += 75
        features.append("Readable identifiers, standard syntax and no VM detected")

    # Determine best match
    best_name = max(scores, key=lambda k: scores[k])
    raw_score = scores[best_name]

    if raw_score <= 15:
        best_name = "Unknown / Custom"
        confidence = 40.0
        details = "The script does not match any standard public obfuscation pattern."
        color = 0x95A5A6
        features.append("Unidentified structure in known patterns")
    else:
        confidence = min(99.0, max(50.0, raw_score))
        color_map = {
            "MoonSec V3": 0x9B59B6,
            "MoonSec V2": 0x8E44AD,
            "IronBrew 2 / AztupBrew": 0xE67E22,
            "Prometheus / PSU": 0x3498DB,
            "LuaObfuscator": 0xE74C3C,
            "Luraph / Luarmor": 0xC0392B,
            "Xen / Synapse Xen": 0x1ABC9C,
            "Goofyscator": 0xF1C40F,
            "Minified / Darklua": 0x34495E,
            "Clean (Unobfuscated)": 0x2ECC71,
        }
        color = color_map.get(best_name, 0x5865F2)
        details_map = {
            "MoonSec V3": "Lua 5.1/Luau virtual machine obfuscator widely used in Roblox scripts.",
            "MoonSec V2": "Legacy MoonSec version with Lua 5.1 bytecode serialization.",
            "IronBrew 2 / AztupBrew": "High-performance VM-based obfuscator with looped opcode dispatching.",
            "Prometheus / PSU": "Modular obfuscation pipeline with anti-tamper protections and metatable proxies.",
            "LuaObfuscator": "Web-based obfuscator with Chaotic Good string encryption and control flow flattening.",
            "Luraph / Luarmor": "Commercial high-security VM obfuscator with runtime integrity checks.",
            "Xen / Synapse Xen": "Obfuscator built for Synapse and Luau environments.",
            "Goofyscator": "Lightweight obfuscator with name scrambling and hex constants.",
            "Minified / Darklua": "Minified code for size reduction without virtual machine protection.",
            "Clean (Unobfuscated)": "Open-source or unobfuscated Lua code with standard identifiers.",
        }
        details = details_map.get(best_name, "Obfuscator detected via heuristic analysis.")

    return {
        "name": best_name,
        "confidence": round(confidence, 1),
        "features": features,
        "details": details,
        "color": color,
        "line_count": len(lines),
        "char_count": len(content),
    }

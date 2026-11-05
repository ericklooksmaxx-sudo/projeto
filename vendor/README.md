# Third-party code

Code and binaries from other projects that the bot's deobfuscation and readability passes rely on.
Binaries live in `tools/`, source and scripts in this folder. Files inside `vendor/` and `tools/` keep their
upstream names on purpose: they reference each other by name.

## MoonsecDeobfuscator (Prometheus / MoonSec V3)

- Source: https://github.com/tupsutumppu/MoonsecDeobfuscator.git
- Author: tupsutumppu
- Where: C# source in `vendor/moonsec_deobfuscator/`, compiled build in `tools/moonsec/` (Linux x64 and arm64 only).
- Used by: `pipeline.py` for specialized devirtualization and disassembly of Prometheus / MoonSec V3 scripts
  (needs the .NET runtime).
- Upstream watermarks have been replaced with the official Hollow Logger watermark
  (`--  [[ Logged by Hollow Logger https://discord.gg/UWjSZ5ugGJ ]]`).
- Integrated with `unluac` decompilation, darklua optimization, variable name inference and formatting passes.

## Deobfuscator-Luraph-V15

- Source: https://github.com/caomod2077/Deobfuscator-Luraph-V15.git
- Author: caomod2077
- License: MIT, see `luraph_v15/LICENSE`
- Used by: `pipeline.py` (`deobfuscate_luraph_v15()`) for specialized devirtualization of Luraph V15 scripts with a
  behavior-trace fallback (needs Node.js).

## Lua-Deobfuscator (MoonSec V2)

- Source: https://github.com/SixZensED/Lua-Deobfuscator.git
- Author: SixZensED
- Where: `moonsec_v2/` (its npm dependencies are included).
- Used by: `pipeline.py` (`deobfuscate_moonsec_v2()`) for devirtualizing MoonSec V2 scripts to Lua 5.1 bytecode,
  decompiled with `unluac` and reconstructed (needs Node.js and Java).

## unluac

- Used by: `pipeline.py` to decompile Lua 5.1 bytecode (`tools/unluac.jar`, needs Java).

## lune and darklua

- https://github.com/lune-org/lune and https://github.com/seaofvoices/darklua
- Not bundled. `tools/lune` and `tools/darklua` are launchers that look for the real binaries
  (`tools/lune-x86_64`, `tools/lune-aarch64`, ... or anything on `PATH`). The `Dockerfile` installs both.

## Code the bot derives from

These sources are no longer shipped, only credited.

- **hidelat-deobfuscator-byaxom** (axom): https://github.com/axomtools/hidelat-deobfuscator-byaxom.
  `namer.py` is a copy of its `renamer.py` with an attribution header. The bot calls `renamecode()` only when the
  user asks for variable-name inference with `.format --rename` or the AI `format_lua` tool with `rename: true`.
- **clyde-deobf** (Oxygen Deobf): https://github.com/oxygen-Deobf/clyde-deobf, Apache License 2.0
  (`clyde/LICENSE`, kept here). The VM-dispatch heuristic in `classifier.py` is a small Python port of the
  numeric-pool and multi-branch dispatch checks in its `src/vmhunt.js`.

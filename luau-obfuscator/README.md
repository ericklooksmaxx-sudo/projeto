# Kyzen V1.0 — LuaU / Roblox Obfuscator

Kyzen is a LuaU (Roblox) source obfuscator focused on making protected scripts
hard to **dump, log, decompile, or run inside fake-Roblox sandboxes**. It
combines a register-based VM, control-flow flattening, string/constant
encryption, opaque predicates, junk code, an anti-tamper guard, a dedicated
**anti-sandbox / anti-dump** guard, and an optional **encrypted bootstrap
layer** (a second obfuscation layer around the whole script).

> **Legitimate use only.** Kyzen is for protecting *your own* scripts' IP
> against theft/skidding. Obfuscation is not encryption and determined
> reverse-engineers can still analyze output — Kyzen raises the cost, it does
> not make code unbreakable.

---

## Architecture

Kyzen is built on the **Prometheus** obfuscation engine (parser, pipeline, step
framework, register VM compiler, and CFF engine — the strongest LuaU-capable
open base of the three references), vendored under `engine/`. Kyzen keeps the
engine as the proven core and adds its own **identity, presets, protection
steps, and the encrypted bootstrap layer**. Ideas were ported from all three
reference obfuscators:

| From | Idea taken into Kyzen |
|------|-----------------------|
| **Prometheus** | Engine core: LuaU parser/unparser, register VM (`Vmify`), CFF (`Cff`), `EncryptStrings`, `ConstantArray`, `AntiTamper`, `NumbersToExpressions` |
| **IronBrew2** | Register-VM philosophy, randomized opcodes, constant/bytecode encryption, VM integrity, crash-on-tamper |
| **Hercules** | Opaque predicate injector, garbage/junk code inserter, watermark header |

### Protection layers (outer → inner)

```
┌──────────────────────────────────────────────────────────┐
│ Watermark header  "-- protected with Kyzen V1.0"           │
│ ┌──────────────────────────────────────────────────────┐ │
│ │ Encrypted bootstrap loader  (--bootstrap)             │ │  outer layer
│ │  · inner script stored as an encrypted blob           │ │  (static dumps
│ │  · decrypted + loadstring'd only at runtime           │ │   see ciphertext)
│ │  · tamper → decrypt garbage → load fails (integrity)  │ │
│ │  · loader itself VM-obfuscated with --bootstrap-protect│ │
│ │ ┌──────────────────────────────────────────────────┐ │ │
│ │ │ Inner protected script:                           │ │ │
│ │ │  AntiSandbox guard  (anti dump/logger/fake-game)  │ │ │  inner layers
│ │ │  Register VM (Vmify)  — optionally nested          │ │ │
│ │ │  CFF, EncryptStrings, ConstantArray, AntiTamper,   │ │ │
│ │ │  OpaquePredicates, JunkCode, NumbersToExpressions  │ │ │
│ │ └──────────────────────────────────────────────────┘ │ │
│ └──────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

---

## Requirements

- **Lua 5.1** to *run the obfuscator* (`lua5.1`). The obfuscator is a Lua program.
- The *output* targets **LuaU / Roblox** (executors). The VM core is
  Lua5.1-compatible (uses `getfenv`/`setfenv`/`unpack or table.unpack`), which
  Roblox/Luau and executors support.

```bash
sudo apt-get install -y lua5.1   # or build Lua 5.1 / use LuaJIT
```

## Usage

```bash
lua5.1 kyzen.lua [options] input.luau
```

| Option | Meaning |
|--------|---------|
| `--preset NAME` | `Kyzen_Light`, `Kyzen_Medium` (default), `Kyzen_Max`, `Kyzen_Fortress` |
| `--out FILE` | output path (default `input.kyzen.luau`) |
| `--seed N` | deterministic build seed |
| `--luau` / `--lua51` | target version (default `--luau`) |
| `--bootstrap` | add the encrypted bootstrap outer layer |
| `--bootstrap-protect` | bootstrap **and** VM-obfuscate the loader (2 layers) |
| `--no-header` | omit the watermark comment |
| `--pretty` | readable output (disables guards; debugging only) |
| `--list` | list presets |

Examples:

```bash
lua5.1 kyzen.lua --preset Kyzen_Medium script.luau
lua5.1 kyzen.lua --preset Kyzen_Max --out dist/main.luau src/main.luau
lua5.1 kyzen.lua --preset Kyzen_Light --bootstrap-protect script.luau
```

## Presets

| Preset | Steps | Bootstrap | Use when |
|--------|-------|-----------|----------|
| **Kyzen_Light** | VM + EncryptStrings + ConstantArray | — | small size/perf budget |
| **Kyzen_Medium** | + AntiSandbox + AntiTamper + CFF + NumbersToExpr | — | balanced default |
| **Kyzen_Max** | + OpaquePredicates + JunkCode (Strict AntiSandbox) | yes | strong protection |
| **Kyzen_Fortress** | Max + loader also VM-obfuscated | yes (+protect) | heaviest, 2 VM layers |

Higher presets cost size and runtime. Benchmark on your target before shipping.

---

## Anti-dump / anti-sandbox / anti-logger (the headline)

The `AntiSandbox` step (`engine/prometheus/steps/AntiSandbox.lua`) injects a
guard that runs **before** your code (and is itself compiled into the VM). Every
probe is `pcall`-guarded and only trips on a **positive** detection, so clean
environments keep running — only instrumented ones derail. On detection it
**silently derails with a deniable error** (e.g. "attempt to index nil with
'Parent'") instead of an obvious "tamper detected", so dumpers can't grep for it.

Detections:

- **Fake-game / sandbox** — verifies `typeof(game)=="Instance"`,
  `game.ClassName=="DataModel"`, `GetService` returns real Instances,
  `workspace == game:GetService("Workspace")`, `Instance.new` authenticity.
  Sandboxes that stub `game` with tables fail.
- **Marker consistency** — real Roblox always ships `typeof`+`Instance` with
  `game`; a sandbox that nils them to dodge probes is caught.
- **Function-hook / logger** — core C closures (`pcall`, `type`, `tostring`,
  `rawequal`, `get/setmetatable`) checked via `iscclosure` or `debug.info`;
  detours flip the guard.
- **Anti-dump** — `string.dump` existing+working inside a Roblox env means the
  env was instrumented to allow dumping.
- **pcall integrity** — a swallowing `pcall` hook is detected.
- **Strict mode** (`Kyzen_Max`/`Fortress`): function-based `__index`/`__newindex`
  env-metatable loggers, and locked-metatable (`getmetatable(game)` must be a
  string in real Roblox).

> Timing-based anti-debug is intentionally **not** used — it is unreliable
> inside an interpreted VM and false-positives on slow devices.

The **encrypted bootstrap** adds anti-dump at the file level: the inner script
is ciphertext on disk and only materializes at runtime; a static dump yields
nothing, and any edit to the blob corrupts decryption.

---

## Tests

```bash
bash tests/run_tests.sh
```

Verifies, with `lua5.1` (the VM core is Lua5.1-compatible):

- **Correctness** — every preset's output prints exactly what the source prints
  (across closures, metatables, varargs, `pcall`, coroutines, string ops).
- **AntiSandbox** — a faithful Roblox stub runs to completion; a fake sandbox
  (`fake-typeof`) and an instrumented env (`string.dump` re-enabled) crash.
- **Anti-dump** — payload string literals never appear in plaintext.

`tests/rbx_harness.lua` stubs a Roblox environment under lua5.1 to exercise the
guard end-to-end **through the VM**.

### Note on LuaU-native execution testing

Correctness here is validated with `lua5.1`, which is semantically equivalent for
the VM core and the portable bootstrap. Running the **final LuaU output under the
real `luau` interpreter** (for `buffer`/`vector`/Roblox-global paths) requires
permission to execute the `luau` binary in this environment — add a permission
rule for it to enable that extra end-to-end pass.

---

## Limitations (honest)

- Obfuscation ≠ encryption. A skilled analyst with an executor can still trace
  runtime behavior; Kyzen raises cost, not impossibility.
- A dumper that hooks `loadstring`/`load` can capture the decrypted inner script
  — but that inner script is itself VM bytecode, not readable source.
- AntiSandbox Strict may false-positive on exotic executors that globally unlock
  metatables or wrap the env; use non-strict (`Kyzen_Medium`) if so.
- Heavy presets increase size and CPU; test performance on your target.

## Credits & license

Kyzen is a derivative built on the **Prometheus** obfuscator by levno-710
(`engine/LICENSE.prometheus`), with ideas ported from **IronBrew2** and
**Hercules**. Respect each upstream project's license when redistributing.

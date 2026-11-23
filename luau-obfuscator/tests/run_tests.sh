#!/usr/bin/env bash
# Kyzen test suite.
#   * Correctness: obfuscated output must print exactly what the source prints
#     (verified with lua5.1 - the VM core is Lua5.1-compatible).
#   * AntiSandbox: must run in a faithful Roblox stub, crash in a fake sandbox.
#   * Anti-dump: payload strings must not appear in plaintext.
#
# Usage: bash tests/run_tests.sh
set -u
cd "$(dirname "$0")/.."
LUA=${LUA:-lua5.1}
PASS=0; FAIL=0
ok(){ echo "  [PASS] $1"; PASS=$((PASS+1)); }
no(){ echo "  [FAIL] $1"; FAIL=$((FAIL+1)); }

SAMPLES=(tests/sample_rich.luau tests/sample_basic.luau)
PRESETS=(Kyzen_Light Kyzen_Medium Kyzen_Max Kyzen_Fortress)

echo "== Correctness (source output == obfuscated output) =="
for s in "${SAMPLES[@]}"; do
  exp=$($LUA "$s" 2>&1)
  for p in "${PRESETS[@]}"; do
    out="tests/_t_$(basename "$s" .luau)_$p.luau"
    $LUA kyzen.lua --preset "$p" --out "$out" "$s" >/dev/null 2>&1
    got=$($LUA "$out" 2>&1)
    if [ "$exp" = "$got" ]; then ok "$p on $(basename "$s")"; else no "$p on $(basename "$s")"; fi
  done
done

echo "== AntiSandbox (uses Kyzen_Medium build of sample_rich) =="
BUILD=tests/_t_sample_rich_Kyzen_Medium.luau
for mode in authentic none; do
  r=$($LUA tests/rbx_harness.lua "$mode" "$BUILD" 2>&1 | tail -1)
  case "$r" in *ran-to-completion*) ok "guard no-op in '$mode'";; *) no "guard tripped in '$mode': $r";; esac
done
for mode in fake-typeof instrument; do
  r=$($LUA tests/rbx_harness.lua "$mode" "$BUILD" 2>&1 | tail -1)
  case "$r" in *crashed*) ok "guard tripped in '$mode'";; *) no "guard failed to trip in '$mode': $r";; esac
done

echo "== Anti-dump (no plaintext payload-literal leakage) =="
# Payload-specific literals (not VM-infra globals like setmetatable/coroutine,
# which the interpreter itself requires in non-bootstrap presets).
for p in Kyzen_Medium Kyzen_Max Kyzen_Fortress; do
  out="tests/_t_sample_rich_$p.luau"
  n=$(grep -cE 'sum_sq|Quick Brown|vararg|boom' "$out" 2>/dev/null)
  if [ "${n:-1}" = "0" ]; then ok "no payload leak in $p"; else no "payload leak ($n) in $p"; fi
done

rm -f tests/_t_*.luau
echo "== $PASS passed, $FAIL failed =="
[ "$FAIL" = "0" ]

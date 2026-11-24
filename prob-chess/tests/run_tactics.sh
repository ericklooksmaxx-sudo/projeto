#!/usr/bin/env bash
# Bateria tatica. Uso: tests/run_tactics.sh [segundos]
T=${1:-3}
BIN=./belief
ok=0; tot=0
while IFS='|' read -r fen key name; do
  [ -z "$fen" ] && continue
  tot=$((tot+1))
  out=$($BIN analyze --fen "$fen" --time "$T" --seed 20251124 2>/dev/null | sed -n '/^  lance /{n;p}')
  got=$(echo "$out" | awk '{print $1}')
  prob=$(echo "$out" | awk '{print $2}')
  pv=$(echo "$out" | cut -c40-)
  if [ "$got" = "$key" ]; then ok=$((ok+1)); mark="OK  "; else mark="erro"; fi
  printf "%s %-26s chave=%-7s engine=%-7s %6s  %s\n" "$mark" "$name" "$key" "$got" "$prob" "$pv"
done < tests/tactics.txt
echo
echo "acertos: $ok/$tot  (${T}s por posicao)"

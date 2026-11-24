#!/usr/bin/env bash
# Perft contra valores conferidos. Os cinco primeiros sao posicoes padrao;
# o ultimo foi verificado no d=4 contra tests/ref.py, gerador independente.
cd "$(dirname "$0")/.."
ok=0; tot=0
while IFS='|' read -r fen d want name; do
  [ -z "$fen" ] && continue
  tot=$((tot+1))
  got=$(./belief perft "$d" --fen "$fen" | tail -1 | awk '{print $3}')
  if [ "$got" = "$want" ]; then ok=$((ok+1)); m="OK  "; else m="FAIL"; fi
  printf "%s d=%s  %-12s esperado=%-12s  %s\n" "$m" "$d" "$got" "$want" "$name"
done < tests/perft.txt
echo; echo "perft: $ok/$tot"
[ "$ok" = "$tot" ]

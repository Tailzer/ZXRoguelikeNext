#!/bin/sh
# run each regression script against a fresh CSpect
GAME="$(cd "$(dirname "$0")/.." && pwd)"
HERE="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$HERE/sd"; rm -f "$HERE"/sd/*
for t in "$@"; do
  pkill -f CSpect.exe; sleep 3
  (cd "$GAME" && mono "$HOME/CSpect3_0_15_2/CSpect.exe" -w2 -zxnext -s28 -esc -mmc="$HERE/sd/" -map=build/roguelike.map build/roguelike.nex > build/cspect.log 2>&1 &)
  for i in $(seq 1 40); do sleep 1; lsof -iTCP:11000 -sTCP:LISTEN >/dev/null 2>&1 && break; done; sleep 2
  echo "===== $t"
  (cd "$HERE" && python3 -I "$t" "$GAME/build/roguelike.map" 2>&1)
done
pkill -f CSpect.exe; rm -f "$GAME"/mono_crash* 2>/dev/null; true

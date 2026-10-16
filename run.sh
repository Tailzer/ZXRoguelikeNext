#!/bin/sh
# Build, then run in CSpect at 28MHz
cd "$(dirname "$0")"
./build.sh || exit 1
mono "$HOME/CSpect3_0_15_2/CSpect.exe" -w3 -zxnext -s28 -tv -esc -map=build/roguelike.map build/roguelike.nex

#!/bin/sh
# Assemble roguelike.asm -> build/roguelike.nex (+ .sld for DeZog, .map for CSpect)
cd "$(dirname "$0")"
mkdir -p build
sjasmplus --fullpath --sld=build/roguelike.sld --lst=build/roguelike.lst roguelike.asm

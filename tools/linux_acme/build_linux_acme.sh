#!/bin/sh
# Baut ACME (Fork mit PDB/Python-Erweiterungen) fuer Linux, ohne die Windows-/Python-Teile.
# Aufruf: sh build_linux_acme.sh <pfad-zu-acme/src> <zielordner>
# Danach:  <zielordner>/acme -f cbm --cpu 6510 -o x.prg src/main.asm
# WICHTIG: NICHT im Projektordner assemblieren - main.asm schreibt Test.map/.lbl/.pdb
# (hier nur Stubs, Test.pdb waere leer). In einer Kopie bauen.
set -e
SRC="$1"; DST="$2"; mkdir -p "$DST"
cp "$SRC"/*.c "$SRC"/*.h "$DST"/ ; cp "$(dirname "$0")/stubs.c" "$DST"/stubs.c
cd "$DST"
gcc -O1 -w -o acme stubs.c $(ls *.c | grep -v -i '_dos\|_riscos\|_amiga\|stubs\|platform.c') -lm
echo "fertig: $DST/acme"

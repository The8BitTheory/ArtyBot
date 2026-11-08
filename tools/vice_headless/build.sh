#!/bin/sh
# Baut VICE ohne Oberflaeche (headless) fuer automatische Tests mit tools/vice_smoke.py,
# z. B. in der Linux-VM eines Cloud-Chats (kein Netz, kein Root).
#   sh tools/vice_headless/build.sh <vice-x.y.tar.gz> <arbeitsordner>
# Ergebnis: <arbeitsordner>/vice-x.y/src/x64sc und .../x128, ROMs in .../data.
# Der Release-Tarball enthaelt die generierten Monitor-Parser (mon_lex.c, mon_parse.c) und
# psiddrv.h; flex, yacc und xa werden deshalb durch Platzhalter ersetzt, dos2unix durch sed.
# make in Etappen aufrufbar (in Cloud-Chats max. ~3 min je Aufruf): einfach erneut starten.
set -e
TAR="$1"; DST="$2"; mkdir -p "$DST/bin"
cd "$DST"
[ -d vice-* ] || tar xzf "$TAR"
cd vice-*
for t in flex yacc xa; do printf '#!/bin/sh\nexit 0\n' > "$DST/bin/$t"; chmod +x "$DST/bin/$t"; done
cat > "$DST/bin/dos2unix" <<'EOS'
#!/bin/sh
files=""; for a in "$@"; do case "$a" in -*) ;; *) files="$files $a";; esac; done
if [ -z "$files" ]; then sed 's/\r$//'; else for f in $files; do sed -i 's/\r$//' "$f"; done; fi
EOS
chmod +x "$DST/bin/dos2unix"
export PATH="$DST/bin:$PATH"
[ -f Makefile ] || LEX=flex ac_cv_prog_LEX=flex ac_cv_prog_lex_root=lex.yy ac_cv_lib_lex='none needed' \
    ac_cv_prog_lex_yytext_pointer=yes YACC=yacc ./configure --enable-headlessui --without-pulse \
    --without-alsa --without-libcurl --disable-pdf-docs --disable-html-docs --without-png
make -j2 -C src/lib
make -j2 -C src x64sc x128
mkdir -p "$HOME/.local/state/vice" "$HOME/.config/vice"
echo "fertig: $(pwd)/src/x64sc $(pwd)/src/x128"

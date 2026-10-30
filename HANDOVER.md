# Projekt-Handover: ArtyBot

**Stand:** 30.10.2026, 11:40 (Wien) – Welten, Weltkarte als Startbildschirm, Theme-System, Welt-Tor
**Basis:** lokaler Arbeitsstand `C:\Users\martin\iCloudDrive\8bit\robotron\ArtyBot`.
**Abgabe:** Sa 31.10.2026, 12:00.

> **Source of Truth ist der lokale Ordner**, nicht GitHub. Martin committet und pusht selbst in unregelmäßigen Abständen; das Repo kann hinterherhinken.
> Regel für neue Chats: Dieses Dokument zuerst lesen. Ist der lokale Code neuer als das Datum oben, den Code als Wahrheit nehmen und dieses Dokument danach aktualisieren.

## Was das Spiel heute kann

Ein spielbarer Kreislauf **Weltkarte → Planen → Ausführen → Weltkarte** ist im Build enthalten.

**Weltkarte** (`world.asm`, Startbildschirm, Einstieg `world_mode`)
- Aufbau wie Donkey Kong Country Returns: Welten mit mehreren Levels, pro Welt ein Tileset (Theme). Alle Levels einer freigeschalteten Welt sind frei wählbar. Fortschritt nur im RAM (`level_done`, 1 Bit pro Level; `worlds_open`; `gate_done`, 1 Bit pro Welt).
- **Welt-Tor:** Die Öffnung in der ersten Kartenzeile ist ein zweiteiliges Holztor (Kartenzeichen `[` `]`, Zelltypen 7/8, `WM_GATE_L/R`). Geschlossen blockiert es. Sind alle Levels der Welt gelöst und der Spieler kommt nach dem letzten Level auf die Karte zurück, steht das Tor erst ~0,6 s geschlossen da und blinkt dann 3× (Tor ↔ Weg, Ton `sound_place`), danach bleibt es als Weg offen (`world_gate_blink`, `gate_done`). Offen kann es betreten werden: die Figur steht danach vor dem Tor, die nächste Welt wird geöffnet (`worlds_open`) und betreten (`world_check_gate`). Hat die Welt keinen Nachfolger, erscheint "The road ends here - for now".
- Karte 19×10 Zellen (2×2 Zeichen, Run-Grafik des Themes) in einem Fenster, Titel " World n: Name " im Rahmen, Statuszeile + Tastenhilfe unten (wie Run-Bildschirm).
- Roboter-Sprite (wie im Run-Modus, mit Laufanimation) läuft mit **WASD oder Cursor** (gehaltene Taste läuft weiter) nur auf dem **Weg** (Zelltyp 6, sandfarben); Gras, Blumen, Bäume, Wasser blockieren.
- Levelknoten: offenes Level = Zielfeld, gelöstes = goldene Truhe, Levelnummer als Ziffer unten rechts im Knoten. Statuszeile zeigt "Meadow 3 - solved   Space: play".
- **Space/Return** auf einem Knoten oder **Mausklick** auf einen Knoten startet das Level (Planungsbildschirm). Gleiches Level wie zuletzt → Befehlsliste bleibt, anderes Level → leere Liste (`last_level`).
- **F5** nächste Welt (nur Welten, die über das Tor geöffnet wurden), **F3** vorige Welt, **F8** Beenden (Rückfrage). Roboterposition wird pro Welt gemerkt (`world_pos_x/y`).
- Welt 1 "Meadow" = Levels 1–4. Tor, Blinken, Durchgehen, F3/F5 im Simulator getestet (`tools/sim_gate.py`, Weltwechsel mit einer temporären zweiten Welt in einer Kopie).

**Planungsbildschirm** (`editor.asm`, Einstieg `game_main`)
- 10×10-Kartenansicht mit Roboter, Paketen, Zielfeldern, Bäumen und Wasser (aus `mapdata.asm`), Hover-Hilfe für Objekte auf der Karte. Hilfefeld: nur rechte Hälfte unter der Befehlsliste (Spalten 22–39, Zeilen 20–23, `INFO_X/INFO_Y/INFO_W` in defs.inc), **höchstens 16 Zeichen pro Zeile**, 2 Textzeilen (`editor_draw_message2`).
- Befehlspalette (3×3-Raster aus 2×2-Icons, Fenster Zeilen 13–23, **WASD-Layout**): `Q`=Pick Up, `W`=Move Fwd, `E`=Drop Off / `A`=Turn Left, `S`=Move Back, `D`=Turn Right / `Z`=Jump, `X`=Turn 180, `C`=Throw. Tasten und Mausflächen stehen in `editor.asm` (`pal_col/pal_row/pal_label`, `cmd_key_codes`, `pal_grid_cmd`, Icon-Zeichen in `palette_icon_chars`). Befehlsnummern: 0 Fwd, 1 Back, 2 Right, 3 Left, 4 Pick, 5 Drop, 6 Turn 180, 7 Jump, 8 Throw (run.asm `run_fetch`). Das 3×3-Raster ist damit voll.
- Befehlsliste bis 99 Einträge, 17 sichtbare Zeilen, Scrollbar mit Pfeilen.
- Maus (1351, Port 1) und Tastatur: Palette über Q W E A S D Z X C (klein = einfügen; Shift+Buchstabe A–Q wählt Listenzeile), Cursor bewegt die Einfügemarke, Shift+Cursor wählt/verschiebt, Backspace löscht (mit Bestätigung), Shift+CLR/HOME leert die Liste (mit Bestätigung), Return bestätigt, ← bricht ab. Tasten 1–9 wählen ein Level der aktuellen Welt (Liste bleibt).
- **F1** (oder **R**) startet den Run-Modus; **F7** zurück zur Weltkarte; **F8** (= Shift+F7) beendet in allen Modi (mit Rückfrage, Soft-Reset). `X` ist im Plan Turn 180. Untere Zeile "F1:Run F7:Map F8:Quit" ist auch per Maus klickbar.
- Titel "ArtyBot - Plan - Meadow 1" (Weltname + Nummer in der Welt, `put_level_name`); ebenso das Label im Run-Fenster.

**Run-Bildschirm** (`run.asm`, Grafik aus `gfx_run.asm`)
- RPG-Look (NES/SNES-Stil): Multicolour-Feld aus 2×2-Zeichen-Zellen (Gras, Baum = Blocker, Truhe = Paket, schimmerndes Zielfeld, Blumen als Deko, Wasser), Fensterrahmen, Zeigehand.
- Roboter als Multicolour-Sprite mit 2-Frame-Laufanimation in 4 Richtungen, getragene Truhe als eigenes Sprite über dem Kopf.
- Jump: Roboter fliegt 16 Frames im Bogen (Tabelle `run_arc`, 10 px hoch) zwei Felder weit. Throw: die Truhe fliegt als eigenes Sprite im Bogen (`run_throw_arc`, Phase 3) und wird erst bei der Landung ins Feld geschrieben (`run_land`, gemeinsam mit Drop Off).
- Unterer Rahmen des Spielfelds (Zeile 21, Spalte 2): "Delivered: n/m" (Pakete auf Zielen / Zielfelder), Routine `draw_run_delivered` in run.asm, aktualisiert bei Levelstart/Neustart, Aufheben und Ablegen/Landen.
- Befehlsliste rechts, der laufende Befehl wird hervorgehoben und mitgescrollt.
- Steuerung: Space = Start/Pause/Weiter, R = Neustart, **F1** (oder P) = zurück zum Planen, **F8** = Beenden.
- Fehlermeldungen mit Fehlerton: blockiert, nichts aufzuheben, Hände voll, nichts abzulegen, hier nicht ablegbar, Programm zu Ende ohne Lieferung, "can't swim" (ins Wasser gelaufen), Baum im Weg (Jump/Throw), nicht landbar (Jump), nichts zu werfen, hierhin nicht werfbar.
- Erfolg: Ton pro geliefertem Paket, 2-Sekunden-Fanfare wenn alle Zielfelder belegt sind, Level wird als gelöst markiert (`progress_mark`), dann Space = zurück zur Weltkarte, R = Wiederholen.

**Regeln**
- Vorwärts/Rückwärts bewegen ein Feld; Bäume, Pakete, Wasser und Feldrand blockieren (kein Schieben).
- Pick Up / Drop Off wirken auf das Feld vor dem Roboter. Ein Paket kann auch von einem Zielfeld wieder aufgenommen werden.
- **Baum** blockiert den Raum: nicht betretbar, nicht überspringbar, nicht überwerfbar. **Wasser** blockiert den Boden: nicht betretbar, kein Ablegen darauf, aber überspringbar und überwerfbar.
- **Jump**: über das nächste Feld auf das übernächste. Nur ein Baum dazwischen verhindert den Sprung (Wasser und Pakete dürfen dazwischen liegen). Das Landefeld muss im Feld liegen und freier Boden oder ein freies Zielfeld sein. Springen mit Paket in der Hand ist erlaubt.
- **Throw**: das getragene Paket landet zwei Felder voraus (eins weiter als Drop Off). Dazwischen gilt dieselbe Regel wie beim Jump; Landefeld freier Boden oder freies Zielfeld (nicht Wasser).
- Level gewonnen, wenn jedes Zielfeld ein Paket trägt.

**Level** (`mapdata.asm`): 4 Level.
- Level 1: ein Paket, ein Ziel, 6 Bäume.
- Level 2: drei Pakete, drei Ziele, 6 Bäume.
- Level 3 ("Fluss"): Fluss in Spalte 5, Roboter und 2 Pakete links, 2 Ziele rechts. Ziel (6,2) ist von Bäumen eingezäunt und nur zur Wasserseite offen → dieses Paket muss geworfen werden. Kürzeste Lösung 17 Befehle (BFS-Regelmodell; ohne Throw bzw. ohne Jump unlösbar; im Simulator bis zur Fanfare durchgespielt).
- Level 4 (Sokoban-Warehouse): Nachbau eines klassischen Sokoban-Levels (8×9, um (1,0) verschoben). Mauern = Bäume (nur der Ring um den Spielbereich), 7 Ziele, 7 Pakete (eins steht schon auf einem Ziel), Roboter bei (3,2) Richtung unten, direkt links neben dem Paket (4,2). Nicht per BFS auf Lösbarkeit geprüft; assembliert fehlerfrei (Kopie, Linux-ACME).
- Zuordnung zu Welten über `world_table` in `world.asm` (erstes Level + Anzahl).
- Format: variable Datensätze – Roboter x/y/Richtung, dann Listen mit vorangestelltem Anzahl-Byte und (x, y)-Paaren: Ziele, Pakete, Bäume, **Wasserfelder**. Neue Level über `plan_level_table`.

**Sound** (`sound.asm`): kleiner Notensequenzer im Raster-IRQ (Stimme 1): Schritt-Blips je Richtung, Fehler, "Ding-Ding" beim Liefern, Fanfare, Sprung-"Boing" (`sound_jump`, steigende Dreiecksnoten über die 16 Sprungframes), Wurf-"Whoosh" (`sound_throw`, fallende Sägezahnnoten).

## Was fehlt / offen

- Keine Zählung von Versuchen, Schritten oder Befehlen als Wertung. Die Aufgabe nennt ausdrücklich "weniger Befehle oder weniger Versuche".
- Kein Programmlängen-Limit pro Level (Anzeige "PROGRAM: 00/99" existiert).
- Nur 4 Level. Bewertet werden Umfang, Qualität und Abwechslung der Level.
- Kein Titelbild / keine Einleitung.
- Nur eine Welt (Meadow); das Tor von Meadow führt daher noch ins Leere (Meldung "road ends here"). Der Fluss oben (Spalten 11/12) ist bewusst Wasser geblieben, nicht Tor. Zweite Welt (z. B. Winter) braucht: Tileset (7 Run-Zellen + 5 Plan-Kacheln + Farben) als Theme, Levels, Karte in `gen_world_maps.py`, Eintrag in `world_table`.
- Optik des Tors (zwei Holztüren, `gate_l/gate_r` in `gen_gfx_run.py`) ist einfach gehalten, kann verfeinert werden.
- Mausklick auf Knoten im Simulator nicht testbar (keine Maus) – in VICE prüfen.
- Kein DKC-artiger Ausgang am Kartenrand (bewusst weggelassen).
- README beschreibt ein altes Konzept (Joystick, 20 Slots, "ROBOTRON") und die KI-Angaben nennen Codex; vor Abgabe neu schreiben.
- `plan layout.txt` zeigt noch das alte 8×8-Layout.
- `tools/sim_screenshots.py` nutzt noch die alte Tastenbelegung (A–G).

## Dateien

| Datei | Inhalt |
|---|---|
| `src/main.asm` | Einstieg, Include-Reihenfolge, Größenprüfung `< $C000` |
| `src/startup.asm` | BASIC-Stub `SYS 2061`, Hardware/IRQ-Setup, Grafik nach VIC-Bank 3 kopieren |
| `src/editor.asm` | Planungsbildschirm, Palette, Befehlsliste, Eingabe, Aufruf von `run_mode` |
| `src/run.asm` | Run-Bildschirm, Ausführung, Regeln (inkl. Jump/Throw), Sprites, Sieg/Fehler, Levelwechsel |
| `src/world.asm` | Themes (`theme_table`, `theme_load`), Welten (`world_table`), Fortschritt, Weltkarten-Bildschirm (`world_mode`) |
| `src/world_maps.asm` | **generiert** von `tools/gen_world_maps.py` – Weltkarten (Nibble-gepackt) und Knotenlisten |
| `src/mapdata.asm` | Leveldaten, `load_plan_level`, Kartenzeichnung und Hover-Texte im Planungsmodus |
| `src/gfx_data.asm` | Befehls-Icons (`gfx_icons`, `gfx_icons2`), Planungs-Tiles, Zeiger-Sprites |
| `src/gfx_run.asm` | **generiert** von `tools/gen_gfx_run.py` – nicht von Hand ändern |
| `src/sound.asm` | SID-Sequenzer und Effekte |
| `src/input.asm` | Tastaturmatrix, Shift/Repeat, 1351-Maus |
| `src/video.asm`, `irq.asm`, `sprites.asm`, `util.asm` | Bildschirmausgabe, Raster-IRQ, Sprites, Helfer |
| `src/text.asm` | Alle UI-Texte (englisch) |
| `inc/defs.inc`, `inc/zp.inc`, `inc/macros.inc` | Konstanten, Zeropage/RAM, Makros |
| `tools/c64sim.py` | Minimaler C64-Emulator (6502, IRQ, Tastatur, VIC-Renderer) für automatische Tests/Screenshots |
| `tools/sim_screenshots.py` | Baut einen Testplan per Tastendruck ein, startet ihn, speichert Screenshots (alte Tastenbelegung, s. oben) |
| `tools/preview_art.py` | Vorschau der Run-Grafik (inkl. Wasser) |
| `tools/gen_gfx_run.py` | **Generator** von `src/gfx_run.asm` (Run-Zellen inkl. Wasser, UI-Zeichen, Sprites): `python -B tools/gen_gfx_run.py` |
| `tools/gen_plan_tiles.py` | **Generator** der Planungs-Kacheln `$80-$88` (Roboter, Gras, Ziel, Truhe, Baum, Wasser); Ausgabe der `!byte`-Zeilen in `gfx_data.asm` einfügen. |
| `tools/gen_cmd_icons.py` | **Generator** der Icons Pick Up / Drop Off (`$F0-$F7`) sowie Jump / Throw (`$90-$97`, Block `gfx_icons2`); Ausgabe in `gfx_data.asm` einfügen: `python -B tools/gen_cmd_icons.py` |
| `tools/gen_world_maps.py` | **Generator** der Weltkarten als ASCII-Art (`.` Weg, `,` Gras, `T` Baum, `*` Blumen, `~` Wasser, `1`–`9` Levelknoten); prüft Größe und Erreichbarkeit aller Knoten: `python -B tools/gen_world_maps.py` |
| `tools/sim_world.py` | Simulator-Test des Ablaufs Weltkarte → Plan (Lösung Level 1) → Run → Sieg → Karte → Level 2 → F7; Screenshots: `python -B tools/sim_world.py build/roboter.prg out/prefix` |
| `tools/sim_gate.py` | Simulator-Test des Welt-Tors: geschlossen blockiert, Level 1 lösen, Tor blinkt auf der Karte, Durchgehen; Screenshots und Frame-genaue Ausgabe von `wm_gate_open`: `python -B tools/sim_gate.py build/roboter.prg out/prefix` (braucht `Test.map` im Projektordner) |
| `tools/sheet.py` | Vergrößerte Vorschau der Planungs-Kacheln als PNG: `python -B tools/sheet.py [out.png]` (braucht Pillow) |
| `tools/linux_acme/` | `stubs.c` + `build_linux_acme.sh`: baut ACME aus `C:\Users\martin\programme\acme\src` für Linux (für Cloud-Chats ohne Windows). Nur in einer **Kopie** des Projekts assemblieren, sonst überschreibt `main.asm` `Test.lbl/.pdb` (`!svl`/`!pdb`) mit Stub-Ausgaben |

## Werkzeug-Regel (für neue Chats)

- **Vor jedem neuen Skript zuerst `tools/` ansehen** und vorhandene Werkzeuge nutzen oder erweitern; neue Werkzeuge immer in `tools/` ablegen und hier in der Dateitabelle eintragen (Zweck + Aufruf).
- Grafik nie von Hand in `gfx_run.asm` ändern (generiert); Planungs-Kacheln über `gen_plan_tiles.py`, Run-Grafik über `gen_gfx_run.py`, Befehls-Icons über `gen_cmd_icons.py`, Weltkarten über `gen_world_maps.py`.
- Screenshots/Tests: `tools/c64sim.py` + `tools/sim_screenshots.py` (Simulator, kein VICE nötig). Nicht im Projektordner ausführen, ohne `__pycache__` zu bedenken (`python -B` verwenden).
- Zeilenenden beibehalten: `defs.inc`, `zp.inc`, `gfx_data.asm` sind CRLF, die übrigen Quellen LF.

## Speicher

- PRG ab `$0801`, Code muss vor `$C000` enden (Assemblierzeit-Prüfung). Aktuelles PRG ca. 12,3 KB (Ende ca. `$380C`) – viel Platz frei.
- VIC-Bank 3: Screen `$C000`, Zeichensatz `$C800`, Sprites ab `$E000`.
- Zeichen: Planungs-Tiles `$80-$88`, Jump/Throw-Icons `$90-$97` (`ICON2_CHAR_BASE`), Scrollbar-Block `$A0` (ROM-Zeichensatz, nicht überschreiben), Run-Grafik `$A1-$CD` (`RUN_CHAR_BASE`, 9 Zelltypen inkl. Weg und Tor links/rechts + 9 UI-Zeichen), Befehls-Icons `$E0-$FD`. Überlappungen prüft `defs.inc` beim Assemblieren. Frei: `$89-$8F`, `$98-$9F`, `$CE-$DF`, `$FE-$FF`.
- Themes: `theme_load` kopiert die 9 Run-Zellen (288 B) nach `RUN_CHAR_BASE` und die 5 Plan-Kacheln (40 B) nach `FLOOR_CHAR`, dazu Farben (`theme_bg1/2` = `$D022/$D023`, `run_cell_colors`, `map_tile_colors`, im RAM in `world.asm`). Die UI-Zeichen und Roboterpfeile bleiben gemeinsam.
- `map_work` `$0200` (100 Bytes), `goal_list` `$0280`, Befehlsprogramm `$0300` (99 Bytes).
- Zeropage: belegte Adressen in `zp.inc`, `editor.asm` (`$29–$2D`, `$43`, `$61`), `run.asm` (`$46–$60`, `$62–$6B` für Jump/Throw), `sound.asm` (`$F8–$FB`); Welt-Block `$6C–$6D`, `$70–$8C` in `zp.inc`. Vor neuen Variablen alle prüfen.

## Build

Aus dem Projektordner:

```powershell
& 'C:\Users\martin\programme\acme\Release\ACME.exe' -f cbm --cpu 6510 -o build\roboter.prg src\main.asm
```

Nach erfolgreichem Build nur Bescheid geben, **VICE nicht selbst starten** (siehe `AGENTS.md`). `Test.map/.lbl/.pdb` entstehen beim Build. `build\artybot.prg` ist ein altes Artefakt.

## Entscheidungen und Ideen

- Brainstorming 30.10. zu weiteren Level-Elementen (Wasser + Springen/Werfen, zerbrechliche Pakete, Schlüssel/Tore, Schalter, Laser/Spiegel, zeitkritische Elemente, Schleifen) sowie Wertung (Befehle, Schritte, Versuche; Programmlänge als Limit/Belohnung). Empfehlung aus dem Chat: zuerst Wertung und mehr Level, dann Schleife (`WIEDERHOLE n` / `ENDE`); Laser und Zeitmechanik eher streichen.
- _(Hier Entscheidungen aus anderen Chats ergänzen.)_

- **30.10. Planungsmodus-Optik:** Karte als Multicolour-Kacheln im Run-Stil (Gras/Baum/Truhe/Ziel, Roboter = weißer Pfeil), `$D022/$D023` in beiden Modi = `RUN_BG1/2`. Befehlsfarben über `cmd_colors` (editor.asm): Bewegen weiß, Drehen cyan, Aufheben grün, Ablegen lila (Gelb = Auswahl). Zeichen `$80-$88` werden von `tools/gen_plan_tiles.py` erzeugt (Ausgabe in `gfx_data.asm` einfügen). Neue Routine `paint` (video.asm) färbt nur Farb-RAM. Text nur mit Farben 0-7 (>=8 = Multicolour).
- **30.10. Wasser, Jump, Throw:** Wasser als Kachel `T_WATER` (=5) mit eigener Liste im Level-Format; Farbe blau. Regeln siehe oben. Jump/Throw liegen auf Z/C unten im Palettenraster; Farbe Jump weiß (Bewegung), Throw lila (Ablegen). Pakete dürfen übersprungen/überworfen werden (nur Bäume blockieren in der Luft) – bewusst so festgelegt, bei Bedarf in `run_do_jump`/`run_do_throw` ändern.
- **30.10. Welten und Weltkarte:** Welten wie DKC Returns (Welt = Tileset + Levelbereich + Karte), Weltkarte ist Startbildschirm, Levels per Laufen mit der Figur wählbar, Welt n+1 nach Lösen aller Levels von Welt n. Ausgang am Kartenrand vorerst nicht. Datenformat: Theme-Datensatz (Zeiger Run-Zellen, Zeiger Plan-Kacheln, 2 Hintergrundfarben, 7 Zellfarben, 6 Plan-Kachelfarben), Welt-Datensatz (Theme, erstes Level, Anzahl, Zeiger Karte/Name/Knoten). Neuer Zelltyp „Weg“ (sandfarben, Farb-RAM gelb), nur auf der Weltkarte begehbar. Levels bleiben in einer globalen `plan_level_table`.
- **30.10. Welt-Tor:** Statt F5 allein öffnet das Tor die nächste Welt (DKC-Prinzip „Ausgang“ in Form eines Tors in der ersten Kartenzeile). `worlds_open` zählt die besuchbaren Welten, `gate_done` merkt sich pro Welt, dass das Blinken schon lief. Zeropage `$8D/$8E` = Zelle, von der die Figur kam (Ausgangsposition beim Verlassen durchs Tor). `RUN_CHAR_BASE` von `$B8` auf `$A1` verschoben, damit 9 Zelltypen passen (`$A0` ist der Scrollbar-Block).

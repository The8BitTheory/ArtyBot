# Projekt-Handover: ArtyBot

**Stand:** 30.10.2026, ca. 14:00 (Wien) – 2 Welten (Meadow, Winter), 10 Levels, Welt-Tor, Rückweg-Bogen, Level-Statistik, Eis, **Schlüssel/Schloss/Tür (NEU, noch NICHT assembliert/getestet – im Chat war der Rechner nicht mehr erreichbar; als Erstes bauen und `sim_winter.py` laufen lassen)**
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
- **F2** (= Shift+F1, nur Test): markiert alle Levels der aktuellen Welt als gelöst (`world_cheat`); die Karte wird neu betreten und das Tor blinkt auf. Vor der Abgabe ggf. entfernen (Block `cmp #KEY_F1` in `world_mode` und Routine `world_cheat` in `world.asm`).
- **F1** öffnet die **Level-Statistik** als Overlay (`world_stats`): Tabelle mit den Levels einer Welt, Spalten Level (Weltname + Nr.), Solved (Yes/No), Runs, Cmds (`-` = kein Wert, also noch nicht gespielt/gelöst oder nur per F2 gelöst). Zeigt nur die Levels der aktuellen Welt; **F3/F5** schaltet im Overlay zwischen den geöffneten Welten um, jede andere Taste schließt (Rückkehr auf die Karte der Ausgangswelt). **Zählung** (`stats_run_start`, `stats_level_won` in `world.asm`, RAM: `level_runs`, `level_cmds`, je 1 Byte pro Level): Ein Run zählt, wenn die Ausführung startet (`run_go`) und der Plan (Level + Befehlsliste, Prüfsumme `stat_s1/s2`) sich seit dem letzten Start geändert hat. Retry, R, Pause/Weiter und F1-Hin-und-Zurück ohne Änderung zählen nicht. Nach der ersten echten Lösung (`level_cmds` ≠ 0) wird `level_runs` eingefroren (Max. 255). Mit F2 gelöste Levels zeigen bei Runs und Cmds "-" (Runs 0) und zählen bei einem echten Run normal weiter. `level_cmds` = Anzahl ausgeführter Befehle (`run_pc`) bis zur Lieferung des letzten Pakets; bei erneuter Lösung gilt der kürzere Wert. Test: `tools/sim_stats.py`. Fensterhöhe = größte Levelzahl einer Welt + 6.
- **F5** nächste Welt (nur Welten, die über das Tor geöffnet wurden), **F3** vorige Welt, **F8** Beenden (Rückfrage). Roboterposition wird pro Welt gemerkt (`world_pos_x/y`).
- Welt 1 "Meadow" = Levels 1–4, Welt 2 "Winter" = Levels 5–9 (Schnee, Kiefern, Eissee, brauner Weg; Karte mit 5 Knoten rund um einen See).
- **Rückweg:** Jede Welt außer der ersten hat einen Bogen (Kartenzeichen `<`, Zelltyp 9, `WM_BACK`, immer begehbar, cyan). Betreten führt in die vorige Welt (`world_check_gate`), die Figur steht dort wieder vor dem Tor. In Winter liegt er unten links neben Level 1. Der Generator verlangt genau einen `<` in jeder Welt außer Welt 1 und keinen in Welt 1.
- Getestet im Simulator: `tools/sim_winter.py` spielt den ganzen Ablauf durch (alle 7 Levels, Tor blinkt, durch das Tor, zurück durch den Bogen, F5/F3, Winter-Tor ohne Nachfolger); `tools/sim_gate.py` prüft das Blinken Frame für Frame.

**Planungsbildschirm** (`editor.asm`, Einstieg `game_main`)
- 10×10-Kartenansicht mit Roboter, Paketen, Zielfeldern, Bäumen und Wasser (aus `mapdata.asm`), Hover-Hilfe für Objekte auf der Karte. Hilfefeld: nur rechte Hälfte unter der Befehlsliste (Spalten 22–39, Zeilen 20–23, `INFO_X/INFO_Y/INFO_W` in defs.inc), **höchstens 16 Zeichen pro Zeile**, 2 Textzeilen (`editor_draw_message2`).
- **Legende** rechts neben dem Spielfeld (Spalten 12–21, Zeilen 2–11; `draw_legend` in editor.asm, Texte `str_leg_*` in text.asm): ArtyBot-Pfeil + "ArtyBot / looking / <Richtung>" (3 Zeilen, eingerückt), danach nur die im Level vorkommenden Kacheln (Target, Package, Tree, Water, Ice, Key, Lock, Door; Gras entfällt) mit Theme-Farben. Reihenfolge `leg_ids`; bei Platzmangel (Zeile 12) werden die letzten weggelassen.
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
- Steuerung: Space = Start/Pause/Weiter, R = Neustart, **F1** (oder P) = zurück zum Planen, **F7** = direkt zur Weltkarte (jederzeit außer bei der Quit-Rückfrage; Befehlsliste bleibt erhalten, wie Space nach Sieg über `run_to_map`), **F8** = Beenden. Untere Zeile: "Space:Go R:Redo F1:Plan F7:Map F8:Exit".
- Fehlermeldungen mit Fehlerton: blockiert, nichts aufzuheben, Hände voll, nichts abzulegen, hier nicht ablegbar, Programm zu Ende ohne Lieferung, "can't swim" (ins Wasser gelaufen), Baum im Weg (Jump/Throw), nicht landbar (Jump), nichts zu werfen, hierhin nicht werfbar.
- Erfolg: Ton pro geliefertem Paket, 2-Sekunden-Fanfare wenn alle Zielfelder belegt sind, Level wird als gelöst markiert (`progress_mark`), dann Space = zurück zur Weltkarte, R = Wiederholen.

**Regeln**
- Vorwärts/Rückwärts bewegen ein Feld; Bäume, Pakete, Wasser und Feldrand blockieren (kein Schieben).
- Pick Up / Drop Off wirken auf das Feld vor dem Roboter. Ein Paket kann auch von einem Zielfeld wieder aufgenommen werden.
- **Baum** blockiert den Raum: nicht betretbar, nicht überspringbar, nicht überwerfbar. **Wasser** blockiert den Boden: nicht betretbar, kein Ablegen darauf, aber überspringbar und überwerfbar.
- **Jump**: über das nächste Feld auf das übernächste. Nur ein Baum dazwischen verhindert den Sprung (Wasser und Pakete dürfen dazwischen liegen). Das Landefeld muss im Feld liegen und freier Boden oder ein freies Zielfeld sein. Springen mit Paket in der Hand ist erlaubt.
- **Throw**: das getragene Paket landet zwei Felder voraus (eins weiter als Drop Off). Dazwischen gilt dieselbe Regel wie beim Jump; Landefeld freier Boden oder freies Zielfeld (nicht Wasser).
- **Eis** (gefrorenes Wasser, `T_ICE`): begehbar, aber wer es betritt, gleitet in Bewegungsrichtung weiter (auch rückwärts), bis wieder Land (Boden/Ziel) erreicht ist – dort bleibt er stehen – oder bis das nächste Feld blockiert ist (Baum, Paket, Feldrand): dann bleibt er auf dem Eis stehen. **Gleitet er auf offenes Wasser (oder gebrochenes Eis), fällt er hinein: Lauf gescheitert ("can't swim", Roboter versinkt; `run_break=2` → `run_drown`).** Weitere Bewegungen vom Eis aus gleiten genauso. Gleiten: 4 px/Frame, keine Schrittanimation, Whoosh-Ton beim Losgleiten (`run_skate_on`).
- Eis bricht (Fehlschlag "The ice broke!", Kachel gebrochenes Eis `T_BROKEN`): **Jump vom Eis** (sofort), **Jump aufs Eis** (bei der Landung), **Throw aufs Eis** (Paket ist weg). Der Roboter versinkt in den ersten beiden Fällen (Sprites aus, `run_sunk`). Über Eis springen/werfen (Eis als Zwischenfeld) ist erlaubt, ebenso Werfen und Aufheben, während der Roboter auf dem Eis steht.
- **Drop Off aufs Eis** ist nicht erlaubt ("Can't drop here", wie bei Wasser) – bewusst so festgelegt.
- Level gewonnen, wenn jedes Zielfeld ein Paket trägt.

**Level** (`mapdata.asm`): Das Projekt ist noch in der **Findungs- und Design-Phase**. Die Level-Inhalte (Anzahl, Layout, Zuordnung zu Welten, Lösungen) ändern sich laufend und werden hier bewusst **nicht** festgehalten – der Code (`mapdata.asm`, `world_table` in `world.asm`) ist die Wahrheit. Lösbarkeit prüft `tools/solve_levels.py`.
- Zuordnung zu Welten über `world_table` in `world.asm` (erstes Level + Anzahl).
- Format: variable Datensätze – Roboter x/y/Richtung, dann Listen mit vorangestelltem Anzahl-Byte und (x, y)-Paaren: Ziele, Pakete, Bäume, **Wasserfelder**, **Eisfelder** (seit 30.10. in jedem Level, Anzahl 0 wenn keins). Neue Level über `plan_level_table`.

**Sound** (`sound.asm`): kleiner Notensequenzer im Raster-IRQ (Stimme 1): Schritt-Blips je Richtung, Fehler, "Ding-Ding" beim Liefern, Fanfare, Sprung-"Boing" (`sound_jump`, steigende Dreiecksnoten über die 16 Sprungframes), Wurf-"Whoosh" (`sound_throw`, fallende Sägezahnnoten).

## Schlüssel, Schloss, Tür (30.10.)

- **Tile-IDs** (`defs.inc`): `T_KEY`=8, `T_LOCK`=9, `T_LOCKED`=10 (Schloss mit Schlüssel, nur `map_work`), `T_DOOR`=11. Anzeige-Zellen/Plan-Kacheln sind in **jedem Theme an denselben Zeichenpositionen**: Run-Zellen 12–15 (`key`, `lock`, `lock_full`, `door`; `RUN_CELL_ICE`+Tile-ID−`T_ICE`), Plan-Kacheln `$8A` Schlüssel, `$8B` Schloss, `$8C` Tür (`KEY_CHAR/LOCK_CHAR/DOOR_CHAR`). Ein neues Theme (z. B. Computerwelt) zeichnet nur andere Grafik (Keycard / Leseschlitz / Schiebetür) in diese Slots; der Code bleibt gleich. Zeichen in `gen_gfx_run.py` (Meadow, `CELLS['key'|'lock'|'lock_full'|'door']`), `gen_theme_winter.py` (übernimmt Meadow-Art, anpassbar) und `gen_plan_tiles.py` (`KEY/LOCK/DOOR`); Farben pro Theme in `world.asm` (`theme_*`, je 4 Einträge hinter „broken ice“ bzw. `T_BROKEN`).
- **Regeln** (`run.asm`): Schlüssel wird mit Pick Up wie ein Paket aufgenommen (`run_item`=1, Sprite 2 zeigt dann `RUN_SPR_KEY` in `KEY_COLOR`; `run_item`=0 Paket). Drop Off auf freien Boden legt ihn ab; **Drop Off oder Throw auf ein Schloss** (`T_LOCK`) → `T_LOCKED`, `run_open_door` macht die zugehörige Tür zu `T_FLOOR` und zeichnet die Zelle neu (Karte ändert sich dynamisch, Meldung „Click! A door opened.“, Ton `sound_place`). Schlüssel zählt nicht als Lieferung, kann nicht auf Zielfeld/Eis-Ziel abgelegt werden; Pakete passen nicht ins Schloss. Schlüssel, Schloss und geschlossene Tür blockieren das Gehen (auch Gleiten). **Geschlossene Tür blockiert Springen/Werfen wie ein Baum**; Schlüssel und Schloss darf man überspringen/überwerfen, nicht darauf landen. Aufgesetzter Schlüssel kann nicht zurückgenommen werden.
- **Levelformat** (`mapdata.asm`): nach der Eisliste folgen Anzahl Schlüssel + (x,y)-Paare, dann Anzahl Schloss/Tür-Paare (max. `MAX_LOCKS`=4) + Datensätze (Schloss x, y, Tür x, y). Alle alten Levels haben `0, 0` am Ende. Im RAM: `lock_list` `$02A0` (4 Byte je Paar), `lock_count` `$24`, `run_item` `$25` (zp.inc).
- **Levels mit Schlüssel/Tür** (Inhalt siehe Code, Level-Design ist noch im Fluss): Die Winter-Levels sind dadurch um eins nach hinten gerückt (`plan_level_table`, `world_table`).
- **Zeichensatz umgebaut:** `RUN_CHAR_BASE` = `$A0` (ROM-Block `$A0` ist weg, Scrollbalken nutzt `SOLID_CHAR` `$8E`), 16 Run-Zelltypen = `$A0–$DF` (voll), Fensterrahmen `UI_FRAME_BASE` `$98–$9F`, Hand `UI_HAND` `$8D`. Plan-Kacheln `$80–$8C`. Frei: `$8F`, `$FE-$FF`.
- **Solver** (`solve_levels.py`) kennt Schlüssel/Schlösser/Türen; `SOLVE_W=4` für gewichtete (schnelle) Suche bei großen Leveln.
- **Offen/ungetestet:** Build (ACME), Simulatorlauf `tools/sim_winter.py` (Level-5-Programm eingetragen, Winter-Indizes verschoben), Optik der neuen Zellen in VICE, Hover-Texte `str_key/str_lock/str_door` im Plan.

## Was fehlt / offen

- Wertung ist da (Level-Statistik, s. oben), aber keine Schritt-Zählung und kein Programmlängen-Limit.
- Kein Programmlängen-Limit pro Level (Anzeige "PROGRAM: 00/99" existiert).
- Level-Inhalte sind noch Entwurf (Findungsphase). Bewertet werden Umfang, Qualität und Abwechslung der Level.
- Kein Titelbild / keine Einleitung.
- Das Tor der letzten Welt (Winter) führt ins Leere (Meldung "road ends here - for now"); eine dritte Welt braucht: Theme (Zellen + Plan-Kacheln + Farben), Levels, Karte in `gen_world_maps.py` (mit `<`), Eintrag in `world_table`/`theme_table`. Der Fluss oben in Meadow (Spalten 11/12) ist bewusst Wasser geblieben, nicht Tor.
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
| `tools/solve_levels.py` | **Löser** (A*) für die Level aus `mapdata.asm` mit den Regeln aus `run.asm`: kürzeste Lösung als Tastenfolge (w s d a q e x z c); `--greedy` für Level mit vielen Paketen: `python -B tools/solve_levels.py [--greedy] [Levelnummern]` |
| `tools/gen_theme_winter.py` | **Generator** von `src/gfx_winter.asm` (Winter-Zellen + Plan-Kacheln, ASCII-Art); `--preview out.png` zeichnet eine Vorschau: `python -B tools/gen_theme_winter.py` |
| `src/gfx_winter.asm` | **generiert** von `tools/gen_theme_winter.py` – nicht von Hand ändern |
| `tools/sim_winter.py` | Simulator-Durchlauf des ganzen Spiels (Meadow → Tor → Winter → Bogen zurück → Winter-Levels), mit Prüfungen und Screenshots: `python -B tools/sim_winter.py build/roboter.prg out/prefix` (braucht `Test.map`) |
| `tools/sim_ice.py` | Simulator-Test der Eis-Regeln (Eis-Levels): Gleiten stoppt am Baum, Jump aufs/vom Eis und Throw aufs Eis brechen es, Drop aufs Eis abgelehnt, Lösungen gewinnen: `python -B tools/sim_ice.py build/roboter.prg out/prefix` (braucht `Test.map`) |
| `tools/sim_stats.py` | Simulator-Test der Level-Statistik: Runs werden nur bei geändertem Plan gezählt, Befehlszahl nach Sieg, Overlay-Screenshots: `python -B tools/sim_stats.py build/roboter.prg build/labels.txt out/prefix` (Labels mit `acme -l build/labels.txt` erzeugen) |
| `tools/sim_gate.py` | Simulator-Test des Welt-Tors: geschlossen blockiert, Level 1 lösen, Tor blinkt auf der Karte, Durchgehen; Screenshots und Frame-genaue Ausgabe von `wm_gate_open`: `python -B tools/sim_gate.py build/roboter.prg out/prefix` (braucht `Test.map` im Projektordner) |
| `tools/sheet.py` | Vergrößerte Vorschau der Planungs-Kacheln als PNG: `python -B tools/sheet.py [out.png]` (braucht Pillow) |
| `tools/linux_acme/` | `stubs.c` + `build_linux_acme.sh`: baut ACME aus `C:\Users\martin\programme\acme\src` für Linux (für Cloud-Chats ohne Windows). Nur in einer **Kopie** des Projekts assemblieren, sonst überschreibt `main.asm` `Test.lbl/.pdb` (`!svl`/`!pdb`) mit Stub-Ausgaben |

## Werkzeug-Regel (für neue Chats)

- **Vor jedem neuen Skript zuerst `tools/` ansehen** und vorhandene Werkzeuge nutzen oder erweitern; neue Werkzeuge immer in `tools/` ablegen und hier in der Dateitabelle eintragen (Zweck + Aufruf).
- Grafik nie von Hand in `gfx_run.asm` ändern (generiert); Planungs-Kacheln über `gen_plan_tiles.py`, Run-Grafik über `gen_gfx_run.py`, Befehls-Icons über `gen_cmd_icons.py`, Weltkarten über `gen_world_maps.py`.
- Screenshots/Tests: `tools/c64sim.py` + `tools/sim_screenshots.py` (Simulator, kein VICE nötig). Nicht im Projektordner ausführen, ohne `__pycache__` zu bedenken (`python -B` verwenden).
- Zeilenenden beibehalten: `defs.inc`, `zp.inc`, `gfx_data.asm` sind CRLF, die übrigen Quellen LF.

## Speicher

- PRG ab `$0801`, Code muss vor `$C000` enden (Assemblierzeit-Prüfung). Aktuelles PRG ca. 14,4 KB (Ende ca. `$404F`) – viel Platz frei.
- VIC-Bank 3: Screen `$C000`, Zeichensatz `$C800`, Sprites ab `$E000`.
- Zeichen: Planungs-Tiles `$80-$89` (Eis = `ICE_CHAR` `$89`), Jump/Throw-Icons `$90-$97` (`ICON2_CHAR_BASE`), Scrollbar-Block `$A0` (ROM-Zeichensatz, nicht überschreiben), Run-Grafik `$A1-$D9` (`RUN_CHAR_BASE`, 12 Zelltypen inkl. Weg, Tor links/rechts, Bogen, Eis, gebrochenes Eis + 9 UI-Zeichen), Befehls-Icons `$E0-$FD`. Überlappungen prüft `defs.inc` beim Assemblieren. Frei: `$8A-$8F`, `$98-$9F`, `$DA-$DF`, `$FE-$FF`. Bei `$DA-$DF` passt noch genau ein weiterer Zelltyp (4 Zeichen).
- Themes: `theme_load` kopiert die 12 Run-Zellen (384 B) nach `RUN_CHAR_BASE` und die `PLAN_TILE_COUNT` = 6 Plan-Kacheln (48 B, inkl. Eis) nach `FLOOR_CHAR`, dazu Farben (`theme_bg1/2` = `$D022/$D023`, `run_cell_colors`, `map_tile_colors`, `theme_plan_robot` = Farbe der Roboterpfeile im Plan, im RAM in `world.asm`). Die UI-Zeichen und Roboterpfeil-Formen bleiben gemeinsam. Winter: `$D022/$D023` = weiß/hellblau, Roboterpfeile lila (weiß wäre im Schnee unsichtbar), Roboter-Sprite bleibt hellgrau mit schwarzem Rand.
- `map_work` `$0200` (100 Bytes), `goal_list` `$0280`, Befehlsprogramm `$0300` (99 Bytes).
- Zeropage: belegte Adressen in `zp.inc`, `editor.asm` (`$29–$2D`, `$43`, `$61`), `run.asm` (`$46–$60`, `$62–$6B` für Jump/Throw, `$6E`/`$6F`/`$8F` für Eis: `run_skate`, `run_break`, `run_sunk`), `sound.asm` (`$F8–$FB`); Welt-Block `$6C–$6D`, `$70–$8C` in `zp.inc`. Vor neuen Variablen alle prüfen.

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
- **30.10. Winter-Welt und Rückweg:** Welt 2 mit eigenem Tileset (`gen_theme_winter.py`), 3 Levels und Bogen zurück zu Welt 1. Alle Zelltypen sind in allen Themes vorhanden (10 Stück, gleiche Reihenfolge), damit `theme_load` einfach kopiert. Für die Levelprüfung gibt es den Löser `solve_levels.py` (Regeln gegen den Simulator abgeglichen: Lösungen für Level 1–7 gewinnen im Simulator).
- **30.10. Eis (gefrorenes Wasser):** neue Tile-IDs `T_ICE` (6) und `T_BROKEN` (7), Levelformat um eine Eisliste erweitert (alle alten Levels mit 0), zwei neue Zelltypen (Eis, gebrochenes Eis) in beiden Themes und eine Plan-Kachel. Regeln siehe oben; offenes Wasser stoppt das Gleiten wie ein Baum. `solve_levels.py` kennt die Eis-Regeln; `sim_ice.py` gleicht sie mit dem Spiel ab.

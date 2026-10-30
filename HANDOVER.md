# Projekt-Handover: ArtyBot

**Stand:** 30.10.2026, 08:00 (Wien)
**Basis:** lokaler Arbeitsstand `C:\Users\martin\iCloudDrive\8bit\robotron\ArtyBot` = letzter Commit `8e4e64c` ("run mode", 29.10. 16:55) **plus nicht committete Änderungen** in `editor.asm`, `run.asm`, `mapdata.asm`, `sound.asm`, `text.asm`, `defs.inc`, `zp.inc` (zuletzt 30.10. 07:33). Das GitHub-Repo hinkt diesem Stand hinterher.
**Abgabe:** Sa 31.10.2026, 12:00.

> Regel für neue Chats: Dieses Dokument zuerst lesen. Ist der lokale Code neuer als das Datum oben, den Code als Wahrheit nehmen und dieses Dokument danach aktualisieren.

## Was das Spiel heute kann

Ein spielbarer Kreislauf **Planen → Ausführen → nächstes Level** ist im Build enthalten.

**Planungsbildschirm** (`editor.asm`, Einstieg `game_main`)
- 10×10-Kartenansicht mit Roboter, Paketen, Zielfeldern und Blockern (aus `mapdata.asm`), Hover-Hilfe für Objekte auf der Karte. Hilfefeld: nur rechte Hälfte unter der Befehlsliste (Spalten 22–39, Zeilen 20–23, `INFO_X/INFO_Y/INFO_W` in defs.inc), **höchstens 16 Zeichen pro Zeile**, 2 Textzeilen (`editor_draw_message2`).
- Befehlspalette (3×3-Raster aus 2×2-Icons, Fenster Zeilen 13–23, **WASD-Layout**): `Q`=Pick Up, `W`=Move Fwd, `E`=Drop Off / `A`=Turn Left, `S`=Move Back, `D`=Turn Right / `X`=Turn 180 (unter S). Tasten und Mausflächen stehen in `editor.asm` (`pal_col/pal_row/pal_label`, `cmd_key_codes`, `pal_grid_cmd`); Befehlsnummern 0–6 unverändert (run.asm).
- Befehlsliste bis 99 Einträge, 17 sichtbare Zeilen, Scrollbar mit Pfeilen.
- Maus (1351, Port 1) und Tastatur: Palette über Q W E A S D X (klein = einfügen; Shift+Buchstabe A–Q wählt Listenzeile), Cursor bewegt die Einfügemarke, Shift+Cursor wählt/verschiebt, Backspace löscht (mit Bestätigung), Shift+CLR/HOME leert die Liste (mit Bestätigung), Return bestätigt, ← bricht ab.
- **F1** (oder **R**) startet den Run-Modus; **F8** (= Shift+F7) beendet in beiden Modi (mit Rückfrage, Soft-Reset). `X` ist im Plan Turn 180.

**Run-Bildschirm** (`run.asm`, Grafik aus `gfx_run.asm`)
- RPG-Look (NES/SNES-Stil): Multicolour-Feld aus 2×2-Zeichen-Zellen (Gras, Baum = Blocker, Truhe = Paket, schimmerndes Zielfeld, Blumen als Deko), Fensterrahmen, Zeigehand.
- Roboter als Multicolour-Sprite mit 2-Frame-Laufanimation in 4 Richtungen, getragene Truhe als eigenes Sprite über dem Kopf.
- Befehlsliste rechts, der laufende Befehl wird hervorgehoben und mitgescrollt.
- Steuerung: Space = Start/Pause/Weiter, R = Neustart, **F1** (oder P) = zurück zum Planen, **F8** = Beenden.
- Fehlermeldungen mit Fehlerton: blockiert, nichts aufzuheben, Hände voll, nichts abzulegen, hier nicht ablegbar, Programm zu Ende ohne Lieferung.
- Erfolg: Ton pro geliefertem Paket, 2-Sekunden-Fanfare wenn alle Zielfelder belegt sind, dann Space = nächstes Level (leere Befehlsliste), R = Wiederholen.

**Regeln**
- Vorwärts/Rückwärts bewegen ein Feld; Blocker, Pakete und Feldrand blockieren (kein Schieben).
- Pick Up / Drop Off wirken auf das Feld vor dem Roboter. Ein Paket kann auch von einem Zielfeld wieder aufgenommen werden.
- Level gewonnen, wenn jedes Zielfeld ein Paket trägt.

**Level** (`mapdata.asm`): 2 Level. Level 1: ein Paket, ein Ziel, 6 Blocker. Level 2: drei Pakete, drei Ziele, 6 Blocker. Nach dem letzten geht es wieder zu Level 1. Format: variable Datensätze (Roboter x/y/Richtung, Ziele, Pakete, Blocker), neue Level über `plan_level_table`.

**Sound** (`sound.asm`): kleiner Notensequenzer im Raster-IRQ (Stimme 1): Schritt-Blips je Richtung, Fehler, "Ding-Ding" beim Liefern, Fanfare.

## Was fehlt / offen

- Keine Zählung von Versuchen, Schritten oder Befehlen als Wertung. Die Aufgabe nennt ausdrücklich "weniger Befehle oder weniger Versuche".
- Kein Programmlängen-Limit pro Level (Anzeige "PROGRAM: 00/99" existiert).
- Nur 2 Level. Bewertet werden Umfang, Qualität und Abwechslung der Level.
- Kein Titelbild / keine Einleitung, kein Level-Auswahlbildschirm.
- Level-Titel ist fest "Factory"; nur die Ziffer wird gepatcht.
- README beschreibt ein altes Konzept (Joystick, 20 Slots, "ROBOTRON") und die KI-Angaben nennen Codex; vor Abgabe neu schreiben.
- `plan layout.txt` zeigt noch das alte 8×8-Layout.
- Nicht committete Änderungen sichern (Commit + Push), damit das Repo dem Stand entspricht.

## Dateien

| Datei | Inhalt |
|---|---|
| `src/main.asm` | Einstieg, Include-Reihenfolge, Größenprüfung `< $C000` |
| `src/startup.asm` | BASIC-Stub `SYS 2061`, Hardware/IRQ-Setup, Grafik nach VIC-Bank 3 kopieren |
| `src/editor.asm` | Planungsbildschirm, Palette, Befehlsliste, Eingabe, Aufruf von `run_mode` |
| `src/run.asm` | Run-Bildschirm, Ausführung, Regeln, Sprites, Sieg/Fehler, Levelwechsel |
| `src/mapdata.asm` | Leveldaten, `load_plan_level`, Kartenzeichnung und Hover-Texte im Planungsmodus |
| `src/gfx_data.asm` | Befehls-Icons, Planungs-Tiles, Zeiger-Sprites |
| `src/gfx_run.asm` | **generiert** von `tools/gen_gfx_run.py` – nicht von Hand ändern |
| `src/sound.asm` | SID-Sequenzer und Effekte |
| `src/input.asm` | Tastaturmatrix, Shift/Repeat, 1351-Maus |
| `src/video.asm`, `irq.asm`, `sprites.asm`, `util.asm` | Bildschirmausgabe, Raster-IRQ, Sprites, Helfer |
| `src/text.asm` | Alle UI-Texte (englisch) |
| `inc/defs.inc`, `inc/zp.inc`, `inc/macros.inc` | Konstanten, Zeropage/RAM, Makros |
| `tools/c64sim.py` | Minimaler C64-Emulator (6502, IRQ, Tastatur, VIC-Renderer) für automatische Tests/Screenshots |
| `tools/sim_screenshots.py` | Baut einen Testplan per Tastendruck ein, startet ihn, speichert Screenshots |
| `tools/preview_art.py` | Vorschau der Run-Grafik |
| `tools/gen_plan_tiles.py` | **Generator** der Planungs-Kacheln `$80-$8A` (Roboter, Gras, Ziel, Truhe, Baum); Ausgabe der `!byte`-Zeilen in `gfx_data.asm` einfügen. |
| `tools/gen_cmd_icons.py` | **Generator** der Icons Pick Up / Drop Off (Paket + Pfeil, `$F0-$F7`); Ausgabe in `gfx_data.asm` einfügen: `python -B tools/gen_cmd_icons.py` |
| `tools/sheet.py` | Vergrößerte Vorschau der Planungs-Kacheln als PNG: `python -B tools/sheet.py [out.png]` (braucht Pillow) |
| `tools/linux_acme/` | `stubs.c` + `build_linux_acme.sh`: baut ACME aus `C:\Users\martin\programme\acme\src` für Linux (für Cloud-Chats ohne Windows). Nur in einer **Kopie** des Projekts assemblieren, sonst überschreibt `main.asm` `Test.lbl/.pdb` (`!svl`/`!pdb`) mit Stub-Ausgaben |

## Werkzeug-Regel (für neue Chats)

- **Vor jedem neuen Skript zuerst `tools/` ansehen** und vorhandene Werkzeuge nutzen oder erweitern; neue Werkzeuge immer in `tools/` ablegen und hier in der Dateitabelle eintragen (Zweck + Aufruf).
- Grafik nie von Hand in `gfx_run.asm` ändern (generiert); Planungs-Kacheln über `gen_plan_tiles.py`, Run-Grafik über `gen_gfx_run.py`.
- Screenshots/Tests: `tools/c64sim.py` + `tools/sim_screenshots.py` (Simulator, kein VICE nötig). Nicht im Projektordner ausführen, ohne `__pycache__` zu bedenken (`python -B` verwenden).

## Speicher

- PRG ab `$0801`, Code muss vor `$C000` enden (Assemblierzeit-Prüfung). Aktuelles PRG ca. 8,8 KB – viel Platz frei.
- VIC-Bank 3: Screen `$C000`, Zeichensatz `$C800`, Sprites ab `$E000`.
- Zeichen: Planungs-Tiles ab `$80`, Run-Grafik ab `$C0`, Befehls-Icons ab `$E0`.
- `map_work` `$0200` (100 Bytes), `goal_list` `$0280`, Befehlsprogramm `$0300` (99 Bytes).
- Zeropage: belegte Adressen in `zp.inc`, `editor.asm` (`$29–$2D`, `$43`, `$61`), `run.asm` (`$46–$60`), `sound.asm` (`$F8–$FB`). Vor neuen Variablen alle drei prüfen.

## Build

Aus dem Projektordner:

```powershell
& 'C:\Users\martin\programme\acme\Release\ACME.exe' -f cbm --cpu 6510 -o build\roboter.prg src\main.asm
```

Nach erfolgreichem Build nur Bescheid geben, **VICE nicht selbst starten** (siehe `AGENTS.md`). `Test.map/.lbl/.pdb` entstehen beim Build. `build\artybot.prg` ist ein altes Artefakt.

## Entscheidungen und Ideen

- Brainstorming 30.10. zu weiteren Level-Elementen (Wasser + Springen/Werfen, zerbrechliche Pakete, Schlüssel/Tore, Schalter, Laser/Spiegel, zeitkritische Elemente, Schleifen) sowie Wertung (Befehle, Schritte, Versuche; Programmlänge als Limit/Belohnung). Noch nichts entschieden. Empfehlung aus dem Chat: zuerst Wertung und mehr Level, dann Schleife (`WIEDERHOLE n` / `ENDE`), dann Wasser mit Springen; Laser und Zeitmechanik eher streichen.
- _(Hier Entscheidungen aus anderen Chats ergänzen.)_

- **30.10. Planungsmodus-Optik:** Karte als Multicolour-Kacheln im Run-Stil (Gras/Baum/Truhe/Ziel, Roboter = weißer Pfeil), `$D022/$D023` in beiden Modi = `RUN_BG1/2`. Befehlsfarben über `cmd_colors` (editor.asm): Bewegen weiß, Drehen cyan, Aufheben grün, Ablegen lila (Gelb = Auswahl). Zeichen `$80-$8A` werden von `tools/gen_plan_tiles.py` erzeugt (Ausgabe in `gfx_data.asm` einfügen). Neue Routine `paint` (video.asm) färbt nur Farb-RAM. Text nur mit Farben 0-7 (>=8 = Multicolour).

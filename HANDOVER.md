# Projekt-Handover: ArtyBot / Roboter

Stand: 29. Oktober 2026  
Projektpfad: `C:\Users\martin\iCloudDrive\8bit\robotron\roboter`

## Kurzüberblick

Das Repository enthält einen C64-Assembler-Prototyp für einen grafischen Programmier-Editor sowie einen separaten, noch nicht integrierten Robotron/Sokoban-Spielmodus. Der aktuell gebaute PRG startet **den Editor-Prototyp**: eine Werkstattansicht mit leerem Kartenfeld, Befehls-Palette und scrollbarer Programmliste. Es gibt derzeit keinen verbundenen Spiellauf, der die im Editor eingegebenen Befehle ausführt.

ACME-Build am 29.10.2026 erfolgreich abgeschlossen; Ergebnis: `build\roboter.prg`. VICE wurde dabei nicht gestartet.

## Aktiver Programmfluss

`src/main.asm` ist der Assembly-Einstieg. Es lädt Konstanten, Zeropage-Definitionen und Makros, danach BASIC-Stub/Hardware-Setup, Raster-IRQ, Speicherhilfe, Video, SID-Sound, Eingabe, Sprites, Editor, Grafikdaten und UI-Texte. `src/startup.asm` setzt den BASIC-Stub `10 SYS 2061`, richtet CPU/Interrupts ein, kopiert Zeichensatz und Grafikdaten in VIC-Bank 3 und springt nach `game_main`. Das Label `game_main` in `src/editor.asm` ist der aktive Editor-Hauptloop.

Pro Frame wartet die Anwendung auf den Raster-IRQ, aktualisiert Maus- und Tastatureingaben, aktualisiert Hover-Hilfe und Editorzustand und bewegt anschließend Sprites. Der Editor verwaltet bis zu 99 Befehle, zeigt 18 Zeilen gleichzeitig und hat eine Palette mit sieben derzeit aktiven Einträgen innerhalb eines Layouts für 18 Kacheln. Einfügen, Auswahl, vorläufiges Verschieben mit Bestätigung/Abbruch, Löschen mit Bestätigung sowie Scrollen sind implementiert. Das Kartenpanel ist aktuell nur ein leeres 8×8-Feld; es ist nicht mit den Leveldaten verbunden.

## Eingabe im aktiven Prototyp

- Maus: Commodore-1351-kompatibler Proportional-Maus-Input an Port 1; Klick auf Palette fügt ein, Klick auf Listenzeile wählt sie aus.
- Tastatur: Palette per Buchstabentasten A–G; Cursor hoch/runter bewegt Einfügemarke. Umschalt+Cursor hoch/runter wählt und verschiebt einen Listeneintrag. Return bestätigt Auswahl oder Löschung; physische linke Pfeiltaste bricht ab. Backspace startet Löschen.
- Sprite 0 ist der Mauszeiger, Sprite 1 die Einfügemarke.

Die README enthält Steuerungsangaben für ein anderes/früheres Spielkonzept (Joystick Port 2, A/D, W/S, FIRE, 20 Slots) und ist nicht als Anleitung für den aktiven Editor zu verwenden.

## Module und Zuständigkeiten

| Datei | Aufgabe / Status |
|---|---|
| `src/main.asm` | Assembly-Einstieg, Include-Reihenfolge, Debug-Labelausgaben und Größenprüfung gegen `$C000`. |
| `src/startup.asm` | BASIC-Stub, C64-Hardware/IRQ-Setup, Kopieren der Grafikdaten und Start des Editorloops. |
| `src/editor.asm` | Aktiver Editor, UI-Zeichnung, Programmverwaltung, Maus-/Tastaturbedienung und Listeninteraktion. |
| `src/input.asm` | CIA-Tastaturmatrix, Shift/Repeat und 1351-Mausbewegung/Klickerkennung. |
| `src/video.asm` | VIC-Bank 3, Textausgabe, Zeichen-/Tile-/Kartenroutinen. Tile/Kartenroutinen sind für den Spielmodus vorgesehen. |
| `src/irq.asm` | Raster-IRQ bei 50 Hz, Frame-Synchronisierung und Sound-Tick. |
| `src/sound.asm` | SID-Initialisierung sowie Bewegungs-, Fehler- und Erfolgstöne; derzeit nicht vom Editorloop verwendet. |
| `src/sprites.asm` | Mauszeiger- und Einfügemarken-Sprites. |
| `src/gfx_data.asm` | Charset-Icons und Sprite-Bitmapdaten mit Assemblierzeit-Größenprüfungen. |
| `src/text.asm` | UI-Texte; enthält auch ältere, teils ungenutzte Spieltexte. |
| `src/game.asm` | Separater Robotron/Sokoban-Spielmodus: 20 Schritte, Simulation, Box schieben, Versuche, Laufstatus. **Nicht in `main.asm` eingebunden; nicht Bestandteil des gebauten PRG.** |
| `src/levels.asm` | Drei 12×10 ASCII-Level für `game.asm`; **nicht eingebunden**. |
| `src/level.asm` | Ältere Level-Laderoutine, offenbar überholt durch `load_level` in `game.asm`; **nicht eingebunden**. |
| `inc/defs.inc` | Hardwareadressen, Speicherlayout, Farben, Feld-/Eingabe-Konstanten. |
| `inc/zp.inc` | Zeropage-/RAM-Zustand, Programm bei `$0300`, Arbeitskarte ab `$0200`. |
| `inc/macros.inc` | 16-Bit-Pointer setzen und Speicherblöcke kopieren. |

`plan layout.txt` ist ein älterer Layoutentwurf. `project-config.json` ist die ACME-Projektkonfiguration. `Test.map`, `Test.lbl` und `Test.pdb` sind vom Assembler erzeugte Diagnose-/Debugdateien.

## Build und Artefakte

Installationsannahmen: ACME 1.01mp oder neuer; das Makefile nennt optional GNU make und VICE. Der verbindliche direkte Build-Befehl lautet:

```powershell
& 'C:\Users\martin\programme\acme\Release\ACME.exe' -f cbm --cpu 6510 -o build\roboter.prg src\main.asm
```

ACME muss aus dem Projektordner gestartet werden, weil `!source`-Pfade relativ zum Arbeitsverzeichnis aufgelöst werden. Erfolgreicher Build zuletzt mit Exitcode 0. Der Build prüft außerdem, dass `prg_end` unterhalb `$C000` bleibt.

`Makefile` definiert `all`, `run` und `clean`; `run` startet VICE automatisch. **Laut Projektanweisung VICE nach einem erfolgreichen Build nicht selbst starten**, sondern nur den Build-Erfolg melden. `Test.map`, `Test.lbl` und `Test.pdb` werden beim Assemblieren ebenfalls aktualisiert.

## Speicher- und Grafiklayout

- PRG-BASIC-Stub an `$0801`, Startcode bei `$080D` (SYS 2061).
- VIC-Bank 3: Screen-RAM `$C000`, kopierter Zeichensatz `$C800`, Sprites `$E000`.
- Code und Daten müssen vor `$C000` enden; die Assembly enthält eine entsprechende Fehlerprüfung.
- Arbeitskarte liegt ab `$0200`, Befehlsprogramm ab `$0300`.
- Custom-Zeichen beginnen bei `$E0`; Charset-Icons werden nach `$CF00` kopiert. Die Palette zeigt aktuell sieben Befehls-Icons.

## Bekannte Lücken und nächste Schritte

1. Zielprodukt und aktueller Stand abgleichen: Soll der Editor ein eigenständiger Editor-Prototyp sein oder der Programmiereditor für das Robotron-Spiel? README und Titel/Texte (`ArtyBot`, `Factory`) sind nicht konsistent mit Dateinamen/älteren Robotron-Texten.
2. Falls Robotron-Ziel gilt: `game.asm`/`levels.asm` in den aktiven Build integrieren, Editorprogramm und Spielausführung verbinden und den Übergang von Planen zu Ausführen definieren. Aktuell stehen aktiver Editor und Spielmodus getrennt; gleichnamige `game_main`-Labels verhindern vermutlich ein einfaches gleichzeitiges Einbinden.
3. Drei Level, Levelwechsel und Interaktionsregeln gegen das gewünschte Design prüfen. `src/level.asm` wirkt redundant und lädt fest `level_1`, während `game.asm` einen dynamischen Lader enthält.
4. Tastatur- und Mausbedienung auf realer Hardware bzw. in einer passenden C64-Umgebung prüfen; Sprite/Mauscode und Bildschirmkoordinaten hängen von VIC/CIA-Konfiguration ab.
5. README anhand der tatsächlich aktiven Bedienung aktualisieren und Eigenbeiträge für eine Abgabe ergänzen.

## Relevante Einschränkungen

Der Build belegt erfolgreiche Assemblierung, nicht die Laufzeitfunktion auf echter Hardware oder im Emulator. VICE wurde gemäß Projektanweisung nicht gestartet. Das gebaute PRG enthält nur die von `main.asm` eingebundenen Module; insbesondere sind die drei Level und der Sokoban-Ausführungscode derzeit nicht enthalten.

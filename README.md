# ROBOTRON — Programmiere Deinen Roboter!

Ein Programmier-Puzzle für den PAL-C64. Du stellst zwanzig Richtungsschritte zusammen,
drückst FIRE und beobachtest, wie der Roboter den Frachtblock zum grünen Ziel schiebt.
Drei Werkstattkarten, Versuchs-Zähler, klare Rückmeldung und SID-Signale für Bewegung,
Fehler und erfolgreiche Lieferung.

## Spielen

- Joystick in Port 2 oder A/D wählt einen der zwanzig Programmslots.
- Hoch/Runter oder W/S ändert den Befehl des gewählten Slots. Befehle: `>`, `v`, `<`, `^`;
  `-` ist ein leerer Schritt.
- FIRE, Return oder Leertaste startet den Lauf. Bei einem Fehler Taste drücken, Programm anpassen und erneut starten.
- Nach erfolgreicher Lieferung FIRE oder Return drücken, um die nächste Karte zu laden.
- Nach Karte 3 beginnt die Runde wieder bei Karte 1.

## Bauen

Assembler: ACME 1.01mp oder neuer. Mit der hier verwendeten Installation im
Projektverzeichnis ausführen (ACME löst `!source` relativ zum Arbeitsverzeichnis auf):

```powershell
& 'C:\Users\martin\programme\acme\Release\ACME.exe' -f cbm --cpu 6510 -o build\roboter.prg src\main.asm
```

Alternativ im Projektordner `make` verwenden; die Pfade für ACME und VICE sind im
Makefile gesetzt und lassen sich bei Bedarf überschreiben. `make run` baut und startet
das PRG in VICE mit PAL-Timing. Das fertige PRG liegt unter `build/roboter.prg`.

## Technik

Das PRG startet über den BASIC-Stub mit `SYS 2061`. Code und Daten bleiben unter `$C000`;
die VIC-Bank 3 enthält Screen bei `$C000`, den Lower/Uppercase-Zeichensatz bei `$C800`
und Sprite-Daten bei `$E000`. Die Befehlsicons belegen `$E0–$FB`, die Scrollpfeile `$FC–$FD`.
Karte und Programm liegen im normalen C64-RAM. Es wird nach dem Start nichts nachgeladen.

## KI-Angaben für die Abgabe

- KI: OpenAI Codex (GPT-6), in der Codex Desktop-App.
- Beitrag der KI: Assembly-Spielmechanik, Joystick-Editor, Leveldaten sowie Dokumentation.
- Eigener Beitrag: bitte vor Abgabe mit den tatsächlich selbst vorgenommenen Änderungen
  ergänzen (z. B. Spielidee, Level-Design, Grafik/Sound, Tests auf Hardware oder in VICE).

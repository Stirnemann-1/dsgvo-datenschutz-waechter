# 🛡 DSGVO Datenschutz Wächter für Windows

Kleines Programm im Infobereich (unten rechts neben der Uhr). Es überwacht
die Zwischenablage und ersetzt beim Kopieren (**Strg+C**) Personendaten durch
nummerierte Platzhalter. Mit **Strg+Alt+V** wird kopierter Text mit
Platzhaltern wieder mit den Originalen eingefügt.

```
Kopiert:   Sehr geehrte Frau Anna Muster, bitte melden Sie sich unter
           anna.muster@beispiel.ch oder 079 000 00 00.
Eingefügt: Sehr geehrte Frau [NAME_1], bitte melden Sie sich unter
           [EMAIL_1] oder [TELEFON_1].
```

## Installation

1. ZIP herunterladen und entpacken (Rechtsklick → «Alle extrahieren»).
2. Den Ordner **«DSGVO Datenschutz Waechter»** an einen festen Ort
   verschieben, z.B. nach «Dokumente».
3. **«DSGVO Datenschutz Waechter.exe»** doppelklicken.

Windows zeigt beim ersten Start evtl. «Der Computer wurde durch Windows
geschützt», weil das Programm nicht kommerziell signiert ist: auf
**«Weitere Informationen» → «Trotzdem ausführen»** klicken.

Beim ersten Start fragt das Programm, ob es bei jedem Windows-Start
automatisch starten soll. Das lässt sich später im Menü ändern.

Das Schild-Symbol erscheint im Infobereich, evtl. versteckt unter dem
Pfeil **^**. Tipp: Symbol in die Taskleiste ziehen, damit es immer sichtbar ist.

## Bedienung

| Was Du tust | Was passiert |
|---|---|
| Text kopieren (Strg+C) | Personendaten werden durch Platzhalter ersetzt |
| Einfügen (Strg+V) | Text mit Platzhaltern |
| **Strg+Alt+V** | Kopierter Text wird **mit den Originalen** eingefügt, danach liegt wieder die Platzhalter-Version in der Zwischenablage |

**Klick auf das Symbol** öffnet das Menü: DSGVO Datenschutz aktiv (an/aus),
letzte Prüfung, Mit Originalen einfügen, Platzhalter zurückübersetzen,
Original der letzten Kopie, Zuordnungstabelle, Zuordnungen löschen,
Mitteilungen, Beim Windows-Start ausführen, Einstellungen, Beenden.

### Ablauf mit einem KI-Tool

1. E-Mail kopieren (Strg+C) → automatisch bereinigt
2. In ChatGPT, Claude, Copilot usw. einfügen (Strg+V)
3. Antwort kopieren (Strg+C)
4. In der E-Mail **Strg+Alt+V** → echte Namen sind wieder da

Die Zuordnung gilt, solange das Programm läuft.

## Einstellungen

`%APPDATA%\DSGVO Datenschutz Waechter\einstellungen.json` – über das Menü
«Einstellungen öffnen …» (öffnet den Editor), danach «Einstellungen neu laden».
Gleiches Format wie die Mac-Version:

- `kategorien`: Arten ein-/ausschalten
- `immer_ersetzen`, `nie_ersetzen`: eigene Begriffe bzw. Ausnahmen
- `ausgenommene_apps`: Programmnamen, z.B. `"WINWORD.EXE"`, `"EXCEL.EXE"`
- `tastenkuerzel_mit_originalen_einfuegen`: Standard `"ctrl+alt+v"`
  (ctrl, alt, shift, cmd = Windows-Taste)

Hinweis: In Word ist Strg+Alt+V sonst «Inhalte einfügen». Wer das braucht,
wählt ein anderes Kürzel, z.B. `"ctrl+alt+shift+v"`.

## Datenschutz des Programms selbst

- Alles läuft lokal, nichts geht ins Internet.
- Zuordnungstabelle nur im Arbeitsspeicher.
- Protokoll (`protokoll.log` im Einstellungsordner) und Mitteilungen
  enthalten nur Zahlen, nie Inhalte.
- Inhalte aus Passwortmanagern und kopierte Dateien werden nie angefasst.
- Originale in der Zwischenablage werden vom Windows-Zwischenablageverlauf
  (Win+V) und der Cloud-Synchronisation ausgeschlossen.

## Grenzen

Hilfsmittel, **keine Garantie** für DSG/DSGVO-Konformität. Die Windows-Version
erkennt Namen mit Regeln (Anrede, Titel, Grussformel, Vornamenliste,
E-Mail-Adresse); eine Namenserkennung wie Apples NaturalLanguage gibt es unter
Windows nicht. In Programme, die als Administrator laufen, kann Strg+Alt+V
nicht automatisch einfügen – dann einfach Strg+V drücken.

## Selbst bauen

Mit dem [Swift-Toolchain für Windows](https://www.swift.org/install/windows/):

```powershell
swift build -c release --product DatenschutzWaechterWindows
swift run -c release Selbsttest
```

Fertige Pakete baut GitHub Actions bei jedem Hochladen automatisch
(Reiter «Actions» → neuester Lauf → «DSGVO-Datenschutz-Waechter-Windows»).

## Lizenz

Veröffentlicht unter der MIT-Lizenz (Datei `LIZENZ.txt` im Paket bzw.
[LICENSE](LICENSE) im Repository) – © 2026 Urs Stirnemann. Ohne Gewähr.

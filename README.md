# 🛡 DSGVO Datenschutz Wächter (macOS und Windows)

[![Bauen und testen](https://github.com/Stirnemann-1/dsgvo-datenschutz-waechter/actions/workflows/bauen.yml/badge.svg)](https://github.com/Stirnemann-1/dsgvo-datenschutz-waechter/actions/workflows/bauen.yml)

> **Windows:** Anleitung in [README-Windows.md](README-Windows.md). Das fertige
> Windows-Paket gibt es unter [Releases](https://github.com/Stirnemann-1/dsgvo-datenschutz-waechter/releases)
> bzw. im Reiter «Actions».
>
> Diese Seite beschreibt die **macOS-Version**.


Native Menüleisten-App: überwacht die Zwischenablage, ersetzt beim Kopieren
(⌘C) Personendaten durch nummerierte Platzhalter und fügt sie mit **⌃⌥V**
wieder mit den Originalen ein.

```
Kopiert:   Sehr geehrter Herr Müller, Frau Anna Keller (anna.keller@firma.ch,
           079 123 45 67) wohnt an der Bahnhofstrasse 12, 8001 Zürich.
Eingefügt: Sehr geehrter Herr [NAME_1], Frau [NAME_2] ([EMAIL_1],
           [TELEFON_1]) wohnt an der [ADRESSE_1], [PLZ_ORT_1].
```

Gegenüber der Python-Version:
- **Eine eigene App** (`DSGVO Datenschutz Wächter.app`), kein Python nötig
- **Bedienungshilfen-Erlaubnis nur für diese App**, nicht für ganz Python
- Gleiche Erkennung, gleiche Einstellungen (`einstellungen.json` wird übernommen)
- Weniger Arbeitsspeicher, startet sofort

---

## Installation

1. ZIP entpacken (Doppelklick), z.B. in «Downloads».
2. **Terminal** öffnen (⌘Leertaste → «Terminal») und eingeben:

   ```bash
   cd ~/Downloads/datenschutz-waechter-swift
   bash bauen.sh
   ```

Das Skript
- prüft, ob Apples Entwicklerwerkzeuge da sind (sonst öffnet sich das
  Installationsfenster; danach `bash bauen.sh` nochmals starten). Xcode
  selbst ist nicht nötig.
- kompiliert die App und lässt den **Selbsttest** laufen (27 Testfälle).
  Schlägt etwas fehl, wird nichts installiert.
- legt die App nach `~/Applications/DSGVO Datenschutz Wächter.app`
- **ersetzt die Python-Version**, falls vorhanden (Einstellungen bleiben)
- richtet den Autostart beim Anmelden ein

Danach erscheint oben rechts das **Schild-Symbol**.

**Beim ersten Gebrauch**
- Beim ersten **⌃⌥V** fragt macOS nach den **Bedienungshilfen**: dort
  «DSGVO Datenschutz Wächter» einschalten. Ohne diese Erlaubnis legt ⌃⌥V die
  Originale nur in die Zwischenablage und Du drückst selbst ⌘V.
- Hattest Du die Python-Version: unter Bedienungshilfen den Eintrag
  **«Python» ausschalten oder entfernen**, er wird nicht mehr gebraucht.
- Fragt macOS, ob die App Mitteilungen senden darf: **Erlauben**.

**Updates:** Neue Version entpacken und wieder `bash bauen.sh`. Weil die App
lokal signiert wird, fragt macOS danach die Bedienungshilfen neu ab.

---

## Bedienung

| Was Du tust | Was passiert |
|---|---|
| Text kopieren (⌘C) | Wird geprüft. Wurde etwas ersetzt, zeigt das Symbol kurz die Anzahl |
| Einfügen (⌘V) | Text mit Platzhaltern |
| **⌃⌥V** (Control + Option + V) | Kopierter Text wird **mit den Originalen** eingefügt. Danach liegt wieder die Platzhalter-Version in der Zwischenablage |

**Menü (Schild-Symbol):** DSGVO Datenschutz aktiv (an/aus) · letzte Prüfung · ⚠️ Warnung bei
besonders schützenswerten Daten · Mit Originalen einfügen · Platzhalter
zurückübersetzen · Original der letzten Kopie · Zuordnungstabelle ·
Zuordnungen löschen · Mitteilungen · Einstellungen öffnen / neu laden ·
Beenden

### Ablauf mit einem KI-Tool

1. E-Mail kopieren (⌘C) → automatisch bereinigt
2. In ChatGPT, Claude usw. einfügen (⌘V): nur `[NAME_1]`, `[EMAIL_1]` …
3. Antwort kopieren (⌘C)
4. In der E-Mail **⌃⌥V** → echte Namen, Adressen, E-Mails sind wieder da

Die Zuordnung gilt, solange die App läuft (bis zum Abmelden oder Neustart).

---

## Was erkannt wird

`NAME` (Anrede, Titel, Grussformel, Signatur, Vornamenliste, E-Mail-Adresse,
Apples Namenserkennung) · `EMAIL` · `TELEFON` · `IBAN` (mit Prüfziffer) ·
`AHV` · `KREDITKARTE` (Luhn) · `ADRESSE` (de/fr/it, Postfach) · `PLZ_ORT` ·
`GEBURTSDATUM` · `IP` · `PROFIL_URL` · `KENNZEICHEN`. Ausgeschaltet:
`ORGANISATION`, `ORT`, `DATUM`.

Warnung (ohne automatisches Entfernen) bei Hinweisen auf Gesundheit,
Religion, Politik, Intimsphäre, Genetik, Strafverfahren, Sozialhilfe
(Art. 5 lit. c DSG).

## Einstellungen

`~/Library/Application Support/Datenschutz-Waechter/einstellungen.json`,
über das Menü «Einstellungen öffnen …», danach «Einstellungen neu laden».

- `kategorien`: Arten ein-/ausschalten
- `immer_ersetzen`: eigene Begriffe, z.B. `"KUNDE": ["Muster AG"]` → `[KUNDE_1]`
- `nie_ersetzen`: Fehlalarme
- `ausgenommene_apps`: Bundle-IDs, z.B. `"com.microsoft.Word"`
  (herausfinden: `osascript -e 'id of app "Microsoft Word"'`)
- `tastenkuerzel_mit_originalen_einfuegen`: Standard `"ctrl+alt+v"`; ctrl oder
  cmd muss dabei sein; `""` = aus
- `nach_einfuegen_platzhalter_wiederherstellen`: `true`/`false`

## Datenschutz der App selbst

- Alles läuft lokal, nichts geht ins Internet.
- Zuordnungstabelle nur im Arbeitsspeicher.
- Protokoll (`~/Library/Logs/Datenschutz-Waechter.log`) und Mitteilungen
  enthalten nur Zahlen, nie Inhalte.
- Passwortmanager-Inhalte und kopierte Dateien werden nie angefasst.
- Originale in der Zwischenablage werden als vertraulich markiert, damit
  Zwischenablage-Verläufe sie nicht speichern.

## Grenzen

Hilfsmittel, **keine Garantie** für DSG/DSGVO-Konformität. Wichtige Texte vor
dem Weitergeben kontrollieren. Wird etwas ersetzt, wird reiner Text eingefügt
(ohne Formatierung).

## Wenn das Bauen fehlschlägt

Das Skript zeigt die Fehlermeldungen und legt das vollständige Protokoll in
`build.log` ab. Schick mir den Inhalt, dann korrigiere ich es.

## Deinstallieren

```bash
bash ~/Downloads/datenschutz-waechter-swift/deinstallieren.sh
```

## Aufbau

```
Package.swift
Sources/DatenschutzKern/            Erkennung, Platzhalter, Einstellungen (macOS + Windows)
Sources/DatenschutzWaechter/        Menüleisten-App für macOS, ⌃⌥V, Mitteilungen
Sources/DatenschutzWaechterWindows/ Infobereich-App für Windows, Strg+Alt+V
Sources/Selbsttest/                 Prüfungen, laufen bei jedem Bauen
.github/workflows/bauen.yml         baut und testet automatisch auf macOS und Windows
bauen.sh / deinstallieren.sh
```

// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Urs Stirnemann – siehe LICENSE und NOTICE

// DSGVO Datenschutz Wächter – Selbsttest
// Läuft beim Bauen (bauen.sh). Gleiche Fälle wie die Tests der Python-Version.

import DatenschutzKern
import Foundation

var fehlerGesamt = 0
var fehlerImTest = 0

func pruefe(_ bedingung: Bool, _ beschreibung: @autoclosure () -> String, zeile: Int = #line) {
    if !bedingung {
        fehlerImTest += 1
        print("    ✗ Zeile \(zeile): \(beschreibung())")
    }
}

func test(_ name: String, _ block: () throws -> Void) {
    fehlerImTest = 0
    do {
        try block()
    } catch {
        fehlerImTest += 1
        print("    ✗ Fehler: \(error)")
    }
    print(fehlerImTest == 0 ? "  ✓ \(name)" : "  ✗ \(name)")
    fehlerGesamt += fehlerImTest
}

let brief = """
Sehr geehrter Herr Dr. Müller

Wie besprochen sende ich Ihnen die Unterlagen von Anna Keller.
Sie erreichen Frau Keller unter anna.keller@beispiel.ch oder +41 79 123 45 67 bzw. 044 765 43 21.
AHV 756.1234.5678.97, IBAN CH93 0076 2011 6238 5295 7.
Adresse: Bahnhofstrasse 12, 8001 Zürich. Geboren am 12.03.1985.

Freundliche Grüsse
Peter Brunner
Seestrasse 5
8800 Thalwil

"""

let geheim = [
    "Müller", "Anna", "Keller", "anna.keller@beispiel.ch", "79 123 45 67", "765 43 21",
    "756.1234.5678.97", "CH93", "Bahnhofstrasse", "8001 Zürich", "12.03.1985",
    "Peter", "Brunner", "Seestrasse", "Thalwil",
]

print("DSGVO Datenschutz Wächter – Selbsttest")

test("Brief vollständig anonymisiert") {
    let e = Anonymisierer().anonymisieren(brief)
    for g in geheim { pruefe(!e.text.contains(g), "«\(g)» ist noch im Text:\n\(e.text)") }
    pruefe(e.geaendert, "nicht geändert")
}

test("Gleiche Person, gleicher Platzhalter") {
    let a = Anonymisierer()
    let e = a.anonymisieren(brief)
    let pAnna = a.zuordnung.begriffe["Anna Keller"] ?? "?"
    pruefe(a.zuordnung.begriffe["Keller"] == pAnna, "Keller ≠ Anna Keller")
    pruefe(e.text.components(separatedBy: pAnna).count - 1 == 2, "\(pAnna) nicht zweimal im Text")
}

test("Platzhalter stabil über mehrere Kopien") {
    let a = Anonymisierer()
    _ = a.anonymisieren("Bitte rufen Sie Hans Meier an: hans.meier@firma.ch")
    let e2 = a.anonymisieren("Hat Meier schon geantwortet? Mail an hans.meier@firma.ch")
    pruefe(e2.text.contains("[NAME_1]") && e2.text.contains("[EMAIL_1]"), e2.text)
    pruefe(!e2.text.contains("Meier"), e2.text)
}

test("Rückübersetzung") {
    let a = Anonymisierer()
    let e = a.anonymisieren(brief)
    let zurueck = a.zurueckuebersetzen(e.text)
    pruefe(zurueck.anzahl > 10, "nur \(zurueck.anzahl) zurückübersetzt")
    pruefe(zurueck.text.contains("anna.keller@beispiel.ch"), zurueck.text)
    pruefe(zurueck.text.contains("Peter Brunner"), zurueck.text)
}

test("Bereits anonymisierter Text bleibt gleich") {
    let a = Anonymisierer()
    let e = a.anonymisieren(brief)
    let e2 = a.anonymisieren(e.text)
    pruefe(e2.text == e.text && !e2.geaendert, e2.text)
}

test("Keine Fehlalarme in normalem Text") {
    let text = """
    Liebe Kolleginnen und Kollegen,

    2024 Rückblick
    Der Umsatz stieg um 12.5 % auf CHF 1'250'000. Version 1.2.3 ist live.
    Die Sitzung findet am Montag um 14:00 statt, Traktanden siehe Anhang.
    Die Muster AG beschäftigt 150 Mitarbeitende in 12 Ländern.
    Liebes Team, bitte prüft die Zahlen bis Freitag.

    """
    let e = Anonymisierer().anonymisieren(text)
    pruefe(e.text == text, e.text)
}

test("Signatur und Anrede") {
    let e = Anonymisierer().anonymisieren("Hallo Sandra,\n\nanbei die Offerte.\n\nLiebe Grüsse\nMarco Rossi\n")
    for g in ["Sandra", "Marco", "Rossi"] { pruefe(!e.text.contains(g), "«\(g)»: \(e.text)") }
}

test("Französisch und Englisch") {
    let text = "Bonjour Nathalie,\nMerci pour votre message. Mon adresse: Rue de Lausanne 15, 1201 Genève.\n"
        + "Dear Mr. Smith, please call me at +44 20 7946 0958.\nBest regards\nJohn Smith"
    let e = Anonymisierer().anonymisieren(text)
    for g in ["Nathalie", "Rue de Lausanne 15", "1201 Genève", "Smith", "7946", "John"] {
        pruefe(!e.text.contains(g), "«\(g)»: \(e.text)")
    }
}

test("Eigene Begriffe und Ausnahmen") {
    var einstellungen = Einstellungen()
    einstellungen.immerErsetzen = ["KUNDE": ["Projekt Phoenix"]]
    einstellungen.nieErsetzen = ["Peter"]
    let e = Anonymisierer(einstellungen: einstellungen).anonymisieren("Das projekt phoenix startet. Peter kommt auch.")
    pruefe(e.text.contains("[KUNDE_1]"), e.text)
    pruefe(e.text.contains("Peter"), e.text)
}

test("Warnung besonders schützenswert") {
    let e = Anonymisierer().anonymisieren("Herr Huber ist seit Montag krankgeschrieben, Diagnose Burnout.")
    pruefe(e.warnungen.contains("Gesundheit"), "\(e.warnungen)")
    pruefe(!e.text.contains("Huber"), e.text)
}

test("Kategorie ausschalten") {
    var einstellungen = Einstellungen()
    einstellungen.kategorien["EMAIL"] = false
    let e = Anonymisierer(einstellungen: einstellungen).anonymisieren("Kontakt: info@firma.ch")
    pruefe(e.text == "Kontakt: info@firma.ch", e.text)
}

test("Zusätzlicher Namenserkenner") {
    let erkenner: Namenserkenner = { _ in [(kategorie: "NAME", wert: "Zbigniew Wójcik")] }
    let e = Anonymisierer(namenserkenner: [erkenner]).anonymisieren("Gestern hat Zbigniew Wójcik angerufen.")
    pruefe(e.text == "Gestern hat [NAME_1] angerufen.", e.text)
}

test("Name nicht über Zeilenumbruch") {
    let e = Anonymisierer().anonymisieren("Lieber Hansruedi\nDanke!\nLG\nMoni")
    pruefe(e.text.contains("Danke!") && !e.text.contains("Hansruedi") && !e.text.contains("Moni"), e.text)
}

test("Nomen nach Vorname bleibt") {
    let e = Anonymisierer().anonymisieren("Thomas Projektleiter? Nein, Thomas Weber leitet es.")
    pruefe(e.text.contains("Projektleiter") && !e.text.contains("Weber"), e.text)
}

test("Bestellnummer ist keine Telefonnummer") {
    let e = Anonymisierer().anonymisieren("Bestellnr. 0012345678, Tel. 0041 79 555 44 33")
    pruefe(e.text.contains("0012345678") && !e.text.contains("555 44 33"), e.text)
}

test("Nummern in Lesereihenfolge") {
    let e = Anonymisierer().anonymisieren(
        "Sehr geehrter Herr Müller, Frau Anna Keller (anna.keller@firma.ch, 079 123 45 67) wohnt an der "
            + "Bahnhofstrasse 12, 8001 Zürich. Gruss an Frau Keller."
    )
    let erwartet = "Sehr geehrter Herr [NAME_1], Frau [NAME_2] ([EMAIL_1], [TELEFON_1]) wohnt an der "
        + "[ADRESSE_1], [PLZ_ORT_1]. Gruss an Frau [NAME_2]."
    pruefe(e.text == erwartet, e.text)
}

test("Weitere Datenarten") {
    let text = "Server 192.168.1.20, Karte 4111 1111 1111 1111, https://www.linkedin.com/in/anna-keller-123, "
        + "Auto ZH 123456, Patient: Hr. Ali Yilmaz, geb. 1975, KK-Nr 756 9217 0769 85"
    let e = Anonymisierer().anonymisieren(text)
    for k in ["IP", "KREDITKARTE", "PROFIL_URL", "KENNZEICHEN", "NAME", "GEBURTSDATUM", "AHV"] {
        pruefe(e.anzahlFuer(k) >= 1, "\(k) fehlt: \(e.text)")
    }
}

test("Emoji verschiebt nichts") {
    let e = Anonymisierer().anonymisieren("😀 Grüezi Frau Bachmann-Steiner, 👍 Mail an a.b@c.ch 🎉")
    pruefe(e.text == "😀 Grüezi Frau [NAME_1], 👍 Mail an [EMAIL_1] 🎉", e.text)
}

test("Tastenkürzel lesen") {
    let k = try KuerzelLeser.lesen("ctrl+alt+v")
    pruefe(k.code == 9 && k.modifier == KuerzelLeser.control | KuerzelLeser.option && k.anzeige == "⌃⌥V", "\(k)")
    pruefe((try KuerzelLeser.lesen("Control + Option + V")).anzeige == "⌃⌥V", "Schreibweise")
    pruefe((try KuerzelLeser.lesen("cmd+shift+v")).anzeige == "⇧⌘V", "cmd+shift")
    pruefe((try KuerzelLeser.lesen("strg+alt+f5")).code == 96, "F5")
    pruefe(k.windowsTaste == 0x56 && k.windowsModifier == 0x4003 && k.anzeigeWindows == "Strg+Alt+V", "Windows: \(k.windowsTaste) \(k.windowsModifier) \(k.anzeigeWindows)")
    pruefe((try KuerzelLeser.lesen("ctrl+shift+f5")).windowsTaste == 0x74, "Windows F5")
    for falsch in ["alt+v", "v", "ctrl+ä", "hyper+v"] {
        pruefe((try? KuerzelLeser.lesen(falsch)) == nil, "«\(falsch)» hätte abgelehnt werden sollen")
    }
}

test("Einstellungen aus JSON") {
    let json: [String: Any] = [
        "_hinweis": "x",
        "kategorien": ["EMAIL": false, "_x": "y"] as [String: Any],
        "nie_ersetzen": ["Zürich"],
        "tastenkuerzel_mit_originalen_einfuegen": "cmd+shift+v",
        "benachrichtigungen": false,
    ]
    let e = Einstellungen(json: json)
    pruefe(e.kategorien["EMAIL"] == false && e.kategorien["NAME"] == true, "kategorien")
    pruefe(e.nieErsetzen == ["Zürich"] && e.tastenkuerzel == "cmd+shift+v" && !e.benachrichtigungen, "Werte")
}

test("Langer Text ist schnell") {
    var teile: [String] = []
    for _ in 0..<150 {
        teile.append("Herr Meier schrieb an hans.meier@firma.ch, Tel. 079 123 45 67.\nBahnhofstrasse 1\n8000 Zürich\n")
        teile.append(String(repeating: "Der Umsatz stieg deutlich und das Projekt läuft gut.\n", count: 20))
    }
    let text = teile.joined()
    let start = Date()
    let e = Anonymisierer().anonymisieren(text)
    let dauer = Date().timeIntervalSince(start)
    print("    \(text.utf16.count) Zeichen in \(String(format: "%.2f", dauer)) s")
    pruefe(e.anzahlFuer("EMAIL") == 150 && e.anzahlFuer("TELEFON") == 150, e.zusammenfassung)
    pruefe(dauer < 5, "zu langsam: \(dauer) s")
}

// MARK: Keine Fehlalarme bei Pronomen, Rollen- und Alltagswörtern

let alltag = [
    "Mein Name ist Peter Müller. Uns geht es gut. Mein Vorschlag: Unser Team trifft sich am Montag.",
    "Hallo zusammen,\nmein Laptop ist kaputt. Könnt ihr uns helfen? Meine Kollegin meldet sich.\nLiebe Grüsse\nEuer Support",
    "Liebe Grüsse\nMein Team",
    "Sehr geehrte Damen und Herren\nWir danken Ihnen. Meines Erachtens passt das.\nFreundliche Grüsse\nIhr Kundendienst",
    "Hoi Mami, mein Zug kommt um 18 Uhr. Uns allen geht es gut.",
]

/// Simuliert eine Namenserkennung, die Wörter am Satzanfang falsch als Namen meldet
let lauteErkennung: Namenserkenner = { text in
    let muster = RE(#"(?:^|(?<=[.!?]\s)|(?<=\n))([A-ZÄÖÜ][a-zäöü]+)"#)
    return muster.alle(text).compactMap { m in
        Range(m.range(at: 1), in: text).map { (kategorie: "NAME", wert: String(text[$0])) }
    }
}

test("Pronomen und Rollen bleiben stehen") {
    let a = Anonymisierer(namenserkenner: [lauteErkennung])
    for (i, text) in alltag.enumerated() {
        let e = a.anonymisieren(text)
        if i == 0 {
            pruefe(!e.text.replacingOccurrences(of: "[NAME_1]", with: "").contains("[NAME_"), e.text)
        } else {
            pruefe(e.text == text, e.text)
        }
    }
    let originale = a.zuordnung.tabelle().map { $0.original }
    pruefe(originale == ["Peter Müller"], "\(originale)")
}

test("Falsch gemerktes Wort bleibt nicht hängen") {
    let a = Anonymisierer(namenserkenner: [lauteErkennung])
    _ = a.anonymisieren("Mein Auto ist rot.")
    let e = a.anonymisieren("Mein Velo ist blau.")
    pruefe(e.text == "Mein Velo ist blau.", e.text)
}

test("Nachnamen, die auch Wörter sind") {
    let e = Anonymisierer().anonymisieren("Sehr geehrter Herr Clement, Herr Weiss weiss Bescheid. Grüsse an Frau Kurz.")
    for g in ["Clement", "Weiss", "Kurz"] { pruefe(!e.text.contains(g), "«\(g)»: \(e.text)") }
    pruefe(e.text.contains("weiss Bescheid"), e.text)
}

test("Apple-Einzelwort mitten im Satz") {
    let erkenner: Namenserkenner = { _ in [(kategorie: "NAME", wert: "Zbigniew")] }
    let e = Anonymisierer(namenserkenner: [erkenner])
        .anonymisieren("Zbigniew hat angerufen. Bitte Zbigniew zurückrufen.")
    pruefe(!e.text.contains("Zbigniew"), e.text)
}

test("Alltagstext bleibt unverändert") {
    let text = """
    Guten Morgen

    Wie besprochen schicke ich Euch die Unterlagen für unser Projekt. Leider hat sich der Termin verschoben,
    deshalb treffen wir uns neu am Donnerstag um 14 Uhr im grossen Sitzungszimmer. Bitte bringt Eure Laptops mit.
    Unser Ziel ist es, bis Ende Monat eine Lösung zu haben. Dein Input ist uns wichtig, also meldet Euch bei Fragen.
    Danke und bis bald!
    Euer Projektteam
    """
    let e = Anonymisierer(namenserkenner: [lauteErkennung]).anonymisieren(text)
    pruefe(e.text == text, e.text)
}

test("Windows-Zeilenumbrüche (CRLF)") {
    let text = "Hallo Zoran\r\nDanke für die Offerte.\r\n\r\nLiebe Grüsse\r\nMarco Rossi\r\n"
    let e = Anonymisierer().anonymisieren(text)
    for g in ["Zoran", "Marco", "Rossi"] { pruefe(!e.text.contains(g), "«\(g)»: \(e.text)") }
    pruefe(e.text.contains("Danke für die Offerte.\r\n"), e.text)
}

print(fehlerGesamt == 0 ? "\nAlle Tests bestanden." : "\n\(fehlerGesamt) Fehler.")
exit(fehlerGesamt == 0 ? 0 : 1)

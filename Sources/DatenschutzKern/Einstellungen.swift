// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Urs Stirnemann – siehe LICENSE und NOTICE

// DSGVO Datenschutz Wächter – Einstellungen (einstellungen.json)

import Foundation

public struct Einstellungen {
    public static let standardKategorien: [String: Bool] = [
        "NAME": true, "EMAIL": true, "TELEFON": true, "IBAN": true, "AHV": true,
        "KREDITKARTE": true, "ADRESSE": true, "PLZ_ORT": true, "GEBURTSDATUM": true,
        "IP": true, "PROFIL_URL": true, "KENNZEICHEN": true,
        "ORGANISATION": false, "ORT": false, "DATUM": false,
    ]

    public var kategorien: [String: Bool] = Einstellungen.standardKategorien
    /// Einzelne Vornamen aus der eingebauten Liste (z.B. "Hallo Anna") ersetzen
    public var vornamenEinzelnErsetzen = true
    /// Begriffe, die immer ersetzt werden: ["KUNDE": ["Muster AG"]]
    public var immerErsetzen: [String: [String]] = ["KUNDE": [], "NAME": []]
    /// Begriffe, die nie ersetzt werden (Fehlalarme)
    public var nieErsetzen: [String] = []
    /// Bundle-IDs von Apps, deren Kopien nicht verändert werden
    public var ausgenommeneApps: [String] = []
    public var benachrichtigungen = true
    public var warnungBesondersSchuetzenswert = true
    public var namenserkennungApple = true
    /// Kopierten Text mit Platzhaltern mit den Originalen einfügen ("" = aus)
    public var tastenkuerzel = "ctrl+alt+v"
    /// Nach dem Einfügen wieder die Platzhalter-Version in die Zwischenablage legen
    public var nachEinfuegenWiederherstellen = true
    public var maxTextlaenge = 200_000

    public init() {}

    public init(json: [String: Any]) {
        self.init()
        if let k = json["kategorien"] as? [String: Any] {
            for (name, wert) in k where !name.hasPrefix("_") {
                if let b = wert as? Bool { kategorien[name] = b }
            }
        }
        if let d = json["immer_ersetzen"] as? [String: Any] {
            var neu: [String: [String]] = [:]
            for (kategorie, liste) in d where !kategorie.hasPrefix("_") {
                neu[kategorie] = (liste as? [Any])?.compactMap { $0 as? String } ?? []
            }
            immerErsetzen = neu
        }
        if let l = json["nie_ersetzen"] as? [Any] { nieErsetzen = l.compactMap { $0 as? String } }
        if let l = json["ausgenommene_apps"] as? [Any] { ausgenommeneApps = l.compactMap { $0 as? String } }
        if let b = json["vornamen_einzeln_ersetzen"] as? Bool { vornamenEinzelnErsetzen = b }
        if let b = json["benachrichtigungen"] as? Bool { benachrichtigungen = b }
        if let b = json["warnung_besonders_schuetzenswert"] as? Bool { warnungBesondersSchuetzenswert = b }
        if let b = json["namenserkennung_apple"] as? Bool { namenserkennungApple = b }
        if let s = json["tastenkuerzel_mit_originalen_einfuegen"] as? String { tastenkuerzel = s }
        if let b = json["nach_einfuegen_platzhalter_wiederherstellen"] as? Bool { nachEinfuegenWiederherstellen = b }
        if let n = json["max_textlaenge"] as? Int { maxTextlaenge = n }
    }

    public static func laden(von url: URL) throws -> Einstellungen {
        let daten = try Data(contentsOf: url)
        guard let json = try JSONSerialization.jsonObject(with: daten) as? [String: Any] else {
            throw NSError(domain: "Einstellungen", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "einstellungen.json enthält kein JSON-Objekt",
            ])
        }
        return Einstellungen(json: json)
    }

    /// Ändert einen Ja/Nein-Wert direkt im Text der Datei, damit Kommentare
    /// und Reihenfolge erhalten bleiben.
    public static func speichere(_ wert: Bool, schluessel: String, in url: URL) throws {
        var text = try String(contentsOf: url, encoding: .utf8)
        let muster = RE("(\"" + NSRegularExpression.escapedPattern(for: schluessel) + "\"\\s*:\\s*)(true|false)")
        if muster.passt(text) {
            text = muster.ersetzen(text, mit: "$1" + (wert ? "true" : "false"))
            try text.write(to: url, atomically: true, encoding: .utf8)
        } else {
            let daten = try Data(contentsOf: url)
            var json = (try JSONSerialization.jsonObject(with: daten) as? [String: Any]) ?? [:]
            json[schluessel] = wert
            let neu = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
            try neu.write(to: url, options: .atomic)
        }
    }
}

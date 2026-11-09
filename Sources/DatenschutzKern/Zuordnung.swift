// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Urs Stirnemann – siehe LICENSE und NOTICE

// DSGVO Datenschutz Wächter – Zuordnung Platzhalter <-> Original
//
// Liegt nur im Arbeitsspeicher und verschwindet beim Beenden der App.

import Foundation

public final class Zuordnung {
    private var nachWert: [String: String] = [:]
    private var originale: [String: String] = [:]
    private var zaehler: [String: Int] = [:]
    /// Bekannte Schreibweisen (Namen, Namensteile, eigene Begriffe) -> Platzhalter
    public private(set) var begriffe: [String: String] = [:]
    public private(set) var begriffReihenfolge: [String] = []
    private var musterCache: [String: RE] = [:]
    private var ohneGrossKlein: Set<String> = []

    public init() {}

    public var anzahl: Int { originale.count }

    public func leeren() {
        nachWert = [:]
        originale = [:]
        zaehler = [:]
        begriffe = [:]
        begriffReihenfolge = []
        musterCache = [:]
        ohneGrossKlein = []
    }

    static func normalisiere(_ kategorie: String, _ wert: String) -> String {
        switch kategorie {
        case "EMAIL":
            return wert.lowercased()
        case "TELEFON":
            let ziffern = wert.filter { $0.isASCII && $0.isNumber }
            if wert.getrimmt.hasPrefix("+") { return "+" + ziffern }
            if ziffern.hasPrefix("00") { return "+" + String(ziffern.dropFirst(2)) }
            if ziffern.hasPrefix("0") { return "+41" + String(ziffern.dropFirst()) }
            return ziffern
        case "IBAN", "AHV", "KREDITKARTE":
            return wert.filter { !($0.isWhitespace || $0 == "." || $0 == "-") }.uppercased()
        default:
            return wert.woerter.joined(separator: " ").lowercased()
        }
    }

    public func platzhalter(_ kategorie: String, _ wert: String) -> String {
        let schluessel = kategorie + "\u{1F}" + Zuordnung.normalisiere(kategorie, wert)
        if let p = nachWert[schluessel] { return p }
        let n = (zaehler[kategorie] ?? 0) + 1
        zaehler[kategorie] = n
        let p = "[\(kategorie)_\(n)]"
        nachWert[schluessel] = p
        originale[p] = kategorie == "ADRESSE" ? wert : wert.woerter.joined(separator: " ")
        return p
    }

    public func merkeBegriff(_ schreibweise: String, _ platzhalter: String, grossKleinEgal: Bool = false) {
        guard begriffe[schreibweise] == nil else { return }
        begriffe[schreibweise] = platzhalter
        begriffReihenfolge.append(schreibweise)
        if grossKleinEgal { ohneGrossKlein.insert(schreibweise) }
    }

    @discardableResult
    public func registriereName(_ name: String, kategorie: String = "NAME") -> String {
        if let bekannt = begriffe[name] { return bekannt }
        let p = platzhalter(kategorie, name)
        merkeBegriff(name, p)
        if kategorie == "NAME" {
            for teil in name.woerter
            where teil.count >= 3 && !Listen.namenspartikel.contains(teil.lowercased()) && !Listen.istStopwort(teil) {
                merkeBegriff(teil, p)
            }
        }
        return p
    }

    func muster(fuer begriff: String) -> RE {
        if let m = musterCache[begriff] { return m }
        let koerper = begriff.woerter
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: #"\s+"#)
        let m = RE(#"(?<!\w)"# + koerper + #"(?=(?:s|'s|’s)?(?!\w))"#, [.caseInsensitive])
        musterCache[begriff] = m
        return m
    }

    func passt(_ begriff: String, _ gefunden: String) -> Bool {
        if ohneGrossKlein.contains(begriff) { return true }
        return gefunden.woerter.joined(separator: " ") == begriff || gefunden.istGrossgeschrieben
    }

    public func original(_ platzhalter: String) -> String? {
        originale[platzhalter]
    }

    /// "[NAME_12]" -> ("NAME", 12)
    public static func zerlege(_ platzhalter: String) -> (kategorie: String, nummer: Int)? {
        guard let m = M.platzhalterGanz.erstes(platzhalter),
              let k = m.text(1, in: platzhalter),
              let n = m.text(2, in: platzhalter) else { return nil }
        return (k, Int(n) ?? 0)
    }

    public func tabelle() -> [(platzhalter: String, original: String)] {
        let sortiert = originale.keys.sorted { a, b in
            let ka = Zuordnung.zerlege(a) ?? (kategorie: a, nummer: 0)
            let kb = Zuordnung.zerlege(b) ?? (kategorie: b, nummer: 0)
            return (ka.kategorie, ka.nummer) < (kb.kategorie, kb.nummer)
        }
        return sortiert.map { (platzhalter: $0, original: originale[$0] ?? "") }
    }
}

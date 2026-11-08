// DSGVO Datenschutz Wächter – Kernlogik
//
// Erkennt Personendaten in einem Text und ersetzt sie durch nummerierte
// Platzhalter wie [NAME_1], [EMAIL_1], [TELEFON_2]. Läuft komplett lokal.

import Foundation

/// Zusätzlicher Namenserkenner (z.B. Apples NaturalLanguage): Text -> [(Kategorie, Wert)]
public typealias Namenserkenner = (String) -> [(kategorie: String, wert: String)]

struct Treffer {
    var start: Int
    var ende: Int
    var kategorie: String
    var wert: String
    var platzhalter: String = ""
}

public struct Ergebnis {
    public let text: String
    public let geaendert: Bool
    /// Anzahl ersetzter Stellen je Kategorie, häufigste zuerst
    public let anzahl: [(kategorie: String, anzahl: Int)]
    public let warnungen: [String]

    public var gesamt: Int { anzahl.reduce(0) { $0 + $1.anzahl } }

    public var zusammenfassung: String {
        if anzahl.isEmpty { return "keine Personendaten gefunden" }
        return anzahl.map { "\($0.anzahl)× \($0.kategorie)" }.joined(separator: ", ")
    }

    public func anzahlFuer(_ kategorie: String) -> Int {
        anzahl.first { $0.kategorie == kategorie }?.anzahl ?? 0
    }
}

public final class Anonymisierer {
    public private(set) var einstellungen: Einstellungen
    public var namenserkenner: [Namenserkenner]
    public let zuordnung = Zuordnung()
    private var nie: Set<String> = []

    public init(einstellungen: Einstellungen = Einstellungen(), namenserkenner: [Namenserkenner] = []) {
        self.einstellungen = einstellungen
        self.namenserkenner = namenserkenner
        setzeEinstellungen(einstellungen)
    }

    // MARK: Setup

    public func setzeEinstellungen(_ neu: Einstellungen) {
        einstellungen = neu
        nie = Set(neu.nieErsetzen)
        registriereEigeneBegriffe()
    }

    private func registriereEigeneBegriffe() {
        for kategorie in einstellungen.immerErsetzen.keys.sorted() {
            var kat = M.keinKategorieZeichen.ersetzen(kategorie.uppercased(), mit: "_")
            if kat.isEmpty { kat = "BEGRIFF" }
            for begriff in einstellungen.immerErsetzen[kategorie] ?? [] {
                let b = begriff.woerter.joined(separator: " ")
                guard !b.isEmpty else { continue }
                if kat == "NAME" {
                    zuordnung.registriereName(b)
                } else {
                    let p = zuordnung.platzhalter(kat, b)
                    zuordnung.merkeBegriff(b, p, grossKleinEgal: true)
                }
            }
        }
    }

    public func zuordnungLeeren() {
        zuordnung.leeren()
        registriereEigeneBegriffe()
    }

    private func an(_ kategorie: String) -> Bool {
        einstellungen.kategorien[kategorie] ?? false
    }

    // MARK: Strukturierte Daten

    private func strukturierteTreffer(_ text: String) -> [Treffer] {
        var t: [Treffer] = []

        func alle(_ re: RE, _ kat: String, gruppe: Int = 0, pruefe: ((String, NSTextCheckingResult) -> Bool)? = nil) {
            guard an(kat) else { return }
            for m in re.alle(text) {
                let r = m.range(at: gruppe)
                guard r.location != NSNotFound, r.length > 0 else { continue }
                let wert = text.teil(r)
                if let pruefe = pruefe, !pruefe(wert, m) { continue }
                t.append(Treffer(start: r.location, ende: r.location + r.length, kategorie: kat, wert: wert))
            }
        }

        func ziffern(_ s: String) -> String { s.filter { $0.isASCII && $0.isNumber } }

        alle(M.email, "EMAIL")
        alle(M.profilURL, "PROFIL_URL")
        alle(M.iban, "IBAN") { w, _ in
            Anonymisierer.ibanOK(w)
                || ((w.hasPrefix("CH") || w.hasPrefix("LI")) && w.replacingOccurrences(of: " ", with: "").count == 21)
        }
        alle(M.ahv, "AHV")
        alle(M.kreditkarte, "KREDITKARTE") { w, _ in
            let z = ziffern(w)
            guard (13...19).contains(z.count), let erste = z.first else { return false }
            return "23456".contains(erste) && Anonymisierer.luhnOK(z)
        }
        alle(M.ip, "IP") { w, _ in w != "0.0.0.0" && w != "127.0.0.1" }
        alle(M.telefon, "TELEFON") { w, m in
            let z = ziffern(w)
            guard (9...15).contains(z.count) else { return false }
            if M.datumsformGanz.passt(w.getrimmt) { return false }
            let s = m.range.location
            let davor = text.teil(von: s - 25, bis: s).lowercased()
            if M.telKontextNummer.passt(davor) && !M.telKontextTelefon.passt(davor) { return false }
            return true
        }
        alle(M.geburtsdatum, "GEBURTSDATUM", gruppe: 1)
        alle(M.strasse, "ADRESSE")
        if an("PLZ_ORT") { t += plzOrt(text) }
        alle(M.kennzeichen, "KENNZEICHEN") { w, m in
            let z = ziffern(w)
            if z.count == 4 && (z.hasPrefix("19") || z.hasPrefix("20")) { return false }
            if w.hasPrefix("AG") {
                let s = m.range.location
                if M.firmaDavor.passt(text.teil(von: s - 30, bis: s)) { return false } // "Muster AG 150"
            }
            return true
        }
        alle(M.datum, "DATUM")
        if an("ORGANISATION") { alle(M.firma, "ORGANISATION") }
        return t
    }

    /// PLZ + Ort nur im Adresskontext (vermeidet "2024 Rückblick").
    private func plzOrt(_ text: String) -> [Treffer] {
        var treffer: [Treffer] = []
        let laenge = text.utf16.count
        var zeilenStarts = [0]
        for (i, c) in text.utf16.enumerated() where c == 10 { zeilenStarts.append(i + 1) }

        for m in M.plzOrt.alle(text) {
            let s = m.range.location
            let e = m.range.location + m.range.length
            let wert = text.teil(m.range)

            var lo = 0
            var hi = zeilenStarts.count
            while lo < hi {
                let mitte = (lo + hi) / 2
                if zeilenStarts[mitte] <= s { lo = mitte + 1 } else { hi = mitte }
            }
            let zeilenNr = lo - 1
            let davor = text.teil(von: zeilenStarts[zeilenNr], bis: s)
            let zeilenEnde = text.stelle(von: "\n", ab: e) ?? laenge
            let danach = text.teil(von: e, bis: zeilenEnde)
            let zahl = M.vierZiffern.erstes(wert).flatMap { Int(wert.teil($0.range)) } ?? 0

            var vorige = ""
            var i = zeilenNr - 1
            while i >= 0 {
                let z = text.teil(von: zeilenStarts[i], bis: zeilenStarts[i + 1]).getrimmt
                if !z.isEmpty { vorige = z; break }
                i -= 1
            }

            var ok = false
            if ["CH", "D-", "A-", "FL-"].contains(where: { wert.hasPrefix($0) }) {
                ok = true
            } else if M.kommaAmEnde.passt(davor) || M.hausnummerAmEnde.passt(davor) {
                ok = true // "Bahnhofstrasse 12, 8001 Zürich"
            } else if davor.getrimmt.isEmpty {
                let allein = M.alleinInZeile.passt(danach)
                let adresseDavor = M.strasse.passt(vorige)
                if adresseDavor || (allein && !(1900...2099).contains(zahl)) { ok = true }
            }
            if ok { treffer.append(Treffer(start: s, ende: e, kategorie: "PLZ_ORT", wert: wert)) }
        }
        return treffer
    }

    // MARK: Namen

    /// Liefert (Kategorie, Wert, Quelle). Schwache Quellen werden strenger geprüft.
    private func namenskandidaten(_ text: String) -> [(String, String, String)] {
        var k: [(String, String, String)] = []
        if an("NAME") {
            for m in M.titelName.alle(text) {
                guard var name = m.text(1, in: text) else { continue }
                let teile = name.woerter
                // Zweites Wort nur behalten, wenn das erste ein bekannter Vorname ist
                if teile.count > 1 && !Listen.vornamen.contains(teile[0]) { name = teile[0] }
                k.append(("NAME", name, "titel"))
            }
            for m in M.vornameNachname.alle(text) {
                guard let v = m.text(1, in: text), let z = m.text(2, in: text) else { continue }
                if Listen.vornamen.contains(v), let letztes = z.woerter.last, !Listen.istNomen(letztes) {
                    k.append(("NAME", text.teil(m.range), "vorname_nachname"))
                }
            }
            for m in M.anrede.alle(text) {
                guard var name = m.text(1, in: text) else { continue }
                let teile = name.woerter
                if teile.count > 1 && !Listen.vornamen.contains(teile[0]) { name = teile[0] }
                if let erstes = name.woerter.first, !Listen.istStopwort(erstes) { k.append(("NAME", name, "anrede")) }
            }
            k += signaturen(text).map { ($0.0, $0.1, "signatur") }
            k += namenAusEmails(text).map { ($0.0, $0.1, "email") }
            if einstellungen.vornamenEinzelnErsetzen {
                var gesehen = Set<String>()
                for m in M.einzelnesWort.alle(text) {
                    let wort = text.teil(m.range)
                    if Listen.vornamen.contains(wort) && gesehen.insert(wort).inserted {
                        k.append(("NAME", wort, "vorname"))
                    }
                }
            }
        }
        for erkenner in namenserkenner {
            for fund in erkenner(text) where an(fund.kategorie) {
                k.append((fund.kategorie, fund.wert, "erkenner"))
            }
        }
        return k
    }

    /// Zusatzprüfung für Kandidaten aus Signatur, Anrede und Apple-Erkennung.
    static func plausibel(_ name: String, quelle: String, textOhneAdressen: String, text: String) -> Bool {
        guard ["anrede", "signatur", "erkenner"].contains(quelle) else { return true }
        let woerter = name.woerter
        guard woerter.count == 1, let wort = woerter.first else { return true }
        // Kommt das Wort auch klein geschrieben vor, ist es ein gewöhnliches Wort ("Mein" / "mein")
        let klein = wort.lowercased()
        if klein != wort {
            let muster = RE(#"(?<!\w)"# + NSRegularExpression.escapedPattern(for: klein) + #"(?!\w)"#)
            if muster.passt(textOhneAdressen) { return false }
        }
        // Apple-Erkennung: unbekanntes Einzelwort nur am Satzanfang -> eher kein Name
        if quelle == "erkenner" && !Listen.vornamen.contains(wort) {
            let muster = RE(#"(?<!\w)"# + NSRegularExpression.escapedPattern(for: wort) + #"(?!\w)"#)
            let weg = CharacterSet(charactersIn: " \t\"'«»“„(-–•*")
            for m in muster.alle(text) {
                let davor = text.teil(von: 0, bis: m.range.location).trimmingCharacters(in: weg)
                if let letztes = davor.last, !letztes.isNewline, !".!?:".contains(letztes) {
                    return true // auch mitten im Satz -> plausibel
                }
            }
            return false
        }
        return true
    }

    private func signaturen(_ text: String) -> [(String, String)] {
        var k: [(String, String)] = []
        let laenge = text.utf16.count
        let trimmen = CharacterSet(charactersIn: " ,.!\t")
        for m in M.gruss.alle(text) {
            let ende = m.range.location + m.range.length
            let zeilenende = text.stelle(von: "\n", ab: ende)
            let restZeile = text.teil(von: ende, bis: zeilenende ?? laenge).trimmingCharacters(in: trimmen)
            if !restZeile.isEmpty, let sm = M.signaturZeile.erstes(restZeile), let n = sm.text(1, in: restZeile) {
                k.append(("NAME", n))
                continue
            }
            guard let ze = zeilenende else { continue }
            let folgende = text.teil(von: ze + 1, bis: laenge).components(separatedBy: "\n").prefix(3)
            for zeile in folgende where !zeile.getrimmt.isEmpty {
                if let sm = M.signaturZeile.erstes(zeile), let n = sm.text(1, in: zeile) {
                    k.append(("NAME", n))
                }
                break
            }
        }
        return k
    }

    private func namenAusEmails(_ text: String) -> [(String, String)] {
        var k: [(String, String)] = []
        for m in M.email.alle(text) {
            let adresse = text.teil(m.range)
            let lokal = (adresse.components(separatedBy: "@").first ?? "").lowercased()
            let teile = lokal.components(separatedBy: CharacterSet(charactersIn: "._-"))
                .filter { $0.count >= 2 && $0.allSatisfy { $0.isLetter } }
            if teile.isEmpty || teile.contains(where: { Listen.generischePostfaecher.contains($0) }) { continue }

            let varianten: [[String]] = teile.map { t in
                let a = t.grossAnfang
                let b = t.replacingOccurrences(of: "ae", with: "ä")
                    .replacingOccurrences(of: "oe", with: "ö")
                    .replacingOccurrences(of: "ue", with: "ü")
                    .grossAnfang
                return a == b ? [a] : [a, b]
            }
            if varianten.count >= 2, let ersteVarianten = varianten.first, let letzteVarianten = varianten.last {
                for vn in ersteVarianten {
                    for nn in letzteVarianten {
                        let muster = RE(#"(?<!\w)"# + NSRegularExpression.escapedPattern(for: vn) + #"\s+"#
                            + NSRegularExpression.escapedPattern(for: nn) + #"(?!\w)"#)
                        if muster.passt(text) { k.append(("NAME", "\(vn) \(nn)")) }
                    }
                }
            }
            for v in varianten {
                for form in v where Listen.vornamen.contains(form) {
                    let muster = RE(#"(?<!\w)"# + NSRegularExpression.escapedPattern(for: form) + #"(?!\w)"#)
                    if muster.passt(text) { k.append(("NAME", form)) }
                }
            }
        }
        return k
    }

    /// Säubert einen Namenskandidaten; nil, wenn er kein plausibler Name ist.
    static func bereinigeNamen(_ kandidat: String, nie: Set<String>) -> String? {
        var s = kandidat.replacingOccurrences(of: "\n", with: " ").woerter.joined(separator: " ")
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:!?()[]\"'«»“”"))
        s = M.titelAmAnfang.ersetzen(s)
        s = M.akadTitelAmAnfang.ersetzen(s)
        if s.isEmpty || s.count < 2 || s.count > 60 { return nil }
        if M.unerlaubteZeichen.passt(s) { return nil }
        guard let erstes = s.first, erstes.isUppercase else { return nil }

        // Nomen/Stoppwörter am Ende abschneiden: "Thomas Projektleiter" -> "Thomas"
        var roh = s.woerter
        while roh.count > 1, let letztes = roh.last, Listen.istNomen(letztes) { roh.removeLast() }
        s = roh.joined(separator: " ")

        let woerter = s.woerter.filter { !Listen.namenspartikel.contains($0.lowercased()) }
        if woerter.isEmpty || woerter.count > 5 { return nil }
        if woerter.allSatisfy({ Listen.istStopwort($0) }) { return nil }
        if Listen.istStopwort(woerter[0]) {
            // "Grüsse Peter" -> "Peter"
            let alle = s.woerter
            return alle.count > 1 ? bereinigeNamen(alle.dropFirst().joined(separator: " "), nie: nie) : nil
        }
        if woerter.count == 1 && Listen.istNomen(woerter[0]) { return nil } // "Kundendienst"
        if nie.contains(s) || nie.contains(where: { $0.lowercased() == s.lowercased() }) { return nil }
        if s.istGrossgeschrieben && s.count <= 4 { return nil } // Abkürzungen wie "SBB", "UBS"
        return s
    }

    // MARK: Hauptfunktion

    public func anonymisieren(_ text: String) -> Ergebnis {
        if text.getrimmt.isEmpty {
            return Ergebnis(text: text, geaendert: false, anzahl: [], warnungen: [])
        }
        let laenge = text.utf16.count
        if einstellungen.maxTextlaenge > 0 && laenge > einstellungen.maxTextlaenge {
            return Ergebnis(text: text, geaendert: false, anzahl: [], warnungen: [
                "Text zu lang (> \(einstellungen.maxTextlaenge) Zeichen) – nicht geprüft",
            ])
        }

        var treffer: [Treffer] = []
        // Bereits vorhandene Platzhalter schützen
        for m in M.platzhalter.alle(text) {
            treffer.append(Treffer(
                start: m.range.location, ende: m.range.location + m.range.length,
                kategorie: "_GESCHUETZT", wert: text.teil(m.range)
            ))
        }
        treffer += strukturierteTreffer(text)

        // Namen sammeln
        var namen: [(String, String)] = []
        let textOhneAdressen = M.profilURL.ersetzen(M.email.ersetzen(text, mit: " "), mit: " ")
        for (kat, kandidat, quelle) in namenskandidaten(text) {
            guard let name = Anonymisierer.bereinigeNamen(kandidat, nie: nie),
                  Anonymisierer.plausibel(name, quelle: quelle, textOhneAdressen: textOhneAdressen, text: text)
            else { continue }
            if !namen.contains(where: { $0.0 == kat && $0.1 == name }) { namen.append((kat, name)) }
        }
        // Einzelwörter, die Teil eines vollen Namens sind, werden zu dessen Alias
        var teile = Set<String>()
        for (kat, n) in namen where kat == "NAME" {
            let w = n.woerter
            if w.count > 1 { teile.formUnion(w) }
        }
        namen = namen.filter { !($0.1.woerter.count == 1 && teile.contains($0.1)) }

        // Nummern in Lesereihenfolge vergeben
        func ersteStelle(_ name: String) -> Int {
            let stellen = ([name] + name.woerter).compactMap { text.range(of: $0)?.lowerBound.utf16Offset(in: text) }
            return stellen.min() ?? laenge
        }
        let reihenfolge = namen.enumerated().map { eintrag in
            (index: eintrag.offset, kat: eintrag.element.0, name: eintrag.element.1,
             stelle: ersteStelle(eintrag.element.1), woerter: eintrag.element.1.woerter.count)
        }.sorted { a, b in
            (a.stelle, -a.woerter, a.index) < (b.stelle, -b.woerter, b.index)
        }
        for eintrag in reihenfolge {
            zuordnung.registriereName(eintrag.name, kategorie: eintrag.kat)
        }

        // Alle bekannten Namen/Begriffe im Text suchen (auch aus früheren Kopien)
        for begriff in zuordnung.begriffReihenfolge {
            guard let p = zuordnung.begriffe[begriff], let kat = Zuordnung.zerlege(p)?.kategorie else { continue }
            if ["NAME", "ORGANISATION", "ORT"].contains(kat) && !an(kat) { continue }
            let vorrangKat = M.vorrang[kat] != nil ? kat : "_EIGEN"
            for m in zuordnung.muster(fuer: begriff).alle(text) {
                let gefunden = text.teil(m.range)
                if zuordnung.passt(begriff, gefunden) {
                    treffer.append(Treffer(
                        start: m.range.location, ende: m.range.location + m.range.length,
                        kategorie: vorrangKat, wert: gefunden, platzhalter: p
                    ))
                }
            }
        }

        // Ersetzen
        let gewaehlt = Anonymisierer.ueberschneidungenAufloesen(treffer)
        var ersetzungen: [(NSRange, String)] = []
        var zaehlung: [String: Int] = [:]
        var katReihenfolge: [String] = []
        for var t in gewaehlt where t.kategorie != "_GESCHUETZT" {
            if t.platzhalter.isEmpty { t.platzhalter = zuordnung.platzhalter(t.kategorie, t.wert) }
            ersetzungen.append((NSRange(location: t.start, length: t.ende - t.start), t.platzhalter))
            let k = Zuordnung.zerlege(t.platzhalter)?.kategorie ?? t.kategorie
            if zaehlung[k] == nil { katReihenfolge.append(k) }
            zaehlung[k, default: 0] += 1
        }
        let neuerText = text.ersetzt(ersetzungen)

        let anzahl = katReihenfolge.enumerated()
            .map { (index: $0.offset, kategorie: $0.element, anzahl: zaehlung[$0.element] ?? 0) }
            .sorted { ($1.anzahl, $0.index) < ($0.anzahl, $1.index) }
            .map { (kategorie: $0.kategorie, anzahl: $0.anzahl) }

        var warnungen: [String] = []
        if einstellungen.warnungBesondersSchuetzenswert {
            warnungen = M.besondersSchuetzenswert.filter { $0.1.passt(text) }.map { $0.0 }
        }
        return Ergebnis(text: neuerText, geaendert: neuerText != text, anzahl: anzahl, warnungen: warnungen)
    }

    static func ueberschneidungenAufloesen(_ treffer: [Treffer]) -> [Treffer] {
        let sortiert = treffer.enumerated().sorted { a, b in
            let va = M.vorrang[a.element.kategorie] ?? 12
            let vb = M.vorrang[b.element.kategorie] ?? 12
            let la = a.element.ende - a.element.start
            let lb = b.element.ende - b.element.start
            return (va, -la, a.element.start, a.offset) < (vb, -lb, b.element.start, b.offset)
        }.map { $0.element }
        var gewaehlt: [Treffer] = []
        for t in sortiert where t.ende > t.start {
            if gewaehlt.allSatisfy({ t.ende <= $0.start || t.start >= $0.ende }) {
                gewaehlt.append(t)
            }
        }
        return gewaehlt.sorted { $0.start < $1.start }
    }

    /// Ersetzt bekannte Platzhalter wieder durch die Originale.
    public func zurueckuebersetzen(_ text: String) -> (text: String, anzahl: Int) {
        var ersetzungen: [(NSRange, String)] = []
        for m in M.platzhalter.alle(text) {
            if let original = zuordnung.original(text.teil(m.range)) {
                ersetzungen.append((m.range, original))
            }
        }
        return (text.ersetzt(ersetzungen), ersetzungen.count)
    }

    // MARK: Prüfziffern

    static func luhnOK(_ ziffern: String) -> Bool {
        var summe = 0
        for (i, c) in ziffern.reversed().enumerated() {
            guard var n = c.wholeNumberValue else { return false }
            if i % 2 == 1 {
                n *= 2
                if n > 9 { n -= 9 }
            }
            summe += n
        }
        return summe % 10 == 0
    }

    static func ibanOK(_ iban: String) -> Bool {
        let s = iban.replacingOccurrences(of: " ", with: "").uppercased()
        guard (15...34).contains(s.count) else { return false }
        let umgestellt = String(s.dropFirst(4)) + String(s.prefix(4))
        var rest = 0
        for c in umgestellt {
            guard c.isASCII, let ascii = c.asciiValue else { return false }
            let wert: Int
            if let z = c.wholeNumberValue {
                wert = z
            } else if c.isLetter {
                wert = Int(ascii) - 55 // A = 10 … Z = 35
            } else {
                return false
            }
            for ziffer in String(wert) {
                rest = (rest * 10 + (ziffer.wholeNumberValue ?? 0)) % 97
            }
        }
        return rest == 1
    }
}

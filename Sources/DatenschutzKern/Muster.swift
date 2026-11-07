// DSGVO Datenschutz Wächter – Wortlisten und Suchmuster
//
// Alle Positionen werden in UTF-16-Einheiten (NSString/NSRange) gerechnet,
// damit NSRegularExpression und Apples Namenserkennung zusammenpassen.

import Foundation

// MARK: - Regex-Hilfe

public final class RE {
    public let regex: NSRegularExpression

    public init(_ muster: String, _ optionen: NSRegularExpression.Options = []) {
        do {
            regex = try NSRegularExpression(pattern: muster, options: optionen)
        } catch {
            fatalError("Ungültiges Suchmuster: \(muster) – \(error)")
        }
    }

    public func alle(_ text: String) -> [NSTextCheckingResult] {
        regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
    }

    public func erstes(_ text: String) -> NSTextCheckingResult? {
        regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
    }

    public func passt(_ text: String) -> Bool {
        erstes(text) != nil
    }

    public func ersetzen(_ text: String, mit vorlage: String = "") -> String {
        regex.stringByReplacingMatches(
            in: text, options: [], range: NSRange(location: 0, length: text.utf16.count), withTemplate: vorlage
        )
    }
}

// MARK: - Text-Hilfen

extension String {
    /// Teilstück nach UTF-16-Bereich
    func teil(_ bereich: NSRange) -> String {
        guard bereich.location != NSNotFound else { return "" }
        return (self as NSString).substring(with: bereich)
    }

    /// Teilstück von/bis (UTF-16)
    func teil(von: Int, bis: Int) -> String {
        let n = utf16.count
        let a = max(0, min(von, n))
        let b = max(a, min(bis, n))
        return (self as NSString).substring(with: NSRange(location: a, length: b - a))
    }

    /// Wie Python str.split(): an Leerraum trennen, leere Teile weglassen
    var woerter: [String] {
        components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
    }

    var getrimmt: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Erste Fundstelle (UTF-16) oder nil
    func stelle(von suche: String, ab: Int = 0) -> Int? {
        let ns = self as NSString
        guard ab <= ns.length else { return nil }
        let r = ns.range(of: suche, options: [], range: NSRange(location: ab, length: ns.length - ab))
        return r.location == NSNotFound ? nil : r.location
    }

    /// Wie Python str.isupper()
    var istGrossgeschrieben: Bool {
        self == uppercased() && self != lowercased()
    }

    /// Wie Python str.capitalize()
    var grossAnfang: String {
        guard let erstes = first else { return self }
        return String(erstes).uppercased() + dropFirst().lowercased()
    }
}

extension NSTextCheckingResult {
    func text(_ gruppe: Int, in quelle: String) -> String? {
        let r = range(at: gruppe)
        return r.location == NSNotFound ? nil : quelle.teil(r)
    }
}

// MARK: - Wortlisten

enum Listen {
    /// Häufige Vornamen in der Schweiz (de/fr/it). Mehrdeutige Wörter wie
    /// "Ernst", "Max", "Frank", "Rosa", "Jean" sind bewusst nicht enthalten.
    static let vornamen: Set<String> = Set("""
    Aaron Adrian Ahmed Alain Albert Alessandro Alessia Alessio Alexander Alexandra
    Alfred Ali Alice Alina Aline Ana Andrea Andreas Angela Anja Anna Anne Annette
    Antoine Antonio Arthur Barbara Beat Beatrice Benedikt Benjamin Bernhard Bettina
    Brigitte Bruno Carina Carla Carmen Catherine Céline Chantal Chiara Christa
    Christian Christina Christine Christoph Christophe Claudia Claudio Corinne
    Cornelia Cyrill Damian Daniel Daniela Dario David Debora Denise Didier Diego
    Dieter Dominik Dominique Doris Edith Elena Elias Elisa Elisabeth Ella Emil
    Emilia Emma Enea Erich Erika Esther Eva Fabian Fabienne Fabio Fatima Felix
    Finn Florian Francesca Francesco Franziska François Françoise Frédéric Fritz
    Gabriel Gabriela Gabriele Georg Gerhard Gian Giovanni Giulia Giuseppe Gregor
    Guido Hannah Hans Hanspeter Hansruedi Heidi Heinz Helen Helena Henri Hugo
    Ida Irene Isabelle Ivan Ivo Jacqueline Jacques Jan Jana Jasmin Jessica
    Johanna Jonas Jonathan Josef Judith Julia Julian Julien Jürg Jürgen Jörg
    Karin Karl Katharina Kathrin Katrin Kevin Klara Klaus Kurt Lara Laura Laurent
    Lea Leandro Lena Leon Leonie Levin Liam Lina Livia Louis Luca Luisa Lukas
    Manuel Manuela Marc Marcel Marco Margrit Maria Marianne Marie Mario Markus
    Martin Martina Mathias Mathieu Matthias Mattia Mehmet Melanie Michael Michel
    Michelle Mila Mohammed Monika Nadia Nadine Nadja Natalie Nathalie Nicolas
    Nicole Nico Nils Nina Noah Noemi Olivia Olivier Oliver Oskar Otto Paola
    Paolo Pascal Patricia Patrick Paul Peter Petra Philipp Philippe Pierre Priska
    Rahel Rainer Ralph Ralf Raphael Regula Remo René Reto Richard Rita Robert
    Robin Roger Roland Rolf Roman Rosmarie Rudolf Ruth Sabine Samuel Sandra Sandro
    Sara Sarah Sebastian Selina Severin Silvan Silvia Simon Simone Sofia Sonja
    Sophie Stefan Stefanie Stephan Susanne Sven Sylvie Tamara Tanja Theo Theresa
    Thomas Tim Tobias Ursula Urs Uwe Valentin Valentina Valérie Vanessa Verena
    Vincent Walter Werner Yannick Yvonne Zoe
    """.woerter)

    /// Wörter, die nie als Name gelten (Vergleich ohne Gross-/Kleinschreibung).
    /// Bewusst NICHT enthalten: Wörter, die auch häufige Nachnamen sind
    /// (z.B. Klein, Lang, Weiss, Kurz, Ganz, Schatz, Will, Per).
    static let stopwoerter: Set<String> = Set("""
    ich du er sie es wir ihr mich dich sich uns euch mir dir ihm ihnen ihn man jemand niemand
    mein meine meinen meinem meiner meines dein deine deinen deinem deiner deines
    sein seine seinen seinem seiner seines ihre ihren ihrem ihrer ihres
    unser unsere unseren unserem unserer unseres unsern euer eure euren eurem eurer eures
    jeder jede jedes jeden jedem alle alles allen aller dieser diese dieses diesen diesem
    jener jene jenes welcher welche welches wer was wem wen wessen
    der die das den dem des ein eine einen einem einer eines kein keine keinen keinem keiner keines
    an am auf aus bei beim bis durch für gegen hinter in im ins mit nach neben ohne seit über
    um unter von vom vor während wegen zu zum zur zwischen trotz laut gemäss gemäß ab pro
    und oder aber denn sondern doch dass ob weil wenn als wie falls obwohl damit sodass bzw
    beziehungsweise sowie also jedoch
    hier dort da heute morgen gestern jetzt nun bald schon noch immer nie oft gerne gern leider
    bitte danke ja nein nicht auch nur sehr etwa vielleicht natürlich genau wieder zusammen
    dann danach vorher zuerst bereits eben sofort anbei beiliegend hiermit ebenfalls übrigens
    eigentlich insbesondere zudem ausserdem außerdem wahrscheinlich hoffentlich trotzdem
    deshalb deswegen darum somit
    ist sind war waren bin bist sei seid habe hast hat haben hatte hatten wird werden wurde
    wurden kann kannst können konnte möchte möchten wollen soll sollen muss müssen darf dürfen
    gibt geht gehen komme kommt kommen sehe sieht lass lasst lassen freue freuen
    hallo hoi hi hey salü sali grüezi servus moin liebe lieber liebes sehr geehrte geehrter
    geehrtes guten tag abend gruss gruß grüsse grüße freundliche freundlichen beste besten
    herzliche herzlichen viele lg mfg vg herr herrn frau dr prof
    team kollegen kolleginnen kollege kollegin allerseits damen herren mitarbeitende mitarbeiter
    mitarbeiterinnen kunden kundinnen kunde kundin freunde eltern familie mitglieder leute leser
    leserinnen gemeinde klasse support kundendienst kundenservice service sekretariat empfang
    buchhaltung verwaltung geschäftsleitung leitung abteilung personalabteilung personal
    administration admin info büro praxis zentrale redaktion vorstand verwaltungsrat direktion
    mami papi mama papa mutter vater mutti vati oma opa grosi grossmami grosspapi grossmutter
    grossvater bruder schwester tochter onkel tante
    montag dienstag mittwoch donnerstag freitag samstag sonntag januar februar märz april mai
    juni juli august september oktober november dezember wochenende woche monat jahr
    betreff anhang anlage information kontakt telefon mobile mobil email e-mail mail adresse
    strasse datum zeit termin projekt firma offerte angebot rechnung vertrag auftrag bestellung
    lieferung frage fragen antwort feedback rückmeldung unterlagen dokument dokumente datei
    dateien bericht protokoll notiz hinweis achtung wichtig sitzung meeting agenda traktanden
    besprechung link name vorname nachname moment management
    zürich bern basel luzern schweiz
    i you he she it we they me him us them my your his its our their the a an and or but to of on
    at for with from by this that these those please hello dear thanks thank regards best kind
    cheers everyone all mr mrs ms sir madam
    je tu il elle nous vous ils elles mon mes ton tes notre nos votre vos leur leurs les un une
    et ou mais pour avec dans sur chez bonjour madame monsieur mesdames messieurs cher chère
    chers merci cordialement salutations salut
    io lui noi voi loro mio mia miei mie tuo tua suo sua nostro nostra vostro vostra il lo gli
    una ma per con buongiorno gentile signora signore cara caro grazie saluti cordiali ciao
    """.woerter)

    static let namenspartikel: Set<String> = [
        "von", "van", "de", "der", "den", "di", "da", "del", "della", "du", "la", "le", "zu", "dos", "das",
    ]

    static let generischePostfaecher: Set<String> = Set("""
    info kontakt contact office admin support service hello hallo mail team sales verkauf
    marketing buchhaltung empfang sekretariat personal hr jobs noreply no-reply news
    newsletter rechnung rechnungen billing post kundendienst kundenservice
    """.woerter)

    static let nomenEndungen: [String] = [
        "ung", "heit", "keit", "schaft", "tion", "ität", "ismus", "tum", "chen", "leiter",
        "leiterin", "gruppe", "team", "abteilung", "bericht", "projekt", "sitzung", "ordnung",
        "zentrum", "verwaltung", "konto", "nummer", "vertrag", "ergebnis", "zeugnis", "verständnis",
        "verhältnis", "ereignis", "kenntnis", "dienst", "service", "support", "zentrale", "stelle",
        "büro", "praxis", "leitung", "kommission", "amt", "gericht", "behörde", "schule", "verein",
        "kasse",
    ]

    static func istStopwort(_ wort: String) -> Bool {
        stopwoerter.contains(wort.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased())
    }

    static func istNomen(_ wort: String) -> Bool {
        let w = wort.lowercased()
        return istStopwort(wort) || (w.count > 5 && nomenEndungen.contains { w.hasSuffix($0) })
    }
}

// MARK: - Suchmuster

enum M {
    static let gross = "A-ZÄÖÜÉÈÀÂÎÔÛÇ"
    static let klein = "a-zäöüßéèàâêîôûçëïœ"
    static let namenswort = #"[\#(gross)][\#(klein)]+(?:-[\#(gross)][\#(klein)]+)*"#
    static let titel = #"(?:Herr|Herrn|Frau|Hr\.|Fr\.|Dr\.|Prof\.|lic\.|med\.|iur\.|phil\.|Dipl\.|Ing\.|Mme|Mlle|M\.|Mr\.?|Mrs\.?|Ms\.?|Sig\.(?:ra)?|Signora|Signor)"#
    static let monate = #"(?:jan|feb|mär|mar|apr|mai|may|jun|jul|aug|sep|okt|oct|nov|dez|dec|janv|févr|mars|avr|juin|juil|août|sept|déc|genn|febb|magg|giu|lug|ago|sett|ott|dic)[a-zäéû]*\.?"#

    // Strukturierte Daten
    static let email = RE(#"(?<![\w.+\-])[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}(?![\w\-])"#)
    static let profilURL = RE(#"(?i)\b(?:https?://)?(?:www\.)?(?:linkedin\.com/in/|xing\.com/profile/|facebook\.com/|instagram\.com/|twitter\.com/|x\.com/|tiktok\.com/@|github\.com/)[A-Za-z0-9_.%\-]+/?"#)
    static let iban = RE(#"\b[A-Z]{2}\d{2}[ ]?(?:[A-Z0-9]{4}[ ]?){2,7}[A-Z0-9]{1,4}\b"#)
    static let ahv = RE(#"(?<!\d)756[.\s]?\d{4}[.\s]?\d{4}[.\s]?\d{2}(?!\d)"#)
    static let kreditkarte = RE(#"(?<![\d\-])(?:\d[ \-]?){12,18}\d(?![\d\-])"#)
    static let ip = RE(#"(?<![\d.])(?:(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)\.){3}(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(?!\d|\.\d)"#)
    static let telefon = RE(#"(?<![\w+])(?:(?:\+|00)[1-9]\d{0,2}[\s./\-]?(?:\(0\)[\s./\-]?)?|\(?0)\d{1,3}\)?(?:[\s./\-]?\d{2,4}){2,4}(?!\w)"#)
    static let datumsformGanz = RE(#"^\d{1,2}[./]\d{1,2}[./]\d{2,4}$"#)
    static let telKontextNummer = RE(#"(?:nr|nummer|no|#|ref|id|ticket|order|bestell|rechnung|auftrag|artikel|kunden)\.?\s*:?\s*$"#)
    static let telKontextTelefon = RE(#"\b(?:tel|telefon|fax|mobil\w*|natel|handy|phone|fon|whatsapp)\b"#)
    /// Gruppe 1 = Datum
    static let geburtsdatum = RE(#"(?i)\b(?:geb\.|geboren(?:\s+am)?|geburtsdatum|geburtstag|jahrgang|jg\.|date de naissance|née?\s+le|nat[oa]\s+il|data di nascita|date of birth|dob|born(?:\s+on)?)\s*:?\s*(\d{1,2}\.\s?\d{1,2}\.\s?\d{2,4}|\d{1,2}\.?\s+\#(monate)\s+\d{4}|\d{4}-\d{2}-\d{2}|\d{1,2}/\d{1,2}/\d{2,4}|(?:19|20)\d{2})"#)
    static let datum = RE(#"(?i)\b(?:\d{1,2}\.\s?\d{1,2}\.\s?(?:19|20)?\d{2}|(?:19|20)\d{2}-\d{2}-\d{2}|\d{1,2}\.?\s+\#(monate)\s+(?:19|20)\d{2})\b"#)

    static let strSuffix = #"(?:strasse|straße|str\.|gasse|gässli|weg|platz|allee|rain|ring|halde|matte|acker|steig|stich|graben|quai|ufer|hof|berg|bühl|feld|park|pfad|stutz|höhe|weid|egg|hang)"#
    static let strAdj = #"(?:(?:Obere|Untere|Alte|Neue|Hintere|Vordere|Innere|Äussere|Grosse|Kleine|Lange|Kurze|[\#(gross)][\#(klein)]+er)\s)?"#
    static let strasse = RE(
        #"\b\#(strAdj)[\#(gross)][\w'.\-]*?\#(strSuffix)\s+\d{1,4}[a-zA-Z]?\b"#
            + #"|\b[\#(gross)][\#(klein)]+\s(?:Strasse|Straße|Gasse|Weg|Platz|Allee|Ring)\s+\d{1,4}[a-zA-Z]?\b"#
            + #"|\b(?:[Rr]ue|[Aa]venue|[Aa]v\.|[Cc]hemin|[Cc]h\.|[Rr]oute|[Rr]te|[Pp]lace|[Bb]oulevard|[Bb]d|[Ii]mpasse|[Qq]uai|[Ss]entier|Via|Viale|Piazza|Vicolo|Corso|Contrada)"#
            + #"\s+(?:(?:de|du|des|la|le|l'|d'|dei|della|del|di|San|Santa|Saint|Sainte)\s*)*[\#(gross)][\w'\-]+(?:\s[\#(gross)][\w'\-]+)?\s+\d{1,4}[a-zA-Z]?\b"#
            + #"|\b(?:Postfach|Case postale|Casella postale)\s*\d{1,6}\b"#
    )
    static let ort = #"(?:St\.\s?)?[\#(gross)][\#(klein)'\-]+(?:[ \t](?:am|an|bei|im|ob|b\.|a\.|sur|près|sous|de|di)[ \t](?:St\.\s?)?[\#(gross)][\#(klein)'\-]+)?"#
    static let plzOrt = RE(#"(?:CH-|CH\s|D-|A-|FL-)?\b[1-9]\d{3}[ \t]+\#(ort)"#)
    static let kommaAmEnde = RE(#",\s*$"#)
    static let hausnummerAmEnde = RE(#"\d{1,4}[a-zA-Z]?,?\s*$"#)
    static let alleinInZeile = RE(#"^\s*[,.;]?\s*$"#)
    static let vierZiffern = RE(#"\d{4}"#)
    static let kennzeichen = RE(#"\b(?:AG|AI|AR|BE|BL|BS|FR|GE|GL|GR|JU|LU|NE|NW|OW|SG|SH|SO|SZ|TG|TI|UR|VD|VS|ZG|ZH)[ ]?\d{1,6}\b"#)
    static let firmaDavor = RE(#"[\#(gross)][\w\&.\-]*\s$"#)
    static let firma = RE(#"\b(?:[\#(gross)][\w\&.'\-]*\s){1,3}(?:AG|GmbH|SA|Sàrl|SARL|KG|Ltd\.?|Inc\.?|LLC|Genossenschaft|Stiftung)\b"#)

    static let platzhalter = RE(#"\[([A-ZÄÖÜ][A-ZÄÖÜ_]*)_(\d+)\]"#)
    static let platzhalterGanz = RE(#"^\[([A-ZÄÖÜ][A-ZÄÖÜ_]*)_(\d+)\]$"#)

    // Namen (Heuristiken) – Gruppe 1 ist jeweils der Name
    static let titelName = RE(#"\b\#(titel)[ \t]+(?:(?:Dr|Prof|lic|med|iur|phil|Dipl|Ing)\.[ \t]*)*(\#(namenswort)(?:[ \t]+(?:(?:von|van|de|di|da|del|zu)[ \t]+)?\#(namenswort))?)"#)
    /// Gruppe 1 = Vorname, Gruppe 2 = Nachname
    static let vornameNachname = RE(#"\b(\#(namenswort))[ \t]+((?:(?:von|van|de|di|da|del|zu|dos)[ \t]+)?\#(namenswort))"#)
    static let anrede = RE(#"(?im)(?:^|(?<=\s))(?:Hallo|Hoi|Hi|Hey|Salü|Sali|Grüezi|Guten\s+(?:Morgen|Tag|Abend)|Liebe[rs]?|Dear|Hello|Bonjour|Salut|Ciao|Buongiorno|Car[ao]|Chère?|Gentile)[ \t]+(?-i:(\#(namenswort)(?:[ \t]+\#(namenswort))?))[ \t]*[,!\n]"#)
    static let gruss = RE(#"(?im)^[ \t]*(?:(?:mit\s+)?(?:freundliche[nr]?|beste[n]?|liebe[n]?|herzliche[n]?|viele|sonnige|schöne|kollegiale|freundschaftliche)\s+)?(?:grüsse[n]?|grüße[n]?|gruss|gruß)\b|^[ \t]*(?:lg|mfg|vg|best regards|kind regards|regards|best|cheers|cordialement|meilleures salutations|salutations distinguées|cordiali saluti|distinti saluti|saluti)\b"#)
    static let signaturZeile = RE(#"^\s*(?:(?:i\.\s?A\.|i\.\s?V\.|p\.\s?p\.)\s*)?(?:\#(titel)\s+)?(\#(namenswort)(?:[ \t]+(?:(?:von|van|de|di|da|del|zu)[ \t]+)?\#(namenswort)){0,3})\s*$"#)
    static let einzelnesWort = RE(#"\b[\#(gross)][\#(klein)]+\b"#)

    // Bereinigung von Namenskandidaten
    static let titelAmAnfang = RE(#"^(?:\#(titel)\s+)+"#)
    static let akadTitelAmAnfang = RE(#"^(?:(?:Dr|Prof|lic|med|iur|phil|Dipl|Ing)\.\s*)+"#)
    static let unerlaubteZeichen = RE(#"[\d@/\\_\[\]\{\}<>|=+*#]"#)
    static let keinKategorieZeichen = RE(#"[^A-ZÄÖÜ_]"#)

    /// Besonders schützenswerte Personendaten (Art. 5 lit. c DSG / Art. 9 DSGVO)
    static let besondersSchuetzenswert: [(String, RE)] = besondersQuellen.map { eintrag in
        (eintrag.0, RE(#"(?i)\b(?:"# + eintrag.1 + ")"))
    }

    static let besondersQuellen: [(String, String)] = [
        ("Gesundheit", #"diagnose|krankheit|erkrank|krankschreib|arbeitsunfähig|arztzeugnis|therapie|medikament|spital|klinik|psychiat|psycholog|depression|burn-?out|krebs|tumor|hiv|aids|diabetes|schwanger|behinderung|unfallmeldung|rezept\b|patient|befund|operation\b|reha\b"#),
        ("Religion/Weltanschauung", #"religion|konfession|katholisch|reformiert|evangelisch|muslim|islamisch|jüdisch|jude\b|jüdin|kirchenaustritt|freikirch|atheist"#),
        ("Politik/Gewerkschaft", #"parteimitglied|parteizugehörig|gewerkschaft|politische[nr]?\s+(?:meinung|gesinnung|ansicht|haltung)|wahlverhalten"#),
        ("Intimsphäre/Herkunft", #"sexuelle\s+orientierung|homosexuell|bisexuell|transgender|ethnisch|rassisch|hautfarbe"#),
        ("Genetik/Biometrie", #"genetisch|dna\b|erbgut|fingerabdr|biometri|gesichtserkennung"#),
        ("Straf-/Verwaltungsverfahren", #"strafverfahren|strafregister|vorstraf|verurteil|anklage|strafanzeige|strafbefehl|polizeilich|untersuchungshaft|verwaltungsverfahren"#),
        ("Sozialhilfe", #"sozialhilfe|iv-rente|invalidenversicherung|ergänzungsleistung|fürsorge|kesb|beistandschaft|betreibung"#),
    ]

    /// Vorrang bei Überschneidungen (kleiner = wichtiger)
    static let vorrang: [String: Int] = [
        "_GESCHUETZT": 0, "EMAIL": 1, "PROFIL_URL": 2, "IBAN": 3, "AHV": 4, "KREDITKARTE": 5,
        "IP": 6, "TELEFON": 7, "GEBURTSDATUM": 8, "ADRESSE": 9, "PLZ_ORT": 10, "KENNZEICHEN": 11,
        "_EIGEN": 12, "NAME": 13, "ORGANISATION": 14, "ORT": 15, "DATUM": 16,
    ]
}

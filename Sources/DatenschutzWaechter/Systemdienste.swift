// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Urs Stirnemann – siehe LICENSE und NOTICE

// DSGVO Datenschutz Wächter – Anbindung an macOS:
// Tastenkürzel (Carbon), Einfügen (CGEvent), Namenserkennung, Mitteilungen, Protokoll

#if os(macOS)
import AppKit
import ApplicationServices
import Carbon
import DatenschutzKern
import NaturalLanguage
import UserNotifications

// MARK: - Protokoll (enthält nie kopierte Inhalte)

private let zeitFormat: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return f
}()

func log(_ text: String) {
    let zeile = zeitFormat.string(from: Date()) + " " + text + "\n"
    if let daten = zeile.data(using: .utf8) {
        FileHandle.standardError.write(daten)
    }
}

// MARK: - Systemweites Tastenkürzel (braucht keine Sonderrechte)

final class Tastenkuerzel {
    var aktion: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    func registrieren(code: UInt32, modifier: UInt32) throws {
        entfernen()
        var typ = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selbst = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(GetEventDispatcherTarget(), { _, _, daten in
            guard let daten = daten else { return 0 }
            let ich = Unmanaged<Tastenkuerzel>.fromOpaque(daten).takeUnretainedValue()
            ich.aktion?()
            return 0
        }, 1, &typ, selbst, &handlerRef)
        guard status == 0 else {
            throw Fehler("Tastenkürzel-Empfang konnte nicht eingerichtet werden (Fehler \(status))")
        }
        let kennung = EventHotKeyID(signature: OSType(0x4453_5768), id: 1) // 'DSWh'
        let ergebnis = RegisterEventHotKey(code, modifier, kennung, GetEventDispatcherTarget(), 0, &hotKeyRef)
        guard ergebnis == 0 else {
            entfernen()
            let grund = ergebnis == -9878 ? "bereits von einer anderen App belegt" : "Fehler \(ergebnis)"
            throw Fehler("Tastenkürzel konnte nicht registriert werden (\(grund))")
        }
    }

    func entfernen() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let ref = handlerRef {
            RemoveEventHandler(ref)
            handlerRef = nil
        }
    }
}

// MARK: - Einfügen simulieren (braucht «Bedienungshilfen»)

enum Einfuegen {
    /// true, wenn die App Tastendrücke senden darf; mit nachfragen=true zeigt macOS den Dialog
    static func bedienungshilfenErlaubt(nachfragen: Bool) -> Bool {
        let optionen = ["AXTrustedCheckOptionPrompt": nachfragen] as CFDictionary
        return AXIsProcessTrustedWithOptions(optionen)
    }

    static func zusatztastenGedrueckt() -> Bool {
        let flags = CGEventSource.flagsState(.hidSystemState)
        return !flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift]).isEmpty
    }

    static func befehlVSenden() {
        let quelle = CGEventSource(stateID: .combinedSessionState)
        let taste = CGKeyCode(kVK_ANSI_V)
        for gedrueckt in [true, false] {
            if let ereignis = CGEvent(keyboardEventSource: quelle, virtualKey: taste, keyDown: gedrueckt) {
                ereignis.flags = .maskCommand
                ereignis.post(tap: .cgAnnotatedSessionEventTap)
            }
        }
    }
}

// MARK: - Namenserkennung mit Apples NaturalLanguage (läuft auf dem Mac)

final class AppleNamenErkenner {
    private let tagger = NLTagger(tagSchemes: [.nameType])

    func erkennen(_ text: String) -> [(kategorie: String, wert: String)] {
        tagger.string = text
        var funde: [(kategorie: String, wert: String)] = []
        let optionen: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: optionen
        ) { tag, bereich in
            let wert = String(text[bereich])
            if tag == .personalName {
                funde.append((kategorie: "NAME", wert: wert))
            } else if tag == .organizationName {
                funde.append((kategorie: "ORGANISATION", wert: wert))
            } else if tag == .placeName {
                funde.append((kategorie: "ORT", wert: wert))
            }
            return true
        }
        return funde
    }
}

// MARK: - Mitteilungen (enthalten nie Originalwerte)

final class Mitteilungen {
    private var erlaubt = false
    private var imAppPaket: Bool { Bundle.main.bundleIdentifier != nil }

    func vorbereiten() {
        guard imAppPaket else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] ok, _ in
            DispatchQueue.main.async { self?.erlaubt = ok }
        }
    }

    func senden(titel: String, text: String) {
        if imAppPaket && erlaubt {
            let inhalt = UNMutableNotificationContent()
            inhalt.title = "DSGVO Datenschutz Wächter"
            inhalt.subtitle = titel
            inhalt.body = text
            let anfrage = UNNotificationRequest(identifier: UUID().uuidString, content: inhalt, trigger: nil)
            UNUserNotificationCenter.current().add(anfrage, withCompletionHandler: nil)
        } else {
            // Ersatzweise über AppleScript
            let skript = "display notification \(Mitteilungen.zitat(text)) "
                + "with title \"DSGVO Datenschutz Wächter\" subtitle \(Mitteilungen.zitat(titel))"
            let prozess = Process()
            prozess.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            prozess.arguments = ["-e", skript]
            try? prozess.run()
        }
    }

    static func zitat(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}
#endif

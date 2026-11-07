// DSGVO Datenschutz Wächter – Tastenkürzel lesen: "ctrl+alt+v" -> Tastencode, Modifier, "⌃⌥V"

import Foundation

public struct Fehler: LocalizedError {
    public let text: String
    public init(_ text: String) { self.text = text }
    public var errorDescription: String? { text }
}

public struct Kuerzel {
    public let code: UInt32
    public let modifier: UInt32
    public let anzeige: String
}

public enum KuerzelLeser {
    // Carbon-Modifier (cmdKey, shiftKey, optionKey, controlKey)
    public static let cmd: UInt32 = 0x0100
    public static let shift: UInt32 = 0x0200
    public static let option: UInt32 = 0x0800
    public static let control: UInt32 = 0x1000

    static let zusatz: [String: UInt32] = [
        "cmd": cmd, "command": cmd, "⌘": cmd, "befehl": cmd,
        "shift": shift, "⇧": shift, "umschalt": shift,
        "alt": option, "option": option, "opt": option, "⌥": option, "wahl": option,
        "ctrl": control, "control": control, "ctl": control, "⌃": control, "strg": control,
    ]

    /// Tastencodes nach Position (US-Layout; V liegt auf der Schweizer Tastatur gleich)
    static let tastencodes: [String: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19,
        "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29, "o": 31,
        "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98, "f8": 100,
        "f9": 101, "f10": 109, "f11": 103, "f12": 111, "leertaste": 49, "space": 49,
    ]

    public static func lesen(_ kuerzel: String) throws -> Kuerzel {
        let teile = kuerzel.replacingOccurrences(of: " ", with: "")
            .split(separator: "+")
            .map { $0.lowercased() }
            .filter { !$0.isEmpty }
        guard teile.count >= 2, let taste = teile.last else {
            throw Fehler("Tastenkürzel «\(kuerzel)» braucht mindestens eine Zusatztaste, z.B. ctrl+alt+v")
        }
        guard let code = tastencodes[taste] else {
            throw Fehler("Unbekannte Taste «\(taste)» in «\(kuerzel)»")
        }
        var modifier: UInt32 = 0
        for t in teile.dropLast() {
            guard let m = zusatz[t] else {
                throw Fehler("Unbekannte Zusatztaste «\(t)» in «\(kuerzel)» (erlaubt: ctrl, alt, shift, cmd)")
            }
            modifier |= m
        }
        // Seit macOS 15 sind Kürzel nur mit ⌥ bzw. ⌥⇧ nicht mehr erlaubt
        guard modifier & (cmd | control) != 0 else {
            throw Fehler("Tastenkürzel «\(kuerzel)» muss ctrl oder cmd enthalten")
        }
        var anzeige = ""
        if modifier & control != 0 { anzeige += "⌃" }
        if modifier & option != 0 { anzeige += "⌥" }
        if modifier & shift != 0 { anzeige += "⇧" }
        if modifier & cmd != 0 { anzeige += "⌘" }
        anzeige += taste.uppercased()
        return Kuerzel(code: code, modifier: modifier, anzeige: anzeige)
    }
}

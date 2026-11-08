// DSGVO Datenschutz Wächter – Windows-App (Symbol im Infobereich)
//
// Überwacht die Zwischenablage. Sobald Text kopiert wird (Strg+C), werden
// Namen, E-Mail-Adressen, Telefonnummern, IBAN, AHV-Nummern, Adressen usw.
// durch nummerierte Platzhalter ersetzt. Mit Strg+Alt+V wird kopierter Text
// mit Platzhaltern wieder mit den Originalen eingefügt.
//
// Alles läuft lokal. Die Zuordnung liegt nur im Arbeitsspeicher; Protokoll
// und Mitteilungen enthalten nie Originalwerte.

#if os(Windows)
import DatenschutzKern
import Foundation
import WinSDK

// MARK: - Hilfen für Windows-Zeichenketten (UTF-16)

func mitBreit<R>(_ text: String, _ arbeit: (UnsafePointer<WCHAR>) -> R) -> R {
    var puffer = Array(text.utf16)
    puffer.append(0)
    return puffer.withUnsafeBufferPointer { arbeit($0.baseAddress!) }
}

/// Schreibt Text in ein Feld fester Länge (z.B. szTip in NOTIFYICONDATAW)
func inFeld<T>(_ feld: inout T, _ text: String) {
    withUnsafeMutableBytes(of: &feld) { roh in
        let einheiten = roh.bindMemory(to: WCHAR.self)
        guard einheiten.count > 0 else { return }
        let quelle = Array(text.utf16.prefix(einheiten.count - 1))
        for i in 0..<einheiten.count {
            einheiten[i] = i < quelle.count ? quelle[i] : 0
        }
    }
}

func niedrigesWort(_ wert: WPARAM) -> UInt32 { UInt32(truncatingIfNeeded: wert) & 0xFFFF }
func niedrigesWort(_ wert: LPARAM) -> UInt32 { UInt32(truncatingIfNeeded: wert) & 0xFFFF }

// MARK: - Konstanten

let WM_TRAY = UINT(WM_APP) + 1
let TRAY_ID: UINT = 1
let HOTKEY_ID: Int32 = 1
let TIMER_EINFUEGEN: UINT_PTR = 1
let TIMER_WIEDERHERSTELLEN: UINT_PTR = 2
let APP_NAME = "DSGVO Datenschutz Wächter"

enum Befehl: UInt32 {
    case aktiv = 100, einfuegen, zurueck, original, tabelle, loeschen
    case mitteilungen, autostart, einstellungen, neuLaden, beenden
}

// MARK: - Fensterprozedur (Windows ruft sie für jede Nachricht auf)

private func fensterProzedur(_ fenster: HWND?, _ nachricht: UINT, _ wParam: WPARAM, _ lParam: LPARAM) -> LRESULT {
    if let app = WindowsWaechter.instanz, app.behandle(nachricht: nachricht, wParam: wParam, lParam: lParam) {
        return 0
    }
    return DefWindowProcW(fenster, nachricht, wParam, lParam)
}

// MARK: - App

final class WindowsWaechter {
    static var instanz: WindowsWaechter?

    private var fenster: HWND?
    private var einstellungen = Einstellungen()
    private var anonymisierer = Anonymisierer()
    private var aktiv = true
    private var eigeneSequenz: DWORD = 0
    private var letztesOriginal: String?
    private var platzhalterText: String?
    private var einfuegenFrist = Date()
    private var statusText = "Noch nichts geprüft"
    private var warnungText: String?
    private var kuerzelAnzeige = ""
    private var taskbarErstellt: UINT = 0
    private var vorherigesFenster: HWND?
    private var erstesMal = false

    private let laufSchluessel = "Software\\Microsoft\\Windows\\CurrentVersion\\Run"
    private let laufName = "DSGVO Datenschutz Waechter"

    private lazy var ausschlussFormate: [UINT] = [
        "ExcludeClipboardContentFromMonitorProcessing", // Passwortmanager
        "Clipboard Viewer Ignore",
        "CanIncludeInClipboardHistory",
    ].map { name in mitBreit(name) { RegisterClipboardFormatW($0) } }

    // MARK: Pfade

    static func exePfad() -> String {
        var puffer = [WCHAR](repeating: 0, count: 32768)
        let laenge = GetModuleFileNameW(nil, &puffer, DWORD(puffer.count))
        return String(decoding: puffer[0..<Int(laenge)], as: UTF16.self)
    }

    private var exeOrdner: String {
        let pfad = WindowsWaechter.exePfad()
        guard let ende = pfad.lastIndex(of: "\\") else { return "." }
        return String(pfad[..<ende])
    }

    private var ordnerPfad: String {
        let basis = ProcessInfo.processInfo.environment["APPDATA"] ?? NSHomeDirectory()
        return basis + "\\DSGVO Datenschutz Waechter"
    }

    private var dateiPfad: String { ordnerPfad + "\\einstellungen.json" }

    // MARK: Start

    static func starten() {
        let pruefModus = CommandLine.arguments.contains("--pruefen")
        if !pruefModus {
            // Nur eine Instanz
            _ = mitBreit("Local\\DSGVO-Datenschutz-Waechter") { CreateMutexW(nil, true, $0) }
            if GetLastError() == DWORD(ERROR_ALREADY_EXISTS) {
                _ = mitBreit("Der DSGVO Datenschutz Wächter läuft bereits.\nDas Symbol findest Du im Infobereich unten rechts (evtl. unter ^).") { text in
                    mitBreit(APP_NAME) { titel in MessageBoxW(nil, text, titel, UINT(MB_OK | MB_ICONINFORMATION)) }
                }
                return
            }
        }
        let app = WindowsWaechter()
        instanz = app
        if pruefModus {
            exit(app.pruefen())
        }
        app.einrichten()
        var nachricht = MSG()
        while GetMessageW(&nachricht, nil, 0, 0) {
            TranslateMessage(&nachricht)
            DispatchMessageW(&nachricht)
        }
        app.aufraeumen()
    }

    private func einrichten() {
        einstellungen = einstellungenLaden()
        anonymisierer = Anonymisierer(einstellungen: einstellungen)
        fensterErstellen()
        guard let fenster = fenster else { return }
        _ = AddClipboardFormatListener(fenster)
        taskbarErstellt = mitBreit("TaskbarCreated") { RegisterWindowMessageW($0) }
        symbolHinzufuegen()
        tastenkuerzelEinrichten()
        log("gestartet")
        if erstesMal && !autostartAktiv() {
            let antwort = meldungsfenster(
                "Der DSGVO Datenschutz Wächter läuft jetzt im Infobereich unten rechts (evtl. unter ^).\n\n"
                    + "Soll er bei jedem Windows-Start automatisch starten?\n\n"
                    + "Tipp: Den Programmordner vorher an einen festen Ort verschieben, z.B. nach «Dokumente».",
                MB_YESNO | MB_ICONQUESTION
            )
            if antwort == IDYES { autostartSetzen(true) }
        }
    }

    private func fensterErstellen() {
        let modul = GetModuleHandleW(nil)
        let klassenName = "DSGVODatenschutzWaechter"
        mitBreit(klassenName) { name in
            var klasse = WNDCLASSEXW()
            klasse.cbSize = UINT(MemoryLayout<WNDCLASSEXW>.size)
            klasse.lpfnWndProc = fensterProzedur
            klasse.hInstance = modul
            klasse.lpszClassName = name
            _ = RegisterClassExW(&klasse)
        }
        fenster = mitBreit(klassenName) { name in
            mitBreit(APP_NAME) { titel in
                CreateWindowExW(0, name, titel, DWORD(WS_OVERLAPPED), 0, 0, 0, 0, nil, nil, modul, nil)
            }
        }
    }

    private func aufraeumen() {
        var daten = basisDaten()
        _ = Shell_NotifyIconW(DWORD(NIM_DELETE), &daten)
        _ = UnregisterHotKey(fenster, HOTKEY_ID)
        _ = RemoveClipboardFormatListener(fenster)
    }

    // MARK: Nachrichten

    func behandle(nachricht: UINT, wParam: WPARAM, lParam: LPARAM) -> Bool {
        switch nachricht {
        case UINT(WM_CLIPBOARDUPDATE):
            zwischenablageGeaendert()
            return true
        case UINT(WM_HOTKEY):
            if wParam == WPARAM(HOTKEY_ID) { mitOriginalenEinfuegen() }
            return true
        case WM_TRAY:
            let maus = niedrigesWort(lParam)
            if maus == UINT(WM_RBUTTONUP) || maus == UINT(WM_LBUTTONUP) { menueZeigen() }
            return true
        case UINT(WM_COMMAND):
            if let befehl = Befehl(rawValue: niedrigesWort(wParam)) { ausfuehren(befehl) }
            return true
        case UINT(WM_TIMER):
            zeitgeber(UINT_PTR(wParam))
            return true
        case UINT(WM_DESTROY):
            PostQuitMessage(0)
            return true
        default:
            if taskbarErstellt != 0 && nachricht == taskbarErstellt {
                symbolHinzufuegen() // Explorer wurde neu gestartet
                return true
            }
            return false
        }
    }

    // MARK: Symbol im Infobereich

    private func basisDaten() -> NOTIFYICONDATAW {
        var daten = NOTIFYICONDATAW()
        daten.cbSize = DWORD(MemoryLayout<NOTIFYICONDATAW>.size)
        daten.hWnd = fenster
        daten.uID = TRAY_ID
        return daten
    }

    private func symbolBild() -> HICON? {
        // IDI_SHIELD (32518) wenn aktiv, IDI_APPLICATION (32512) wenn pausiert
        LoadIconW(nil, UnsafePointer<WCHAR>(bitPattern: aktiv ? 32518 : 32512))
    }

    private func tooltip() -> String {
        APP_NAME + (aktiv ? " – aktiv" : " – pausiert")
    }

    @discardableResult
    private func symbolHinzufuegen() -> Bool {
        var daten = basisDaten()
        daten.uFlags = UINT(NIF_MESSAGE | NIF_ICON | NIF_TIP)
        daten.uCallbackMessage = WM_TRAY
        daten.hIcon = symbolBild()
        inFeld(&daten.szTip, tooltip())
        return Shell_NotifyIconW(DWORD(NIM_ADD), &daten)
    }

    private func symbolAktualisieren() {
        var daten = basisDaten()
        daten.uFlags = UINT(NIF_ICON | NIF_TIP)
        daten.hIcon = symbolBild()
        inFeld(&daten.szTip, tooltip())
        _ = Shell_NotifyIconW(DWORD(NIM_MODIFY), &daten)
    }

    private func melden(_ titel: String, _ text: String, immer: Bool = false, warnung: Bool = false) {
        guard immer || einstellungen.benachrichtigungen else { return }
        var daten = basisDaten()
        daten.uFlags = UINT(NIF_INFO)
        inFeld(&daten.szInfoTitle, titel)
        inFeld(&daten.szInfo, text)
        daten.dwInfoFlags = DWORD(warnung ? NIIF_WARNING : NIIF_INFO)
        _ = Shell_NotifyIconW(DWORD(NIM_MODIFY), &daten)
    }

    @discardableResult
    private func meldungsfenster(_ text: String, _ stil: Int32) -> Int32 {
        mitBreit(text) { t in
            mitBreit(APP_NAME) { titel in
                MessageBoxW(fenster, t, titel, UINT(stil | MB_SETFOREGROUND | MB_TOPMOST))
            }
        }
    }

    // MARK: Menü

    private func menueZeigen() {
        guard let fenster = fenster, let menue = CreatePopupMenu() else { return }

        func eintrag(_ text: String, _ befehl: Befehl?, an: Bool = false) {
            var flags = UINT(MF_STRING)
            if an { flags |= UINT(MF_CHECKED) }
            if befehl == nil { flags |= UINT(MF_GRAYED) }
            _ = mitBreit(text) { AppendMenuW(menue, flags, UINT_PTR(befehl?.rawValue ?? 0), $0) }
        }
        func trenner() {
            _ = AppendMenuW(menue, UINT(MF_SEPARATOR), 0, nil)
        }

        eintrag("DSGVO Datenschutz aktiv", .aktiv, an: aktiv)
        eintrag(statusText, nil)
        if let warnung = warnungText { eintrag(warnung, nil) }
        trenner()
        eintrag("Mit Originalen einfügen" + (kuerzelAnzeige.isEmpty ? "" : "\t" + kuerzelAnzeige), .einfuegen)
        eintrag("Platzhalter in Zwischenablage zurückübersetzen", .zurueck)
        eintrag("Original der letzten Kopie zurück in die Zwischenablage", .original)
        trenner()
        eintrag("Zuordnungstabelle anzeigen …", .tabelle)
        eintrag("Zuordnungen löschen", .loeschen)
        trenner()
        eintrag("Mitteilungen anzeigen", .mitteilungen, an: einstellungen.benachrichtigungen)
        eintrag("Beim Windows-Start ausführen", .autostart, an: autostartAktiv())
        eintrag("Einstellungen öffnen …", .einstellungen)
        eintrag("Einstellungen neu laden", .neuLaden)
        trenner()
        eintrag("Beenden", .beenden)

        vorherigesFenster = GetForegroundWindow()
        var punkt = POINT()
        _ = GetCursorPos(&punkt)
        _ = SetForegroundWindow(fenster)
        _ = TrackPopupMenu(menue, UINT(TPM_RIGHTBUTTON | TPM_BOTTOMALIGN), punkt.x, punkt.y, 0, fenster, nil)
        _ = PostMessageW(fenster, UINT(WM_NULL), 0, 0)
        _ = DestroyMenu(menue)
    }

    private func ausfuehren(_ befehl: Befehl) {
        switch befehl {
        case .aktiv:
            aktiv.toggle()
            symbolAktualisieren()
        case .einfuegen:
            mitOriginalenEinfuegen(zielFenster: vorherigesFenster)
        case .zurueck:
            zurueckuebersetzen()
        case .original:
            originalZurueck()
        case .tabelle:
            let zeilen = anonymisierer.zuordnung.tabelle().map { "\($0.platzhalter)  →  \($0.original)" }
            meldungsfenster(
                "Nur im Arbeitsspeicher – wird beim Beenden gelöscht.\n\n"
                    + (zeilen.isEmpty ? "(noch leer)" : zeilen.joined(separator: "\n"))
                    + "\n\nTipp: Strg+C kopiert diesen Text.",
                MB_OK | MB_ICONINFORMATION
            )
        case .loeschen:
            let antwort = meldungsfenster(
                "Zuordnungen löschen?\n\nDanach können Platzhalter nicht mehr zurückübersetzt werden. Die Nummerierung beginnt neu.",
                MB_YESNO | MB_ICONQUESTION
            )
            if antwort == IDYES {
                anonymisierer.zuordnungLeeren()
                letztesOriginal = nil
                statusText = "Zuordnungen gelöscht"
            }
        case .mitteilungen:
            einstellungen.benachrichtigungen.toggle()
            try? Einstellungen.speichere(
                einstellungen.benachrichtigungen, schluessel: "benachrichtigungen", in: URL(fileURLWithPath: dateiPfad)
            )
        case .autostart:
            autostartSetzen(!autostartAktiv())
        case .einstellungen:
            _ = mitBreit("open") { verb in
                mitBreit("notepad.exe") { programm in
                    mitBreit("\"\(dateiPfad)\"") { argument in
                        ShellExecuteW(fenster, verb, programm, argument, nil, SW_SHOWNORMAL)
                    }
                }
            }
        case .neuLaden:
            einstellungen = einstellungenLaden()
            anonymisierer.setzeEinstellungen(einstellungen)
            tastenkuerzelEinrichten()
            melden("Einstellungen geladen", "Die neuen Einstellungen sind aktiv.", immer: true)
        case .beenden:
            aufraeumen()
            _ = DestroyWindow(fenster)
        }
    }

    // MARK: Zwischenablage

    private func oeffnen() -> Bool {
        for _ in 0..<10 {
            if OpenClipboard(fenster) { return true }
            Sleep(15) // ein anderes Programm hält die Zwischenablage gerade offen
        }
        return false
    }

    private func lesen() -> String? {
        guard IsClipboardFormatAvailable(UINT(CF_UNICODETEXT)), oeffnen() else { return nil }
        defer { _ = CloseClipboard() }
        guard let griff = GetClipboardData(UINT(CF_UNICODETEXT)), let zeiger = GlobalLock(griff) else { return nil }
        defer { _ = GlobalUnlock(griff) }
        return String(decodingCString: zeiger.assumingMemoryBound(to: WCHAR.self), as: UTF16.self)
    }

    private func globalerSpeicher(_ bytes: UnsafeRawBufferPointer) -> HGLOBAL? {
        guard let griff = GlobalAlloc(UINT(GMEM_MOVEABLE), SIZE_T(bytes.count)) else { return nil }
        if let ziel = GlobalLock(griff) {
            if let quelle = bytes.baseAddress {
                ziel.copyMemory(from: quelle, byteCount: bytes.count)
            }
            _ = GlobalUnlock(griff)
        }
        return griff
    }

    private func schreiben(_ text: String, vertraulich: Bool = false) {
        var einheiten = Array(text.utf16)
        einheiten.append(0)
        guard oeffnen() else { return }
        _ = EmptyClipboard()
        if let griff = einheiten.withUnsafeBytes({ globalerSpeicher($0) }) {
            _ = SetClipboardData(UINT(CF_UNICODETEXT), griff)
        }
        if vertraulich {
            // Nicht in den Windows-Zwischenablageverlauf (Win+V), nicht in die Cloud,
            // von anderen Zwischenablage-Programmen ignorieren
            var null: DWORD = 0
            for name in ["CanIncludeInClipboardHistory", "CanUploadToCloudClipboard",
                         "ExcludeClipboardContentFromMonitorProcessing"] {
                let format = mitBreit(name) { RegisterClipboardFormatW($0) }
                if let griff = withUnsafeBytes(of: &null, { globalerSpeicher($0) }) {
                    _ = SetClipboardData(format, griff)
                }
            }
        }
        _ = CloseClipboard()
        eigeneSequenz = GetClipboardSequenceNumber()
    }

    /// Prozess-ID und Programmname des Fensters im Vordergrund
    private func vordergrund() -> (pid: DWORD, exe: String?) {
        guard let w = GetForegroundWindow() else { return (0, nil) }
        var pid: DWORD = 0
        _ = GetWindowThreadProcessId(w, &pid)
        guard let prozess = OpenProcess(DWORD(PROCESS_QUERY_LIMITED_INFORMATION), false, pid) else { return (pid, nil) }
        defer { _ = CloseHandle(prozess) }
        var puffer = [WCHAR](repeating: 0, count: 1024)
        var laenge = DWORD(puffer.count)
        guard QueryFullProcessImageNameW(prozess, 0, &puffer, &laenge) else { return (pid, nil) }
        let pfad = String(decoding: puffer[0..<Int(laenge)], as: UTF16.self)
        return (pid, pfad.split(separator: "\\").last.map(String.init))
    }

    private func zwischenablageGeaendert() {
        let sequenz = GetClipboardSequenceNumber()
        guard aktiv, sequenz != eigeneSequenz else { return }
        if IsClipboardFormatAvailable(UINT(CF_HDROP)) { return } // kopierte Dateien
        if ausschlussFormate.contains(where: { IsClipboardFormatAvailable($0) }) { return }
        let vorne = vordergrund()
        if vorne.pid == GetCurrentProcessId() { return } // z.B. aus der Zuordnungstabelle kopiert
        if let exe = vorne.exe,
           einstellungen.ausgenommeneApps.contains(where: { $0.caseInsensitiveCompare(exe) == .orderedSame }) {
            return
        }
        guard let text = lesen(), !text.isEmpty else { return }

        let ergebnis = anonymisierer.anonymisieren(text)
        let zeit = uhrzeit()
        if ergebnis.geaendert {
            letztesOriginal = text
            schreiben(ergebnis.text)
            statusText = "\(zeit) – ersetzt: \(ergebnis.zusammenfassung)"
            melden("\(ergebnis.gesamt) Angabe(n) ersetzt", ergebnis.zusammenfassung)
            log("ersetzt: \(ergebnis.zusammenfassung)") // nur Zahlen, keine Inhalte
        } else {
            statusText = "\(zeit) – keine Personendaten gefunden"
        }
        if ergebnis.warnungen.isEmpty {
            warnungText = nil
        } else {
            let hinweis = ergebnis.warnungen.joined(separator: ", ")
            warnungText = "⚠ Evtl. besonders schützenswert: \(hinweis)"
            if einstellungen.warnungBesondersSchuetzenswert {
                melden("Besonders schützenswerte Daten?",
                       "Der Text enthält Hinweise auf: \(hinweis). Bitte vor dem Weitergeben prüfen.",
                       immer: true, warnung: true)
            }
        }
    }

    // MARK: Mit Originalen einfügen (Strg+Alt+V)

    private func mitOriginalenEinfuegen(zielFenster: HWND? = nil) {
        guard let text = lesen(), !text.isEmpty else {
            melden("Nichts einzufügen", "In der Zwischenablage ist kein Text.", immer: true)
            return
        }
        let ergebnis = anonymisierer.zurueckuebersetzen(text)
        guard ergebnis.anzahl > 0 else {
            melden("Keine bekannten Platzhalter",
                   "Der kopierte Text enthält keine Platzhalter, die seit dem Start erfasst wurden.", immer: true)
            return
        }
        schreiben(ergebnis.text, vertraulich: true)
        statusText = "\(uhrzeit()) – \(ergebnis.anzahl) Platzhalter mit Originalen eingefügt"
        log("\(ergebnis.anzahl) Platzhalter zurückübersetzt")
        if let ziel = zielFenster { _ = SetForegroundWindow(ziel) }
        platzhalterText = text
        einfuegenFrist = Date().addingTimeInterval(3)
        _ = SetTimer(fenster, TIMER_EINFUEGEN, 30, nil)
    }

    private func zusatztastenGedrueckt() -> Bool {
        [VK_CONTROL, VK_MENU, VK_SHIFT, VK_LWIN, VK_RWIN].contains { taste in
            (GetAsyncKeyState(Int32(taste)) & Int16(bitPattern: 0x8000)) != 0
        }
    }

    private func strgVSenden() {
        func taste(_ code: Int32, los: Bool) -> INPUT {
            var eingabe = INPUT()
            eingabe.type = DWORD(INPUT_KEYBOARD)
            eingabe.ki.wVk = WORD(code)
            eingabe.ki.dwFlags = los ? DWORD(KEYEVENTF_KEYUP) : 0
            return eingabe
        }
        var eingaben = [
            taste(Int32(VK_CONTROL), los: false), taste(0x56, los: false),
            taste(0x56, los: true), taste(Int32(VK_CONTROL), los: true),
        ]
        _ = SendInput(UINT(eingaben.count), &eingaben, Int32(MemoryLayout<INPUT>.size))
    }

    private func zeitgeber(_ kennung: UINT_PTR) {
        switch kennung {
        case TIMER_EINFUEGEN:
            // Warten, bis Strg/Alt losgelassen sind, damit die Ziel-App ein sauberes Strg+V erhält
            if zusatztastenGedrueckt() && Date() < einfuegenFrist { return }
            _ = KillTimer(fenster, TIMER_EINFUEGEN)
            if zusatztastenGedrueckt() {
                melden("Originale liegen in der Zwischenablage", "Jetzt Strg+V drücken.", immer: true)
                platzhalterText = nil
                return
            }
            strgVSenden()
            if einstellungen.nachEinfuegenWiederherstellen {
                _ = SetTimer(fenster, TIMER_WIEDERHERSTELLEN, 1000, nil)
            } else {
                platzhalterText = nil
            }
        case TIMER_WIEDERHERSTELLEN:
            _ = KillTimer(fenster, TIMER_WIEDERHERSTELLEN)
            // Nur, wenn seither nichts Neues kopiert wurde
            if let text = platzhalterText, GetClipboardSequenceNumber() == eigeneSequenz {
                schreiben(text)
            }
            platzhalterText = nil
        default:
            break
        }
    }

    private func zurueckuebersetzen() {
        guard let text = lesen(), !text.isEmpty else {
            melden("Nichts zurückzuübersetzen", "In der Zwischenablage ist kein Text.", immer: true)
            return
        }
        let ergebnis = anonymisierer.zurueckuebersetzen(text)
        guard ergebnis.anzahl > 0 else {
            melden("Nichts zurückübersetzt", "Keine bekannten Platzhalter gefunden.", immer: true)
            return
        }
        schreiben(ergebnis.text, vertraulich: true)
        statusText = "\(ergebnis.anzahl) Platzhalter zurückübersetzt"
        melden("\(ergebnis.anzahl) Platzhalter zurückübersetzt", "Strg+V fügt jetzt den Text mit Originalen ein.", immer: true)
    }

    private func originalZurueck() {
        guard let original = letztesOriginal else {
            melden("Kein Original", "Es gibt noch kein gespeichertes Original.", immer: true)
            return
        }
        schreiben(original, vertraulich: true)
        statusText = "Original liegt in der Zwischenablage (bis zur nächsten Kopie)"
        melden("Original wiederhergestellt", "Strg+V fügt jetzt den unveränderten Text ein.", immer: true)
    }

    // MARK: Tastenkürzel

    private func tastenkuerzelEinrichten() {
        _ = UnregisterHotKey(fenster, HOTKEY_ID)
        kuerzelAnzeige = ""
        let kuerzel = einstellungen.tastenkuerzel.trimmingCharacters(in: .whitespaces)
        guard !kuerzel.isEmpty else { return }
        do {
            let k = try KuerzelLeser.lesen(kuerzel)
            if RegisterHotKey(fenster, HOTKEY_ID, UINT(k.windowsModifier), UINT(k.windowsTaste)) {
                kuerzelAnzeige = k.anzeigeWindows
                log("Tastenkürzel \(k.anzeigeWindows) aktiv")
            } else {
                melden("Tastenkürzel nicht verfügbar",
                       "\(k.anzeigeWindows) ist bereits von einem anderen Programm belegt.", immer: true)
            }
        } catch {
            melden("Tastenkürzel nicht verfügbar", error.localizedDescription, immer: true)
        }
    }

    // MARK: Autostart (Registry: HKCU\...\Run)

    private var hkcu: HKEY? {
        HKEY(bitPattern: Int(Int32(bitPattern: 0x8000_0001))) // HKEY_CURRENT_USER
    }

    private func autostartAktiv() -> Bool {
        var groesse: DWORD = 0
        let status = mitBreit(laufSchluessel) { schluessel in
            mitBreit(laufName) { name in
                RegGetValueW(hkcu, schluessel, name, DWORD(RRF_RT_REG_SZ), nil, nil, &groesse)
            }
        }
        return status == ERROR_SUCCESS
    }

    private func autostartSetzen(_ an: Bool) {
        if an {
            var einheiten = Array("\"\(WindowsWaechter.exePfad())\"".utf16)
            einheiten.append(0)
            let bytes = DWORD(einheiten.count * MemoryLayout<WCHAR>.size)
            _ = mitBreit(laufSchluessel) { schluessel in
                mitBreit(laufName) { name in
                    einheiten.withUnsafeBytes { daten in
                        RegSetKeyValueW(hkcu, schluessel, name, DWORD(REG_SZ), daten.baseAddress, bytes)
                    }
                }
            }
        } else {
            _ = mitBreit(laufSchluessel) { schluessel in
                mitBreit(laufName) { name in RegDeleteKeyValueW(hkcu, schluessel, name) }
            }
        }
    }

    // MARK: Einstellungen, Protokoll

    private func einstellungenLaden() -> Einstellungen {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: ordnerPfad, withIntermediateDirectories: true)
        if !fm.fileExists(atPath: dateiPfad) {
            erstesMal = true
            let vorlage = exeOrdner + "\\einstellungen.json"
            if fm.fileExists(atPath: vorlage) { try? fm.copyItem(atPath: vorlage, toPath: dateiPfad) }
        }
        do {
            return try Einstellungen.laden(von: URL(fileURLWithPath: dateiPfad))
        } catch {
            if fm.fileExists(atPath: dateiPfad) {
                log("Einstellungen fehlerhaft: \(error.localizedDescription)")
                melden("Einstellungen fehlerhaft", "Standardwerte werden verwendet.", immer: true)
            }
            return Einstellungen()
        }
    }

    private func uhrzeit() -> String {
        let format = DateFormatter()
        format.dateFormat = "HH:mm"
        return format.string(from: Date())
    }

    private func log(_ text: String) {
        let format = DateFormatter()
        format.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let zeile = format.string(from: Date()) + " " + text + "\r\n"
        let pfad = ordnerPfad + "\\protokoll.log"
        let fm = FileManager.default
        if !fm.fileExists(atPath: pfad) { _ = fm.createFile(atPath: pfad, contents: nil) }
        if let datei = FileHandle(forWritingAtPath: pfad), let daten = zeile.data(using: .utf8) {
            datei.seekToEndOfFile()
            datei.write(daten)
            datei.closeFile()
        }
    }

    // MARK: Selbstprüfung (für den automatischen Build: --pruefen <bericht.txt>)

    func pruefen() -> Int32 {
        var bericht: [String] = []
        var ergebnis: Int32 = 0
        einstellungen = einstellungenLaden()
        anonymisierer = Anonymisierer(einstellungen: einstellungen)
        fensterErstellen()
        bericht.append("Fenster: " + (fenster != nil ? "ok" : "FEHLER"))
        if fenster == nil { ergebnis = 1 }

        do {
            let k = try KuerzelLeser.lesen(einstellungen.tastenkuerzel)
            let ok = RegisterHotKey(fenster, HOTKEY_ID, UINT(k.windowsModifier), UINT(k.windowsTaste))
            bericht.append("Tastenkürzel \(k.anzeigeWindows): " + (ok ? "ok" : "nicht registriert"))
            if ok { _ = UnregisterHotKey(fenster, HOTKEY_ID) }
        } catch {
            bericht.append("Tastenkürzel: FEHLER \(error.localizedDescription)")
            ergebnis = 1
        }

        let symbolOk = symbolHinzufuegen()
        bericht.append("Symbol im Infobereich: " + (symbolOk ? "ok" : "nicht verfügbar"))
        if symbolOk { aufraeumen() }

        let original = "Hallo Anna Keller\r\nbitte an anna.keller@beispiel.ch schreiben."
        schreiben(original)
        if let gelesen = lesen() {
            let e = anonymisierer.anonymisieren(gelesen)
            schreiben(e.text)
            let zurueck = anonymisierer.zurueckuebersetzen(lesen() ?? "")
            let ok = gelesen == original && !e.text.contains("Keller") && zurueck.text == original
            bericht.append("Zwischenablage: " + (ok ? "ok" : "FEHLER") + " – "
                + e.text.replacingOccurrences(of: "\r\n", with: " / "))
            if !ok { ergebnis = 1 }
        } else {
            bericht.append("Zwischenablage: auf diesem Rechner nicht verfügbar")
            if ergebnis == 0 { ergebnis = 2 }
        }

        let text = bericht.joined(separator: "\r\n") + "\r\n"
        if let index = CommandLine.arguments.firstIndex(of: "--pruefen"), index + 1 < CommandLine.arguments.count {
            try? text.write(toFile: CommandLine.arguments[index + 1], atomically: true, encoding: .utf8)
        }
        return ergebnis
    }
}
#endif

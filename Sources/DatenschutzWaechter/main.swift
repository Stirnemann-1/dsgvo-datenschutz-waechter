// DSGVO Datenschutz Wächter – Start (macOS)

#if os(macOS)
import AppKit

let anwendung = NSApplication.shared
anwendung.setActivationPolicy(.accessory) // kein Dock-Symbol, nur Menüleiste
let waechter = Waechter()
waechter.starten()
anwendung.run()
#else
print("Die Mac-App läuft nur unter macOS. Für Windows: Produkt «DatenschutzWaechterWindows».")
#endif

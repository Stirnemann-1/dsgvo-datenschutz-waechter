// DSGVO Datenschutz Wächter – Start

import AppKit

let anwendung = NSApplication.shared
anwendung.setActivationPolicy(.accessory) // kein Dock-Symbol, nur Menüleiste
let waechter = Waechter()
waechter.starten()
anwendung.run()

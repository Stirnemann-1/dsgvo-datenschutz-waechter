// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Urs Stirnemann – siehe LICENSE und NOTICE

// DSGVO Datenschutz Wächter – Start (Windows)

#if os(Windows)
WindowsWaechter.starten()
#else
print("Die Windows-App läuft nur unter Windows. Für den Mac: Produkt «DatenschutzWaechter».")
#endif

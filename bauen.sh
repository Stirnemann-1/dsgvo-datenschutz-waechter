#!/bin/bash
# DSGVO Datenschutz Wächter (Swift) bauen, testen und installieren.
#   bash bauen.sh
set -euo pipefail
cd "$(dirname "$0")"

NAME="DSGVO Datenschutz Wächter"
ANZEIGE="DSGVO Datenschutz Wächter"
BUNDLE_ID="ch.datenschutz-waechter"
VERSION_NR="$(tr -d '[:space:]' < VERSION)"
LABEL="ch.datenschutz-waechter"
APP="$HOME/Applications/$NAME.app"
SUPPORT="$HOME/Library/Application Support/Datenschutz-Waechter"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/Datenschutz-Waechter.log"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
# Gebaut wird auf der internen Festplatte – externe Laufwerke (exFAT, z.B. Samsung T7)
# vertragen das Signieren von Apps nicht.
BAU="$HOME/Library/Caches/Datenschutz-Waechter-Build"

echo "🛡  DSGVO Datenschutz Wächter (Swift) wird gebaut …"

# --- 1. Entwicklerwerkzeuge ---------------------------------------------------
if ! xcrun --find swift >/dev/null 2>&1; then
  echo "❌ Apples Entwicklerwerkzeuge fehlen."
  echo "   Gleich öffnet sich ein Installationsfenster. Danach dieses Skript nochmals starten."
  xcode-select --install 2>/dev/null || true
  exit 1
fi
echo "   $(swift --version 2>&1 | head -1)"

# --- 2. Kompilieren -----------------------------------------------------------
echo "   Kompiliere (beim ersten Mal ca. 1–2 Minuten) …"
mkdir -p "$BAU"
if ! swift build -c release --scratch-path "$BAU" >build.log 2>&1; then
  echo "❌ Kompilieren fehlgeschlagen. Die Fehler:"
  grep -E "error:" build.log | head -20 || tail -30 build.log
  echo ""
  echo "   Das vollständige Protokoll liegt in: $(pwd)/build.log"
  exit 1
fi
BIN="$(swift build -c release --scratch-path "$BAU" --show-bin-path)"

# --- 3. Selbsttest ------------------------------------------------------------
echo "   Selbsttest …"
if ! "$BIN/Selbsttest"; then
  echo "❌ Selbsttest fehlgeschlagen – die App wird nicht installiert."
  exit 1
fi

# --- 4. App-Paket -------------------------------------------------------------
PAKET="$BAU/paket/$NAME.app"
rm -rf "$BAU/paket"
mkdir -p "$PAKET/Contents/MacOS" "$PAKET/Contents/Resources"
cp "$BIN/DatenschutzWaechter" "$PAKET/Contents/MacOS/DatenschutzWaechter"
cp einstellungen.json "$PAKET/Contents/Resources/einstellungen.json"
cp LICENSE "$PAKET/Contents/Resources/LICENSE.txt"
cp NOTICE "$PAKET/Contents/Resources/NOTICE.txt"
cat > "$PAKET/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>$ANZEIGE</string>
  <key>CFBundleDisplayName</key><string>$ANZEIGE</string>
  <key>CFBundleExecutable</key><string>DatenschutzWaechter</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION_NR</string>
  <key>CFBundleVersion</key><string>$VERSION_NR</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>© 2026 Urs Stirnemann · Apache-Lizenz 2.0 · läuft lokal, ohne Cloud.</string>
</dict>
</plist>
EOF
xattr -cr "$PAKET" 2>/dev/null || true
if ! codesign --force --sign - "$PAKET" 2>codesign.log; then
  echo "❌ Signieren fehlgeschlagen:"
  cat codesign.log
  exit 1
fi

# --- 5. Alte Versionen stoppen (auch die Python-Version) ----------------------
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -f "Datenschutz-Waechter/app.py" 2>/dev/null || true
pkill -x DatenschutzWaechter 2>/dev/null || true
sleep 1

PYTHON_ALT=0
if [ -d "$SUPPORT/venv" ] || [ -f "$SUPPORT/app.py" ]; then
  PYTHON_ALT=1
  echo "   Entferne die Python-Version (Deine Einstellungen bleiben erhalten) …"
  rm -rf "$SUPPORT/venv" "$SUPPORT/__pycache__"
  rm -f "$SUPPORT"/app.py "$SUPPORT"/anonymisierer.py "$SUPPORT"/apple_namen.py \
        "$SUPPORT"/spacy_namen.py "$SUPPORT"/tastenkuerzel.py "$SUPPORT"/einstellungen.vorlage.json
fi

UPDATE=0
[ -d "$APP" ] && UPDATE=1
# Frühere Version unter altem Namen ersetzen
ALT_APP="$HOME/Applications/Datenschutz-Waechter.app"
if [ -d "$ALT_APP" ]; then UPDATE=1; rm -rf "$ALT_APP"; fi

# --- 6. Installieren ----------------------------------------------------------
mkdir -p "$HOME/Applications" "$SUPPORT" "$HOME/Library/LaunchAgents" "$HOME/Library/Logs"
rm -rf "$APP"
cp -R "$PAKET" "$APP"
[ -f "$SUPPORT/einstellungen.json" ] || cp einstellungen.json "$SUPPORT/einstellungen.json"
[ -x "$LSREGISTER" ] && "$LSREGISTER" -f "$APP" >/dev/null 2>&1 || true

if [ "$UPDATE" = 1 ]; then
  # Neue Signatur -> alte Bedienungshilfen-Erlaubnis gilt nicht mehr; sauber zurücksetzen
  tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
fi

# --- 7. Autostart -------------------------------------------------------------
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$APP/Contents/MacOS/DatenschutzWaechter</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict>
  <key>ProcessType</key><string>Interactive</string>
  <key>LimitLoadToSessionType</key><string>Aqua</string>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOF
launchctl bootstrap "gui/$(id -u)" "$PLIST"

echo ""
echo "✅ Fertig! Oben rechts in der Menüleiste erscheint das Schild-Symbol."
echo "   App:           $APP"
echo "   Einstellungen: $SUPPORT/einstellungen.json"
echo "   Protokoll:     $LOG  (enthält nie kopierte Inhalte)"
echo ""
echo "   Beim ersten ⌃⌥V fragt macOS nach den Bedienungshilfen: «DSGVO Datenschutz Wächter» einschalten."
if [ "$PYTHON_ALT" = 1 ]; then
  echo ""
  echo "   ⚠️  Die Python-Version ist entfernt. Bitte in Systemeinstellungen → Datenschutz & Sicherheit"
  echo "      → Bedienungshilfen den Eintrag «Python» ausschalten bzw. mit «–» entfernen."
fi
if [ "$UPDATE" = 1 ]; then
  echo ""
  echo "   ℹ️  Update: Die Bedienungshilfen-Erlaubnis wurde zurückgesetzt und wird beim nächsten ⌃⌥V neu erfragt."
fi

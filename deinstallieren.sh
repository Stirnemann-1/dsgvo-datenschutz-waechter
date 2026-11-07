#!/bin/bash
# DSGVO Datenschutz Wächter stoppen und vollständig entfernen.
LABEL="ch.datenschutz-waechter"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
pkill -x DatenschutzWaechter 2>/dev/null || true
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -rf "$HOME/Applications/Datenschutz-Waechter.app" "$HOME/Applications/DSGVO Datenschutz Wächter.app"
rm -rf "$HOME/Library/Application Support/Datenschutz-Waechter"
rm -f "$HOME/Library/Logs/Datenschutz-Waechter.log"
tccutil reset Accessibility ch.datenschutz-waechter >/dev/null 2>&1 || true
echo "DSGVO Datenschutz Wächter wurde entfernt."

#!/usr/bin/env bash
# Pomodoro Timer Plasmoid Installer
# Author: David A — GNU GPL v2.0
set -euo pipefail

WIDGET_ID="com.pomodoro.timer"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/$WIDGET_ID"
DEST="$HOME/.local/share/plasma/plasmoids/$WIDGET_ID"
ICON_SRC="$SRC/logo.png"
ICON_DEST_DIR="$HOME/.local/share/icons/hicolor/128x128/apps"
ICON_DEST="$ICON_DEST_DIR/$WIDGET_ID.png"

echo "==> Installing Pomodoro Timer plasmoid (v2.0)…"

if [ -d "$DEST" ]; then
    echo "    Removing previous version at $DEST"
    rm -rf "$DEST"
fi

mkdir -p "$DEST"
cp -r "$SRC/"* "$DEST/"
echo "    Installed to $DEST"

if [ -f "$ICON_SRC" ]; then
    mkdir -p "$ICON_DEST_DIR"
    cp "$ICON_SRC" "$ICON_DEST"
    echo "    Installed custom icon to $ICON_DEST"
    kbuildsycoca6 >/dev/null 2>&1 || true
fi

echo "==> Restarting plasmashell…"
kquitapp6 plasmashell 2>/dev/null || kquitapp5 plasmashell 2>/dev/null || true
sleep 1
nohup plasmashell &>/dev/null &
disown

echo ""
echo "✓ Done!"
echo ""
echo "To add the widget:"
echo "  Right-click taskbar → Edit Panel → Add Widgets → search 'Pomodoro Timer'"
echo ""
echo "To configure presets:"
echo "  Right-click the widget → Configure…"
echo ""
echo "Built-in presets: Classic (25/5) and Long Focus (50/10)"

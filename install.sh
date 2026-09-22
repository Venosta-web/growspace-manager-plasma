#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="com.venosta.growspace-manager-plasma"
PACKAGE_DIR="$ROOT/package"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
INSTALLED_DIR="$DATA_HOME/plasma/plasmoids/$PLUGIN_ID"

if [[ ! -f "$PACKAGE_DIR/metadata.json" ]]; then
    echo "Error: $PACKAGE_DIR/metadata.json is missing." >&2
    exit 1
fi

if ! grep -q '"KPackageStructure"[[:space:]]*:[[:space:]]*"Plasma/Applet"' "$PACKAGE_DIR/metadata.json"; then
    echo "Error: source package metadata is not a Plasma/Applet." >&2
    exit 1
fi

if [[ -d "$INSTALLED_DIR" ]]; then
    echo "Removing existing development install:"
    echo "  $INSTALLED_DIR"
    rm -rf -- "$INSTALLED_DIR"
fi

echo "Installing Growspace Manager Plasma widget..."
kpackagetool6 --type Plasma/Applet --install "$PACKAGE_DIR"

echo
echo "Installed: $PLUGIN_ID"
echo "Open Plasma's Add Widgets dialog and add “Growspace Manager”."
echo
echo "Development note: if the widget is already present on the desktop/panel,"
echo "Plasma may keep the old QML instance in memory after an update."
echo "Reload it with: systemctl --user restart plasma-plasmashell.service"

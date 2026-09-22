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

if [[ -d "$INSTALLED_DIR" ]]; then
    if kpackagetool6 --type Plasma/Applet --show "$PLUGIN_ID" >/dev/null 2>&1; then
        echo "Upgrading existing Growspace Manager Plasma widget..."
        kpackagetool6 --type Plasma/Applet --upgrade "$PACKAGE_DIR"
    else
        echo "Removing stale/malformed development install at:"
        echo "  $INSTALLED_DIR"
        rm -rf -- "$INSTALLED_DIR"
        echo "Installing Growspace Manager Plasma widget..."
        kpackagetool6 --type Plasma/Applet --install "$PACKAGE_DIR"
    fi
else
    echo "Installing Growspace Manager Plasma widget..."
    kpackagetool6 --type Plasma/Applet --install "$PACKAGE_DIR"
fi

echo
echo "Installed: $PLUGIN_ID"
echo "Open Plasma's Add Widgets dialog and add “Growspace Manager”."

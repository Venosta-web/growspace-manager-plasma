#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="com.venosta.growspace-manager-plasma"
PACKAGE_DIR="$ROOT/package"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
INSTALLED_DIR="$DATA_HOME/plasma/plasmoids/$PLUGIN_ID"
BUILD_DIR="$ROOT/build/native"
NATIVE_UI_DIR="$PACKAGE_DIR/contents/ui/native"
GENERATED_PLUGIN="$NATIVE_UI_DIR/libgrowspacewalletplugin.so"

cleanup() {
    rm -f -- "$GENERATED_PLUGIN"
}
trap cleanup EXIT

if [[ ! -f "$PACKAGE_DIR/metadata.json" ]]; then
    echo "Error: $PACKAGE_DIR/metadata.json is missing." >&2
    exit 1
fi

if ! grep -q '"KPackageStructure"[[:space:]]*:[[:space:]]*"Plasma/Applet"' "$PACKAGE_DIR/metadata.json"; then
    echo "Error: source package metadata is not a Plasma/Applet." >&2
    exit 1
fi

for command in cmake c++; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Error: '$command' is required to build the KWallet bridge." >&2
        echo "On Kubuntu install the development dependencies documented in README.md." >&2
        exit 1
    fi
done

echo "Building native KWallet bridge..."
cmake -S "$ROOT" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR" --parallel

BUILT_PLUGIN="$(find "$BUILD_DIR" -type f -name 'libgrowspacewalletplugin.so' -print -quit)"
if [[ -z "$BUILT_PLUGIN" ]]; then
    echo "Error: native KWallet plugin was not produced." >&2
    exit 1
fi

mkdir -p "$NATIVE_UI_DIR"
cp -- "$BUILT_PLUGIN" "$GENERATED_PLUGIN"

if [[ -d "$INSTALLED_DIR" ]]; then
    echo "Removing existing development install:"
    echo "  $INSTALLED_DIR"
    rm -rf -- "$INSTALLED_DIR"
fi

echo "Installing Growspace Manager Plasma widget..."
kpackagetool6 --type Plasma/Applet --install "$PACKAGE_DIR"

echo
echo "Installed: $PLUGIN_ID"
echo "The Home Assistant login is shared through KWallet."
echo "Each widget keeps only its own growspace/display settings."
echo
echo "Development note: reload existing widgets with:"
echo "  systemctl --user restart plasma-plasmashell.service"

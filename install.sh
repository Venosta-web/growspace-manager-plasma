#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
BUILD_DIR="$ROOT/build/native"

OVERVIEW_ID="com.venosta.growspace-manager-plasma"
IRRIGATION_ID="com.venosta.growspace-manager-irrigation"

OVERVIEW_PACKAGE="$ROOT/package"
IRRIGATION_PACKAGE="$ROOT/package-irrigation"

OVERVIEW_NATIVE="$OVERVIEW_PACKAGE/contents/ui/native/libgrowspacewalletplugin.so"
IRRIGATION_NATIVE="$IRRIGATION_PACKAGE/contents/ui/native/libgrowspacewalletplugin.so"

cleanup() {
    rm -f -- "$OVERVIEW_NATIVE" "$IRRIGATION_NATIVE"
}
trap cleanup EXIT

for package_dir in "$OVERVIEW_PACKAGE" "$IRRIGATION_PACKAGE"; do
    if [[ ! -f "$package_dir/metadata.json" ]]; then
        echo "Error: $package_dir/metadata.json is missing." >&2
        exit 1
    fi

    if ! grep -q '"KPackageStructure"[[:space:]]*:[[:space:]]*"Plasma/Applet"' "$package_dir/metadata.json"; then
        echo "Error: $package_dir is not a Plasma/Applet package." >&2
        exit 1
    fi
done

for command in cmake c++; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "Error: '$command' is required to build the KWallet bridge." >&2
        echo "Install the development dependencies documented in README.md." >&2
        exit 1
    fi
done

echo "Building shared native KWallet bridge..."
cmake -S "$ROOT" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR" --parallel

BUILT_PLUGIN="$(find "$BUILD_DIR" -type f -name 'libgrowspacewalletplugin.so' -print -quit)"
if [[ -z "$BUILT_PLUGIN" ]]; then
    echo "Error: native KWallet plugin was not produced." >&2
    exit 1
fi

mkdir -p "$(dirname "$OVERVIEW_NATIVE")" "$(dirname "$IRRIGATION_NATIVE")"
cp -- "$BUILT_PLUGIN" "$OVERVIEW_NATIVE"
cp -- "$BUILT_PLUGIN" "$IRRIGATION_NATIVE"

install_widget() {
    local plugin_id="$1"
    local package_dir="$2"
    local installed_dir="$DATA_HOME/plasma/plasmoids/$plugin_id"

    if [[ -d "$installed_dir" ]]; then
        echo "Removing existing development install:"
        echo "  $installed_dir"
        rm -rf -- "$installed_dir"
    fi

    echo "Installing $plugin_id..."
    kpackagetool6 --type Plasma/Applet --install "$package_dir"
}

install_widget "$OVERVIEW_ID" "$OVERVIEW_PACKAGE"
install_widget "$IRRIGATION_ID" "$IRRIGATION_PACKAGE"

echo
echo "Installed:"
echo "  $OVERVIEW_ID"
echo "  $IRRIGATION_ID"
echo
echo "Both widgets reuse the same Home Assistant credentials from KWallet."
echo
echo "Reload existing widgets with:"
echo "  systemctl --user restart plasma-plasmashell.service"

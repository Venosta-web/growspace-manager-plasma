#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v apt-get >/dev/null 2>&1; then
    echo "This bootstrap installer is intended for Kubuntu/Ubuntu-based Plasma systems." >&2
    echo "For other distributions, install the dependencies listed in README.md and run ./install.sh." >&2
    exit 1
fi

if [[ "$EUID" -eq 0 ]]; then
    SUDO=""
elif command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
else
    echo "sudo is required to install build dependencies." >&2
    exit 1
fi

echo "Installing Growspace Manager Plasma dependencies..."
$SUDO apt-get update
$SUDO apt-get install -y \
    build-essential \
    cmake \
    extra-cmake-modules \
    qt6-base-dev \
    qt6-declarative-dev \
    qml6-module-qtwebsockets \
    libkf6wallet-dev \
    libkf6package-tools

echo
echo "Building and installing Growspace Manager Plasma..."
chmod +x "$ROOT/install.sh"
"$ROOT/install.sh"

echo
echo "Reloading Plasma..."
if systemctl --user restart plasma-plasmashell.service; then
    echo "Plasma reloaded."
else
    echo "Widgets are installed, but Plasma could not be reloaded automatically."
    echo "Log out/in or restart plasmashell manually."
fi

echo
echo "Installation complete."
echo "Open Plasma's Add Widgets dialog and search for 'Growspace Manager'."

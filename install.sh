#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if kpackagetool6 --type Plasma/Applet --show com.venosta.growspace-manager-plasma >/dev/null 2>&1; then
    kpackagetool6 --type Plasma/Applet --upgrade "$ROOT/package"
else
    kpackagetool6 --type Plasma/Applet --install "$ROOT/package"
fi

echo "Growspace Manager Plasma installed. Open Plasma's Add Widgets dialog to add it."

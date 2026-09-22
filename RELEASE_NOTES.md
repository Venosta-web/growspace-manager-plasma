# Growspace Manager Plasma v0.6.0

First packaged public release of the Growspace Manager Plasma 6 widget suite.

## Included widgets

### Growspace Manager
- Live temperature, humidity, VPD, plant and stage overview
- Growspace selection by user-facing name
- Shared Home Assistant credentials through KDE KWallet
- Live grow-light, exhaust, circulation, humidifier and dehumidifier status
- Native On/Off, 0–10 and 0–100% actuator readings
- Grow-room-specific device icons and active fan animation
- Sensor-backed animated irrigation tank visualization
- Contextual VPD state
- Responsive Plasma desktop/panel layout

### Growspace Manager Irrigation
- 5-minute VWC crop-steering history
- Pore EC / Bulk EC support
- P0 / P1 / P2 / P3 phase strip
- Target VWC and dryback guides
- Scheduled irrigation-shot markers
- Lights-on-anchored timeline
- Pump / next-cycle context

### Growspace Manager History
- User-selectable growspace and metric
- Dynamic metric discovery from Growspace Manager + Home Assistant
- 24-hour history graphs
- Continuous and binary/step traces
- Semantic Optimal / Warning / Danger coloring
- Context bands, safety limits and controller setpoints
- Day/night-aware VPD context
- Current / min / max values and hover inspection

## Installation

On Kubuntu / Ubuntu-based Plasma 6 systems:

```bash
tmp="$(mktemp -d)"
cd "$tmp"
curl -fL https://github.com/Venosta-web/growspace-manager-plasma/releases/latest/download/growspace-manager-plasma.tar.gz -o growspace-manager-plasma.tar.gz
tar -xzf growspace-manager-plasma.tar.gz
cd growspace-manager-plasma
bash install-kubuntu.sh
```

The installer builds the small KF6/KWallet bridge locally and installs all three widgets.

## Requirements

- KDE Plasma 6
- KDE KWallet
- Home Assistant
- Growspace Manager custom integration
- Home Assistant long-lived access token

See README.md for full setup and troubleshooting.

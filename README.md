# Growspace Manager Plasma

A native **KDE Plasma 6 widget suite** for [Growspace Manager](https://github.com/Venosta-web/growspace_manager), bringing live Home Assistant growspace data, irrigation/crop-steering data, and metric history directly onto the Plasma desktop.

**Current release: v0.6.0**

The project installs three independent Plasma widgets:

| Widget | Purpose |
| --- | --- |
| **Growspace Manager** | Compact live growspace dashboard |
| **Growspace Manager Irrigation** | VWC / crop-steering irrigation chart |
| **Growspace Manager History** | Configurable 24-hour graph for any supported metric |

All three widgets share one Home Assistant login through **KDE KWallet** while keeping their own growspace/metric configuration.

## Highlights

### Growspace Manager

The main overview widget provides a compact grow-room dashboard with:

- growspace name, stage and week
- temperature, humidity, VPD and plant count
- contextual VPD state such as Optimal / Warning / Danger
- automatic day/night state
- live grow-light, exhaust, circulation, humidifier and dehumidifier status
- native device values: On/Off, 0–10 controller intensity, or 0–100%
- custom grow-room device icons and active fan animation
- irrigation status when an irrigation pump is configured
- sensor-backed irrigation tanks only when a tank level sensor exists
- animated tank level, capacity, low-water threshold and depletion information
- automatic growspace discovery by user-facing name
- responsive desktop/panel layout

### Growspace Manager Irrigation

A dedicated crop-steering widget based on the same data model as the Growspace Manager Lovelace card:

- measured VWC history from `growspace_manager/get_crop_steering_history`
- 5-minute history buckets
- lights-on-anchored 24-hour timeline
- Target VWC and P2 dryback guides
- optional Pore EC and Bulk EC traces
- P0 Activation / P1 Saturation / P2 Maintenance / P3 Dryback phase strip
- scheduled irrigation-shot markers
- measured VWC-based P1 → P2 transition
- backend `phase_changed_at` support for an early P3 transition
- current VWC, pump state, next cycle and EC values

### Growspace Manager History

A reusable graph widget for the last 24 hours:

- select a growspace by its normal user-facing name
- dynamically discover only metrics actually configured for that growspace
- distinguish multiple sensors using Home Assistant friendly names
- retrieve history with `growspace_manager/get_history_stats`
- continuous line graphs and binary/step graphs
- current, minimum and maximum values
- hover timestamp/value tooltips
- contextual target bands and controller setpoints
- semantic history coloring: Optimal / Warning / Danger
- day/night-aware VPD ranges using historical light state when available
- subtle warning/danger animations

Supported metrics depend on the growspace configuration and can include temperature, humidity, VPD, CO₂, soil moisture, tank level, exhaust/circulation speed, humidifier/dehumidifier state, substrate temperature, pH, EC sensors, power, energy, drain volume and irrigation flow.

## Requirements

- KDE Plasma 6
- KDE KWallet
- Home Assistant with the Growspace Manager custom integration installed
- a Home Assistant long-lived access token
- Qt 6 / KDE Frameworks 6 build dependencies for the small bundled KWallet bridge

The native bridge is compiled **locally on the user's machine** and bundled inside each plasmoid. Nothing is installed as a custom system-wide QML module.

## Quick install — Kubuntu / Ubuntu-based Plasma

Download the latest release bundle and run the bootstrap installer:

```bash
tmp="$(mktemp -d)"
cd "$tmp"
curl -fL https://github.com/Venosta-web/growspace-manager-plasma/releases/latest/download/growspace-manager-plasma.tar.gz -o growspace-manager-plasma.tar.gz
tar -xzf growspace-manager-plasma.tar.gz
cd growspace-manager-plasma
bash install-kubuntu.sh
```

The bootstrap script installs the required packages with APT, builds the KWallet bridge, installs all three widgets, and reloads Plasma.

After installation:

1. Right-click the Plasma desktop or panel.
2. Choose **Add Widgets…**
3. Add **Growspace Manager**.
4. Open its settings.
5. Enter the Home Assistant URL and a long-lived access token once.
6. Select the growspace by name.
7. Add the Irrigation and History widgets as desired; they reuse the same KWallet login automatically.

## Manual install

### Kubuntu dependencies

```bash
sudo apt update
sudo apt install \
  build-essential cmake extra-cmake-modules \
  qt6-base-dev qt6-declarative-dev qml6-module-qtwebsockets \
  libkf6wallet-dev kpackagetool6
```

Then install:

```bash
./install.sh
systemctl --user restart plasma-plasmashell.service
```

For development from Git:

```bash
git clone https://github.com/Venosta-web/growspace-manager-plasma.git
cd growspace-manager-plasma
bash install-kubuntu.sh
```

To update a Git checkout later:

```bash
git pull
./install.sh
systemctl --user restart plasma-plasmashell.service
```

## Shared KWallet login

The Home Assistant URL and long-lived access token are stored in the user's KDE network wallet:

```text
Folder: Growspace Manager Plasma
Entry:  homeassistant
```

Credentials are shared across every Growspace Manager Plasma widget instance. Per-widget Plasma configuration stores only things such as:

- selected growspace ID
- selected history metric/entity
- refresh interval
- display/connection preferences

Existing early-development installs containing a plaintext token are migrated to KWallet when possible and the old per-widget credential is cleared after a successful KWallet write.

## Home Assistant APIs used

The widgets intentionally remain frontends. Grow logic, automation, target calculations and data modelling stay in Growspace Manager.

The suite currently consumes:

```text
growspace_manager/get_data
growspace_manager/get_crop_steering_history
growspace_manager/get_history_stats
```

It also uses Home Assistant's native WebSocket `get_states` command for live device/entity display values.

## Release bundles

Each GitHub release contains:

- `growspace-manager-plasma.tar.gz`
- `growspace-manager-plasma.zip`
- `SHA256SUMS`

The bundle contains the complete source required to build the small KWallet bridge locally and install all three widgets.

GitHub's automatically generated source archives are also available, but the named release bundle is recommended because the README install command always points to the latest release.

## Project layout

```text
package/             Main Growspace Manager widget
package-irrigation/  Irrigation / crop-steering widget
package-history/     Configurable 24-hour history widget
native/              Shared KF6/KWallet QML bridge source
install.sh           Build + install all widgets
install-kubuntu.sh   Install Kubuntu dependencies + run install.sh
```

## Troubleshooting

### Widget does not appear after updating

Reload Plasma:

```bash
systemctl --user restart plasma-plasmashell.service
```

### KWallet prompt

The first widget may ask to unlock or authorize the KDE wallet. This is expected. Once credentials are stored, the other Growspace Manager widgets reuse them.

### Build fails because a command or dependency is missing

On Kubuntu, rerun:

```bash
bash install-kubuntu.sh
```

### Home Assistant connects but no growspaces appear

Confirm the Growspace Manager integration is installed and that the configured token can access Home Assistant's WebSocket API.

## Security

- Home Assistant credentials are stored in KDE KWallet rather than normal Plasma widget configuration.
- The repository does not ship precompiled KWallet bridge binaries.
- Release bundles contain source; the native bridge is built locally against the user's installed Qt/KF6 libraries.

## License

MIT

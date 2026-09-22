# Growspace Manager Plasma

Native KDE Plasma 6 widget for [Growspace Manager](https://github.com/Venosta-web/growspace_manager), showing live Home Assistant growspace data directly on the Kubuntu desktop or panel.

## Current status

The first functional development build is implemented.

It can:

- authenticate against Home Assistant over its native WebSocket API
- call `growspace_manager/get_data`
- select a configured growspace, or automatically use the first available growspace
- show temperature, humidity, VPD, plant count, stage/week, day/night state and irrigation information
- show live connection/authentication/error state
- refresh automatically on a configurable interval
- render as both a compact Plasma panel widget and an expanded desktop/popup widget

## Requirements

- KDE Plasma 6
- Growspace Manager installed in Home Assistant
- a Home Assistant long-lived access token
- Qt WebSockets QML support

On Kubuntu/Ubuntu, install the QML WebSocket module if it is not already present:

```bash
sudo apt install qml6-module-qtwebsockets
```

## Install during development

Clone the repository and run:

```bash
chmod +x install.sh
./install.sh
```

Or install manually:

```bash
kpackagetool6 --type Plasma/Applet --install package
```

To update an existing development install:

```bash
kpackagetool6 --type Plasma/Applet --upgrade package
```

Then open Plasma's widget picker and add **Growspace Manager**.

## Configuration

Right-click the widget and open **Configure Growspace Manager…**.

Enter:

1. **Home Assistant URL** — for example `http://homeassistant.local:8123`
2. **Long-lived access token**
3. **Growspace ID** — optional; leave blank to use the first growspace returned by Growspace Manager
4. **Refresh interval**

The widget converts the Home Assistant HTTP(S) URL to the corresponding `ws://` or `wss://` WebSocket endpoint automatically.

## Security note

The development build stores the Home Assistant access token in the local Plasma widget configuration. It is never committed to this repository, but the local storage is **not encrypted**.

KWallet-backed credential storage is the next security milestone before a stable release.

## Data source

Growspace Manager already exposes the required structured data via:

```text
growspace_manager/get_data
```

The Plasma widget intentionally remains a frontend. Grow logic, automation and data modelling stay inside the Home Assistant integration.

## Next milestones

- KWallet credential storage
- automatic growspace picker populated from the API
- Growspace Manager alert display
- Home Assistant event-driven refresh in addition to periodic polling
- Rootforge/Growspace Manager branded visual treatment
- quick actions for supported Growspace Manager services
- packaging/release automation

## License

MIT

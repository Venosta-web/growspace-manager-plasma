# Growspace Manager Plasma

Native KDE Plasma 6 widget for [Growspace Manager](https://github.com/Venosta-web/growspace_manager), showing live Home Assistant growspace data directly on the Kubuntu desktop or panel.

## Current status

v0.2 adds shared, encrypted Home Assistant credentials through KDE KWallet.

The widget can:

- authenticate against Home Assistant over its native WebSocket API
- call `growspace_manager/get_data`
- share one Home Assistant URL/token securely across every widget instance
- keep each widget's growspace selection and refresh settings independent
- migrate the old per-widget plaintext token into KWallet on first launch
- select a configured growspace, or automatically use the first available growspace
- show temperature, humidity, VPD, plant count, stage/week, day/night state and irrigation information
- show live connection/authentication/error state
- refresh automatically on a configurable interval
- render as both a compact Plasma panel widget and an expanded desktop/popup widget

## Requirements

Runtime:

- KDE Plasma 6
- KDE KWallet
- Growspace Manager installed in Home Assistant
- Qt WebSockets QML support

Development/install dependencies on Kubuntu:

```bash
sudo apt install \
  build-essential cmake extra-cmake-modules \
  qt6-base-dev qt6-declarative-dev qml6-module-qtwebsockets \
  libkf6wallet-dev
```

The installer compiles a very small native KF6 bridge and bundles it inside the plasmoid. No system-wide custom QML module is installed.

## Install during development

```bash
git pull
./install.sh
systemctl --user restart plasma-plasmashell.service
```

Then add **Growspace Manager** from Plasma's widget picker.

## Shared KWallet login

The Home Assistant URL and long-lived token live in the user's KDE network wallet under:

```text
Folder: Growspace Manager Plasma
Entry:  homeassistant
```

They are shared by every Growspace Manager plasmoid instance.

Per-widget configuration contains only:

- Growspace ID
- refresh interval
- auto-connect/display behavior

### Migration from v0.1

If an existing widget still has the old plaintext token in its Plasma configuration, v0.2 does this automatically:

1. opens KWallet
2. writes the Home Assistant URL and token to the shared KWallet entry
3. waits for KWallet to confirm the write
4. clears the old `accessToken` and `haUrl` values from that widget's Plasma config
5. reconnects using the KWallet credential

A second widget can therefore be added without pasting the token again.

## Data source

Growspace Manager already exposes the required structured data via:

```text
growspace_manager/get_data
```

The Plasma widget intentionally remains a frontend. Grow logic, automation and data modelling stay inside the Home Assistant integration.

## Next milestones

- growspace selector populated automatically from the API
- Growspace Manager alert display
- Home Assistant event-driven refresh in addition to periodic polling
- Rootforge/Growspace Manager branded visual treatment
- quick actions for supported Growspace Manager services
- packaging/release automation

## License

MIT

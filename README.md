# Growspace Manager Plasma

Native KDE Plasma 6 widget for [Growspace Manager](https://github.com/Venosta-web/growspace_manager), showing live Home Assistant growspace data directly on the Kubuntu desktop or panel.

## Current status

v0.2 adds shared, encrypted Home Assistant credentials through KDE KWallet.

The widget can:

- authenticate against Home Assistant over its native WebSocket API
- call `growspace_manager/get_data`
- share one Home Assistant URL/token securely across every widget instance
- keep each widget's growspace selection and refresh settings independent
- fetch available growspaces directly from Growspace Manager and show their user-facing names in a selector
- migrate the old per-widget plaintext token into KWallet on first launch
- select a configured growspace, or automatically use the first available growspace
- show temperature, humidity, VPD, plant count, stage/week, day/night state and irrigation information
- automatically show sensor-backed irrigation tanks with animated liquid level, low-level warnings, capacity, depletion state and estimated time remaining
- show compact live actuator chips for configured lights, exhaust, circulation, humidification and dehumidification devices, preserving native On/Off, 0–10, or 0–100% readings
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

- selected growspace (stored internally by ID, shown in the UI by its user-facing name)
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

- Growspace Manager alert display
- Home Assistant event-driven refresh in addition to periodic polling
- Rootforge/Growspace Manager branded visual treatment
- quick actions for supported Growspace Manager services
- packaging/release automation

## License

MIT


## Growspace Manager Irrigation widget

The repository also contains a second Plasma applet:

```text
Growspace Manager Irrigation
com.venosta.growspace-manager-irrigation
```

It uses the same shared KWallet Home Assistant login as the overview widget, but keeps its own growspace selection.

The chart mirrors the Growspace Manager Lovelace crop-steering data flow:

- fetches growspace context with `growspace_manager/get_data`
- fetches measured irrigation history with `growspace_manager/get_crop_steering_history`
- plots the 5-minute VWC buckets across the same lights-on-anchored day used by the Lovelace crop-steering chart
- overlays Target VWC and the P2 maintenance dryback threshold
- optionally plots Pore EC and Bulk EC when those sensors are configured
- shows current VWC, irrigation pump state, next cycle, and latest EC values
- renders the P0/P1/P2/P3 crop-steering phase strip using the same boundaries as the Lovelace card
- renders scheduled irrigation-shot markers on the same 24-hour timeline, dimming shots that are already in the past
- derives the P1→P2 saturation boundary from the measured VWC history and honors an actual early P3 `phase_changed_at` boundary when supplied by the backend

Both applets are installed by `./install.sh`.

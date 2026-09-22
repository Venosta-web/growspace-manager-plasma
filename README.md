# Growspace Manager Plasma

Native KDE Plasma 6 widget for [Growspace Manager](https://github.com/Venosta-web/growspace_manager), showing live Home Assistant growspace data directly on the Kubuntu desktop or panel.

## Planned features

- Native Plasma 6 / QML widget
- Compact panel and full desktop views
- Direct Home Assistant WebSocket connection
- Growspace selection
- Temperature, RH, VPD, plant count, irrigation and alert status
- Rootforge / Growspace Manager visual styling
- Secure credential storage via KWallet
- Optional quick actions for Growspace Manager / Home Assistant services

## Data source

The widget is designed to use Growspace Manager's existing Home Assistant WebSocket API, including:

```text
growspace_manager/get_data
```

This keeps grow logic in the Home Assistant integration and makes the Plasma widget a lightweight frontend.

## Development status

Early scaffold / prototype.

## Install during development

```bash
kpackagetool6 --type Plasma/Applet --install package
```

To update an existing development install:

```bash
kpackagetool6 --type Plasma/Applet --upgrade package
```

Then add **Growspace Manager** from Plasma's widget picker.

## License

MIT

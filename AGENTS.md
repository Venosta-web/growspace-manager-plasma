# AGENTS.md

## Project goal
Build a native KDE Plasma 6 frontend for Growspace Manager.

## Architecture
- UI: QML / QtQuick / Plasma Components
- Backend: Home Assistant WebSocket API
- Primary Growspace Manager command: `growspace_manager/get_data`
- Do not duplicate grow-control logic already implemented in Growspace Manager.
- Keep Home Assistant credentials out of source control.
- Target secure credential storage through KWallet.

## UX targets
- Compact panel representation
- Small desktop card
- Large multi-growspace dashboard
- Expanded details / quick actions
- Match Rootforge / Growspace Manager visual identity without sacrificing Plasma theme compatibility

# AGENTS.md

## Project goal

Build a native KDE Plasma 6 frontend for Growspace Manager.

## Architecture

- UI: QML / QtQuick / Plasma Components / Kirigami
- Transport: Qt WebSockets QML module
- Backend: Home Assistant WebSocket API
- Primary Growspace Manager command: `growspace_manager/get_data`
- Do not duplicate grow-control logic already implemented in Growspace Manager.
- Do not commit Home Assistant credentials or test tokens.
- The current development build stores the token in Plasma configuration; migrate this to KWallet before stable release.

## Current wire fields used

The `growspace_manager/get_data` response is a collection keyed by growspace ID.

The first UI uses:

- `identity.growspace_id`
- `identity.name`
- `identity.type`
- `grid.total_plants`
- `environment.temperature`
- `environment.humidity`
- `environment.vpd`
- `environment.irrigation_pump_state`
- `metrics.vpd_status`
- `metrics.granular_stage`
- `metrics.is_day`
- `metrics.veg_week`
- `metrics.flower_week`
- `metrics.dry_week`
- `metrics.cure_week`
- `irrigation.next_scheduled_cycle`

Prefer backend-owned values rather than deriving duplicate grow logic in QML.

## UX targets

- compact panel representation
- small desktop card
- large multi-growspace dashboard
- expanded details / quick actions
- match Rootforge / Growspace Manager visual identity without sacrificing Plasma theme compatibility
- graceful handling of unavailable sensors, bad auth, offline Home Assistant and missing growspaces

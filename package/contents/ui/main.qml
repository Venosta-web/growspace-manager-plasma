import QtQuick
import QtQuick.Layouts
import QtWebSockets
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import "native" as NativeWallet

PlasmoidItem {
    id: root

    implicitWidth: 430
    implicitHeight: 286
        + (deviceChips.length > 0 ? 34 : 0)
        + (hasIrrigationPump ? 32 : 0)
        + (sensorTanks.length > 0
            ? 122 * Math.ceil(sensorTanks.length / (width >= 390 ? 2 : 1))
            : 0)
    preferredRepresentation: fullRepresentation

    property bool authenticated: false
    property bool loading: false
    property bool walletLoaded: false
    property string connectionState: i18n("Loading KWallet…")
    property string errorMessage: ""
    property var collection: ({})
    property var growspace: null
    property string selectedGrowspaceId: ""
    property int nextMessageId: 1
    property int dataRequestId: 0
    property int statesRequestId: 0
    property var hassStates: ({})
    property string lastUpdated: ""

    readonly property string defaultHaUrl: "http://homeassistant.local:8123"
    property string haUrl: wallet.url.length > 0 ? wallet.url : defaultHaUrl
    property string accessToken: wallet.token
    property string legacyHaUrl: String(plasmoid.configuration.haUrl || "").trim()
    property string legacyAccessToken: String(plasmoid.configuration.accessToken || "").trim()
    property string configuredGrowspaceId: String(plasmoid.configuration.growspaceId || "").trim()
    property int refreshSeconds: Math.max(10, plasmoid.configuration.refreshInterval || 30)
    property bool autoConnect: plasmoid.configuration.autoConnect
    property bool configured: walletLoaded && wallet.hasCredentials
    property bool shouldConnect: configured && autoConnect
    property string wsUrl: websocketUrl(haUrl)

    property string growspaceName: valueAt(growspace, ["identity", "name"], selectedGrowspaceId || i18n("Growspace"))
    property string temperatureText: formatNumber(valueAt(growspace, ["environment", "temperature"], null), 1, " °C")
    property string humidityText: formatNumber(valueAt(growspace, ["environment", "humidity"], null), 0, " %")
    property string vpdText: formatNumber(valueAt(growspace, ["environment", "vpd"], null), 2, " kPa")
    property string plantCountText: String(valueAt(growspace, ["grid", "total_plants"], 0))
    property string vpdStatusText: displayText(valueAt(growspace, ["metrics", "vpd_status"], "unknown"))
    property string stageText: displayText(valueAt(growspace, ["metrics", "granular_stage"], valueAt(growspace, ["identity", "type"], "unknown")))
    property string periodText: valueAt(growspace, ["metrics", "is_day"], false) ? i18n("Day") : i18n("Night")
    property string irrigationPumpEntity: String(valueAt(growspace, ["irrigation", "irrigation_config", "irrigation_pump_entity"], "") || "").trim()
    property bool hasIrrigationPump: irrigationPumpEntity.length > 0
    property string irrigationText: displayText(valueAt(growspace, ["environment", "irrigation_pump_state"], "unknown"))
    property string nextIrrigationText: formatSchedule(valueAt(growspace, ["irrigation", "next_scheduled_cycle"], null))
    property string stageWeekText: stageWeek()
    property var irrigationTanks: valueAt(growspace, ["environment", "irrigation_tanks"], [])
    property var sensorTanks: filteredSensorTanks()
    property int lowTankCount: warningTankCount()
    property var deviceChips: buildDeviceChips()

    Plasmoid.title: i18n("Growspace Manager")
    Plasmoid.icon: "view-statistics"

    NativeWallet.WalletStore {
        id: wallet

        onLoadFinished: function(success) {
            root.walletLoaded = success

            if (!success) {
                root.connectionState = i18n("KWallet error")
                root.errorMessage = wallet.errorString
                return
            }

            if (!wallet.hasCredentials && root.legacyAccessToken.length > 0) {
                root.connectionState = i18n("Migrating login to KWallet…")
                var migrationUrl = root.legacyHaUrl.length > 0
                    ? root.legacyHaUrl
                    : root.defaultHaUrl
                wallet.saveCredentials(migrationUrl, root.legacyAccessToken)
                return
            }

            root.reconnect(50)
        }

        onSaveFinished: function(success) {
            if (!success) {
                root.walletLoaded = false
                root.connectionState = i18n("KWallet error")
                root.errorMessage = wallet.errorString
                return
            }

            root.walletLoaded = true

            // One-time migration cleanup: after KWallet confirms the write,
            // remove the old plaintext values from this plasmoid instance.
            if (root.legacyAccessToken.length > 0) {
                plasmoid.configuration.accessToken = ""
                plasmoid.configuration.haUrl = ""
            }

            root.errorMessage = ""
            root.reconnect(50)
        }

        onClearFinished: function(success) {
            if (success) {
                root.authenticated = false
                root.collection = ({})
                root.growspace = null
                root.selectedGrowspaceId = ""
                root.connectionState = i18n("Not configured")
                root.errorMessage = ""
                socket.active = false
            } else {
                root.errorMessage = wallet.errorString
            }
        }
    }

    Component.onCompleted: wallet.load()

    function websocketUrl(baseUrl) {
        var base = (baseUrl || "").trim()
        if (!base)
            return ""

        while (base.endsWith("/"))
            base = base.slice(0, -1)

        if (base.startsWith("https://"))
            base = "wss://" + base.slice(8)
        else if (base.startsWith("http://"))
            base = "ws://" + base.slice(7)
        else if (!base.startsWith("ws://") && !base.startsWith("wss://"))
            base = "ws://" + base

        if (!base.endsWith("/api/websocket"))
            base += "/api/websocket"

        return base
    }

    function valueAt(object, path, fallback) {
        var current = object
        for (var i = 0; i < path.length; ++i) {
            if (current === null || current === undefined || typeof current !== "object")
                return fallback
            if (!(path[i] in current))
                return fallback
            current = current[path[i]]
        }
        return current === null || current === undefined ? fallback : current
    }

    function formatNumber(value, decimals, suffix) {
        if (value === null || value === undefined || value === "" || value === "unknown" || value === "unavailable")
            return "—"

        var number = Number(value)
        if (isNaN(number))
            return String(value)

        return number.toFixed(decimals) + suffix
    }

    function displayText(value) {
        if (value === null || value === undefined || value === "" || value === "unknown" || value === "unavailable")
            return "—"

        var words = String(value).replace(/_/g, " ").split(" ")
        for (var i = 0; i < words.length; ++i) {
            if (words[i].length > 0)
                words[i] = words[i].charAt(0).toUpperCase() + words[i].slice(1)
        }
        return words.join(" ")
    }

    function filteredSensorTanks() {
        var tanks = irrigationTanks || []
        var result = []
        for (var i = 0; i < tanks.length; ++i) {
            var tank = tanks[i]
            if (!tank)
                continue
            var entity = String(tank.sensor_entity || "").trim()
            if (entity.length > 0)
                result.push(tank)
        }
        return result
    }

    function warningTankCount() {
        var count = 0
        var tanks = sensorTanks || []
        for (var i = 0; i < tanks.length; ++i) {
            if (tanks[i] && tanks[i].is_warning === true)
                count++
        }
        return count
    }

    function arrayAt(path) {
        var value = valueAt(growspace, path, [])
        return Array.isArray(value) ? value : []
    }

    function bundleEntityIds(path, key) {
        var bundles = arrayAt(path)
        var result = []
        for (var i = 0; i < bundles.length; ++i) {
            var id = String((bundles[i] || {})[key] || "").trim()
            if (id.length > 0)
                result.push(id)
        }
        return result
    }

    function concatUnique(a, b) {
        var result = []
        var seen = ({})
        var lists = [a || [], b || []]
        for (var l = 0; l < lists.length; ++l) {
            for (var i = 0; i < lists[l].length; ++i) {
                var id = String(lists[l][i] || "").trim()
                if (id.length > 0 && !seen[id]) {
                    seen[id] = true
                    result.push(id)
                }
            }
        }
        return result
    }

    function stateFor(entityId) {
        return hassStates && hassStates[entityId] ? hassStates[entityId] : null
    }

    function normalizeBinary(entity) {
        if (!entity || entity.state === "unknown" || entity.state === "unavailable")
            return "—"
        if (entity.state === "on")
            return "On"
        if (entity.state === "off")
            return "Off"
        var n = Number(entity.state)
        if (!isNaN(n))
            return n > 0 ? "On" : "Off"
        return displayText(entity.state)
    }

    function normalizeLight(entity, entityId) {
        if (!entity || entity.state === "unknown" || entity.state === "unavailable")
            return "—"

        var attrs = entity.attributes || ({})
        var unit = String(attrs.unit_of_measurement || "")

        if (unit === "%") {
            var pct = Number(entity.state)
            return isNaN(pct) ? "—" : Math.round(pct) + "%"
        }

        // Dimmable light entities can retain their last brightness while off.
        // The actual on/off state wins so an off grow light never looks active.
        if (entity.state === "off") {
            if (attrs.supported_color_modes !== undefined || attrs.brightness !== undefined)
                return "0%"
            return "Off"
        }

        if (attrs.brightness !== undefined && attrs.brightness !== null) {
            var brightness = Number(attrs.brightness)
            if (!isNaN(brightness))
                return Math.round(brightness / 255 * 100) + "%"
        }

        if (entity.state === "on")
            return "On"

        var n = Number(entity.state)
        if (!isNaN(n))
            return String(Math.round(n))

        return displayText(entity.state)
    }

    function normalizeFan(entity, entityId) {
        if (!entity || entity.state === "unknown" || entity.state === "unavailable")
            return "—"

        var domain = String(entityId || "").split(".")[0]
        var attrs = entity.attributes || ({})

        if (domain === "fan") {
            if (entity.state === "off")
                return "Off"
            var pct = Number(attrs.percentage)
            if (!isNaN(pct))
                return Math.round(pct) + "%"
            return "On"
        }

        var n = Number(entity.state)
        if (!isNaN(n)) {
            if (domain === "switch" || domain === "input_boolean" || domain === "binary_sensor")
                return n > 0 ? "On" : "Off"

            var unit = String(attrs.unit_of_measurement || "")
            if (unit === "%" || n > 10)
                return Math.round(n) + "%"
            return String(Math.round(n))
        }

        if (entity.state === "on")
            return "On"
        if (entity.state === "off")
            return "Off"
        return displayText(entity.state)
    }

    function normalizeClimate(entity) {
        if (!entity || entity.state === "unknown" || entity.state === "unavailable")
            return "—"

        var attrs = entity.attributes || ({})
        if (entity.state === "off")
            return "Off"

        var pct = Number(attrs.percentage)
        if (!isNaN(pct))
            return Math.round(pct) + "%"

        return displayText(entity.state)
    }

    function aggregateDevice(entityIds, normalizer) {
        if (!entityIds || entityIds.length === 0)
            return ({ "configured": false, "value": "—", "active": false })

        var values = []
        var active = false
        for (var i = 0; i < entityIds.length; ++i) {
            var entity = stateFor(entityIds[i])
            var value = normalizer(entity, entityIds[i])
            values.push(value)
            if (value !== "Off" && value !== "0" && value !== "0%" && value !== "—")
                active = true
        }

        var unique = []
        for (var j = 0; j < values.length; ++j) {
            if (unique.indexOf(values[j]) < 0)
                unique.push(values[j])
        }

        var display = unique.length === 1
            ? unique[0]
            : unique.slice(0, 3).join(" / ")

        if (unique.length > 3)
            display += "…"

        return ({
            "configured": true,
            "value": display,
            "active": active
        })
    }

    function buildDeviceChips() {
        if (!growspace)
            return []

        var env = valueAt(growspace, ["environment"], ({}))
        var chips = []

        // Match the Lovelace DeviceState resolver: existing growspaces often
        // use light_sensors/light_sensor for the actual light entity as well as
        // day/night detection. Newer configs may additionally use
        // growlight_entities. Keep AC Infinity power entities as a Plasma-side
        // fallback because their grow-light bundle has no fan-style readback.
        var lightIds = concatUnique(
            env.light_sensors || (env.light_sensor ? [env.light_sensor] : []),
            env.growlight_entities || []
        )
        lightIds = concatUnique(
            lightIds,
            bundleEntityIds(["environment", "growlight_ac_infinity_devices"], "power_entity")
        )
        var exhaustIds = concatUnique(
            env.exhaust_fan_entities || (env.exhaust_entity ? [env.exhaust_entity] : []),
            bundleEntityIds(["environment", "exhaust_fan_ac_infinity_devices"], "speed_entity")
        )
        var circulationIds = concatUnique(
            env.circulation_fan_entities || (env.circulation_fan_entity ? [env.circulation_fan_entity] : []),
            bundleEntityIds(["environment", "circulation_fan_ac_infinity_devices"], "speed_entity")
        )
        var humidifierIds = concatUnique(
            env.humidifier_entities || (env.humidifier_entity ? [env.humidifier_entity] : []),
            bundleEntityIds(["environment", "humidifier_ac_infinity_devices"], "speed_entity")
        )
        var dehumidifierIds = concatUnique(
            env.dehumidifier_entities || (env.dehumidifier_entity ? [env.dehumidifier_entity] : []),
            bundleEntityIds(["environment", "dehumidifier_ac_infinity_devices"], "speed_entity")
        )

        // Future-compatible aliases: Growspace Manager does not currently model
        // a dedicated AC/climate actuator, but if one is added to the payload
        // this chip starts rendering without changing the UI.
        var acIds = env.air_conditioner_entities || env.ac_entities || env.climate_entities || []
        if (env.air_conditioner_entity)
            acIds = concatUnique(acIds, [env.air_conditioner_entity])
        if (env.ac_entity)
            acIds = concatUnique(acIds, [env.ac_entity])
        if (env.climate_entity)
            acIds = concatUnique(acIds, [env.climate_entity])

        var item = aggregateDevice(lightIds, normalizeLight)
        if (item.configured)
            chips.push({ "label": i18n("Light"), "icon": Qt.resolvedUrl("../images/grow-light.svg"), "value": item.value, "active": item.active })

        item = aggregateDevice(exhaustIds, normalizeFan)
        if (item.configured)
            chips.push({ "label": i18n("Exhaust"), "icon": Qt.resolvedUrl("../images/exhaust-fan.svg"), "value": item.value, "active": item.active })

        item = aggregateDevice(circulationIds, normalizeFan)
        if (item.configured)
            chips.push({ "label": i18n("Circulation"), "icon": Qt.resolvedUrl("../images/circulation-fan.svg"), "value": item.value, "active": item.active })

        item = aggregateDevice(dehumidifierIds, normalizeFan)
        if (item.configured)
            chips.push({ "label": i18n("Dehumidifier"), "icon": Qt.resolvedUrl("../images/dehumidifier.svg"), "value": item.value, "active": item.active })

        item = aggregateDevice(humidifierIds, normalizeFan)
        if (item.configured)
            chips.push({ "label": i18n("Humidifier"), "icon": Qt.resolvedUrl("../images/humidifier.svg"), "value": item.value, "active": item.active })

        item = aggregateDevice(acIds, normalizeClimate)
        if (item.configured)
            chips.push({ "label": i18n("AC"), "icon": Qt.resolvedUrl("../images/air-conditioner.svg"), "value": item.value, "active": item.active })

        return chips
    }

    function requestStates() {
        if (!authenticated)
            return
        statesRequestId = sendCommand({ "type": "get_states" })
    }

    function formatSchedule(value) {
        if (!value)
            return i18n("Not scheduled")

        var date = new Date(value)
        if (isNaN(date.getTime()))
            return String(value)

        return Qt.formatDateTime(date, "ddd HH:mm")
    }

    function stageWeek() {
        var flowerWeek = Number(valueAt(growspace, ["metrics", "flower_week"], 0))
        var vegWeek = Number(valueAt(growspace, ["metrics", "veg_week"], 0))
        var dryWeek = Number(valueAt(growspace, ["metrics", "dry_week"], 0))
        var cureWeek = Number(valueAt(growspace, ["metrics", "cure_week"], 0))

        if (flowerWeek > 0)
            return i18n("Flower week %1", flowerWeek)
        if (vegWeek > 0)
            return i18n("Veg week %1", vegWeek)
        if (dryWeek > 0)
            return i18n("Dry week %1", dryWeek)
        if (cureWeek > 0)
            return i18n("Cure week %1", cureWeek)
        return stageText
    }

    function stageBadgeText() {
        var stage = stageText
        if (stage === "—")
            return ""

        var week = ""
        var flowerWeek = Number(valueAt(growspace, ["metrics", "flower_week"], 0))
        var vegWeek = Number(valueAt(growspace, ["metrics", "veg_week"], 0))
        var dryWeek = Number(valueAt(growspace, ["metrics", "dry_week"], 0))
        var cureWeek = Number(valueAt(growspace, ["metrics", "cure_week"], 0))

        if (flowerWeek > 0) week = " · W" + flowerWeek
        else if (vegWeek > 0) week = " · W" + vegWeek
        else if (dryWeek > 0) week = " · W" + dryWeek
        else if (cureWeek > 0) week = " · W" + cureWeek

        return stage.toUpperCase() + week
    }

    function vpdDetailIsGood() {
        var status = String(vpdStatusText || "").toLowerCase()
        return status === "optimal" || status === "good"
    }

    function reconnect(delay) {
        authenticated = false
        loading = false
        dataRequestId = 0
        socket.active = false

        if (!walletLoaded) {
            connectionState = i18n("Loading KWallet…")
        } else if (shouldConnect) {
            reconnectTimer.interval = delay === undefined ? 150 : delay
            reconnectTimer.restart()
        } else if (!configured) {
            connectionState = i18n("Not configured")
        } else {
            connectionState = i18n("Disconnected")
        }
    }

    function connectSocket() {
        if (!shouldConnect)
            return

        errorMessage = ""
        connectionState = i18n("Connecting…")
        socket.url = wsUrl
        socket.active = true
    }

    function sendCommand(command) {
        if (socket.status !== WebSocket.Open || !authenticated)
            return 0

        var id = nextMessageId++
        var message = {}
        for (var key in command)
            message[key] = command[key]
        message.id = id

        socket.sendTextMessage(JSON.stringify(message))
        return id
    }

    function requestData() {
        if (!authenticated)
            return

        loading = true
        dataRequestId = sendCommand({ "type": "growspace_manager/get_data" })
    }

    function selectGrowspace() {
        var data = collection || {}
        var keys = Object.keys(data)

        if (keys.length === 0) {
            growspace = null
            selectedGrowspaceId = ""
            return
        }

        var wanted = configuredGrowspaceId
        if (wanted.length > 0 && data[wanted] !== undefined) {
            selectedGrowspaceId = wanted
            growspace = data[wanted]
            return
        }

        selectedGrowspaceId = keys[0]
        growspace = data[keys[0]]

        if (wanted.length > 0 && wanted !== selectedGrowspaceId)
            errorMessage = i18n("Growspace '%1' was not found; showing '%2'.", wanted, selectedGrowspaceId)
    }

    function applyCollection(data) {
        collection = data && typeof data === "object" ? data : ({})
        selectGrowspace()
        requestStates()

        if (Object.keys(collection).length === 0) {
            loading = false
            lastUpdated = Qt.formatTime(new Date(), "HH:mm:ss")
            errorMessage = i18n("Growspace Manager returned no growspaces.")
        } else if (configuredGrowspaceId.length === 0 || configuredGrowspaceId === selectedGrowspaceId) {
            errorMessage = ""
        }
    }

    function handleMessage(message) {
        var payload
        try {
            payload = JSON.parse(message)
        } catch (error) {
            errorMessage = i18n("Invalid WebSocket response from Home Assistant.")
            return
        }

        if (payload.type === "auth_required") {
            connectionState = i18n("Authenticating…")
            socket.sendTextMessage(JSON.stringify({
                "type": "auth",
                "access_token": accessToken
            }))
            return
        }

        if (payload.type === "auth_ok") {
            authenticated = true
            connectionState = i18n("Connected")
            errorMessage = ""
            requestData()
            return
        }

        if (payload.type === "auth_invalid") {
            authenticated = false
            connectionState = i18n("Authentication failed")
            errorMessage = payload.message || i18n("Home Assistant rejected the access token.")
            socket.active = false
            return
        }

        if (payload.type === "result" && payload.id === dataRequestId) {
            if (payload.success) {
                applyCollection(payload.result)
            } else {
                loading = false
                errorMessage = payload.error && payload.error.message
                    ? payload.error.message
                    : i18n("Growspace data request failed.")
            }
            return
        }

        if (payload.type === "result" && payload.id === statesRequestId) {
            loading = false
            lastUpdated = Qt.formatTime(new Date(), "HH:mm:ss")

            if (payload.success && Array.isArray(payload.result)) {
                var mapped = ({})
                for (var i = 0; i < payload.result.length; ++i) {
                    var state = payload.result[i]
                    if (state && state.entity_id)
                        mapped[state.entity_id] = state
                }
                hassStates = mapped
            } else if (!payload.success) {
                errorMessage = payload.error && payload.error.message
                    ? payload.error.message
                    : i18n("Could not load Home Assistant device states.")
            }
        }
    }

    onAutoConnectChanged: reconnect(150)
    onConfiguredGrowspaceIdChanged: selectGrowspace()

    Timer {
        id: reconnectTimer
        interval: 150
        repeat: false
        onTriggered: root.connectSocket()
    }

    Timer {
        id: refreshTimer
        interval: root.refreshSeconds * 1000
        repeat: true
        running: root.authenticated
        onTriggered: root.requestData()
    }

    WebSocket {
        id: socket
        active: false

        onTextMessageReceived: function(message) {
            root.handleMessage(message)
        }

        onStatusChanged: {
            if (status === WebSocket.Connecting) {
                root.connectionState = i18n("Connecting…")
            } else if (status === WebSocket.Open && !root.authenticated) {
                root.connectionState = i18n("Authenticating…")
            } else if (status === WebSocket.Error) {
                root.authenticated = false
                root.loading = false
                root.connectionState = i18n("Connection error")
                root.errorMessage = errorString || i18n("Could not connect to Home Assistant.")
            } else if (status === WebSocket.Closed) {
                root.authenticated = false
                root.loading = false
                if (root.shouldConnect && !reconnectTimer.running) {
                    root.connectionState = i18n("Reconnecting…")
                    reconnectTimer.interval = 5000
                    reconnectTimer.restart()
                }
            }
        }
    }

    compactRepresentation: MouseArea {
        implicitWidth: compactRow.implicitWidth + Kirigami.Units.smallSpacing * 2
        implicitHeight: Math.max(Kirigami.Units.iconSizes.smallMedium, compactRow.implicitHeight) + Kirigami.Units.smallSpacing
        onClicked: root.expanded = !root.expanded

        RowLayout {
            id: compactRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Rectangle {
                implicitWidth: 8
                implicitHeight: 8
                radius: 4
                color: root.authenticated
                    ? Kirigami.Theme.positiveTextColor
                    : (root.errorMessage.length > 0 ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor)
            }

            PlasmaComponents.Label {
                text: root.growspace
                    ? root.temperatureText + "  ·  " + root.humidityText
                    : i18n("Growspace")
                font.bold: true
            }
        }
    }

    fullRepresentation: ColumnLayout {
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 7

                    PlasmaComponents.Label {
                        text: root.growspaceName
                        font.bold: true
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize + 4
                        elide: Text.ElideRight
                        Layout.maximumWidth: parent.width * 0.62
                    }

                    Rectangle {
                        visible: root.stageBadgeText().length > 0
                        implicitWidth: stageBadgeLabel.implicitWidth + 14
                        implicitHeight: 22
                        radius: 6
                        color: Qt.rgba(
                            Kirigami.Theme.highlightColor.r,
                            Kirigami.Theme.highlightColor.g,
                            Kirigami.Theme.highlightColor.b,
                            0.10
                        )

                        PlasmaComponents.Label {
                            id: stageBadgeLabel
                            anchors.centerIn: parent
                            text: root.stageBadgeText()
                            font.bold: true
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                            color: Kirigami.Theme.highlightColor
                            opacity: 0.92
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                RowLayout {
                    spacing: 5

                    Rectangle {
                        implicitWidth: 7
                        implicitHeight: 7
                        radius: 4
                        color: root.authenticated
                            ? Kirigami.Theme.positiveTextColor
                            : (root.errorMessage.length > 0
                                ? Kirigami.Theme.negativeTextColor
                                : Kirigami.Theme.disabledTextColor)

                        SequentialAnimation on opacity {
                            running: root.loading
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.35; duration: 500 }
                            NumberAnimation { to: 1.0; duration: 500 }
                        }
                    }

                    PlasmaComponents.Label {
                        text: root.connectionState
                            + (root.lastUpdated.length > 0 ? " · " + root.lastUpdated : "")
                        opacity: 0.48
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                    }
                }
            }

            PlasmaComponents.Button {
                icon.name: "view-refresh"
                display: PlasmaComponents.AbstractButton.IconOnly
                flat: true
                enabled: root.authenticated && !root.loading
                onClicked: root.requestData()
            }
        }

        Rectangle {
            visible: root.walletLoaded && !root.configured
            Layout.fillWidth: true
            implicitHeight: setupColumn.implicitHeight + 24
            radius: 8
            color: Qt.rgba(Kirigami.Theme.textColor.r,
                           Kirigami.Theme.textColor.g,
                           Kirigami.Theme.textColor.b, 0.045)

            ColumnLayout {
                id: setupColumn
                anchors.fill: parent
                anchors.margins: 12

                PlasmaComponents.Label {
                    text: i18n("Home Assistant login required")
                    font.bold: true
                }

                PlasmaComponents.Label {
                    text: i18n("Configure the shared Home Assistant login once. KWallet will reuse it for every Growspace Manager widget.")
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    opacity: 0.62
                }
            }
        }

        PlasmaComponents.Label {
            visible: root.errorMessage.length > 0
            Layout.fillWidth: true
            text: root.errorMessage
            color: Kirigami.Theme.negativeTextColor
            wrapMode: Text.WordWrap
        }

        GridLayout {
            visible: root.configured
            Layout.fillWidth: true
            columns: root.width >= 420 ? 4 : 2
            columnSpacing: 6
            rowSpacing: 6

            MetricTile {
                Layout.fillWidth: true
                title: i18n("Temperature")
                value: root.temperatureText
                detail: root.periodText
                iconName: "temperature-normal"
            }

            MetricTile {
                Layout.fillWidth: true
                title: i18n("Humidity")
                value: root.humidityText
                detail: root.periodText
                iconName: "weather-showers"
            }

            MetricTile {
                Layout.fillWidth: true
                title: i18n("VPD")
                value: root.vpdText
                detail: root.vpdStatusText
                iconName: "speedometer"
                accentDetail: root.vpdDetailIsGood()
            }

            MetricTile {
                Layout.fillWidth: true
                title: i18n("Plants")
                value: root.plantCountText
                detail: root.stageWeekText
                iconName: "view-grid"
            }
        }

        Flow {
            visible: root.deviceChips.length > 0
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                model: root.deviceChips

                DeviceStatusChip {
                    iconName: modelData.icon
                    label: modelData.label
                    value: modelData.value
                    active: modelData.active
                }
            }
        }

        Rectangle {
            visible: root.hasIrrigationPump
            Layout.fillWidth: true
            implicitHeight: 34
            radius: 7
            color: Qt.rgba(Kirigami.Theme.textColor.r,
                           Kirigami.Theme.textColor.g,
                           Kirigami.Theme.textColor.b, 0.035)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                spacing: 7

                Kirigami.Icon {
                    source: Qt.resolvedUrl("../images/irrigation.svg")
                    implicitWidth: 16
                    implicitHeight: 16
                    opacity: 0.62
                }

                PlasmaComponents.Label {
                    text: i18n("Irrigation")
                    font.bold: true
                }

                PlasmaComponents.Label {
                    text: root.irrigationText
                    color: root.irrigationText === "On"
                        ? Kirigami.Theme.highlightColor
                        : Kirigami.Theme.textColor
                    opacity: root.irrigationText === "On" ? 1.0 : 0.58
                    font.bold: root.irrigationText === "On"
                }

                Item { Layout.fillWidth: true }

                PlasmaComponents.Label {
                    text: root.nextIrrigationText
                    opacity: 0.58
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
            }
        }

        ColumnLayout {
            visible: root.sensorTanks.length > 0
            Layout.fillWidth: true
            spacing: 5

            RowLayout {
                Layout.fillWidth: true

                PlasmaComponents.Label {
                    text: i18np("%1 tank", "%1 tanks", root.sensorTanks.length)
                    font.bold: true
                    opacity: 0.76
                }

                Item { Layout.fillWidth: true }

                PlasmaComponents.Label {
                    visible: root.lowTankCount > 0
                    text: i18np("⚠ %1 low", "⚠ %1 low", root.lowTankCount)
                    color: Kirigami.Theme.negativeTextColor
                    font.bold: true
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: root.width >= 390 ? 2 : 1
                columnSpacing: 6
                rowSpacing: 6

                Repeater {
                    model: root.sensorTanks

                    TankGauge {
                        tank: modelData
                        Layout.fillWidth: true
                    }
                }
            }
        }

        Item {
            visible: root.configured
            Layout.fillHeight: true
            Layout.minimumHeight: 1
        }
    }
}

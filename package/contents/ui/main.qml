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
    implicitHeight: 320
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
        loading = false
        lastUpdated = Qt.formatTime(new Date(), "HH:mm:ss")

        if (Object.keys(collection).length === 0)
            errorMessage = i18n("Growspace Manager returned no growspaces.")
        else if (configuredGrowspaceId.length === 0 || configuredGrowspaceId === selectedGrowspaceId)
            errorMessage = ""
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
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "view-statistics"
                implicitWidth: Kirigami.Units.iconSizes.medium
                implicitHeight: implicitWidth
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PlasmaComponents.Label {
                    text: root.growspaceName
                    font.bold: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize + 3
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                PlasmaComponents.Label {
                    text: root.connectionState
                        + (root.lastUpdated.length > 0 ? i18n(" · updated %1", root.lastUpdated) : "")
                    opacity: 0.65
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                implicitWidth: 9
                implicitHeight: 9
                radius: 4.5
                color: root.authenticated
                    ? Kirigami.Theme.positiveTextColor
                    : (root.errorMessage.length > 0 ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.disabledTextColor)
            }
        }

        Rectangle {
            visible: root.walletLoaded && !root.configured
            Layout.fillWidth: true
            implicitHeight: setupColumn.implicitHeight + Kirigami.Units.largeSpacing * 2
            radius: Kirigami.Units.smallSpacing
            color: Kirigami.Theme.backgroundColor
            border.width: 1
            border.color: Kirigami.Theme.disabledTextColor

            ColumnLayout {
                id: setupColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Kirigami.Units.largeSpacing

                PlasmaComponents.Label {
                    text: i18n("Home Assistant login required")
                    font.bold: true
                }

                PlasmaComponents.Label {
                    text: i18n("Configure the shared Home Assistant login once. It will be stored in KWallet and reused by every Growspace Manager widget.")
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    opacity: 0.75
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
            columnSpacing: Kirigami.Units.smallSpacing
            rowSpacing: Kirigami.Units.smallSpacing

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
            }

            MetricTile {
                Layout.fillWidth: true
                title: i18n("Plants")
                value: root.plantCountText
                detail: root.stageWeekText
                iconName: "view-grid"
            }
        }

        Rectangle {
            visible: root.configured
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: detailsColumn.implicitHeight + Kirigami.Units.largeSpacing
            radius: Kirigami.Units.smallSpacing
            color: Kirigami.Theme.backgroundColor
            border.width: 1
            border.color: Kirigami.Theme.disabledTextColor

            ColumnLayout {
                id: detailsColumn
                anchors.fill: parent
                anchors.margins: Kirigami.Units.smallSpacing * 1.5
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true

                    PlasmaComponents.Label {
                        text: i18n("Stage")
                        opacity: 0.65
                    }

                    Item { Layout.fillWidth: true }

                    PlasmaComponents.Label {
                        text: root.stageText
                        font.bold: true
                    }
                }

                RowLayout {
                    visible: root.hasIrrigationPump
                    Layout.fillWidth: true

                    PlasmaComponents.Label {
                        text: i18n("Irrigation pump")
                        opacity: 0.65
                    }

                    Item { Layout.fillWidth: true }

                    PlasmaComponents.Label {
                        text: root.irrigationText
                        font.bold: true
                    }
                }

                RowLayout {
                    visible: root.hasIrrigationPump
                    Layout.fillWidth: true

                    PlasmaComponents.Label {
                        text: i18n("Next irrigation")
                        opacity: 0.65
                    }

                    Item { Layout.fillWidth: true }

                    PlasmaComponents.Label {
                        text: root.nextIrrigationText
                        font.bold: true
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    PlasmaComponents.Label {
                        text: root.selectedGrowspaceId.length > 0
                            ? i18n("%1 · %2 growspace(s)", root.selectedGrowspaceId, Object.keys(root.collection || {}).length)
                            : i18n("No growspace selected")
                        opacity: 0.55
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    PlasmaComponents.Button {
                        text: root.loading ? i18n("Refreshing…") : i18n("Refresh")
                        enabled: root.authenticated && !root.loading
                        icon.name: "view-refresh"
                        onClicked: root.requestData()
                    }
                }
            }
        }
    }
}

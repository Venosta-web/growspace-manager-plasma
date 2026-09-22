import QtQuick
import QtQuick.Layouts
import QtWebSockets
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import "../code/MetricCatalog.js" as MetricCatalog
import "native" as NativeWallet

PlasmoidItem {
    id: root

    implicitWidth: 520
    implicitHeight: 300
    preferredRepresentation: fullRepresentation

    property bool walletLoaded: false
    property bool authenticated: false
    property bool loading: false
    property string statusText: i18n("Loading KWallet…")
    property string errorMessage: ""

    property var collection: ({})
    property var statesById: ({})
    property var growspace: null
    property var metricOption: null
    property var historyPoints: []

    property int nextMessageId: 1
    property int dataRequestId: 0
    property int statesRequestId: 0
    property int historyRequestId: 0

    property string configuredGrowspaceId: String(plasmoid.configuration.growspaceId || "").trim()
    property string configuredMetricKey: String(plasmoid.configuration.metricKey || "").trim()
    property string configuredMetricEntityId: String(plasmoid.configuration.metricEntityId || "").trim()
    property int refreshSeconds: Math.max(60, plasmoid.configuration.refreshInterval || 300)
    property bool autoConnect: plasmoid.configuration.autoConnect

    readonly property string growspaceName: growspace
        ? String(((growspace.identity || {}).name) || i18n("Growspace"))
        : i18n("Growspace")
    readonly property string metricTitle: metricOption
        ? String(metricOption.displayName || metricOption.title || i18n("Metric"))
        : i18n("Metric")
    readonly property string metricUnit: metricOption ? String(metricOption.unit || "") : ""
    readonly property var latestValue: historyPoints.length > 0
        ? historyPoints[historyPoints.length - 1].value
        : null

    Plasmoid.title: i18n("Growspace Manager History")
    Plasmoid.icon: "office-chart-line"

    NativeWallet.WalletStore {
        id: wallet

        onLoadFinished: function(success) {
            root.walletLoaded = success

            if (!success) {
                root.statusText = i18n("KWallet error")
                root.errorMessage = wallet.errorString
                return
            }

            if (!wallet.hasCredentials) {
                root.statusText = i18n("Shared login missing")
                root.errorMessage = i18n("Configure the shared Home Assistant login in a Growspace Manager widget.")
                return
            }

            root.reconnect(50)
        }
    }

    Component.onCompleted: wallet.load()

    onConfiguredGrowspaceIdChanged: if (authenticated) requestBootstrap()
    onConfiguredMetricKeyChanged: if (authenticated) requestBootstrap()
    onConfiguredMetricEntityIdChanged: if (authenticated) requestBootstrap()
    onAutoConnectChanged: reconnect(150)

    function websocketUrl(baseUrl) {
        var base = String(baseUrl || "").trim()
        if (base.startsWith("https://"))
            base = "wss://" + base.slice(8)
        else if (base.startsWith("http://"))
            base = "ws://" + base.slice(7)
        else if (!base.startsWith("ws://") && !base.startsWith("wss://"))
            base = "ws://" + base

        while (base.endsWith("/"))
            base = base.slice(0, -1)

        return base.endsWith("/api/websocket")
            ? base
            : base + "/api/websocket"
    }

    function reconnect(delay) {
        authenticated = false
        loading = false
        socket.active = false

        if (!walletLoaded) {
            statusText = i18n("Loading KWallet…")
            return
        }

        if (!wallet.hasCredentials) {
            statusText = i18n("Shared login missing")
            return
        }

        if (!autoConnect) {
            statusText = i18n("Paused")
            return
        }

        reconnectTimer.interval = delay === undefined ? 150 : delay
        reconnectTimer.restart()
    }

    function connectSocket() {
        if (!wallet.hasCredentials || !autoConnect)
            return

        errorMessage = ""
        statusText = i18n("Connecting…")
        socket.url = websocketUrl(wallet.url)
        socket.active = true
    }

    function sendCommand(command) {
        if (!authenticated || socket.status !== WebSocket.Open)
            return 0

        var id = nextMessageId++
        command.id = id
        socket.sendTextMessage(JSON.stringify(command))
        return id
    }

    function requestBootstrap() {
        if (!authenticated)
            return

        loading = true
        historyPoints = []
        metricOption = null

        dataRequestId = sendCommand({
            type: "growspace_manager/get_data"
        })

        statesRequestId = sendCommand({
            type: "get_states"
        })
    }

    function maybeResolveMetric() {
        if (Object.keys(collection || {}).length === 0
                || Object.keys(statesById || {}).length === 0)
            return

        var keys = Object.keys(collection)
        if (keys.length === 0) {
            loading = false
            errorMessage = i18n("No growspaces are available.")
            return
        }

        var selectedId = configuredGrowspaceId
        if (!selectedId || collection[selectedId] === undefined)
            selectedId = keys[0]

        growspace = collection[selectedId]

        var option = MetricCatalog.findOption(
            growspace,
            statesById,
            configuredMetricKey,
            configuredMetricEntityId
        )

        if (!option) {
            loading = false
            metricOption = null
            errorMessage = i18n("No graphable configured metrics are available for this growspace.")
            return
        }

        metricOption = option
        requestHistory()
    }

    function requestHistory() {
        if (!metricOption)
            return

        var end = new Date()
        var start = new Date(end.getTime() - 24 * 60 * 60 * 1000)

        statusText = i18n("Loading 24-hour history…")
        historyRequestId = sendCommand({
            type: "growspace_manager/get_history_stats",
            entity_ids: [metricOption.entityId],
            start_time: start.toISOString(),
            end_time: end.toISOString(),
            interval_minutes: 30,
            significant_changes_only: true
        })
    }

    function formatValue(value) {
        if (value === null || value === undefined)
            return "—"

        if (metricOption && metricOption.step
                && metricOption.axisMin === 0 && metricOption.axisMax === 1)
            return Number(value) >= 0.5 ? i18n("On") : i18n("Off")

        var n = Number(value)
        if (isNaN(n))
            return "—"

        var digits = Math.abs(n) >= 100 ? 0 : (Math.abs(n) >= 10 ? 1 : 2)
        var suffix = metricUnit.length > 0 ? " " + metricUnit : ""
        return n.toFixed(digits) + suffix
    }

    function minValue() {
        if (!historyPoints || historyPoints.length === 0)
            return null
        var result = historyPoints[0].value
        for (var i = 1; i < historyPoints.length; ++i)
            result = Math.min(result, historyPoints[i].value)
        return result
    }

    function maxValue() {
        if (!historyPoints || historyPoints.length === 0)
            return null
        var result = historyPoints[0].value
        for (var i = 1; i < historyPoints.length; ++i)
            result = Math.max(result, historyPoints[i].value)
        return result
    }

    function handleMessage(message) {
        var p
        try {
            p = JSON.parse(message)
        } catch (e) {
            loading = false
            errorMessage = i18n("Invalid Home Assistant response.")
            return
        }

        if (p.type === "auth_required") {
            statusText = i18n("Authenticating…")
            socket.sendTextMessage(JSON.stringify({
                type: "auth",
                access_token: wallet.token
            }))
            return
        }

        if (p.type === "auth_ok") {
            authenticated = true
            statusText = i18n("Connected")
            requestBootstrap()
            return
        }

        if (p.type === "auth_invalid") {
            authenticated = false
            loading = false
            statusText = i18n("Authentication failed")
            errorMessage = p.message || i18n("Home Assistant rejected the KWallet token.")
            socket.active = false
            return
        }

        if (p.type !== "result")
            return

        if (p.id === dataRequestId) {
            if (p.success) {
                collection = p.result || ({})
                maybeResolveMetric()
            } else {
                loading = false
                errorMessage = p.error && p.error.message
                    ? p.error.message
                    : i18n("Could not load growspace data.")
            }
            return
        }

        if (p.id === statesRequestId) {
            if (p.success && Array.isArray(p.result)) {
                var mapped = ({})
                for (var i = 0; i < p.result.length; ++i) {
                    var state = p.result[i]
                    if (state && state.entity_id)
                        mapped[state.entity_id] = state
                }
                statesById = mapped
                maybeResolveMetric()
            } else {
                loading = false
                errorMessage = i18n("Could not load Home Assistant entity states.")
            }
            return
        }

        if (p.id === historyRequestId) {
            loading = false

            if (!p.success) {
                errorMessage = p.error && p.error.message
                    ? p.error.message
                    : i18n("Could not load metric history.")
                return
            }

            var raw = (p.result || ({}))[metricOption.entityId] || []
            historyPoints = MetricCatalog.normalizeHistory(raw, metricOption)
            statusText = i18n("Updated %1", Qt.formatTime(new Date(), "HH:mm"))
            errorMessage = ""
        }
    }

    Timer {
        id: reconnectTimer
        repeat: false
        onTriggered: root.connectSocket()
    }

    Timer {
        interval: root.refreshSeconds * 1000
        repeat: true
        running: root.authenticated && root.autoConnect
        onTriggered: root.requestBootstrap()
    }

    WebSocket {
        id: socket
        active: false

        onTextMessageReceived: function(message) {
            root.handleMessage(message)
        }

        onStatusChanged: {
            if (status === WebSocket.Error) {
                root.loading = false
                root.statusText = i18n("Connection error")
                root.errorMessage = errorString || i18n("Could not connect to Home Assistant.")
            } else if (status === WebSocket.Closed
                    && root.autoConnect
                    && root.walletLoaded
                    && wallet.hasCredentials
                    && !reconnectTimer.running) {
                root.authenticated = false
                reconnectTimer.interval = 5000
                reconnectTimer.restart()
            }
        }
    }

    compactRepresentation: MouseArea {
        implicitWidth: compactRow.implicitWidth + 12
        implicitHeight: compactRow.implicitHeight + 8
        onClicked: root.expanded = !root.expanded

        RowLayout {
            id: compactRow
            anchors.centerIn: parent
            spacing: 5

            Kirigami.Icon {
                source: "office-chart-line"
                implicitWidth: 16
                implicitHeight: 16
            }

            PlasmaComponents.Label {
                text: root.metricOption
                    ? root.metricTitle + " " + root.formatValue(root.latestValue)
                    : i18n("History")
                font.bold: true
            }
        }
    }

    fullRepresentation: ColumnLayout {
        spacing: 7

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                PlasmaComponents.Label {
                    text: root.growspaceName
                    font.bold: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize + 3
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                PlasmaComponents.Label {
                    text: root.metricTitle + " · " + i18n("last 24 hours")
                    opacity: 0.60
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            PlasmaComponents.Button {
                icon.name: "view-refresh"
                display: PlasmaComponents.AbstractButton.IconOnly
                flat: true
                enabled: root.authenticated && !root.loading
                onClicked: root.requestBootstrap()
            }
        }

        RowLayout {
            visible: root.metricOption !== null
            Layout.fillWidth: true
            spacing: 14

            PlasmaComponents.Label {
                text: root.formatValue(root.latestValue)
                font.bold: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 5
            }

            ColumnLayout {
                spacing: 0

                PlasmaComponents.Label {
                    text: i18n("Min %1", root.formatValue(root.minValue()))
                    opacity: 0.52
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }

                PlasmaComponents.Label {
                    text: i18n("Max %1", root.formatValue(root.maxValue()))
                    opacity: 0.52
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
            }

            Item { Layout.fillWidth: true }

            PlasmaComponents.Label {
                text: root.statusText
                opacity: 0.46
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
        }

        PlasmaComponents.Label {
            visible: root.errorMessage.length > 0
            Layout.fillWidth: true
            text: root.errorMessage
            color: Kirigami.Theme.negativeTextColor
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 8
            color: Qt.rgba(
                Kirigami.Theme.textColor.r,
                Kirigami.Theme.textColor.g,
                Kirigami.Theme.textColor.b, 0.035)

            HistoryChart {
                anchors.fill: parent
                anchors.margins: 6
                points: root.historyPoints
                unit: root.metricUnit
                stepMode: root.metricOption ? root.metricOption.step : false
                fixedMin: root.metricOption ? root.metricOption.axisMin : null
                fixedMax: root.metricOption ? root.metricOption.axisMax : null
                minimumSpan: root.metricOption ? Number(root.metricOption.minSpan || 1) : 1
            }
        }
    }
}

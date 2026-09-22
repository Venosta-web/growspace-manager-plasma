import QtQuick
import QtQuick.Layouts
import QtWebSockets
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import "native" as NativeWallet

PlasmoidItem {
    id: root
    implicitWidth: 560
    implicitHeight: 360
    preferredRepresentation: fullRepresentation

    property bool authenticated: false
    property bool loading: false
    property bool walletLoaded: false
    property string statusText: i18n("Loading KWallet…")
    property string errorMessage: ""
    property var collection: ({})
    property var growspace: null
    property var history: ({})
    property string selectedGrowspaceId: ""
    property int nextMessageId: 1
    property int dataRequestId: 0
    property int historyRequestId: 0

    property string growspaceIdSetting: String(plasmoid.configuration.growspaceId || "").trim()
    property int refreshSeconds: Math.max(60, plasmoid.configuration.refreshInterval || 300)
    property bool autoConnect: plasmoid.configuration.autoConnect
    property bool showEc: plasmoid.configuration.showEc

    readonly property string growspaceName: valueAt(growspace, ["identity","name"], selectedGrowspaceId || i18n("Irrigation"))
    readonly property var strategy: valueAt(growspace, ["irrigation","irrigation_strategy"], null)
    readonly property var targetVwc: strategy ? strategy.target_vwc_percent : null
    readonly property var dryback: strategy ? strategy.maintenance_dryback_percent : null
    readonly property string pumpState: displayText(valueAt(growspace, ["environment","irrigation_pump_state"], "unknown"))
    readonly property string nextCycle: formatSchedule(valueAt(growspace, ["irrigation","next_scheduled_cycle"], null))
    readonly property var latestVwc: chart.lastValue(history.soil_moisture || [])
    readonly property var latestPore: chart.lastValue(history.pore_ec || [])
    readonly property var latestBulk: chart.lastValue(history.bulk_ec || [])

    Plasmoid.title: i18n("Growspace Manager Irrigation")
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
            root.reconnect(50)
        }
    }

    Component.onCompleted: wallet.load()
    onGrowspaceIdSettingChanged: if (authenticated) requestGrowspaceData()

    function websocketUrl(baseUrl) {
        var base = String(baseUrl || "").trim()
        if (base.startsWith("https://")) base = "wss://" + base.slice(8)
        else if (base.startsWith("http://")) base = "ws://" + base.slice(7)
        else if (!base.startsWith("ws://") && !base.startsWith("wss://")) base = "ws://" + base
        while (base.endsWith("/")) base = base.slice(0,-1)
        return base.endsWith("/api/websocket") ? base : base + "/api/websocket"
    }

    function valueAt(obj, path, fallback) {
        var cur = obj
        for (var i=0;i<path.length;++i) {
            if (cur === null || cur === undefined || typeof cur !== "object" || !(path[i] in cur)) return fallback
            cur = cur[path[i]]
        }
        return cur === null || cur === undefined ? fallback : cur
    }

    function displayText(v) {
        if (v === null || v === undefined || v === "" || v === "unknown" || v === "unavailable") return "—"
        var s = String(v).replace(/_/g," ")
        return s.charAt(0).toUpperCase() + s.slice(1)
    }

    function formatSchedule(v) {
        if (!v) return i18n("Not scheduled")
        var d = new Date(v)
        return isNaN(d.getTime()) ? String(v) : Qt.formatDateTime(d,"ddd HH:mm")
    }

    function reconnect(delay) {
        authenticated = false
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
            statusText = i18n("Disconnected")
            return
        }
        reconnectTimer.interval = delay || 150
        reconnectTimer.restart()
    }

    function connectSocket() {
        loading = true
        errorMessage = ""
        statusText = i18n("Connecting…")
        socket.url = websocketUrl(wallet.url)
        socket.active = true
    }

    function sendCommand(obj) {
        var id = nextMessageId++
        obj.id = id
        socket.sendTextMessage(JSON.stringify(obj))
        return id
    }

    function requestGrowspaceData() {
        if (!authenticated) return
        loading = true
        dataRequestId = sendCommand({"type":"growspace_manager/get_data"})
    }

    function chooseGrowspace() {
        var keys = Object.keys(collection || {})
        if (keys.length === 0) {
            selectedGrowspaceId = ""
            growspace = null
            return false
        }
        var wanted = growspaceIdSetting
        selectedGrowspaceId = wanted.length > 0 && collection[wanted] !== undefined ? wanted : keys[0]
        growspace = collection[selectedGrowspaceId]
        return true
    }

    function requestHistory() {
        if (!selectedGrowspaceId) {
            loading = false
            return
        }
        historyRequestId = sendCommand({
            "type":"growspace_manager/get_crop_steering_history",
            "growspace_id":selectedGrowspaceId
        })
    }

    function handleMessage(message) {
        var p
        try { p = JSON.parse(message) }
        catch(e) { errorMessage = i18n("Invalid Home Assistant response."); loading = false; return }

        if (p.type === "auth_required") {
            statusText = i18n("Authenticating…")
            socket.sendTextMessage(JSON.stringify({"type":"auth","access_token":wallet.token}))
        } else if (p.type === "auth_ok") {
            authenticated = true
            statusText = i18n("Connected")
            requestGrowspaceData()
        } else if (p.type === "auth_invalid") {
            authenticated = false
            loading = false
            statusText = i18n("Authentication failed")
            errorMessage = p.message || i18n("Home Assistant rejected the KWallet token.")
            socket.active = false
        } else if (p.type === "result" && p.id === dataRequestId) {
            if (!p.success) {
                loading = false
                errorMessage = p.error && p.error.message ? p.error.message : i18n("Could not load growspace data.")
                return
            }
            collection = p.result || ({})
            if (chooseGrowspace()) requestHistory()
            else {
                loading = false
                errorMessage = i18n("No growspaces are available.")
            }
        } else if (p.type === "result" && p.id === historyRequestId) {
            loading = false
            if (p.success) {
                history = p.result || ({})
                errorMessage = ""
                statusText = i18n("Connected · updated %1", Qt.formatTime(new Date(),"HH:mm"))
            } else {
                errorMessage = p.error && p.error.message ? p.error.message : i18n("Could not load irrigation history.")
            }
        }
    }

    Timer { id: reconnectTimer; repeat: false; onTriggered: root.connectSocket() }
    Timer {
        interval: root.refreshSeconds * 1000
        repeat: true
        running: root.authenticated
        onTriggered: root.requestGrowspaceData()
    }

    WebSocket {
        id: socket
        active: false
        onTextMessageReceived: function(message){ root.handleMessage(message) }
        onStatusChanged: {
            if (status === WebSocket.Error) {
                root.loading = false
                root.statusText = i18n("Connection error")
                root.errorMessage = errorString || i18n("Could not connect to Home Assistant.")
            } else if (status === WebSocket.Closed && root.autoConnect && root.walletLoaded && wallet.hasCredentials && !reconnectTimer.running) {
                root.authenticated = false
                reconnectTimer.interval = 5000
                reconnectTimer.restart()
            }
        }
    }

    compactRepresentation: MouseArea {
        implicitWidth: compactRow.implicitWidth + 10
        implicitHeight: compactRow.implicitHeight + 8
        onClicked: root.expanded = !root.expanded
        RowLayout {
            id: compactRow
            anchors.centerIn: parent
            PlasmaComponents.Label { text: "💧" }
            PlasmaComponents.Label {
                text: root.latestVwc === null ? i18n("Irrigation") : Number(root.latestVwc).toFixed(1) + "% VWC"
                font.bold: true
            }
        }
    }

    fullRepresentation: ColumnLayout {
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Kirigami.Icon {
                source: "office-chart-line"
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
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                PlasmaComponents.Label {
                    text: root.statusText
                    opacity: 0.65
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
            }
            PlasmaComponents.Button {
                icon.name: "view-refresh"
                enabled: root.authenticated && !root.loading
                onClicked: root.requestGrowspaceData()
                ToolTip.text: i18n("Refresh")
            }
        }

        PlasmaComponents.Label {
            visible: root.errorMessage.length > 0
            Layout.fillWidth: true
            text: root.errorMessage
            color: Kirigami.Theme.negativeTextColor
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.largeSpacing
            PlasmaComponents.Label {
                text: root.latestVwc === null ? "VWC —" : "VWC " + Number(root.latestVwc).toFixed(1) + "%"
                font.bold: true
            }
            PlasmaComponents.Label {
                text: root.targetVwc === null ? i18n("Target —") : i18n("Target %1%", Number(root.targetVwc).toFixed(1))
                opacity: 0.72
            }
            PlasmaComponents.Label {
                text: i18n("Pump %1", root.pumpState)
                opacity: 0.72
            }
            Item { Layout.fillWidth: true }
            PlasmaComponents.Label {
                text: root.nextCycle
                opacity: 0.72
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Kirigami.Units.smallSpacing
            color: Qt.rgba(0,0,0,0.10)
            border.width: 1
            border.color: Kirigami.Theme.disabledTextColor

            IrrigationChart {
                id: chart
                anchors.fill: parent
                anchors.margins: 6
                soilMoisture: root.history.soil_moisture || []
                poreEc: root.history.pore_ec || []
                bulkEc: root.history.bulk_ec || []
                lightsOn: root.history.lights_on || ""
                targetVwc: root.targetVwc
                maintenanceDryback: root.dryback
                showEc: root.showEc
            }
        }

        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents.Label {
                text: root.showEc && root.latestPore !== null
                    ? "Pore EC " + Number(root.latestPore).toFixed(2) + " mS/cm"
                    : ""
                visible: text.length > 0
                opacity: 0.65
            }
            PlasmaComponents.Label {
                text: root.showEc && root.latestBulk !== null
                    ? "Bulk EC " + Number(root.latestBulk).toFixed(2) + " mS/cm"
                    : ""
                visible: text.length > 0
                opacity: 0.65
            }
            Item { Layout.fillWidth: true }
            PlasmaComponents.Label {
                text: i18n("5 min buckets · lights-on anchored")
                opacity: 0.48
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }
        }
    }
}

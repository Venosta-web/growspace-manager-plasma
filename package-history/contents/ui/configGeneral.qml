import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtWebSockets
import org.kde.kirigami as Kirigami
import "../code/MetricCatalog.js" as MetricCatalog
import "native" as NativeWallet

Kirigami.FormLayout {
    id: page

    property string cfg_growspaceId: ""
    property string cfg_metricKey: ""
    property string cfg_metricEntityId: ""
    property alias cfg_refreshInterval: refreshInterval.value
    property alias cfg_autoConnect: autoConnect.checked

    property var collection: ({})
    property var statesById: ({})
    property int nextMessageId: 1
    property int dataRequestId: 0
    property int statesRequestId: 0
    property bool authenticated: false
    property string statusText: i18n("Loading KWallet…")
    property bool statusError: false

    function websocketUrl(baseUrl) {
        var base = String(baseUrl || "").trim()
        if (base.startsWith("https://")) base = "wss://" + base.slice(8)
        else if (base.startsWith("http://")) base = "ws://" + base.slice(7)
        else if (!base.startsWith("ws://") && !base.startsWith("wss://")) base = "ws://" + base
        while (base.endsWith("/")) base = base.slice(0, -1)
        return base.endsWith("/api/websocket") ? base : base + "/api/websocket"
    }

    function selectedGrowspace() {
        if (!collection)
            return null
        if (cfg_growspaceId && collection[cfg_growspaceId] !== undefined)
            return collection[cfg_growspaceId]
        var keys = Object.keys(collection)
        return keys.length > 0 ? collection[keys[0]] : null
    }

    function rebuildGrowspaces() {
        growspaceModel.clear()

        var entries = []
        for (var id in collection) {
            if (!Object.prototype.hasOwnProperty.call(collection, id))
                continue
            var identity = (collection[id] || {}).identity || ({})
            entries.push({
                growspaceId: id,
                displayName: String(identity.name || i18n("Unnamed growspace"))
            })
        }

        entries.sort(function(a, b) {
            return a.displayName.localeCompare(b.displayName)
        })

        for (var i = 0; i < entries.length; ++i)
            growspaceModel.append(entries[i])

        var index = 0
        for (var j = 0; j < growspaceModel.count; ++j) {
            if (growspaceModel.get(j).growspaceId === cfg_growspaceId) {
                index = j
                break
            }
        }

        if (growspaceModel.count > 0) {
            growspaceSelector.currentIndex = index
            cfg_growspaceId = growspaceModel.get(index).growspaceId
        }

        rebuildMetrics()
    }

    function rebuildMetrics() {
        metricModel.clear()

        var growspace = selectedGrowspace()
        var options = MetricCatalog.optionsForGrowspace(growspace, statesById)

        for (var i = 0; i < options.length; ++i)
            metricModel.append(options[i])

        if (metricModel.count === 0) {
            cfg_metricKey = ""
            cfg_metricEntityId = ""
            statusError = true
            statusText = i18n("No graphable configured metrics found for this growspace.")
            return
        }

        var selected = 0
        for (var j = 0; j < metricModel.count; ++j) {
            var row = metricModel.get(j)
            if (row.metricKey === cfg_metricKey && row.entityId === cfg_metricEntityId) {
                selected = j
                break
            }
        }

        metricSelector.currentIndex = selected
        var chosen = metricModel.get(selected)
        cfg_metricKey = chosen.metricKey
        cfg_metricEntityId = chosen.entityId
        statusError = false
        statusText = i18np("%1 metric available", "%1 metrics available", metricModel.count)
    }

    NativeWallet.WalletStore {
        id: wallet

        onLoadFinished: function(success) {
            if (!success) {
                statusError = true
                statusText = wallet.errorString
                return
            }

            if (!wallet.hasCredentials) {
                statusError = true
                statusText = i18n("Configure the shared Home Assistant login first.")
                return
            }

            socket.url = websocketUrl(wallet.url)
            socket.active = true
        }
    }

    Component.onCompleted: wallet.load()

    ListModel { id: growspaceModel }
    ListModel { id: metricModel }

    WebSocket {
        id: socket
        active: false

        onTextMessageReceived: function(message) {
            var p
            try { p = JSON.parse(message) }
            catch (e) {
                statusError = true
                statusText = i18n("Invalid Home Assistant response.")
                return
            }

            if (p.type === "auth_required") {
                sendTextMessage(JSON.stringify({
                    type: "auth",
                    access_token: wallet.token
                }))
            } else if (p.type === "auth_ok") {
                authenticated = true
                dataRequestId = nextMessageId++
                sendTextMessage(JSON.stringify({
                    id: dataRequestId,
                    type: "growspace_manager/get_data"
                }))
                statesRequestId = nextMessageId++
                sendTextMessage(JSON.stringify({
                    id: statesRequestId,
                    type: "get_states"
                }))
            } else if (p.type === "auth_invalid") {
                statusError = true
                statusText = p.message || i18n("Authentication failed.")
                active = false
            } else if (p.type === "result" && p.id === dataRequestId) {
                if (p.success) {
                    collection = p.result || ({})
                    if (Object.keys(statesById).length > 0)
                        rebuildGrowspaces()
                } else {
                    statusError = true
                    statusText = p.error && p.error.message
                        ? p.error.message
                        : i18n("Could not load growspaces.")
                }
            } else if (p.type === "result" && p.id === statesRequestId) {
                if (p.success && Array.isArray(p.result)) {
                    var mapped = ({})
                    for (var i = 0; i < p.result.length; ++i) {
                        var state = p.result[i]
                        if (state && state.entity_id)
                            mapped[state.entity_id] = state
                    }
                    statesById = mapped
                    if (Object.keys(collection).length > 0)
                        rebuildGrowspaces()
                } else {
                    statusError = true
                    statusText = i18n("Could not load Home Assistant entity states.")
                }
            }
        }

        onStatusChanged: if (status === WebSocket.Error) {
            statusError = true
            statusText = errorString || i18n("Could not connect to Home Assistant.")
        }
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        text: i18n("24-hour history")
        level: 3
    }

    QQC2.ComboBox {
        id: growspaceSelector
        Kirigami.FormData.label: i18n("Growspace:")
        Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        model: growspaceModel
        textRole: "displayName"

        onActivated: function(index) {
            if (index < 0 || index >= growspaceModel.count)
                return
            cfg_growspaceId = growspaceModel.get(index).growspaceId
            rebuildMetrics()
        }
    }

    QQC2.ComboBox {
        id: metricSelector
        Kirigami.FormData.label: i18n("Metric:")
        Layout.minimumWidth: Kirigami.Units.gridUnit * 20
        model: metricModel
        textRole: "displayName"

        onActivated: function(index) {
            if (index < 0 || index >= metricModel.count)
                return
            var selected = metricModel.get(index)
            cfg_metricKey = selected.metricKey
            cfg_metricEntityId = selected.entityId
        }
    }

    RowLayout {
        Kirigami.FormData.isSection: true
        Layout.fillWidth: true

        QQC2.Label {
            Layout.fillWidth: true
            text: page.statusText
            color: page.statusError
                ? Kirigami.Theme.negativeTextColor
                : Kirigami.Theme.textColor
            opacity: page.statusError ? 1.0 : 0.65
            wrapMode: Text.WordWrap
        }

        QQC2.Button {
            text: i18n("Reload")
            icon.name: "view-refresh"
            enabled: wallet.hasCredentials
            onClicked: {
                socket.active = false
                wallet.load()
            }
        }
    }

    QQC2.SpinBox {
        id: refreshInterval
        Kirigami.FormData.label: i18n("Refresh interval:")
        from: 60
        to: 3600
        stepSize: 60
        editable: true
        textFromValue: function(value) {
            return i18np("%1 second", "%1 seconds", value)
        }
        valueFromText: function(text) {
            var n = parseInt(text)
            return isNaN(n) ? 300 : n
        }
    }

    QQC2.CheckBox {
        id: autoConnect
        Kirigami.FormData.label: i18n("Connection:")
        text: i18n("Refresh automatically")
    }

    QQC2.Label {
        Kirigami.FormData.isSection: true
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        opacity: 0.62
        text: i18n("Only metrics backed by a configured Home Assistant entity are shown. Multi-sensor metrics are labeled with the sensor's friendly name.")
    }
}

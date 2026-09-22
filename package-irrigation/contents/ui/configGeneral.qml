import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtWebSockets
import org.kde.kirigami as Kirigami
import "native" as NativeWallet

Kirigami.FormLayout {
    id: page

    property string cfg_growspaceId: ""
    property alias cfg_refreshInterval: refreshInterval.value
    property alias cfg_autoConnect: autoConnect.checked
    property alias cfg_showEc: showEc.checked

    property bool growspacesLoading: false
    property string growspaceStatus: i18n("Loading growspaces…")
    property bool growspaceStatusError: false
    property int nextMessageId: 1
    property int dataRequestId: 0

    function websocketUrl(baseUrl) {
        var base = String(baseUrl || "").trim()
        if (base.startsWith("https://")) base = "wss://" + base.slice(8)
        else if (base.startsWith("http://")) base = "ws://" + base.slice(7)
        else if (!base.startsWith("ws://") && !base.startsWith("wss://")) base = "ws://" + base
        while (base.endsWith("/")) base = base.slice(0, -1)
        return base.endsWith("/api/websocket") ? base : base + "/api/websocket"
    }

    function selectConfiguredGrowspace() {
        var wanted = String(cfg_growspaceId || "")
        if (wanted.length === 0) {
            growspaceSelector.currentIndex = 0
            return
        }
        for (var i = 1; i < growspaceModel.count; ++i) {
            if (growspaceModel.get(i).growspaceId === wanted) {
                growspaceSelector.currentIndex = i
                return
            }
        }
        growspaceSelector.currentIndex = 0
    }

    function rebuildGrowspaces(collection) {
        var entries = []
        for (var id in collection) {
            if (!Object.prototype.hasOwnProperty.call(collection, id)) continue
            var identity = (collection[id] || {}).identity || {}
            entries.push({
                "growspaceId": id,
                "displayName": String(identity.name || i18n("Unnamed growspace"))
            })
        }
        entries.sort(function(a,b){ return a.displayName.localeCompare(b.displayName) })

        growspaceModel.clear()
        growspaceModel.append({"growspaceId":"","displayName":i18n("Automatic (first available)")})
        for (var i = 0; i < entries.length; ++i) growspaceModel.append(entries[i])

        growspacesLoading = false
        growspaceStatusError = false
        growspaceStatus = i18np("%1 growspace available", "%1 growspaces available", entries.length)
        selectConfiguredGrowspace()
    }

    function fetchGrowspaces() {
        if (!wallet.hasCredentials) {
            growspaceStatusError = true
            growspaceStatus = i18n("Configure the shared Home Assistant login in the main Growspace Manager widget first.")
            return
        }
        growspacesLoading = true
        growspaceStatus = i18n("Loading growspaces…")
        growspaceStatusError = false
        socket.active = false
        socket.url = websocketUrl(wallet.url)
        socket.active = true
    }

    onCfg_growspaceIdChanged: selectConfiguredGrowspace()

    NativeWallet.WalletStore {
        id: wallet
        onLoadFinished: function(success) {
            if (!success) {
                page.growspaceStatusError = true
                page.growspaceStatus = wallet.errorString
                return
            }
            page.fetchGrowspaces()
        }
    }

    Component.onCompleted: wallet.load()

    ListModel {
        id: growspaceModel
        ListElement { growspaceId: ""; displayName: qsTr("Automatic (first available)") }
    }

    WebSocket {
        id: socket
        active: false

        onTextMessageReceived: function(message) {
            var p = JSON.parse(message)
            if (p.type === "auth_required") {
                sendTextMessage(JSON.stringify({"type":"auth","access_token":wallet.token}))
            } else if (p.type === "auth_ok") {
                var id = page.nextMessageId++
                page.dataRequestId = id
                sendTextMessage(JSON.stringify({"id":id,"type":"growspace_manager/get_data"}))
            } else if (p.type === "auth_invalid") {
                page.growspacesLoading = false
                page.growspaceStatusError = true
                page.growspaceStatus = p.message || i18n("Authentication failed.")
                active = false
            } else if (p.type === "result" && p.id === page.dataRequestId) {
                if (p.success) page.rebuildGrowspaces(p.result || {})
                else {
                    page.growspacesLoading = false
                    page.growspaceStatusError = true
                    page.growspaceStatus = p.error && p.error.message ? p.error.message : i18n("Could not load growspaces.")
                }
                active = false
            }
        }

        onStatusChanged: if (status === WebSocket.Error) {
            page.growspacesLoading = false
            page.growspaceStatusError = true
            page.growspaceStatus = errorString || i18n("Could not connect to Home Assistant.")
        }
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        text: i18n("Irrigation widget")
        level: 3
    }

    QQC2.ComboBox {
        id: growspaceSelector
        Kirigami.FormData.label: i18n("Growspace:")
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        model: growspaceModel
        textRole: "displayName"
        enabled: !page.growspacesLoading
        onActivated: function(index) {
            page.cfg_growspaceId = growspaceModel.get(index).growspaceId
        }
    }

    RowLayout {
        Kirigami.FormData.isSection: true
        Layout.fillWidth: true
        QQC2.Label {
            Layout.fillWidth: true
            text: page.growspaceStatus
            color: page.growspaceStatusError ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
            opacity: page.growspaceStatusError ? 1 : 0.7
        }
        QQC2.Button {
            text: i18n("Refresh")
            icon.name: "view-refresh"
            enabled: wallet.hasCredentials && !page.growspacesLoading
            onClicked: page.fetchGrowspaces()
        }
    }

    QQC2.CheckBox {
        id: showEc
        Kirigami.FormData.label: i18n("Chart:")
        text: i18n("Show Pore EC / Bulk EC when available")
    }

    QQC2.SpinBox {
        id: refreshInterval
        Kirigami.FormData.label: i18n("Refresh interval:")
        from: 60
        to: 3600
        stepSize: 60
        editable: true
        textFromValue: function(value) { return i18np("%1 second","%1 seconds",value) }
        valueFromText: function(text) {
            var n = parseInt(text)
            return isNaN(n) ? 300 : n
        }
    }

    QQC2.CheckBox {
        id: autoConnect
        Kirigami.FormData.label: i18n("Connection:")
        text: i18n("Connect automatically")
    }

    QQC2.Label {
        Kirigami.FormData.isSection: true
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        opacity: 0.7
        text: i18n("This applet reuses the Home Assistant credentials stored by Growspace Manager in KWallet.")
    }
}

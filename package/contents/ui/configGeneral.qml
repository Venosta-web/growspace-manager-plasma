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

    property bool walletLoaded: false
    property string walletStatus: i18n("Loading shared credentials…")
    property bool growspacesLoading: false
    property string growspaceStatus: i18n("Waiting for Home Assistant credentials…")
    property bool growspaceStatusError: false
    property int nextMessageId: 1
    property int dataRequestId: 0

    function websocketUrl(baseUrl) {
        var base = String(baseUrl || "").trim()
        if (base.length === 0)
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
        if (!growspacesLoading && growspaceModel.count > 1) {
            growspaceStatusError = true
            growspaceStatus = i18n("The previously selected growspace is no longer available. Choose another growspace.")
        }
    }

    function rebuildGrowspaceModel(collection) {
        var entries = []

        for (var growspaceId in collection) {
            if (!Object.prototype.hasOwnProperty.call(collection, growspaceId))
                continue

            var item = collection[growspaceId] || {}
            var identity = item.identity || {}
            var name = String(identity.name || "").trim()

            if (name.length === 0)
                name = i18n("Unnamed growspace")

            entries.push({
                "growspaceId": growspaceId,
                "displayName": name,
                "growspaceType": String(identity.type || "")
            })
        }

        entries.sort(function(a, b) {
            return a.displayName.localeCompare(b.displayName)
        })

        growspaceModel.clear()
        growspaceModel.append({
            "growspaceId": "",
            "displayName": i18n("Automatic (first available)"),
            "growspaceType": ""
        })

        for (var i = 0; i < entries.length; ++i)
            growspaceModel.append(entries[i])

        growspacesLoading = false
        growspaceStatusError = false

        if (entries.length === 0)
            growspaceStatus = i18n("Growspace Manager returned no growspaces.")
        else
            growspaceStatus = i18np("%1 growspace available", "%1 growspaces available", entries.length)

        selectConfiguredGrowspace()
    }

    function fetchGrowspaces() {
        if (!wallet.hasCredentials) {
            growspaceStatusError = true
            growspaceStatus = i18n("Save the shared Home Assistant login first.")
            return
        }

        growspacesLoading = true
        growspaceStatusError = false
        growspaceStatus = i18n("Loading growspaces…")
        dataRequestId = 0

        growspaceSocket.active = false
        growspaceSocket.url = websocketUrl(wallet.url)
        growspaceSocket.active = true
    }

    onCfg_growspaceIdChanged: selectConfiguredGrowspace()

    NativeWallet.WalletStore {
        id: wallet

        onLoadFinished: function(success) {
            page.walletLoaded = success
            if (!success) {
                page.walletStatus = wallet.errorString
                page.growspaceStatusError = true
                page.growspaceStatus = i18n("Could not load shared credentials.")
                return
            }

            haUrl.text = wallet.url.length > 0
                ? wallet.url
                : "http://homeassistant.local:8123"
            accessToken.text = wallet.token
            page.walletStatus = wallet.hasCredentials
                ? i18n("Shared credentials loaded from KWallet")
                : i18n("No shared credentials saved yet")

            if (wallet.hasCredentials)
                page.fetchGrowspaces()
        }

        onSaveFinished: function(success) {
            page.walletLoaded = success
            page.walletStatus = success
                ? i18n("Saved securely in KWallet — all Growspace widgets can use this login")
                : wallet.errorString

            if (success)
                page.fetchGrowspaces()
        }

        onClearFinished: function(success) {
            if (success) {
                accessToken.text = ""
                page.walletStatus = i18n("Shared Home Assistant credentials removed")
                growspaceSocket.active = false
                growspaceModel.clear()
                growspaceModel.append({
                    "growspaceId": "",
                    "displayName": i18n("Automatic (first available)"),
                    "growspaceType": ""
                })
                growspaceSelector.currentIndex = 0
                page.growspaceStatusError = false
                page.growspaceStatus = i18n("Waiting for Home Assistant credentials…")
            } else {
                page.walletStatus = wallet.errorString
            }
        }
    }

    ListModel {
        id: growspaceModel

        ListElement {
            growspaceId: ""
            displayName: qsTr("Automatic (first available)")
            growspaceType: ""
        }
    }

    WebSocket {
        id: growspaceSocket
        active: false

        onTextMessageReceived: function(message) {
            var payload
            try {
                payload = JSON.parse(message)
            } catch (error) {
                page.growspacesLoading = false
                page.growspaceStatusError = true
                page.growspaceStatus = i18n("Home Assistant returned an invalid WebSocket response.")
                active = false
                return
            }

            if (payload.type === "auth_required") {
                sendTextMessage(JSON.stringify({
                    "type": "auth",
                    "access_token": wallet.token
                }))
                return
            }

            if (payload.type === "auth_ok") {
                var id = page.nextMessageId++
                page.dataRequestId = id
                sendTextMessage(JSON.stringify({
                    "id": id,
                    "type": "growspace_manager/get_data"
                }))
                return
            }

            if (payload.type === "auth_invalid") {
                page.growspacesLoading = false
                page.growspaceStatusError = true
                page.growspaceStatus = payload.message || i18n("Home Assistant rejected the KWallet access token.")
                active = false
                return
            }

            if (payload.type === "result" && payload.id === page.dataRequestId) {
                if (payload.success) {
                    page.rebuildGrowspaceModel(payload.result || {})
                } else {
                    page.growspacesLoading = false
                    page.growspaceStatusError = true
                    page.growspaceStatus = payload.error && payload.error.message
                        ? payload.error.message
                        : i18n("Could not fetch Growspace Manager growspaces.")
                }
                active = false
            }
        }

        onStatusChanged: {
            if (status === WebSocket.Error) {
                page.growspacesLoading = false
                page.growspaceStatusError = true
                page.growspaceStatus = errorString || i18n("Could not connect to Home Assistant.")
            } else if (status === WebSocket.Closed && page.growspacesLoading && page.dataRequestId === 0) {
                page.growspacesLoading = false
                page.growspaceStatusError = true
                page.growspaceStatus = i18n("Connection to Home Assistant closed before growspaces were loaded.")
            }
        }
    }

    Component.onCompleted: wallet.load()

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        text: i18n("Shared Home Assistant login")
        level: 3
    }

    QQC2.TextField {
        id: haUrl
        Kirigami.FormData.label: i18n("Home Assistant URL:")
        placeholderText: "http://homeassistant.local:8123"
        inputMethodHints: Qt.ImhUrlCharactersOnly
        enabled: !wallet.busy
    }

    QQC2.TextField {
        id: accessToken
        Kirigami.FormData.label: i18n("Long-lived access token:")
        placeholderText: i18n("Paste Home Assistant token")
        echoMode: TextInput.Password
        enabled: !wallet.busy
    }

    Kirigami.InlineMessage {
        Kirigami.FormData.isSection: true
        Layout.fillWidth: true
        visible: true
        type: wallet.errorString.length > 0
            ? Kirigami.MessageType.Error
            : Kirigami.MessageType.Positive
        text: page.walletStatus
    }

    RowLayout {
        Kirigami.FormData.isSection: true

        QQC2.Button {
            text: wallet.busy ? i18n("Saving…") : i18n("Save shared login")
            icon.name: "kwalletmanager"
            enabled: !wallet.busy && accessToken.text.trim().length > 0
            onClicked: {
                var url = haUrl.text.trim()
                if (url.length === 0) {
                    url = "http://homeassistant.local:8123"
                    haUrl.text = url
                }
                wallet.saveCredentials(url, accessToken.text.trim())
            }
        }

        QQC2.Button {
            text: i18n("Forget login")
            icon.name: "edit-delete"
            enabled: !wallet.busy && wallet.hasCredentials
            onClicked: wallet.clearCredentials()
        }
    }

    Kirigami.Separator {
        Kirigami.FormData.isSection: true
        Layout.fillWidth: true
    }

    Kirigami.Heading {
        Kirigami.FormData.isSection: true
        text: i18n("This widget")
        level: 3
    }

    QQC2.ComboBox {
        id: growspaceSelector
        Kirigami.FormData.label: i18n("Growspace:")
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        model: growspaceModel
        textRole: "displayName"
        enabled: !page.growspacesLoading && growspaceModel.count > 0

        onActivated: function(index) {
            if (index < 0 || index >= growspaceModel.count)
                return
            page.cfg_growspaceId = growspaceModel.get(index).growspaceId
        }
    }

    RowLayout {
        Kirigami.FormData.isSection: true
        Layout.fillWidth: true

        QQC2.Label {
            Layout.fillWidth: true
            text: page.growspaceStatus
            color: page.growspaceStatusError
                ? Kirigami.Theme.negativeTextColor
                : Kirigami.Theme.textColor
            opacity: page.growspaceStatusError ? 1.0 : 0.7
            wrapMode: Text.WordWrap
        }

        QQC2.Button {
            text: i18n("Refresh")
            icon.name: "view-refresh"
            enabled: wallet.hasCredentials && !page.growspacesLoading
            onClicked: page.fetchGrowspaces()
        }
    }

    QQC2.SpinBox {
        id: refreshInterval
        Kirigami.FormData.label: i18n("Refresh interval:")
        from: 10
        to: 3600
        stepSize: 5
        editable: true

        textFromValue: function(value) {
            return i18np("%1 second", "%1 seconds", value)
        }

        valueFromText: function(text) {
            var parsed = parseInt(text)
            return isNaN(parsed) ? 30 : parsed
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
        text: i18n("Home Assistant credentials are shared through KWallet. This widget stores only the selected growspace and its display/refresh settings.")
    }
}

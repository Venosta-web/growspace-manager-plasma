import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import "native" as NativeWallet

Kirigami.FormLayout {
    id: page

    property alias cfg_growspaceId: growspaceId.text
    property alias cfg_refreshInterval: refreshInterval.value
    property alias cfg_autoConnect: autoConnect.checked

    property bool walletLoaded: false
    property string walletStatus: i18n("Loading shared credentials…")

    NativeWallet.WalletStore {
        id: wallet

        onLoadFinished: function(success) {
            page.walletLoaded = success
            if (!success) {
                page.walletStatus = wallet.errorString
                return
            }

            haUrl.text = wallet.url.length > 0
                ? wallet.url
                : "http://homeassistant.local:8123"
            accessToken.text = wallet.token
            page.walletStatus = wallet.hasCredentials
                ? i18n("Shared credentials loaded from KWallet")
                : i18n("No shared credentials saved yet")
        }

        onSaveFinished: function(success) {
            page.walletLoaded = success
            page.walletStatus = success
                ? i18n("Saved securely in KWallet — all Growspace widgets can use this login")
                : wallet.errorString
        }

        onClearFinished: function(success) {
            if (success) {
                accessToken.text = ""
                page.walletStatus = i18n("Shared Home Assistant credentials removed")
            } else {
                page.walletStatus = wallet.errorString
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

    QQC2.TextField {
        id: growspaceId
        Kirigami.FormData.label: i18n("Growspace ID:")
        placeholderText: i18n("Optional — blank selects the first growspace")
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
        text: i18n("The Home Assistant URL and token are shared through KWallet. Growspace ID and refresh settings remain unique to each widget.")
    }
}

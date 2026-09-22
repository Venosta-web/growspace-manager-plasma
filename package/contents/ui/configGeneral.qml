import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_haUrl: haUrl.text
    property alias cfg_accessToken: accessToken.text
    property alias cfg_growspaceId: growspaceId.text
    property alias cfg_refreshInterval: refreshInterval.value
    property alias cfg_autoConnect: autoConnect.checked

    function persistConnectionSettings() {
        var url = haUrl.text.trim()
        if (url.length === 0) {
            url = "http://homeassistant.local:8123"
            haUrl.text = url
        }

        plasmoid.configuration.haUrl = url
        plasmoid.configuration.accessToken = accessToken.text.trim()
        plasmoid.configuration.growspaceId = growspaceId.text.trim()
        plasmoid.configuration.refreshInterval = refreshInterval.value
        plasmoid.configuration.autoConnect = autoConnect.checked
    }

    QQC2.TextField {
        id: haUrl
        Kirigami.FormData.label: i18n("Home Assistant URL:")
        placeholderText: "http://homeassistant.local:8123"
        inputMethodHints: Qt.ImhUrlCharactersOnly
        onEditingFinished: page.persistConnectionSettings()
    }

    QQC2.TextField {
        id: accessToken
        Kirigami.FormData.label: i18n("Long-lived access token:")
        placeholderText: i18n("Paste Home Assistant token")
        echoMode: TextInput.Password
        onEditingFinished: page.persistConnectionSettings()
    }

    Kirigami.InlineMessage {
        Kirigami.FormData.isSection: true
        Layout.fillWidth: true
        visible: true
        type: Kirigami.MessageType.Warning
        text: i18n("Development build: the token is stored in your local Plasma configuration and is not encrypted yet. KWallet support is planned before a stable release.")
    }

    QQC2.TextField {
        id: growspaceId
        Kirigami.FormData.label: i18n("Growspace ID:")
        placeholderText: i18n("Optional — blank selects the first growspace")
        onEditingFinished: page.persistConnectionSettings()
    }

    QQC2.SpinBox {
        id: refreshInterval
        Kirigami.FormData.label: i18n("Refresh interval:")
        from: 10
        to: 3600
        stepSize: 5
        editable: true
        onValueModified: page.persistConnectionSettings()

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
        onToggled: page.persistConnectionSettings()
    }

    QQC2.Button {
        Kirigami.FormData.isSection: true
        text: i18n("Save and connect")
        icon.name: "network-connect"
        onClicked: page.persistConnectionSettings()
    }

    QQC2.Label {
        Kirigami.FormData.isSection: true
        text: i18n("Loaded locally: URL %1 · token %2 characters",
                   haUrl.text.trim().length > 0 ? "✓" : "✗",
                   accessToken.text.trim().length)
        opacity: 0.7
    }
}

import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Rectangle {
    id: root

    property var tank: ({})

    readonly property var rawLevel: tank && tank.fill_level !== undefined ? tank.fill_level : null
    readonly property bool hasLevel: rawLevel !== null && rawLevel !== undefined && !isNaN(Number(rawLevel))
    readonly property real level: hasLevel ? Math.max(0, Math.min(100, Number(rawLevel))) : 0
    readonly property real warningLevel: tank && tank.warning_level !== undefined
        ? Number(tank.warning_level)
        : 0
    readonly property bool warning: tank && tank.is_warning === true
        || (hasLevel && !isNaN(warningLevel) && level <= warningLevel)
    readonly property real capacityLiters: tank && tank.volume_liters !== null
        && tank.volume_liters !== undefined ? Number(tank.volume_liters) : NaN
    readonly property real currentLiters: hasLevel && !isNaN(capacityLiters)
        ? capacityLiters * level / 100.0
        : NaN
    readonly property color liquidColor: warning
        ? Kirigami.Theme.negativeTextColor
        : Kirigami.Theme.highlightColor

    implicitHeight: 118
    implicitWidth: 178
    radius: Kirigami.Units.smallSpacing
    color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
                   Kirigami.Theme.backgroundColor.g,
                   Kirigami.Theme.backgroundColor.b, 0.55)
    border.width: 1
    border.color: warning
        ? Qt.rgba(Kirigami.Theme.negativeTextColor.r,
                  Kirigami.Theme.negativeTextColor.g,
                  Kirigami.Theme.negativeTextColor.b, 0.65)
        : Qt.rgba(Kirigami.Theme.textColor.r,
                  Kirigami.Theme.textColor.g,
                  Kirigami.Theme.textColor.b, 0.12)

    function displayName(value) {
        var words = String(value || qsTr("Tank")).replace(/_/g, " ").split(" ")
        for (var i = 0; i < words.length; ++i) {
            if (words[i].length > 0)
                words[i] = words[i].charAt(0).toUpperCase() + words[i].slice(1)
        }
        return words.join(" ")
    }

    function depletionText() {
        if (!tank)
            return ""

        var state = String(tank.depletion_status || "")
        var status = ""
        if (state === "depleting")
            status = qsTr("↓ Depleting")
        else if (state === "refilling")
            status = qsTr("↑ Refilling")
        else if (state === "static" || state === "normal")
            status = qsTr("— Stable")

        var hours = tank.hours_remaining
        var remaining = ""
        if (hours !== null && hours !== undefined && !isNaN(Number(hours))) {
            var n = Number(hours)
            remaining = n >= 48
                ? qsTr("%1d left").arg(Math.floor(n / 24))
                : qsTr("%1h left").arg(Math.round(n))
        }

        if (status.length > 0 && remaining.length > 0)
            return status + " · " + remaining
        return status.length > 0 ? status : remaining
    }

    function litersText() {
        if (isNaN(capacityLiters))
            return ""
        if (isNaN(currentLiters))
            return qsTr("%1 L tank").arg(capacityLiters.toFixed(0))
        return qsTr("%1 / %2 L").arg(currentLiters.toFixed(1)).arg(capacityLiters.toFixed(0))
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.largeSpacing

        Item {
            id: vessel
            Layout.preferredWidth: 54
            Layout.fillHeight: true
            Layout.topMargin: 4
            Layout.bottomMargin: 4

            Rectangle {
                id: cap
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                width: 24
                height: 7
                radius: 2
                color: Qt.rgba(Kirigami.Theme.textColor.r,
                               Kirigami.Theme.textColor.g,
                               Kirigami.Theme.textColor.b, 0.28)
            }

            Rectangle {
                id: tankBody
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: cap.bottom
                anchors.topMargin: -1
                anchors.bottom: parent.bottom
                width: 50
                radius: 7
                color: Qt.rgba(Kirigami.Theme.textColor.r,
                               Kirigami.Theme.textColor.g,
                               Kirigami.Theme.textColor.b, 0.07)
                border.width: 1
                border.color: warning
                    ? Qt.rgba(Kirigami.Theme.negativeTextColor.r,
                              Kirigami.Theme.negativeTextColor.g,
                              Kirigami.Theme.negativeTextColor.b, 0.8)
                    : Qt.rgba(Kirigami.Theme.textColor.r,
                              Kirigami.Theme.textColor.g,
                              Kirigami.Theme.textColor.b, 0.24)
                clip: true

                Rectangle {
                    id: water
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 3
                    anchors.rightMargin: 3
                    anchors.bottomMargin: 3
                    height: root.hasLevel
                        ? Math.max(2, (tankBody.height - 6) * root.level / 100.0)
                        : 0
                    color: Qt.rgba(root.liquidColor.r,
                                   root.liquidColor.g,
                                   root.liquidColor.b, 0.72)

                    Behavior on height {
                        NumberAnimation {
                            duration: 900
                            easing.type: Easing.OutCubic
                        }
                    }

                    Item {
                        id: surface
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        height: 8
                        clip: true

                        Row {
                            id: waves
                            y: -3
                            spacing: -4

                            Repeater {
                                model: 5

                                Rectangle {
                                    width: 18
                                    height: 8
                                    radius: 9
                                    color: Qt.rgba(1, 1, 1, 0.16)
                                }
                            }

                            NumberAnimation on x {
                                from: -14
                                to: 0
                                duration: 1800
                                loops: Animation.Infinite
                                easing.type: Easing.InOutSine
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 4
                    height: parent.height * 0.38
                    radius: 5
                    color: Qt.rgba(1, 1, 1, 0.045)
                }

                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: root.hasLevel ? Math.round(root.level) + "%" : qsTr("N/A")
                    font.bold: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize + 1
                    color: Kirigami.Theme.textColor
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 2

            RowLayout {
                Layout.fillWidth: true

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: root.displayName(root.tank ? root.tank.name : "")
                    font.bold: true
                    elide: Text.ElideRight
                }

                PlasmaComponents.Label {
                    visible: root.warning
                    text: "⚠"
                    color: Kirigami.Theme.negativeTextColor
                    font.bold: true
                }
            }

            PlasmaComponents.Label {
                visible: root.litersText().length > 0
                text: root.litersText()
                opacity: 0.78
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }

            PlasmaComponents.Label {
                visible: root.depletionText().length > 0
                text: root.depletionText()
                color: root.warning
                    ? Kirigami.Theme.negativeTextColor
                    : Kirigami.Theme.textColor
                opacity: root.warning ? 1.0 : 0.70
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true

                PlasmaComponents.Label {
                    text: root.hasLevel
                        ? qsTr("Level %1%").arg(root.level.toFixed(0))
                        : qsTr("Sensor unavailable")
                    opacity: 0.62
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }

                Item { Layout.fillWidth: true }

                PlasmaComponents.Label {
                    visible: !isNaN(root.warningLevel) && root.warningLevel > 0
                    text: qsTr("Low ≤ %1%").arg(root.warningLevel.toFixed(0))
                    color: root.warning
                        ? Kirigami.Theme.negativeTextColor
                        : Kirigami.Theme.disabledTextColor
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                }
            }
        }
    }
}

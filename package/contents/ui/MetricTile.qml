import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Rectangle {
    id: tile

    property string title: ""
    property string value: "—"
    property string detail: ""
    property string iconName: "view-statistics"
    property bool accentDetail: false

    implicitWidth: 112
    implicitHeight: 76
    radius: 8

    color: Qt.rgba(
        Kirigami.Theme.textColor.r,
        Kirigami.Theme.textColor.g,
        Kirigami.Theme.textColor.b,
        0.045
    )

    RowLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 8

        Kirigami.Icon {
            source: tile.iconName
            implicitWidth: 18
            implicitHeight: 18
            opacity: 0.72
            Layout.alignment: Qt.AlignTop
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            PlasmaComponents.Label {
                text: tile.title
                opacity: 0.58
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                text: tile.value
                font.bold: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 3
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                visible: tile.detail.length > 0
                text: tile.detail
                color: tile.accentDetail
                    ? Kirigami.Theme.positiveTextColor
                    : Kirigami.Theme.textColor
                opacity: tile.accentDetail ? 0.95 : 0.50
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }
}

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

    implicitWidth: 112
    implicitHeight: 82
    radius: Kirigami.Units.smallSpacing
    color: Kirigami.Theme.backgroundColor
    border.width: 1
    border.color: Kirigami.Theme.disabledTextColor

    RowLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing * 1.5
        spacing: Kirigami.Units.smallSpacing

        Kirigami.Icon {
            source: tile.iconName
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: implicitWidth
            Layout.alignment: Qt.AlignTop
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            PlasmaComponents.Label {
                text: tile.title
                opacity: 0.72
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                text: tile.value
                font.bold: true
                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 2
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                visible: tile.detail.length > 0
                text: tile.detail
                opacity: 0.62
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }
}

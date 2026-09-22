import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Rectangle {
    id: root

    property string iconName: "dialog-information"
    property string label: ""
    property string value: "—"
    property bool active: false
    property bool unavailable: value === "—"

    implicitHeight: 30
    implicitWidth: content.implicitWidth + Kirigami.Units.smallSpacing * 3
    radius: height / 2

    color: active
        ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                  Kirigami.Theme.highlightColor.g,
                  Kirigami.Theme.highlightColor.b, 0.13)
        : Qt.rgba(Kirigami.Theme.textColor.r,
                  Kirigami.Theme.textColor.g,
                  Kirigami.Theme.textColor.b, 0.045)

    border.width: 1
    border.color: active
        ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                  Kirigami.Theme.highlightColor.g,
                  Kirigami.Theme.highlightColor.b, 0.42)
        : Qt.rgba(Kirigami.Theme.textColor.r,
                  Kirigami.Theme.textColor.g,
                  Kirigami.Theme.textColor.b, 0.12)

    RowLayout {
        id: content
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        spacing: 4

        Kirigami.Icon {
            source: root.iconName
            implicitWidth: 16
            implicitHeight: 16
            opacity: root.unavailable ? 0.45 : 0.9
        }

        PlasmaComponents.Label {
            text: root.label
            opacity: 0.65
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }

        PlasmaComponents.Label {
            text: root.value
            font.bold: true
            color: root.active ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
            opacity: root.unavailable ? 0.5 : 1.0
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
    }
}

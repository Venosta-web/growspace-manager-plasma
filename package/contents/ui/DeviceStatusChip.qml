import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

Rectangle {
    id: root

    property url iconName: ""
    property string label: ""
    property string value: "—"
    property bool active: false
    property bool unavailable: value === "—"

    implicitHeight: 28
    implicitWidth: content.implicitWidth + 18
    radius: 7

    color: active
        ? Qt.rgba(Kirigami.Theme.highlightColor.r,
                  Kirigami.Theme.highlightColor.g,
                  Kirigami.Theme.highlightColor.b, 0.12)
        : Qt.rgba(Kirigami.Theme.textColor.r,
                  Kirigami.Theme.textColor.g,
                  Kirigami.Theme.textColor.b, 0.035)

    border.width: active ? 1 : 0
    border.color: Qt.rgba(Kirigami.Theme.highlightColor.r,
                         Kirigami.Theme.highlightColor.g,
                         Kirigami.Theme.highlightColor.b, 0.28)

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 5

        Kirigami.Icon {
            source: root.iconName
            color: root.active ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
            implicitWidth: 15
            implicitHeight: 15
            opacity: root.unavailable ? 0.35 : (root.active ? 1.0 : 0.62)

            RotationAnimator on rotation {
                running: root.active && (root.label === qsTr("Circulation") || root.label === qsTr("Exhaust"))
                from: 0
                to: 360
                duration: 5000
                loops: Animation.Infinite
            }
        }

        PlasmaComponents.Label {
            text: root.label
            opacity: 0.54
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }

        PlasmaComponents.Label {
            text: root.value
            font.bold: true
            color: root.active ? Kirigami.Theme.highlightColor : Kirigami.Theme.textColor
            opacity: root.unavailable ? 0.42 : 0.92
            font.pointSize: Kirigami.Theme.smallFont.pointSize
        }
    }
}

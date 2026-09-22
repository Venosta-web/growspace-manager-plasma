import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation

    compactRepresentation: PlasmaComponents.Label {
        text: "🌱 Growspace"
    }

    fullRepresentation: ColumnLayout {
        spacing: 8

        PlasmaComponents.Label {
            text: "Growspace Manager"
            font.bold: true
            font.pointSize: 16
        }

        PlasmaComponents.Label {
            text: "Plasma 6 prototype — Home Assistant connection coming next."
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}

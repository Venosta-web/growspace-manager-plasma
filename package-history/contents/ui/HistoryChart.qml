import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root

    property var points: []
    property string unit: ""
    property bool stepMode: false
    property var fixedMin: null
    property var fixedMax: null
    property real minimumSpan: 1

    property var hoverPoint: null
    property real hoverX: -1

    readonly property double endMs: Date.now()
    readonly property double startMs: endMs - 24 * 60 * 60 * 1000

    function domain() {
        if (fixedMin !== null && fixedMin !== undefined
                && fixedMax !== null && fixedMax !== undefined)
            return { min: Number(fixedMin), max: Number(fixedMax) }

        if (!points || points.length === 0)
            return { min: 0, max: minimumSpan }

        var min = points[0].value
        var max = points[0].value
        for (var i = 1; i < points.length; ++i) {
            min = Math.min(min, points[i].value)
            max = Math.max(max, points[i].value)
        }

        var span = Math.max(max - min, minimumSpan)
        var center = (max + min) / 2
        var pad = span * 0.14
        return {
            min: center - span / 2 - pad,
            max: center + span / 2 + pad
        }
    }

    function formatValue(value) {
        if (stepMode && fixedMin === 0 && fixedMax === 1)
            return value >= 0.5 ? qsTr("On") : qsTr("Off")

        if (Math.abs(value) >= 100)
            return Math.round(value) + (unit ? " " + unit : "")
        if (Math.abs(value) >= 10)
            return value.toFixed(1) + (unit ? " " + unit : "")
        return value.toFixed(2) + (unit ? " " + unit : "")
    }

    function formatAxis(value) {
        if (stepMode && fixedMin === 0 && fixedMax === 1)
            return value >= 0.5 ? qsTr("On") : qsTr("Off")
        if (Math.abs(value) >= 100)
            return String(Math.round(value))
        if (Math.abs(value) >= 10)
            return value.toFixed(1)
        return value.toFixed(2)
    }

    function nearest(mouseX) {
        if (!points || points.length === 0 || plot.plotWidth <= 0)
            return null

        var ratio = Math.max(0, Math.min(1,
            (mouseX - plot.leftPadding) / plot.plotWidth))
        var target = startMs + ratio * (endMs - startMs)

        var nearestPoint = points[0]
        var distance = Math.abs(nearestPoint.timestamp - target)
        for (var i = 1; i < points.length; ++i) {
            var d = Math.abs(points[i].timestamp - target)
            if (d < distance) {
                distance = d
                nearestPoint = points[i]
            }
        }
        return nearestPoint
    }

    onPointsChanged: canvas.requestPaint()
    onUnitChanged: canvas.requestPaint()
    onStepModeChanged: canvas.requestPaint()
    onFixedMinChanged: canvas.requestPaint()
    onFixedMaxChanged: canvas.requestPaint()
    onMinimumSpanChanged: canvas.requestPaint()

    Item {
        id: plot
        anchors.fill: parent

        readonly property real leftPadding: 48
        readonly property real rightPadding: 14
        readonly property real topPadding: 14
        readonly property real bottomPadding: 30
        readonly property real plotWidth: Math.max(1, width - leftPadding - rightPadding)
        readonly property real plotHeight: Math.max(1, height - topPadding - bottomPadding)

        Canvas {
            id: canvas
            anchors.fill: parent
            renderTarget: Canvas.FramebufferObject

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                var d = root.domain()

                function xAt(timestamp) {
                    return plot.leftPadding
                        + ((timestamp - root.startMs) / (root.endMs - root.startMs))
                        * plot.plotWidth
                }

                function yAt(value) {
                    return plot.topPadding + plot.plotHeight
                        - ((value - d.min) / Math.max(0.00001, d.max - d.min))
                        * plot.plotHeight
                }

                ctx.font = "10px sans-serif"
                ctx.lineWidth = 1

                for (var i = 0; i <= 4; ++i) {
                    var fraction = i / 4
                    var y = plot.topPadding + fraction * plot.plotHeight

                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.075)
                    ctx.beginPath()
                    ctx.moveTo(plot.leftPadding, y)
                    ctx.lineTo(plot.leftPadding + plot.plotWidth, y)
                    ctx.stroke()

                    var value = d.max - fraction * (d.max - d.min)
                    ctx.fillStyle = Qt.rgba(1, 1, 1, 0.48)
                    ctx.textAlign = "right"
                    ctx.fillText(root.formatAxis(value), plot.leftPadding - 6, y + 3)
                }

                for (var h = 0; h <= 24; h += 6) {
                    var ts = root.startMs + h * 60 * 60 * 1000
                    var x = xAt(ts)

                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.045)
                    ctx.beginPath()
                    ctx.moveTo(x, plot.topPadding)
                    ctx.lineTo(x, plot.topPadding + plot.plotHeight)
                    ctx.stroke()

                    ctx.fillStyle = Qt.rgba(1, 1, 1, 0.42)
                    ctx.textAlign = h === 0 ? "left" : (h === 24 ? "right" : "center")
                    ctx.fillText(Qt.formatTime(new Date(ts), "HH:mm"), x, height - 7)
                }

                if (!root.points || root.points.length === 0)
                    return

                ctx.strokeStyle = Kirigami.Theme.highlightColor
                ctx.lineWidth = 2.4
                ctx.lineJoin = "round"
                ctx.lineCap = "round"
                ctx.beginPath()

                var started = false
                var previousY = 0

                for (var p = 0; p < root.points.length; ++p) {
                    var point = root.points[p]
                    if (point.timestamp < root.startMs || point.timestamp > root.endMs)
                        continue

                    var px = xAt(point.timestamp)
                    var py = yAt(point.value)

                    if (!started) {
                        ctx.moveTo(px, py)
                        started = true
                    } else if (root.stepMode) {
                        ctx.lineTo(px, previousY)
                        ctx.lineTo(px, py)
                    } else {
                        ctx.lineTo(px, py)
                    }
                    previousY = py
                }
                ctx.stroke()

                if (root.hoverPoint !== null) {
                    var hx = xAt(root.hoverPoint.timestamp)
                    var hy = yAt(root.hoverPoint.value)

                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.28)
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(hx, plot.topPadding)
                    ctx.lineTo(hx, plot.topPadding + plot.plotHeight)
                    ctx.stroke()

                    ctx.fillStyle = Kirigami.Theme.highlightColor
                    ctx.beginPath()
                    ctx.arc(hx, hy, 3.5, 0, Math.PI * 2)
                    ctx.fill()
                }
            }
        }

        Text {
            visible: !root.points || root.points.length === 0
            anchors.centerIn: parent
            text: qsTr("No history data for the last 24 hours")
            color: Kirigami.Theme.disabledTextColor
            font.pixelSize: 11
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            onPositionChanged: function(mouse) {
                root.hoverPoint = root.nearest(mouse.x)
                root.hoverX = mouse.x
                canvas.requestPaint()
            }

            onExited: {
                root.hoverPoint = null
                root.hoverX = -1
                canvas.requestPaint()
            }
        }

        Rectangle {
            visible: root.hoverPoint !== null
            x: Math.max(4, Math.min(parent.width - width - 4,
                root.hoverX > parent.width * 0.62
                    ? root.hoverX - width - 10
                    : root.hoverX + 10))
            y: 8
            implicitWidth: tooltipColumn.implicitWidth + 18
            implicitHeight: tooltipColumn.implicitHeight + 14
            radius: 7
            color: Kirigami.Theme.backgroundColor
            border.width: 1
            border.color: Qt.rgba(
                Kirigami.Theme.textColor.r,
                Kirigami.Theme.textColor.g,
                Kirigami.Theme.textColor.b, 0.18)

            Column {
                id: tooltipColumn
                anchors.centerIn: parent
                spacing: 2

                Text {
                    text: root.hoverPoint
                        ? Qt.formatDateTime(new Date(root.hoverPoint.timestamp), "ddd HH:mm")
                        : ""
                    color: Kirigami.Theme.textColor
                    font.bold: true
                    font.pixelSize: 11
                }

                Text {
                    text: root.hoverPoint ? root.formatValue(root.hoverPoint.value) : ""
                    color: Kirigami.Theme.textColor
                    font.pixelSize: 11
                }
            }
        }
    }
}

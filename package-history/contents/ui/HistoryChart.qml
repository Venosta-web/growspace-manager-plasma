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
    property var metricContext: ({ "hasContext": false })
    property var lightPoints: []

    property var hoverPoint: null
    property real hoverX: -1

    property double endMs: Date.now()
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

    onPointsChanged: {
        endMs = Date.now()
        canvas.requestPaint()
    }
    onUnitChanged: canvas.requestPaint()
    onStepModeChanged: canvas.requestPaint()
    onFixedMinChanged: canvas.requestPaint()
    onFixedMaxChanged: canvas.requestPaint()
    onMinimumSpanChanged: canvas.requestPaint()
    onMetricContextChanged: canvas.requestPaint()
    onLightPointsChanged: canvas.requestPaint()

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

                function semanticColor(status) {
                    if (status === "danger")
                        return Kirigami.Theme.negativeTextColor
                    if (status === "warning")
                        return Kirigami.Theme.neutralTextColor
                    if (status === "optimal")
                        return Kirigami.Theme.positiveTextColor
                    return Kirigami.Theme.highlightColor
                }

                function contextAt(timestamp) {
                    if (!root.metricContext || !root.metricContext.hasContext)
                        return null

                    if (root.metricContext.periodic === true) {
                        var period = "day"
                        if (root.lightPoints && root.lightPoints.length > 0) {
                            var candidate = root.lightPoints[0]
                            for (var lp = 0; lp < root.lightPoints.length; ++lp) {
                                if (root.lightPoints[lp].timestamp <= timestamp)
                                    candidate = root.lightPoints[lp]
                                else
                                    break
                            }
                            period = Number(candidate.value) > 0 ? "day" : "night"
                        } else {
                            period = root.metricContext.currentPeriod || "day"
                        }
                        return root.metricContext[period] || null
                    }

                    return root.metricContext
                }

                function statusAt(value, timestamp) {
                    if (!root.metricContext || !root.metricContext.hasContext)
                        return "neutral"

                    var n = Number(value)
                    if (isNaN(n))
                        return "neutral"

                    if (root.metricContext.periodic === true) {
                        var thresholds = contextAt(timestamp)
                        if (!thresholds)
                            return "neutral"
                        if (n < thresholds.dangerMin || n > thresholds.dangerMax)
                            return "danger"
                        if (n < thresholds.optimalMin || n > thresholds.optimalMax)
                            return "warning"
                        return "optimal"
                    }

                    var result = root.metricContext.safeStatus || "neutral"
                    var limits = root.metricContext.limits || []
                    for (var li = 0; li < limits.length; ++li) {
                        var limit = limits[li]
                        var crossed = limit.side === "lower"
                            ? n <= Number(limit.value)
                            : n >= Number(limit.value)
                        if (crossed) {
                            if (limit.status === "danger")
                                return "danger"
                            result = "warning"
                        }
                    }

                    var bands = root.metricContext.bands || []
                    if (bands.length > 0) {
                        var inBand = false
                        for (var bi = 0; bi < bands.length; ++bi) {
                            if (n >= Number(bands[bi].min) && n <= Number(bands[bi].max)) {
                                inBand = true
                                break
                            }
                        }
                        return inBand ? "optimal" : (result === "danger" ? "danger" : "warning")
                    }

                    return result
                }

                // Context bands and limits are drawn below the data trace.
                if (root.metricContext && root.metricContext.hasContext) {
                    if (root.metricContext.periodic === true) {
                        var sliceCount = 96
                        for (var sl = 0; sl < sliceCount; ++sl) {
                            var t0 = root.startMs + (root.endMs - root.startMs) * sl / sliceCount
                            var t1 = root.startMs + (root.endMs - root.startMs) * (sl + 1) / sliceCount
                            var th = contextAt((t0 + t1) / 2)
                            if (!th)
                                continue

                            var bandTop = yAt(th.optimalMax)
                            var bandBottom = yAt(th.optimalMin)
                            ctx.fillStyle = Qt.rgba(
                                Kirigami.Theme.positiveTextColor.r,
                                Kirigami.Theme.positiveTextColor.g,
                                Kirigami.Theme.positiveTextColor.b, 0.085)
                            ctx.fillRect(xAt(t0), bandTop, Math.max(1, xAt(t1) - xAt(t0)), bandBottom - bandTop)

                            ctx.strokeStyle = Qt.rgba(
                                Kirigami.Theme.negativeTextColor.r,
                                Kirigami.Theme.negativeTextColor.g,
                                Kirigami.Theme.negativeTextColor.b, 0.30)
                            ctx.lineWidth = 1
                            ctx.setLineDash([4, 4])
                            ctx.beginPath()
                            ctx.moveTo(xAt(t0), yAt(th.dangerMin))
                            ctx.lineTo(xAt(t1), yAt(th.dangerMin))
                            ctx.moveTo(xAt(t0), yAt(th.dangerMax))
                            ctx.lineTo(xAt(t1), yAt(th.dangerMax))
                            ctx.stroke()
                            ctx.setLineDash([])
                        }
                    } else {
                        var bands = root.metricContext.bands || []
                        for (var bb = 0; bb < bands.length; ++bb) {
                            var byTop = yAt(Number(bands[bb].max))
                            var byBottom = yAt(Number(bands[bb].min))
                            ctx.fillStyle = Qt.rgba(
                                Kirigami.Theme.positiveTextColor.r,
                                Kirigami.Theme.positiveTextColor.g,
                                Kirigami.Theme.positiveTextColor.b, 0.085)
                            ctx.fillRect(plot.leftPadding, byTop, plot.plotWidth, byBottom - byTop)
                        }

                        var limits = root.metricContext.limits || []
                        for (var ll = 0; ll < limits.length; ++ll) {
                            var ly = yAt(Number(limits[ll].value))
                            var lc = limits[ll].status === "danger"
                                ? Kirigami.Theme.negativeTextColor
                                : Kirigami.Theme.neutralTextColor
                            ctx.strokeStyle = Qt.rgba(lc.r, lc.g, lc.b, 0.56)
                            ctx.lineWidth = 1
                            ctx.setLineDash([5, 4])
                            ctx.beginPath()
                            ctx.moveTo(plot.leftPadding, ly)
                            ctx.lineTo(plot.leftPadding + plot.plotWidth, ly)
                            ctx.stroke()
                            ctx.setLineDash([])
                        }

                        var guides = root.metricContext.guides || []
                        for (var gg = 0; gg < guides.length; ++gg) {
                            var gy = yAt(Number(guides[gg].value))
                            ctx.strokeStyle = Qt.rgba(
                                Kirigami.Theme.highlightColor.r,
                                Kirigami.Theme.highlightColor.g,
                                Kirigami.Theme.highlightColor.b, 0.42)
                            ctx.lineWidth = 1
                            ctx.setLineDash([2, 4])
                            ctx.beginPath()
                            ctx.moveTo(plot.leftPadding, gy)
                            ctx.lineTo(plot.leftPadding + plot.plotWidth, gy)
                            ctx.stroke()
                            ctx.setLineDash([])
                        }
                    }
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

                ctx.lineWidth = 2.4
                ctx.lineJoin = "round"
                ctx.lineCap = "round"

                var previousPoint = null
                for (var p = 0; p < root.points.length; ++p) {
                    var point = root.points[p]
                    if (point.timestamp < root.startMs || point.timestamp > root.endMs)
                        continue

                    if (previousPoint === null) {
                        previousPoint = point
                        continue
                    }

                    var x0 = xAt(previousPoint.timestamp)
                    var y0 = yAt(previousPoint.value)
                    var x1 = xAt(point.timestamp)
                    var y1 = yAt(point.value)
                    var status = statusAt(point.value, point.timestamp)
                    ctx.strokeStyle = semanticColor(status)
                    ctx.beginPath()
                    ctx.moveTo(x0, y0)

                    if (root.stepMode) {
                        ctx.lineTo(x1, y0)
                        ctx.lineTo(x1, y1)
                    } else {
                        ctx.lineTo(x1, y1)
                    }

                    ctx.stroke()
                    previousPoint = point
                }

                if (root.points.length === 1) {
                    var only = root.points[0]
                    var oc = semanticColor(statusAt(only.value, only.timestamp))
                    ctx.fillStyle = oc
                    ctx.beginPath()
                    ctx.arc(xAt(only.timestamp), yAt(only.value), 3, 0, Math.PI * 2)
                    ctx.fill()
                }

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

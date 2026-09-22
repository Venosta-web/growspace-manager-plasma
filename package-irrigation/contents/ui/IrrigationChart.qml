import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root

    property var soilMoisture: []
    property var poreEc: []
    property var bulkEc: []
    property string lightsOn: ""
    property var targetVwc: null
    property var maintenanceDryback: null
    property bool showEc: true

    property var hoverSample: null
    property real hoverX: -1

    readonly property double dayMs: 24 * 60 * 60 * 1000
    readonly property double anchorMs: {
        var parsed = Date.parse(lightsOn)
        return isNaN(parsed) ? 0 : parsed - 2 * 60 * 60 * 1000
    }

    function numericPoints(series) {
        var result = []
        if (!series)
            return result

        for (var i = 0; i < series.length; ++i) {
            var item = series[i]
            if (!item || item.value === null || item.value === undefined)
                continue
            var value = Number(item.value)
            var timestamp = Date.parse(item.timestamp)
            if (isNaN(value) || isNaN(timestamp))
                continue
            if (anchorMs > 0 && (timestamp < anchorMs || timestamp > anchorMs + dayMs))
                continue
            result.push({ "timestamp": timestamp, "value": value })
        }
        return result
    }

    function lastValue(series) {
        var points = numericPoints(series)
        return points.length > 0 ? points[points.length - 1].value : null
    }

    function vwcDomain() {
        var values = numericPoints(soilMoisture).map(function(p) { return p.value })
        var target = Number(targetVwc)
        var dryback = Number(maintenanceDryback)

        if (!isNaN(target)) {
            values.push(target)
            if (!isNaN(dryback))
                values.push(target - dryback)
        }

        if (values.length === 0)
            return { "min": 0, "max": 100 }

        var lo = Math.min.apply(null, values)
        var hi = Math.max.apply(null, values)
        var span = Math.max(hi - lo, 4)
        var pad = Math.max(2, span * 0.18)

        return {
            "min": Math.max(0, lo - pad),
            "max": Math.min(100, hi + pad)
        }
    }

    function ecDomain() {
        var values = []
        var a = numericPoints(poreEc)
        var b = numericPoints(bulkEc)

        for (var i = 0; i < a.length; ++i) values.push(a[i].value)
        for (var j = 0; j < b.length; ++j) values.push(b[j].value)

        if (values.length === 0)
            return { "min": 0, "max": 5 }

        var lo = Math.min.apply(null, values)
        var hi = Math.max.apply(null, values)
        var span = Math.max(hi - lo, 0.6)
        var pad = Math.max(0.25, span * 0.18)
        return { "min": Math.max(0, lo - pad), "max": hi + pad }
    }

    function formatTime(ms) {
        return Qt.formatTime(new Date(ms), "HH:mm")
    }

    function nearestSample(mouseX) {
        if (anchorMs <= 0 || plot.width <= 0)
            return null

        var ratio = Math.max(0, Math.min(1, (mouseX - plot.leftPadding) / plot.plotWidth))
        var wanted = anchorMs + ratio * dayMs
        var vwc = numericPoints(soilMoisture)
        if (vwc.length === 0)
            return null

        var nearest = vwc[0]
        var best = Math.abs(nearest.timestamp - wanted)
        for (var i = 1; i < vwc.length; ++i) {
            var distance = Math.abs(vwc[i].timestamp - wanted)
            if (distance < best) {
                best = distance
                nearest = vwc[i]
            }
        }

        function nearestValue(series) {
            var points = numericPoints(series)
            if (points.length === 0)
                return null
            var point = points[0]
            var delta = Math.abs(point.timestamp - nearest.timestamp)
            for (var j = 1; j < points.length; ++j) {
                var d = Math.abs(points[j].timestamp - nearest.timestamp)
                if (d < delta) {
                    delta = d
                    point = points[j]
                }
            }
            return point.value
        }

        return {
            "timestamp": nearest.timestamp,
            "vwc": nearest.value,
            "pore": nearestValue(poreEc),
            "bulk": nearestValue(bulkEc)
        }
    }

    onSoilMoistureChanged: canvas.requestPaint()
    onPoreEcChanged: canvas.requestPaint()
    onBulkEcChanged: canvas.requestPaint()
    onLightsOnChanged: canvas.requestPaint()
    onTargetVwcChanged: canvas.requestPaint()
    onMaintenanceDrybackChanged: canvas.requestPaint()
    onShowEcChanged: canvas.requestPaint()

    Item {
        id: plot
        anchors.fill: parent

        readonly property real leftPadding: 42
        readonly property real rightPadding: root.showEc ? 42 : 12
        readonly property real topPadding: 14
        readonly property real bottomPadding: 28
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
                ctx.reset()
                ctx.clearRect(0, 0, width, height)

                var vDomain = root.vwcDomain()
                var eDomain = root.ecDomain()

                function xAt(timestamp) {
                    if (root.anchorMs <= 0)
                        return plot.leftPadding
                    return plot.leftPadding
                        + ((timestamp - root.anchorMs) / root.dayMs) * plot.plotWidth
                }

                function yVwc(value) {
                    return plot.topPadding + plot.plotHeight
                        - ((value - vDomain.min) / Math.max(0.001, vDomain.max - vDomain.min))
                        * plot.plotHeight
                }

                function yEc(value) {
                    return plot.topPadding + plot.plotHeight
                        - ((value - eDomain.min) / Math.max(0.001, eDomain.max - eDomain.min))
                        * plot.plotHeight
                }

                // Grid and Y labels
                ctx.font = "10px sans-serif"
                ctx.lineWidth = 1
                for (var i = 0; i <= 4; ++i) {
                    var f = i / 4
                    var y = plot.topPadding + f * plot.plotHeight
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.08)
                    ctx.beginPath()
                    ctx.moveTo(plot.leftPadding, y)
                    ctx.lineTo(plot.leftPadding + plot.plotWidth, y)
                    ctx.stroke()

                    var vLabel = vDomain.max - f * (vDomain.max - vDomain.min)
                    ctx.fillStyle = Qt.rgba(1, 1, 1, 0.52)
                    ctx.textAlign = "right"
                    ctx.fillText(vLabel.toFixed(0) + "%", plot.leftPadding - 6, y + 3)

                    if (root.showEc && (root.poreEc.length > 0 || root.bulkEc.length > 0)) {
                        var eLabel = eDomain.max - f * (eDomain.max - eDomain.min)
                        ctx.textAlign = "left"
                        ctx.fillText(eLabel.toFixed(1), plot.leftPadding + plot.plotWidth + 6, y + 3)
                    }
                }

                // Time grid: anchor, +6h, +12h, +18h, +24h.
                if (root.anchorMs > 0) {
                    for (var h = 0; h <= 24; h += 6) {
                        var timestamp = root.anchorMs + h * 60 * 60 * 1000
                        var x = xAt(timestamp)
                        ctx.strokeStyle = Qt.rgba(1, 1, 1, h === 0 || h === 24 ? 0.10 : 0.06)
                        ctx.beginPath()
                        ctx.moveTo(x, plot.topPadding)
                        ctx.lineTo(x, plot.topPadding + plot.plotHeight)
                        ctx.stroke()

                        ctx.fillStyle = Qt.rgba(1, 1, 1, 0.45)
                        ctx.textAlign = h === 0 ? "left" : (h === 24 ? "right" : "center")
                        ctx.fillText(root.formatTime(timestamp), x, height - 7)
                    }
                }

                function drawGuide(value, label, color) {
                    if (value === null || value === undefined || isNaN(Number(value)))
                        return
                    var y = yVwc(Number(value))
                    ctx.save()
                    ctx.setLineDash([5, 4])
                    ctx.strokeStyle = color
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(plot.leftPadding, y)
                    ctx.lineTo(plot.leftPadding + plot.plotWidth, y)
                    ctx.stroke()
                    ctx.setLineDash([])
                    ctx.fillStyle = color
                    ctx.textAlign = "left"
                    ctx.fillText(label, plot.leftPadding + 5, Math.max(plot.topPadding + 10, y - 4))
                    ctx.restore()
                }

                var target = Number(root.targetVwc)
                var dryback = Number(root.maintenanceDryback)
                if (!isNaN(target)) {
                    drawGuide(target, "Target " + target.toFixed(1) + "%", Kirigami.Theme.positiveTextColor)
                    if (!isNaN(dryback))
                        drawGuide(target - dryback,
                                  "P2 " + (target - dryback).toFixed(1) + "%",
                                  Kirigami.Theme.neutralTextColor)
                }

                function drawSeries(series, yFunction, color, widthPx) {
                    if (!series)
                        return
                    ctx.strokeStyle = color
                    ctx.lineWidth = widthPx
                    ctx.lineJoin = "round"
                    ctx.lineCap = "round"
                    ctx.beginPath()

                    var drawing = false
                    for (var i = 0; i < series.length; ++i) {
                        var item = series[i]
                        if (!item || item.value === null || item.value === undefined) {
                            drawing = false
                            continue
                        }

                        var value = Number(item.value)
                        var timestamp = Date.parse(item.timestamp)
                        if (isNaN(value) || isNaN(timestamp)
                                || root.anchorMs <= 0
                                || timestamp < root.anchorMs
                                || timestamp > root.anchorMs + root.dayMs) {
                            drawing = false
                            continue
                        }

                        var x = xAt(timestamp)
                        var y = yFunction(value)
                        if (!drawing) {
                            ctx.moveTo(x, y)
                            drawing = true
                        } else {
                            ctx.lineTo(x, y)
                        }
                    }
                    ctx.stroke()
                }

                drawSeries(root.soilMoisture, yVwc, Kirigami.Theme.highlightColor, 2.5)

                if (root.showEc) {
                    drawSeries(root.poreEc, yEc, Kirigami.Theme.positiveTextColor, 1.6)
                    drawSeries(root.bulkEc, yEc, Kirigami.Theme.neutralTextColor, 1.6)
                }

                // Current-time marker within the photoperiod day.
                var now = Date.now()
                if (root.anchorMs > 0 && now >= root.anchorMs && now <= root.anchorMs + root.dayMs) {
                    var nowX = xAt(now)
                    ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.36)
                    ctx.lineWidth = 1
                    ctx.beginPath()
                    ctx.moveTo(nowX, plot.topPadding)
                    ctx.lineTo(nowX, plot.topPadding + plot.plotHeight)
                    ctx.stroke()
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true

            onPositionChanged: function(mouse) {
                var sample = root.nearestSample(mouse.x)
                root.hoverSample = sample
                root.hoverX = mouse.x
            }

            onExited: {
                root.hoverSample = null
                root.hoverX = -1
            }
        }

        Rectangle {
            visible: root.hoverSample !== null
            x: Math.max(4, Math.min(parent.width - width - 4,
                                    root.hoverX > parent.width * 0.62
                                        ? root.hoverX - width - 10
                                        : root.hoverX + 10))
            y: 8
            width: tooltipColumn.implicitWidth + 18
            height: tooltipColumn.implicitHeight + 14
            radius: Kirigami.Units.smallSpacing
            color: Kirigami.Theme.backgroundColor
            border.width: 1
            border.color: Kirigami.Theme.disabledTextColor

            Column {
                id: tooltipColumn
                anchors.centerIn: parent
                spacing: 2

                Text {
                    text: root.hoverSample ? root.formatTime(root.hoverSample.timestamp) : ""
                    color: Kirigami.Theme.textColor
                    font.bold: true
                    font.pixelSize: 11
                }

                Text {
                    text: root.hoverSample ? "VWC  " + root.hoverSample.vwc.toFixed(1) + "%" : ""
                    color: Kirigami.Theme.textColor
                    font.pixelSize: 11
                }

                Text {
                    visible: root.showEc && root.hoverSample && root.hoverSample.pore !== null
                    text: root.hoverSample && root.hoverSample.pore !== null
                        ? "Pore EC  " + root.hoverSample.pore.toFixed(2) + " mS/cm"
                        : ""
                    color: Kirigami.Theme.textColor
                    font.pixelSize: 11
                }

                Text {
                    visible: root.showEc && root.hoverSample && root.hoverSample.bulk !== null
                    text: root.hoverSample && root.hoverSample.bulk !== null
                        ? "Bulk EC  " + root.hoverSample.bulk.toFixed(2) + " mS/cm"
                        : ""
                    color: Kirigami.Theme.textColor
                    font.pixelSize: 11
                }
            }
        }
    }
}

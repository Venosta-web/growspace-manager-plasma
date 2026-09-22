.pragma library

var DEFINITIONS = [
    { key: "temperature", title: "Temperature", unit: "°C", fields: ["temperature_sensors", "temperature_sensor"], minSpan: 4, step: false },
    { key: "humidity", title: "Humidity", unit: "%", fields: ["humidity_sensors", "humidity_sensor"], minSpan: 20, step: false },
    { key: "vpd", title: "VPD", unit: "kPa", fields: ["vpd_sensors", "vpd_sensor"], minSpan: 0.6, step: false },
    { key: "co2", title: "CO₂", unit: "ppm", fields: ["co2_sensors", "co2_sensor"], minSpan: 400, step: false },
    { key: "soil_moisture", title: "Soil Moisture", unit: "%", fields: ["soil_moisture_sensors", "soil_moisture_sensor"], minSpan: 20, step: false },
    { key: "light", title: "Light", unit: "", fields: ["light_sensors", "light_sensor", "growlight_entities"], minSpan: 1, step: true },
    { key: "exhaust", title: "Exhaust", unit: "", fields: ["exhaust_fan_entities", "exhaust_entity"], bundleField: "exhaust_fan_ac_infinity_devices", bundleKey: "speed_entity", minSpan: 10, step: false },
    { key: "circulation_fan", title: "Circulation Fan", unit: "", fields: ["circulation_fan_entities", "circulation_fan_entity"], bundleField: "circulation_fan_ac_infinity_devices", bundleKey: "speed_entity", minSpan: 10, step: false },
    { key: "humidifier", title: "Humidifier", unit: "", fields: ["humidifier_entities", "humidifier_entity"], bundleField: "humidifier_ac_infinity_devices", bundleKey: "speed_entity", minSpan: 10, step: false },
    { key: "dehumidifier", title: "Dehumidifier", unit: "", fields: ["dehumidifier_entities", "dehumidifier_entity"], bundleField: "dehumidifier_ac_infinity_devices", bundleKey: "speed_entity", minSpan: 1, step: true },
    { key: "substrate_temperature", title: "Substrate Temperature", unit: "°C", fields: ["substrate_temperature_sensors"], minSpan: 4, step: false },
    { key: "energy", title: "Energy", unit: "kWh", fields: ["energy_sensors"], minSpan: 5, step: false },
    { key: "power", title: "Power", unit: "W", fields: ["power_sensors"], minSpan: 500, step: false },
    { key: "ph", title: "pH", unit: "", fields: ["ph_sensors"], minSpan: 1, step: false },
    { key: "feed_ec", title: "Feed EC", unit: "mS/cm", fields: ["feed_ec_sensors"], minSpan: 1, step: false },
    { key: "bulk_ec", title: "Bulk EC", unit: "mS/cm", fields: ["bulk_ec_sensors"], minSpan: 1, step: false },
    { key: "pore_ec", title: "Pore EC", unit: "mS/cm", fields: ["pore_ec_sensors"], minSpan: 1, step: false },
    { key: "runoff_ec", title: "Runoff EC", unit: "mS/cm", fields: ["runoff_ec_sensors"], minSpan: 1, step: false },
    { key: "drain_volume", title: "Drain Volume", unit: "L", fields: ["drain_volume_sensors"], minSpan: 5, step: false },
    { key: "irrigation_flow", title: "Irrigation Flow", unit: "L/h", fields: ["irrigation_flow_sensors"], minSpan: 10, step: false }
]

function _array(value) {
    if (Array.isArray(value))
        return value
    if (value === null || value === undefined || value === "")
        return []
    return [value]
}

function _unique(values) {
    var result = []
    var seen = ({})
    for (var i = 0; i < values.length; ++i) {
        var id = String(values[i] || "").trim()
        if (id.length > 0 && !seen[id]) {
            seen[id] = true
            result.push(id)
        }
    }
    return result
}

function _definition(key) {
    for (var i = 0; i < DEFINITIONS.length; ++i) {
        if (DEFINITIONS[i].key === key)
            return DEFINITIONS[i]
    }
    return null
}

function _friendlyName(entityId, states) {
    var state = states && states[entityId] ? states[entityId] : null
    var attrs = state && state.attributes ? state.attributes : ({})
    return String(attrs.friendly_name || entityId)
}

function _unitFor(def, entityId, states) {
    var state = states && states[entityId] ? states[entityId] : null
    var attrs = state && state.attributes ? state.attributes : ({})
    var stateUnit = attrs.unit_of_measurement
    if (stateUnit !== undefined && stateUnit !== null && String(stateUnit).length > 0)
        return String(stateUnit)

    var domain = String(entityId).split(".")[0]
    if (domain === "fan")
        return "%"
    return def.unit || ""
}

function _shapeFor(def, entityId, states) {
    var state = states && states[entityId] ? states[entityId] : null
    var attrs = state && state.attributes ? state.attributes : ({})
    var domain = String(entityId).split(".")[0]
    var raw = state ? String(state.state || "") : ""
    var n = Number(raw)

    var step = def.step === true
    var axisMin = null
    var axisMax = null

    if (domain === "fan" && attrs.percentage !== undefined) {
        step = true
        axisMin = 0
        axisMax = 100
    } else if (domain === "switch" || domain === "binary_sensor" || domain === "humidifier" || raw === "on" || raw === "off") {
        step = true
        axisMin = 0
        axisMax = 1
    } else if (domain === "light" && (raw === "on" || raw === "off")) {
        step = true
        axisMin = 0
        axisMax = 1
    } else if ((def.key === "exhaust" || def.key === "circulation_fan" || def.key === "humidifier") && !isNaN(n) && n >= 0 && n <= 10) {
        axisMin = 0
        axisMax = 10
    }

    return { step: step, axisMin: axisMin, axisMax: axisMax }
}

function _isGraphable(entityId, states) {
    var state = states && states[entityId] ? states[entityId] : null
    if (!state)
        return false

    var raw = String(state.state || "")
    if (raw === "unknown" || raw === "unavailable")
        return true
    if (raw === "on" || raw === "off")
        return true
    if (!isNaN(Number(raw)))
        return true
    if (entityId.indexOf("fan.") === 0 && state.attributes && state.attributes.percentage !== undefined)
        return true
    return false
}

function optionsForGrowspace(growspace, states) {
    if (!growspace)
        return []

    var env = growspace.environment || ({})
    var irrigation = growspace.irrigation || ({})
    var irrigationConfig = irrigation.irrigation_config || ({})
    var options = []
    var used = ({})

    function pushOption(def, entityId, explicitTitle) {
        entityId = String(entityId || "").trim()
        if (!entityId || used[entityId] || !_isGraphable(entityId, states))
            return

        used[entityId] = true
        var shape = _shapeFor(def, entityId, states)
        options.push({
            metricKey: def.key,
            title: explicitTitle || def.title,
            entityId: entityId,
            friendlyName: _friendlyName(entityId, states),
            unit: _unitFor(def, entityId, states),
            step: shape.step,
            axisMin: shape.axisMin,
            axisMax: shape.axisMax,
            minSpan: def.minSpan || 1
        })
    }

    for (var i = 0; i < DEFINITIONS.length; ++i) {
        var def = DEFINITIONS[i]
        var ids = []

        for (var f = 0; f < def.fields.length; ++f)
            ids = ids.concat(_array(env[def.fields[f]]))

        if (def.bundleField) {
            var bundles = _array(env[def.bundleField])
            for (var b = 0; b < bundles.length; ++b) {
                var id = bundles[b] ? bundles[b][def.bundleKey] : ""
                if (id)
                    ids.push(id)
            }
        }

        ids = _unique(ids)
        for (var j = 0; j < ids.length; ++j)
            pushOption(def, ids[j])
    }

    var tankDef = { key: "irrigation_tank_level", title: "Tank Level", unit: "%", minSpan: 20, step: false }
    var tanks = _array(env.irrigation_tanks)
    for (var t = 0; t < tanks.length; ++t) {
        if (tanks[t] && tanks[t].sensor_entity)
            pushOption(tankDef, tanks[t].sensor_entity, tanks[t].name ? "Tank Level · " + String(tanks[t].name).replace(/_/g, " ") : "Tank Level")
    }

    var irrigationDef = { key: "irrigation", title: "Irrigation Pump", unit: "", minSpan: 1, step: true }
    pushOption(irrigationDef, irrigationConfig.irrigation_pump_entity)

    var drainDef = { key: "drain", title: "Drain Pump", unit: "", minSpan: 1, step: true }
    pushOption(drainDef, irrigationConfig.drain_pump_entity)

    // AC Infinity grow-light power is a useful actuator metric but is not one of
    // the Lovelace card's environmental sensor mappings.
    var growlightPowerDef = { key: "growlight_power", title: "Grow Light Power", unit: "", minSpan: 10, step: false }
    var growlightBundles = _array(env.growlight_ac_infinity_devices)
    for (var g = 0; g < growlightBundles.length; ++g) {
        if (growlightBundles[g] && growlightBundles[g].power_entity)
            pushOption(growlightPowerDef, growlightBundles[g].power_entity)
    }

    // Make multi-sensor categories unambiguous in the selector.
    var counts = ({})
    for (var c = 0; c < options.length; ++c)
        counts[options[c].title] = (counts[options[c].title] || 0) + 1

    for (var o = 0; o < options.length; ++o) {
        options[o].displayName = counts[options[o].title] > 1
            ? options[o].title + " — " + options[o].friendlyName
            : options[o].title
    }

    return options
}

function findOption(growspace, states, metricKey, entityId) {
    var options = optionsForGrowspace(growspace, states)
    for (var i = 0; i < options.length; ++i) {
        if (options[i].metricKey === metricKey && options[i].entityId === entityId)
            return options[i]
    }
    return options.length > 0 ? options[0] : null
}

function normalizeHistory(points, option) {
    var result = []
    if (!points || !option)
        return result

    var domain = String(option.entityId || "").split(".")[0]

    for (var i = 0; i < points.length; ++i) {
        var point = points[i] || ({})
        var raw = String(point.s === undefined || point.s === null ? "" : point.s)
        var attrs = point.a || ({})
        var value = NaN

        if (domain === "fan" && attrs.percentage !== undefined && attrs.percentage !== null)
            value = Number(attrs.percentage)
        else if (raw === "on")
            value = 1
        else if (raw === "off")
            value = 0
        else
            value = Number(raw)

        var timestamp = Date.parse(point.lu || "")
        if (!isNaN(value) && !isNaN(timestamp))
            result.push({ timestamp: timestamp, value: value })
    }

    result.sort(function(a, b) { return a.timestamp - b.timestamp })
    return result
}


function _finite(value) {
    var n = Number(value)
    return isNaN(n) ? null : n
}

function _band(minValue, maxValue, label) {
    var min = _finite(minValue)
    var max = _finite(maxValue)
    if (min === null || max === null || !(max > min))
        return null
    return { min: min, max: max, label: label || "Target" }
}

function _limit(value, side, status, label) {
    var n = _finite(value)
    if (n === null)
        return null
    return {
        value: n,
        side: side,
        status: status,
        label: label || (status === "danger" ? "Critical" : "Warning")
    }
}

function _guide(value, label, tolerance) {
    var n = _finite(value)
    if (n === null || n <= 0)
        return null
    var t = _finite(tolerance)
    return {
        value: n,
        label: label || "Setpoint",
        tolerance: t !== null && t > 0 ? t : null
    }
}

function _pushIf(array, value) {
    if (value)
        array.push(value)
}

function _fanGuides(context, env, metricKey) {
    var signal = metricKey === "temperature"
        ? "temperature"
        : (metricKey === "humidity" ? "humidity" : (metricKey === "vpd" ? "vpd" : ""))
    if (!signal)
        return

    var exhaust = env.exhaust_fan_config || ({})
    if (exhaust.enabled === true) {
        _pushIf(context.guides, _guide(
            exhaust[signal + "_target"],
            "Exhaust setpoint",
            exhaust[signal + "_tolerance"]
        ))
    }

    var circulation = env.circulation_fan_config || ({})
    if (circulation.enabled === true
            && String(circulation.regulation_mode || "") === signal) {
        _pushIf(context.guides, _guide(
            circulation[signal + "_target"],
            "Circulation setpoint",
            circulation[signal + "_tolerance"]
        ))
    }
}

function _stageCandidates(stage) {
    var raw = String(stage || "")
    var result = [raw]
    if (raw.indexOf("flower_") === 0)
        result.push("flower")
    if (raw.indexOf("veg_") === 0)
        result.push("veg")
    return result
}

function contextForOption(growspace, states, option) {
    var context = {
        hasContext: false,
        metricKey: option ? option.metricKey : "",
        unit: option ? option.unit : "",
        periodic: false,
        currentPeriod: "day",
        lightEntityId: "",
        bands: [],
        limits: [],
        guides: [],
        safeStatus: "neutral"
    }

    if (!growspace || !option)
        return context

    var env = growspace.environment || ({})
    var irrigation = growspace.irrigation || ({})
    var config = irrigation.irrigation_config || ({})
    var strategy = irrigation.irrigation_strategy || ({})
    var metrics = growspace.metrics || ({})
    var key = option.metricKey

    if (key === "vpd") {
        var dayBand = _band(metrics.day_vpd_target_min, metrics.day_vpd_target_max, "Day target")
        var nightBand = _band(metrics.night_vpd_target_min, metrics.night_vpd_target_max, "Night target")
        var dayDangerLow = _finite(metrics.day_vpd_danger_min)
        var dayDangerHigh = _finite(metrics.day_vpd_danger_max)
        var nightDangerLow = _finite(metrics.night_vpd_danger_min)
        var nightDangerHigh = _finite(metrics.night_vpd_danger_max)

        if (dayBand && nightBand && dayDangerLow !== null && dayDangerHigh !== null
                && nightDangerLow !== null && nightDangerHigh !== null) {
            context.periodic = true
            context.currentPeriod = metrics.is_day === false ? "night" : "day"
            context.day = {
                optimalMin: dayBand.min,
                optimalMax: dayBand.max,
                dangerMin: dayDangerLow,
                dangerMax: dayDangerHigh
            }
            context.night = {
                optimalMin: nightBand.min,
                optimalMax: nightBand.max,
                dangerMin: nightDangerLow,
                dangerMax: nightDangerHigh
            }

            var lightIds = _unique(
                _array(env.light_sensors)
                    .concat(_array(env.light_sensor))
                    .concat(_array(env.growlight_entities))
            )
            context.lightEntityId = lightIds.length > 0 ? lightIds[0] : ""
            context.hasContext = true
            context.safeStatus = "optimal"
        }

        _fanGuides(context, env, key)
        if (context.guides.length > 0)
            context.hasContext = true
        return context
    }

    if (key === "soil_moisture"
            && env.soil_moisture_band_compatible === true) {
        _pushIf(context.bands, _band(
            (env.soil_moisture_band || {}).min,
            (env.soil_moisture_band || {}).max,
            "Moisture target"
        ))
    }

    if (key === "pore_ec") {
        _pushIf(context.bands, _band(
            strategy.pore_ec_target_min,
            strategy.pore_ec_target_max,
            "Pore EC target"
        ))
    }

    if (key === "feed_ec") {
        var ranges = _array(config.ec_target_ranges)
        var candidates = _stageCandidates(metrics.granular_stage)
        for (var r = 0; r < ranges.length; ++r) {
            var range = ranges[r] || ({})
            if (candidates.indexOf(String(range.stage || "")) >= 0) {
                _pushIf(context.bands, _band(
                    range.feed_ec_min !== undefined ? range.feed_ec_min : range.min_ec,
                    range.feed_ec_max !== undefined ? range.feed_ec_max : range.max_ec,
                    "Feed EC target"
                ))
                break
            }
        }
    }

    if (key === "irrigation_tank_level") {
        var tanks = _array(env.irrigation_tanks)
        for (var t = 0; t < tanks.length; ++t) {
            var tank = tanks[t] || ({})
            if (String(tank.sensor_entity || "") === String(option.entityId || "")) {
                _pushIf(context.limits, _limit(
                    tank.warning_level,
                    "lower",
                    "warning",
                    "Low tank"
                ))
                context.safeStatus = "optimal"
                break
            }
        }
    }

    if (key === "runoff_ec") {
        _pushIf(context.limits, _limit(
            config.halt_on_runoff_ec_threshold,
            "upper",
            "danger",
            "Runoff EC halt"
        ))
        if (context.limits.length > 0)
            context.safeStatus = "optimal"
    }

    if (key === "temperature") {
        var fanConfigs = [
            env.circulation_fan_config || ({}),
            env.exhaust_fan_config || ({})
        ]
        for (var fc = 0; fc < fanConfigs.length; ++fc) {
            _pushIf(context.limits, _limit(
                fanConfigs[fc].critical_temp_low,
                "lower",
                "danger",
                "Critical low"
            ))
            _pushIf(context.limits, _limit(
                fanConfigs[fc].critical_temp_high,
                "upper",
                "danger",
                "Critical high"
            ))
        }
    }

    _fanGuides(context, env, key)

    context.hasContext = context.bands.length > 0
        || context.limits.length > 0
        || context.guides.length > 0

    return context
}

function normalizeAuxHistory(points, entityId) {
    return normalizeHistory(points, {
        entityId: entityId,
        step: true,
        axisMin: 0,
        axisMax: 1,
        unit: ""
    })
}

function periodForTimestamp(context, timestamp, lightPoints) {
    if (!context || context.periodic !== true)
        return "day"

    if (!lightPoints || lightPoints.length === 0)
        return context.currentPeriod || "day"

    var candidate = null
    for (var i = 0; i < lightPoints.length; ++i) {
        if (lightPoints[i].timestamp <= timestamp)
            candidate = lightPoints[i]
        else
            break
    }

    if (!candidate)
        candidate = lightPoints[0]

    return Number(candidate.value) > 0 ? "day" : "night"
}

function thresholdsForTimestamp(context, timestamp, lightPoints) {
    if (!context || context.periodic !== true)
        return null
    var period = periodForTimestamp(context, timestamp, lightPoints)
    return context[period] || context.day || null
}

function _crossedLimit(limit, value) {
    if (!limit)
        return false
    if (limit.side === "lower")
        return value <= limit.value
    return value >= limit.value
}

function statusForContext(context, value, timestamp, lightPoints) {
    var n = Number(value)
    if (!context || !context.hasContext || isNaN(n))
        return "neutral"

    if (context.periodic === true) {
        var thresholds = thresholdsForTimestamp(context, timestamp, lightPoints)
        if (!thresholds)
            return "neutral"
        if (n < thresholds.dangerMin || n > thresholds.dangerMax)
            return "danger"
        if (n < thresholds.optimalMin || n > thresholds.optimalMax)
            return "warning"
        return "optimal"
    }

    var result = context.safeStatus || "neutral"

    for (var i = 0; i < context.limits.length; ++i) {
        var limit = context.limits[i]
        if (_crossedLimit(limit, n)) {
            if (limit.status === "danger")
                return "danger"
            result = "warning"
        }
    }

    if (context.bands.length > 0) {
        var inBand = false
        for (var b = 0; b < context.bands.length; ++b) {
            if (n >= context.bands[b].min && n <= context.bands[b].max) {
                inBand = true
                break
            }
        }
        if (inBand)
            return "optimal"
        if (result !== "danger")
            return "warning"
    }

    return result
}

function statusLabel(status) {
    if (status === "optimal")
        return "Optimal"
    if (status === "warning")
        return "Warning"
    if (status === "danger")
        return "Danger"
    return ""
}

function _numberText(value) {
    var n = Number(value)
    if (isNaN(n))
        return ""
    if (Math.abs(n) >= 100)
        return String(Math.round(n))
    if (Math.abs(n) >= 10)
        return n.toFixed(1)
    return n.toFixed(2)
}

function contextSummary(context, unit) {
    if (!context || !context.hasContext)
        return ""

    var suffix = unit ? " " + unit : ""

    if (context.periodic === true) {
        var period = context.currentPeriod || "day"
        var t = context[period] || context.day
        if (t)
            return (period === "night" ? "Night" : "Day")
                + " target "
                + _numberText(t.optimalMin) + "–" + _numberText(t.optimalMax) + suffix
    }

    if (context.bands.length > 0) {
        var band = context.bands[0]
        return String(band.label || "Target") + " "
            + _numberText(band.min) + "–" + _numberText(band.max) + suffix
    }

    if (context.limits.length > 0) {
        if (context.limits.length >= 2) {
            var lower = null
            var upper = null
            for (var i = 0; i < context.limits.length; ++i) {
                if (context.limits[i].side === "lower")
                    lower = context.limits[i]
                if (context.limits[i].side === "upper")
                    upper = context.limits[i]
            }
            if (lower && upper)
                return "Critical range "
                    + _numberText(lower.value) + "–" + _numberText(upper.value) + suffix
        }

        var limit = context.limits[0]
        var symbol = limit.side === "lower" ? "≤ " : "≥ "
        return String(limit.label || "Limit") + " "
            + symbol + _numberText(limit.value) + suffix
    }

    if (context.guides.length > 0) {
        var guide = context.guides[0]
        return String(guide.label || "Setpoint") + " "
            + _numberText(guide.value) + suffix
    }

    return ""
}

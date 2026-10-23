.pragma library

var defaultStart = 23 * 60
var defaultEnd = 7 * 60

function validMinute(value) {
    return typeof value === 'number' && isFinite(value) && Math.floor(value) === value && value >= 0 && value < 1440
}

function validRange(start, end) {
    return validMinute(start) && validMinute(end) && start !== end
}

// Match the actual DatetimeRunner::refreshDatetime night path (not the generic
// Global::timer helper): start included, end excluded, including across midnight.
function inWindow(enabled, start, end, minute) {
    if (enabled !== true || !validRange(start, end) || !validMinute(minute)) return false
    return start > end ? minute >= start || minute < end : minute >= start && minute < end
}

function initialRange(start, end) {
    return validRange(start, end) ? [start, end] : [defaultStart, defaultEnd]
}

function formatMinute(value) {
    if (!validMinute(value)) return '--:--'
    var hour = Math.floor(value / 60)
    var minute = value % 60
    return (hour < 10 ? '0' : '') + hour + ':' + (minute < 10 ? '0' : '') + minute
}

function shifted(value, delta) {
    if (!validMinute(value) || !isFinite(delta) || Math.floor(delta) !== delta) return value
    return ((value + delta) % 1440 + 1440) % 1440
}

function setEnabled(timer, enabled) {
    if (!timer || typeof enabled !== 'boolean') return false
    if (!enabled) {
        if (timer.enabled) timer.enabled = false
        return true
    }
    var range = initialRange(timer.startMinutes, timer.endMinutes)
    return apply(timer, range[0], range[1], true)
}

// Only an explicit UI action calls this function. Loading the panel never writes
// native settings, auto/manual brightness or a duplicate schedule preference.
function apply(timer, start, end, enabled) {
    if (!timer || !validRange(start, end) || typeof enabled !== 'boolean') return false
    var changed = timer.startMinutes !== start || timer.endMinutes !== end
    // Prevent a transient enabled schedule with one old and one new endpoint.
    if (changed && timer.enabled) timer.enabled = false
    if (timer.startMinutes !== start) timer.startMinutes = start
    if (timer.endMinutes !== end) timer.endMinutes = end
    if (timer.enabled !== enabled) timer.enabled = enabled
    return true
}

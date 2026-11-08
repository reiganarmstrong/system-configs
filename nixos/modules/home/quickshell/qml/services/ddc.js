.pragma library
// Parsing for ddcutil's output, kept apart from the Brightness service so it
// can be tested without a monitor.

// `ddcutil detect` (normal output level) -> [{bus, output}], one per display
// that answers DDC/CI. `output` is the DRM connector without its card prefix
// ("card1-DP-3" -> "DP-3"), which is the name niri gives the output.
function parseDetect(text) {
    const displays = [];
    let current = null;
    for (const line of String(text).split("\n")) {
        if (/^\S/.test(line)) {
            // "Display 2" starts a usable display; "Invalid display",
            // "Phantom display" and the like start ones to skip.
            current = /^Display \d+/.test(line) ? {bus: -1, output: ""} : null;
            if (current)
                displays.push(current);
            continue;
        }
        if (!current)
            continue;
        const bus = line.match(/I2C bus:\s*\/dev\/i2c-(\d+)/);
        if (bus)
            current.bus = parseInt(bus[1]);
        const connector = line.match(/DRM[_ ]connector:\s*card\d+-(\S+)/);
        if (connector)
            current.output = connector[1];
    }
    return displays.filter(d => d.bus >= 0 && d.output !== "");
}

// Lines of "<bus> VCP 10 C <current> <max>" -> {bus: {current, max}}. A bus
// whose read failed is left out.
function parseLevels(text) {
    const levels = {};
    for (const line of String(text).split("\n")) {
        const m = line.match(/^(\d+)\s+VCP 10 C (\d+) (\d+)/);
        if (m && parseInt(m[3]) > 0)
            levels[m[1]] = {current: parseInt(m[2]), max: parseInt(m[3])};
    }
    return levels;
}

// The output the keys and slider act on: the focused one when it can be
// adjusted, otherwise the built-in panel.
function pickTarget(targets, focused) {
    if (focused && targets[focused])
        return focused;
    return targets.builtin ? "builtin" : "";
}

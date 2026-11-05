-- Motion: springy windows, quick eased fades and slides everywhere else.

hl.config({ animations = { enabled = true } })

hl.curve("easeOut", { type = "bezier", points = { {0.05, 0.7}, {0.1, 1} } })
hl.curve("easeIn", { type = "bezier", points = { {0.3, 0}, {0.8, 0.15} } })
hl.curve("smooth", { type = "bezier", points = { {0.2, 0}, {0, 1} } })
hl.curve("gentle", { type = "spring", mass = 1, stiffness = 210, dampening = 22 })
hl.curve("brisk", { type = "spring", mass = 1, stiffness = 320, dampening = 28 })

local function animate(leaf, speed, curve, style)
    local spec = { leaf = leaf, enabled = true, speed = speed, style = style }
    if curve == "gentle" or curve == "brisk" then
        spec.spring = curve
    else
        spec.bezier = curve
    end
    hl.animation(spec)
end

animate("windows", 5, "gentle")
animate("windowsIn", 4.5, "gentle", "popin 88%")
animate("windowsOut", 2, "easeIn", "popin 88%")
animate("windowsMove", 5, "brisk")
animate("border", 4, "smooth")
animate("fadeIn", 2.5, "smooth")
animate("fadeOut", 2, "easeIn")
animate("fade", 3, "smooth")
animate("layers", 3.5, "easeOut")
animate("layersIn", 3.5, "easeOut", "fade")
animate("layersOut", 2, "easeIn", "fade")
animate("workspaces", 4.5, "easeOut", "slide")
animate("specialWorkspace", 4.5, "easeOut", "slidevert")

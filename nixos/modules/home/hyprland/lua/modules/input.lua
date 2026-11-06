-- Keyboard, pointer and touchpad.

hl.config({
    input = {
        kb_layout = "us",
        -- Keyboard focus follows the pointer, but only when it crosses into
        -- another window, not when a window moves under a still pointer.
        follow_mouse = 1,
        mouse_refocus = false,
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            disable_while_typing = true,
            clickfinger_behavior = true,
        },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

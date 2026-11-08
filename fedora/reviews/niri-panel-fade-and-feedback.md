# Floating-panel fade and stable white Control Center feedback

The profile carries scoped Noctalia patches through a rebuild of Fedora's signed source RPM. Niri remains the compositor. Floating panels keep their existing glass and fullscreen stacking, with a stationary 150 ms fade replacing the edge wipe. Active Home shortcuts and the selected sidebar tab stay white in the dark theme, including while hovered. Press briefly dims that same light surface, preserving dark ink. Inactive shortcuts have a small dark press response before the actual on/off change.

The Control Center patch uses theme roles and the existing button palette API. It applies only at the shortcut style and sidebar update functions, so refreshes and theme changes retain it. Global Primary, headings, sliders, carets, destructive buttons and sidebar keyboard navigation retain upstream behavior. White hover also covers retained mouse input focus, preventing a tile from staying dim after the pointer leaves.

## Source and build guards

The role downloads the matching signed Fedora source RPM and checks its trusted signature before reading dependencies. The desktop account builds it with Fedora's original build, test, runtime asset and license steps. Every patch uses checked application plus a marker check. All patch and helper hashes contribute to the local RPM release. Local hash changes permit downgrades only after checking the upstream version remains the same, and the installed release must match exactly afterwards. Unchanged runs skip compilation. Disabling the custom package restores stock Noctalia through a scoped distro-sync.

A third patch fixes only the upstream UPower integration test fixture. Its fake battery originally unregistered its own D-Bus property handler inside that callback. The failure reproduced five times, with the debugger stopping in systemd's bus-slot disconnection. Deferring fixture unregistration until the callback returns passed five repeated runs with all original assertions intact. Installed battery code is unchanged.

## Review and runtime evidence

Claude Opus 5.5 at medium effort approved the fade after reviewing real slowed-motion frames. The first prototype left bare compositor blur after its pixels faded. Clearing blur below 40% card opacity removed that ghost. The final close restored checkerboard contrast to 68, 73 and 76 gray levels as the card faded, against 77 in the untouched background, instead of retaining the original blurred span of 8.

On the VM, the fade passed rapid opening and closing, reduced motion, Escape and outside-click dismissal. Control Center, clipboard, session and wallpaper menus stayed on Overlay above a fullscreen checkerboard. Fullscreen covered the Top-layer bar, and leaving fullscreen revealed the bar again. Fuzzel remained accessible above fullscreen. The display stayed at 1512×982, scale 1.

The Control Center design was revised by Opus after the user explicitly chose white active tiles with calmer hover and press feedback. The implementation keeps hover fully white, because Noctalia treats retained mouse input focus as hover too. Only the press response dims an active item, to 88% opacity.

Opus also approved the final white-selection captures and code. Rest and hover match, an active press stays light with dark ink, and an inactive press stays dark with light ink. Mouse toggles, sidebar clicks, keyboard sidebar navigation and live light/dark reload passed. The original Do Not Disturb state and display mode were restored after the tests.

Build and final package verification are recorded below when complete.

Physical Framework hardware, its fractional scale and actual browser video playback are outside this VM verification.

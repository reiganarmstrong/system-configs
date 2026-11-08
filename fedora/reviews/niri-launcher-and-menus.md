# Launcher grays and flush glass menus

Reviewed and tested on November 7, 2026, with Noctalia 5.4.1 and Niri 26.04 in the Fedora VM at 1512×982. Opus 5.5 at medium effort designed the changes and reviewed actual desktop captures. Codex implemented them, checked the upstream layout and color paths, and verified behavior. A separate Codex review found no blocking stability or reproducibility issues.

## Final configuration

The dark Graphite palette uses Primary `#a3a3a9` with OnPrimary `#0a0a0b`, and Secondary `#7c7c83`. This replaces the nearly white selected launcher row with medium gray and makes the focused search outline quieter. Light-backed icons remain distinct from the selection. Calculated contrast is 7.89:1 for selected-row titles and 4.67:1 for the native 70%-opacity subtitles. These figures describe the palette pairs, not a full accessibility audit.

Noctalia has no launcher-specific selection or search-ring color settings. The selected row uses Primary/OnPrimary, and the focused input ring uses Secondary. These shared roles also affect Settings selections, clipboard selections, active control-center tiles, sliders, headings and other focus rings. The approved gray keeps those readable. An earlier dark-gray/light-text proposal was rejected because it made headings and slider fills too dim. The terminal colors and light palette are unchanged.

The focused search ring cannot be removed through native configuration. `shell.input_borders = false` only affects unfocused fields, so that setting was not added. Search keeps automatic focus, typing and normal keyboard navigation. The active workspace pill uses a fixed `#f2f2f3` fill; Noctalia derives dark label text from that hex color.

Bar-relative menus use `shell.panel.floating_offset = 0`. Their top edges touch the bar while their native rounded corners, border, transparency and animations remain. This removes the strip of wallpaper between bar and menu, but does not create a seamless concave join. The launcher and polkit prompt stay centered and do not use this offset.

## Fullscreen finding

Native attached placement inherits the host bar's layer. With the existing Top-layer bar, fullscreen Ghostty covered attached control-center, clipboard and session panels. Noctalia reported the panels open, but they were invisible and Escape did not close them. The candidate was reverted. Although the layer advertised Exclusive keyboard interactivity, the probe's focused-window report remained Ghostty; the test does not establish an invisible keyboard grab.

The final menus retain floating placement on the Overlay layer, above fullscreen windows. The bar stays on Top, so fullscreen video can still cover it. No custom scripts, plugins, patches, per-monitor coordinates or shell-state tracking are installed.

## Verification

- The deployed selected-row, search-ring and workspace-pill pixels match `#a3a3a9`, `#7c7c83` and `#f2f2f3` respectively.
- Super+Space opens the centered launcher. Down/Up moves the selected row, typing `disks` filters to Disks, Enter launches the real app, and Escape closes the launcher. The test app was closed afterward.
- Clicking Network, Audio and Session opens the appropriate panel. Clicking outside dismisses the open menu. Home's active tile and session shortcut badges retain dark labels on gray.
- Home, Network and Session captures at scales 1, 1.25 and 1.5 show flush placement without an extra gap. Scale 1 was restored afterward.
- Over fullscreen Ghostty, Super+S, Super+Shift+V, Super+Shift+E and Super+Space all open visible Overlay panels. Escape closes each and returns focus to the still-fullscreen app. The disposable window was removed.
- A temporary native animation override confirmed the same final menu layout with animations disabled. The override was removed and animation was restored.
- Both `niri validate` and `noctalia config validate` pass. The full apply reports `ok=78 changed=2 failed=0`, and the unchanged rerun reports `ok=78 changed=0 failed=0`. The final `--check --diff` reports `ok=74 changed=0 failed=0`.

The role contains the final colors, menu spacing and workspace setting. The install guide maps the tracked sources and includes a Git-bundle transfer path for the unpublished branch. VM credentials, captures, probes and overrides remain ignored and are not dependencies of the laptop install. Physical Framework hardware and multi-monitor behavior still need verification on the laptop.

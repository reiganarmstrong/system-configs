# Floating glass menus and native fullscreen

The user prioritized automatic fullscreen behavior and glass over a physically joined dropdown. The profile restores the previously approved native floating-menu design, retaining the larger status icons, numbered workspaces, centered glass Fuzzel and hidden shell close buttons.

## Configuration

`bar.main.layer = "top"` lets Niri draw fullscreen windows over the bar. Control center, wallpaper and session use `floating` placement with an explicit `shell.panel.floating_layer = "overlay"`. Their existing `transparency_mode = "glass"`, border and shadow now apply independently of the solid bar. `floating_offset = 0` keeps menus close to it, while click anchoring remains enabled. Clipboard, Fuzzel and polkit stay centered and floating.

The result uses supported Noctalia settings. It needs no auto-hide shortcuts, compositor-state watcher, plugin or fork. The tradeoff is rounded floating cards instead of the former concave join. The bar remains solid black during ordinary desktop use.

## Live VM checks on November 7, 2026

- A disposable grayscale checkerboard window occupied the full 1512×982 output. Screenshots and sampled top-edge pixels confirmed that fullscreen covered the entire bar. The bar's layer remained Top.
- Super+S, Super+Shift+V and Super+Shift+E opened control center, clipboard and session above the fullscreen window. Wallpaper opened through native IPC. Every menu used the `noctalia-panel` Overlay surface, with no attached-panel surface. Escape closed each and returned focus to the same full-size fullscreen window.
- Fuzzel also appeared on Overlay above fullscreen and closed with Escape. Leaving fullscreen made the bar visible again.
- Normal clock, network, volume and session clicks opened their intended floating menus. Outside clicks dismissed each. Existing Noctalia shortcuts were unchanged.
- Glass was inspected over both the wallpaper and the checkerboard. In a blank panel strip, checker contrast fell from 77 gray levels in the background to 5 levels through the panel, and the native blur rule retains `xray false` so underlying windows contribute.
- The display mode and scale remained 1512×982 at scale 1. The probe window and temporary script were removed, and existing windows were left alone.
- The apply reports `ok=106 changed=1 failed=0`. The unchanged rerun reports `ok=106 changed=0 failed=0`, and `--check --diff` reports `ok=98 changed=0 failed=0`. Native Noctalia validation has zero warnings.

Claude Opus 5.5 at medium effort reviewed all eleven selected live captures and the configuration, approving glass, readability, placement and fullscreen behavior without revisions. The familiar empty space in short control-center tabs remains an upstream sizing choice.

This verifies compositor fullscreen stacking with a test window, rather than a particular browser video player. Physical Framework hardware and multiple monitors were not tested in this run.

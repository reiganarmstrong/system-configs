# Roomier status icons

On November 7, 2026, Claude Opus 5.5 at medium effort designed and separately reviewed larger, more widely spaced status icons. Codex implemented the native settings and checked the live VM.

## Change

The bar's widget gap increases from 4 to 8 logical pixels. Media, tray, notifications, network, Bluetooth, volume, brightness and session use `scale = 1.25`, raising their native Tabler glyph size from 16 to 20 px. Noctalia 5.4.1 has no configurable icon stroke weight; scaling the glyph also increases its line width. The graphic battery retains its original size because it already draws a heavier outline. Clock, workspace pills, bar height, actions and panel placement are unchanged.

These are supported settings in `roles/niri/templates/noctalia.toml.j2`. There are no extra assets, scripts or shell patches.

## Verification

- Actual VM screenshots at 1512×982, scale 1 show icon ink increasing from 12 to 15 px tall. Network, volume and session have 11–12 px visible gaps. Workspace pixels match the before capture exactly.
- The native validator reports zero warnings. Live IPC confirms the configured spacing and widget scales, and the display mode and scale remain unchanged.
- Clicking network, volume and session opens their correct native menus. Escape closes each. Screenshots confirm the joins remain flush and hover highlights neither overlap nor clip at the screen edge. The bar remains on Overlay.
- Opus inspected all eight before, after, hover and panel captures and approved spacing 8 without revisions.
- The apply reports `ok=102 changed=1 failed=0`; the unchanged rerun reports `ok=102 changed=0 failed=0`. `--check --diff` reports `ok=93 changed=0 failed=0`.

## Limits

The VM has no battery, backlight or Bluetooth adapter. Tray items, unread notifications and media were absent during the captures. Their appearance together and battery balance still need a check on the Framework laptop. The changes use the same native per-widget scaling for each glyph.

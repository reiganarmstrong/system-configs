# Noctalia notch review

Reviewed the configuration changes after `dbf620c`. Opus 5.5 at medium effort supplied the design and a separate design review. Codex implemented the settings, investigated upstream behavior, and ran the live VM checks. A separate Codex stability review found no schema errors or unrelated regressions.

## Findings and resolution

The initial centered capsule showed the clock alone and expanded on hover. Live testing showed that expansion moved the clock away from the pointer. Clicking immediately opened Home, but waiting 500 ms before clicking selected a workspace. Opus rejected that behavior and specified a steady row with workspaces, media, clock and status widgets. The final configuration applies that revision and removes all accordion settings.

Keeping connection and battery status visible also addresses the review's concern that the first design hid the information requested for the notch. Removing the accordion eliminates the clipping behavior behind a possible invisible input strip. That strip was a source-level concern, not a reproduced VM defect.

The remaining bright focused-workspace pill matches Graphite's active controls. The reviewer requested no change to it. Its prominence should be assessed on the laptop.

## Maintenance decisions

The implementation uses one stock capsule group, native widgets and floating panels. It adds no plugin, shell fork, state tracker or custom animation code. The group sizes to its content, avoiding fixed widths for individual displays.

The transparent host bar has blur and shadow disabled because those effects cover its full width. Floating panels retain their own glass background. The visible notch is near-opaque, and the transparent host bar reserves a full-width 34 px strip. Native panel motion, hover highlights and tooltips provide animation; the surface does not morph into a panel or grow taller like the reference video.

GUI widget rearrangements save overrides that replace the role's arrays. NIRI.md documents which saved keys to inspect and recommends checking validation warnings when upgrading Noctalia.

## Verification

The final revision was deployed to Fedora 45 with Niri 26.04 and Noctalia 5.4.1. Immediate and delayed clock clicks both open Home. A workspace click after a 500 ms hover selects the intended workspace. All five configured panels open beneath the notch. The capsule and control center fit at scales 1, 1.25 and 1.5, and the layout renders with animations disabled.

Native configuration validation reports no warnings. The full playbook rerun reports `ok=65 changed=0 failed=0`, and both systemd managers report no failed units. Disposable test windows and animation overrides were removed, and scale 1 was restored.

Physical battery, Wi-Fi, Bluetooth, multiple displays and fully populated laptop width remain untested. Local screenshots, logs and the detailed design reports are retained in ignored `fedora/.local/niri-vm/`.

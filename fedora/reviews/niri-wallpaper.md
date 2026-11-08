# Graphite wallpaper review

The user requested a less plain background to make the glass effects stand out. Opus 5.5 at medium effort designed two overlapping graphite folds with lit crests, soft shadows, faint pleats and fine grain. Codex installed the self-contained SVG through the existing raster-rendering task. No palette, blur, panel-opacity or notch settings changed.

A separate Opus 5.5 medium review approved the actual VM screenshots with no required revisions. The wallpaper is visibly more structured, stays monochrome and leaves dark space behind the notch. Ghostty shows the clearest improvement: the bright crest becomes a soft diagonal band through its translucent background, while text remains readable.

The control center's outer panel and small cards remain fairly opaque, so their glass effect improves only subtly. Its user card displays a strong wallpaper-derived image, which should not be mistaken for evidence of blur. The result does not meet the designer's stronger proposed criterion of a clear diagonal across the lower two-thirds of the control center. The reviewer accepted the wallpaper within the requested scope; stronger transparency there would require a separate theme change.

The actual VM capture covers 16:9. Rendered 16:10 and 3:2 crops retain the central folds and dark notch area, but physical Framework rendering and Noctalia's 3:2 crop were not tested. Display brightness, banding, blur performance and the dock over the new wallpaper remain unverified.

## Deployment correction

Live testing found that replacing a PNG at the same path leaves Noctalia's wallpaper texture cached. The render filename now includes the source hash as well as dimensions. The playbook renders the image before publishing Noctalia's configuration, so live reload sees an existing file at the new path. A separate Codex stability review found no blockers in the hash naming, ordering, idempotence, check-mode behavior or SVG dependencies.

The first already-cached VM image was refreshed with a temporary wallpaper-disable override, which was then removed. Subsequent updates use the corrected task order. Old wallpaper renders are retained; no personal wallpaper settings or files are deleted.

## Verification

- The SVG parses, all reused paths resolve locally, and it contains no scripts, external images, text or fonts. The guest renders it successfully with `rsvg-convert`.
- A full playbook run at 1920×1200 passes with `changed=2`. Restoring 3840×2400 passes with `changed=1`. The final full rerun reports `ok=65 changed=0 failed=0`.
- Native configuration validation reports zero warnings. Final VM checks confirm the active 3840×2400 PNG and no failed system or user units.

Detailed design reports, captures and deployment logs are retained in ignored `fedora/.local/niri-vm/`.

# Spider-Verse wallpaper review

The user requested a minimal Spider-Verse-inspired background in red, black, gray and white, generated with GPT and judged by Claude. The built-in GPT image generation tool produced `roles/niri/files/wallpaper-spiderverse.png`. The adjacent Markdown file records its exact prompt and provenance. The original generated file is bundled without image processing or artificial upscaling.

Claude Opus 5.5 at medium effort approved the asset and actual desktop, control-center and terminal captures with no required revisions. The halftone print, angular shards and sparse web lines convey the requested theme. The composition keeps roughly 60–65% of the frame near-black, leaves clean space behind the notch and preserves text readability. The reviewer noted that the corner webs read somewhat like generic cobwebs but did not require an edit.

The bright crossing sits low in the composition, so Ghostty shows only a faint red and gray band and the top control center looks almost solid. Its user card draws its own wallpaper preview, which is not evidence of background blur. Claude accepted this tradeoff for the latest minimal brief. Shell opacity, blur and the neutral Graphite controls remain unchanged.

The native image is 1586×992. Large forms hold up in the VM, but thin webs and halftone dots soften when enlarged. This is not native 4K artwork. Actual screenshots verify the 16:9 crop; the 3:2 crop was judged from geometry. Physical display quality and rendering performance remain unmeasured.

## Delivery and verification

The role fingerprints the PNG on the Ansible controller and installs it under a SHA-256-based filename before publishing Noctalia's configuration. Noctalia handles scaling and cropping directly. This preserves cache invalidation while removing the SVG rendering step and its `librsvg2-tools` dependency. The SVG-specific `niri_wallpaper_size` variable is retired and documented. Previous SVG sources and installed wallpaper files are retained; switching back to SVG requires restoring its render task and dependency.

A separate Codex review found no blockers in controller delegation, privilege handling, task dependencies, cache behavior, idempotence or check mode.

- Full apply: `ok=65 changed=2 failed=0`.
- Unchanged rerun: `ok=65 changed=0 failed=0`.
- `--check --diff`: `ok=64 changed=0 failed=0`.
- Installed asset SHA-256 matches the bundled PNG and its filename fingerprint.
- Native Noctalia validation reports zero warnings; system and user managers report no failed units.

Detailed reports, captures and logs remain in ignored `fedora/.local/niri-vm/`.

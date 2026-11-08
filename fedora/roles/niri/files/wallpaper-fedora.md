# Fedora fetch wallpaper

`wallpaper-fedora.png` is the user-approved, Python-rendered 2880×1920 wallpaper. The image is bundled directly; installation needs no rendering tools or network service. It uses actual monospace glyphs, a graphite field and seven gray swatches followed by one Fedora-blue swatch. Noctalia handles other output sizes with its native crop mode.

## Reproduce

The source is the user's `ascii-wallpaper-generator` project, commit `f8f9974c2b1e57e84de360d0c323e1c161d6fb04`, branch `codex/fedora-neofetch-preset`. Its development worktree is `/home/reagan/.t3/worktrees/ascii-wallpaper-generator/fedora-neofetch`.

From that project:

```sh
uv run ascii-wallpaper --config examples/fedora-framework.json \
  --width 2880 --height 1920 --output output/fedora-framework-2880x1920.png
```

Copy that PNG to `fedora/roles/niri/files/wallpaper-fedora.png` in this repository, then rerun `fedora/niri.yml`. The installed filename includes the image checksum, so replacing the asset invalidates Noctalia's cache without restarting the shell.

The preset records the hardware explicitly supplied by the user: Framework 13 Pro, Intel Core i5, 32 GB RAM and 1 TB SSD. These are the target laptop's specifications, not detected statistics from the rehearsal VM. The heading is Fedora Linux, with niri and Noctalia listed as the desktop components.

The Fedora ASCII logo comes from Fastfetch under the MIT license. Its notice is preserved in [wallpaper-fedora-license.txt](wallpaper-fedora-license.txt). The renderer uses its bundled DejaVu Sans Mono font.

## Review

Claude Opus 5.5 medium approved the native and 3840×2400 previews, checking full-resolution glyph clarity, correct text and crop safety. The renderer's 42 tests, lint, formatting and package build pass. A separate code review found no blockers, and the previous Apple and custom example outputs remained pixel-identical. The user approved installing this wallpaper after viewing the native PNG.

The subsequent VM install reports `ok=65 changed=2 failed=0`, followed by a full rerun with `ok=65 changed=0 failed=0`. The active wallpaper's SHA-256 matches the approved source. Native Noctalia validation has zero warnings, and a desktop capture confirms the actual 16:9 crop. Logs and the capture are retained in ignored `fedora/.local/niri-vm/`.

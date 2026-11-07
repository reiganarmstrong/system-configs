# Brighter Zsh colors and stable MacBook VNC sizing

Checked November 7, 2026. Opus 5.5 at medium effort designed the terminal colors and approved five actual probe captures. Codex implemented the changes, verified the live configuration and reviewed display behavior. A separate Codex display review checked native Niri custom modes and the upstream TigerVNC Mac client options.

## Terminal colors

The 16 Ghostty ANSI slots now use brighter, distinct red, green, yellow, blue, magenta and cyan hues. Starship reuses those values: green user/host and success, blue paths, magenta branches, cyan runtimes, yellow dirty-tree status and red errors. ANSI 8 changes from `#5a5a61` to `#8b8b94`, improving the autosuggestion plugin's existing `fg=8` without a zshrc change. Normal foreground, background, glass opacity, font, prompt formats and ASCII symbols remain as before.

Ghostty's palette exactly matches `Graphite.json`'s dark terminal normal/bright maps. The light palette and every Noctalia UI role are unchanged. No shared GNOME source, plugin code or personal startup file was modified. The terminal palette also affects programs using ANSI colors, including the fastfetch greeting.

Verification:

- JSON and TOML parse; all 16 ANSI slots match across the two files. The light palette and dark UI roles compare equal to the prior commit.
- Ghostty's native configuration validator passes. Starship's real renderer emits all seven expected prompt color roles with no errors.
- A disposable interactive Zsh probe shows green known commands, red unknown commands, yellow quoted strings, a readable gray autosuggestion and the intended prompt roles. A private ZLE observer confirmed the buffer/suggestion before capture, so screenshots do not depend on typing speed.
- The probe uses its own temporary history and project, restores prior focus and closes only its own window. Existing Ghostty instances received the native GTK `reload-config` action rather than a restart. Starship refreshes when the next prompt is generated.
- Opus's live review approved the colors, error/success characters and suggestion contrast with no required revisions.

## MacBook display

The regression check initially reported 1920×1080 at scale 1, larger than the previously used 1512×982 MacBook viewport. The VM's output was unpinned and followed its current preferred mode. TigerVNC can request a new desktop size; that is a plausible explanation for the preferred-mode change, not proof of a particular client action.

The tracked VM-only profile now selects native `mode custom=true "1512x982@60"` and `scale 1` for `Virtual-1`. The rendered config validates, the running output and screenshots are 1512×982, and existing terminals reflow to fit. The same geometry check that failed before the fix passes afterward and after the later Ansible runs. Native Framework installs retain `niri_outputs: []` with automatic display selection.

The executable Mac launcher passes DesktopSize and RemoteResize directly on the CLI, disables automatic color/encoding selection, selects full color and lossless Tight without JPEG, and opens fullscreen through the installed TigerVNC app. It uses the existing SSH tunnel to localhost:5903 and stores no password. These two resize flags are not accepted in every saved-profile reader, so no unsupported `.tigervnc` profile was added.

The helper passes `bash -n`, and its options/app bundle were checked against upstream TigerVNC stable sources. The Mac client was not operated remotely. Matching the logical desktop avoids fractional shrinking; it does not add Retina-native rendering to the official Mac app. Reconnect using the helper to apply its client-side settings.

Final normal Ansible rerun: `ok=102 changed=0 failed=0`. Final `--check --diff`: `ok=93 changed=0 failed=0`. Temporary guest probes and test projects were removed; detailed captures and checks remain in ignored `.local/niri-vm/`.

Sources: [Niri outputs](https://github.com/niri-wm/niri/blob/v26.04/docs/wiki/Configuration:-Outputs.md), [TigerVNC viewer manual](https://tigervnc.org/doc/vncviewer.html), [stable viewer parameters](https://github.com/TigerVNC/tigervnc/blob/v1.16.0/vncviewer/parameters.cxx), [Mac packaging](https://github.com/TigerVNC/tigervnc/blob/v1.16.0/release/makemacapp.in).

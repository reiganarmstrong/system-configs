# Niri profile review

Reviewed the implementation at `66b85c5` against base `7e2ac10`, then fixed the findings in the same worktree. Opus 5.5 at medium effort implemented the design. Codex reviewed the configuration, provisioning and migration, with separate standards and requirements reviews.

## Standards

No documented coding-standard violations or material code smells were found. The role reuses the existing app and shell provisioning and leaves the GNOME profile's defaults intact.

The standards reviewer also identified two correctness defects, both fixed:

- The JSONC helper discarded comments inside objects containing only comments. It now inserts settings while preserving the original contents, with a regression test.
- Changing `niri_wallpaper_size` did not regenerate an existing wallpaper. Render filenames now include the dimensions, and Noctalia receives the selected path.

## Spec

The requirements review identified two migration gaps, both fixed:

- Disk, keyring and printer tools had been omitted. Disks, Seahorse, Print Settings and pavucontrol are now installed, with CUPS and Avahi enabled. Noctalia replaces Blueman's pairing controls, and Niri output configuration replaces wdisplays. These substitutions are documented.
- Tailscale had been dropped. The role now installs it from its signed stable repository, enables the daemon and sets the desktop account as operator. Tailnet authentication remains an interactive installation step.

The new worktree, native Niri blur, Noctalia v5 integration, monochrome design, main applications and shortcut intent match the request.

## Additional checks and fixes

Ansible validates Niri templates in temporary files. Relative personal includes were consequently checked in the wrong directory. The template now includes the user's absolute config path, and validation was verified to reject a broken personal override. Boolean switches also accept the documented `-e name=false` form under Ansible 2.22.

Validation passed for all three playbooks' syntax, eight JSONC tests, Niri and Noctalia templates with defaults and overrides, and 93 shortcuts checked against Noctalia's CLI. Added packages install without a competing GNOME keyring daemon. Targeted production tasks passed in Fedora 45; wallpaper resizing and Tailscale operator updates worked, and their rerun and check-mode checks reported zero changes. Systemd calls were excluded from those targeted container runs. Initial implementation provisioning and configuration tests are recorded in [NIRI.md](../NIRI.md#testing).

A subsequent live Fedora 45 VM check found that oo7 was installed but never started, so GDM's PAM password handoff expired. The role now starts the vendor service with Niri and stops it with the graphical session. A clean reboot and GDM login verified automatic keyring unlock. Noctalia's interactive first-run wizard is also disabled for this preconfigured profile.

The VM verified desktop rendering, terminal and launcher shortcuts, and lock/unlock over VNC. A final native playbook rerun reported zero changes. MacBook keyboard capture, measured graphics performance, suspend, portals and laptop hardware remain untested. Details are in [the live VM verification](../NIRI.md#live-vm-verification).

Standards: 0 violations or smell findings. Spec: 2 findings, both resolved; the largest was incomplete app migration. The auxiliary correctness findings are also resolved.

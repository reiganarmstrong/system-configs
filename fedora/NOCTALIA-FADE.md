# Floating-panel fade

The Niri profile carries a small source patch to Noctalia. Floating menus fade as stationary cards rather than wiping out from the bar. The patch changes their opening and closing transitions only. Bar, dock, notification and attached-panel transitions retain their upstream implementation, and Noctalia's global reduced-motion settings still apply.

The same rebuild includes a separate Control Center patch. Active Home shortcut tiles and the active sidebar tab stay white with dark ink in the dark theme, including while hovered. Press dims that same light surface slightly instead of swapping it to dark gray with light ink. Hover stays fully white because mouse clicks retain input focus, which Noctalia also treats as hover. Inactive tiles have a small dark press response, followed by one crossfade to white when enabled. The roles reverse appropriately in the light theme. Global accent colors, headings, sliders, focus indicators and destructive buttons keep their upstream styling.

The compositor remains Niri. This does not require Umbriel, Hyprland or a different Linux distribution.

## Files and defaults

- [`noctalia-floating-panel-fade.patch`](roles/niri/files/noctalia-floating-panel-fade.patch) changes the floating-panel renderer.
- [`noctalia-quiet-selection.patch`](roles/niri/files/noctalia-quiet-selection.patch) keeps active Control Center items light through hover and press, with a restrained press response for inactive tiles.
- [`noctalia-upower-test-lifetime.patch`](roles/niri/files/noctalia-upower-test-lifetime.patch) fixes an upstream test fixture that unregisters its own D-Bus property handler while the callback is running. Deferred unregistration runs between messages instead. Its assertions and the installed battery code are unchanged.
- [`build-noctalia-fade.py`](roles/niri/files/build-noctalia-fade.py) prepares Fedora's source RPM and builds the patched RPM.
- [`noctalia-fade.yml`](roles/niri/tasks/noctalia-fade.yml) manages installation and rollback at the end of the Niri role.

`niri_noctalia_panel_fade_enabled` defaults to `true` and controls the custom package with both patches. Set it to `false` to restore the complete stock package. `niri_noctalia_build_jobs` defaults to roughly one compiler job per 3 GiB of RAM, capped at eight jobs and the available CPU count. The 8 GiB VM uses two jobs. The initial build installs compiler dependencies and runs Fedora's upstream test step, so it takes substantially longer than a normal provisioning run. Subsequent unchanged runs skip the build.

## Build and update behavior

Ansible reads the installed Noctalia version and Fedora release number, then downloads the matching source RPM from Fedora's build archive. Its signature must verify against the installation's trusted RPM keys before dependencies are read or source is built.

The regular desktop account builds the package with Fedora's original dependencies, build commands, complete test step, runtime assets and license files. A local `.graphite.<identity>` release suffix records all patch fingerprints and the helper fingerprint. The cache retains the signed source, adjusted spec, applied patches, build log, source RPM, binary RPM and SHA-256 manifest.

Patch application uses `git apply --check` and `git apply`, followed by a check that the changed renderer is present. A changed upstream patch context or unfamiliar spec layout stops the build. The existing installed package is left in place, and the rest of the desktop has already been configured.

The local RPM is unsigned. Only its installation bypasses the RPM signature check, after verification of the signed Fedora source. Repository signature checks remain enabled. Installation permits a lower local hash suffix, because hashes are identities rather than increasing version numbers. Before installing, the role checks that the upstream version and release have not changed during the build; afterwards it requires the exact requested patched release.

Normal Fedora updates can replace the custom RPM with a newer distribution package. After upgrading Noctalia, rerun the normal `niri.yml` command from [NIRI.md](NIRI.md). Ansible will build the newly installed version with the same patch. This is an explicit provisioning step, not a background compiler or a DNF transaction hook. If the patch stops fitting a future release, inspect the failure and update or retire the patch before continuing.

An installed package does not replace an already running process. After a changed build, restart Noctalia from an unlocked session or log out and back in. Ansible prints a notice; it does not restart the compositor or close application windows.

## Return to the distribution package

Rerun the normal Niri provisioning command with:

```text
-e niri_noctalia_panel_fade_enabled=false
```

The role runs a scoped `dnf distro-sync noctalia` when it finds a local Graphite release. Restart the shell afterwards to load the stock binary. Compiler dependencies and build artifacts remain available for reuse.

## Maintenance

The patches currently target Noctalia 5.4.1. A new release may accept them unchanged. A successful patch application is only the first check: compilation, upstream tests and a live menu check still matter. Check opening and closing over a busy background, Escape and outside-click dismissal, rapid toggling, reduced motion, and menus above fullscreen. Check shortcut on/off/press states, sidebar navigation and light/dark palette changes too.

Niri does not fade a layer's compositor blur with its pixels. The fade patch therefore clears blur below 40% card opacity, avoiding a bare frosted rectangle before opening or after closing. Keep this cutoff until the compositor can fade the blur with the card, or upstream offers an equivalent transition. If upstream adds native settings for either change, retire the corresponding patch after checking the replacement.

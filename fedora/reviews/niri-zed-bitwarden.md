# Zed and Bitwarden migration

The Niri profile replaces the previously managed VSCodium RPM with Zed and adds Bitwarden Desktop. The shared GNOME role is unchanged. Both apps use the exact macOSicons assets selected by the user, downloaded with pinned SHA-256 checksums and extracted without image conversion.

## Installation and migration

- Zed's official stable v1.27.0 Linux bundle is installed under the desktop account. Its archive SHA-256 matches the GitHub release asset digest. The account owns the app bundle, and subsequent runs skip downloading or extracting over an installed app, preserving native updates. `rsync` supports the updater; Mesa Vulkan drivers are explicit dependencies. The independent desktop entry and theme icons live outside the updated bundle.
- Bitwarden 2026.10.3 is installed system-wide through Flathub. Its existing sandbox policy permits the Secret Service and Polkit. The role supplies upstream's `com.bitwarden.Bitwarden.unlock` action with `auth_self` for an active user, and no authorization for inactive or remote sessions. Account login and enabling biometric unlock remain interactive.
- Only the old `codium` package, its managed repository and its managed icon are removed. VSCodium's existing settings and extensions are retained. New installations no longer create VSCodium configuration directories.
- Zed uses the light glass icon `wgafyS8Bfo` by eldershi. Bitwarden uses `mY3jnG41sr`, credited to Bitwarden Inc. Desktop-entry and upstream icon-name aliases share their respective original 1024×1024 PNG bytes.

## VM verification on November 7, 2026

- The first-install `--check --diff` completed successfully before either app was installed: `ok=98 changed=12 failed=0`.
- The actual apply reports `ok=107 changed=14 failed=0`; an unchanged rerun reports `ok=105 changed=0 failed=0`. The final `--check --diff` reports `ok=97 changed=0 failed=0`.
- Both apps opened from the configured Fuzzel launcher. Captures show their selected icons and real application windows. Zed reports v1.27.0 and rendered through the guest's VirGL OpenGL adapter without an emulated-GPU override. Bitwarden reached its empty login screen. No account or vault was accessed.
- GTK icon lookup for both installed desktop entries resolves to the selected Graphite theme files. All four installed PNG aliases match their manifest hashes. Desktop-entry validation passes. The old RPM and repository are absent; both former VSCodium settings files remain.
- Niri, Noctalia and Fuzzel validators pass. Noctalia reports no warnings. Niri's optional absent personal include remains a harmless warning.

The VM was off when deployment began. Tests used a temporary graphical session after starting it, then returned to GDM with automatic login still disabled. Because that test session did not supply a login password, oo7 remained locked and showed its normal unlock prompt. Keyring unlocking through password-based GDM login, real fingerprint unlock and browser-extension integration were not tested in this run.

Claude Opus 5.5 at medium effort approved the exact assets, actual launcher captures and integration with no blockers. Its optional cleanup was adopted: the first-install archive is removed after successful extraction rather than retaining 87 MB in the account. Applying that cleanup reports `ok=106 changed=1 failed=0`; a focused dry run of the archive-removal task then reports `changed=false`.

## Sources

- [Zed Linux installation](https://zed.dev/docs/linux), [v1.27.0 release](https://github.com/zed-industries/zed/releases/tag/v1.27.0), and [native Linux updater](https://github.com/zed-industries/zed/blob/v1.27.0/crates/auto_update/src/auto_update.rs).
- [Bitwarden desktop feature support](https://bitwarden.com/help/desktop-app-feature-support/), [Flathub manifest](https://github.com/flathub/com.bitwarden.desktop), and [native unlock policy](https://github.com/bitwarden/clients/blob/main/apps/desktop/resources/com.bitwarden.desktop.policy).

# Settings edge-case review, 2026-11-06

Baseline: `7e2ac10d250d392dabce271b4d458d37ad6229f4`. Reviewed working-tree status, implementation boundaries, the first report, and backend save/display/admin paths and shared launch/service code. This is a focused independent review, not exhaustive runtime coverage of all 19 pages. No desktop operations, installations, system changes or personal-data reads were performed. I applied the unslop writing guidance. No delegates were started.

## Confirmed new findings

### 1. Save failures can leave live and persisted settings inconsistent

Severity: Medium. Confidence: high. Reproduced with isolated Python unit-level calls and mocked desktop commands.

Evidence: `nixos/modules/home/settings/settings.py:230-242`. Live Hyprland and GTK changes run inside the rollback block, but all three persistence writes run after that block. Atomic replacement protects each individual file, not the save transaction.

Reproduction A:

1. Import production `settings.py`; replace `state_dir` with a fresh `TemporaryDirectory` path.
2. Replace `apply_appearance` with a recorder; replace `write_json` with a function raising `OSError('simulated ENOSPC')`.
3. Call `save(defaults() | {'textScale': 1.25})`.

Observed: the exception propagates; appearance calls are `[1.25]`, with no call restoring the old scale; `preferences.json` does not exist. The backend reports failure while the live appearance remains changed. This also applies to a write-denied state directory after live application succeeds.

Reproduction B:

1. Use another temporary state directory and a no-op `apply_appearance`.
2. Leave production `write_json` intact; replace `write_overrides` with a function raising `OSError('simulated settings.lua failure')`.
3. Save the same scale change.

Observed: the save raises, but reading `preferences.json` returns `{'textScale': 1.25}`; `idle.conf` does not exist. A failure at a later write can therefore commit only some artifacts. Existing files would retain their old contents instead. For lock timing changes, an idle-file failure also skips the hypridle restart.

Impact: reported failure does not describe the actual state. Reopening Settings, restarting the compositor, and the current session can disagree. This is independent of the first review's disappearing error banner.

Smallest maintainable fix: include persistence in the transaction boundary, stage all generated contents before applying live changes, preserve prior artifacts, and restore both live state and replaced artifacts on failure. Attempt each rollback independently so one rollback error cannot suppress the others. Add fault-injection tests at each write boundary. Individual atomic writes alone cannot provide this guarantee.

### 2. Terminal applications fail when TERMINAL includes arguments

Severity: Low. Confidence: high for the command construction. Confirmed by code inspection only; no graphical launch reproduction.

Evidence: `nixos/modules/home/quickshell/qml/services/AppLaunch.qml:8-10`. The command array places the entire `TERMINAL` string in argv[0].

Reproduction steps: launch an isolated shell with `TERMINAL='ghostty --new-window'`, then open a desktop entry with `Terminal=true` through the launcher or Startup apps. The constructed command begins `['ghostty --new-window', '-e', ...]`. This requests an executable literally containing the space and argument, so a normal installation cannot resolve it. No failure handler reports this to Settings. With TERMINAL unset, the explicit `ghostty` fallback avoids this particular defect.

Impact: valid terminal entries silently fail under an environment that configures terminal arguments. Startup and normal launcher paths share this implementation.

Smallest maintainable fix: define an explicit terminal argv setting, with Ghostty as the default. If supporting the existing environment string, parse it with a proper argument parser rather than whitespace splitting or shell execution, and validate the resulting nonempty argv. Document the supported contract.

## Plausible risks requiring further testing

- `settings.py:234-236`: if restoring Hyprland raises, GTK restoration is skipped. An injected failure would prove control flow, but a realistic compositor failure and recovery scenario was not tested.
- `settings.py:262-269`: a disconnected preview output can make watchdog restoration fail before clearing the pending record. Whether Hyprland accepts the saved disconnected monitor rule determines the outcome. Hot-unplug testing is needed.
- Malformed preferences are rejected by `read_json` rather than recovered. Whether that should be a defect depends on the intended recovery policy; automatic destructive recovery would be inappropriate.

## Tests and limits

- Python production-module harness A: passed, reproduced missing live rollback after injected preference-write failure.
- Python production-module harness B: passed, reproduced partial persistence after injected generated-file failure.
- Both used temporary directories removed by `TemporaryDirectory`; subprocess application was mocked. No running preferences or state were touched.
- Inspected command construction for terminal launching. No QML harness, graphical lifecycle tests, real disk-full test, hardware tests, or Nix checks were run in this pass.
- Read status and diff statistics against HEAD, which equals the requested baseline. Existing first-review findings were excluded. This pass does not establish complete page-by-page search or lifecycle coverage.

## Disagreement with the first report

The first report's broad statement that preference saves roll back live Hyprland/GTK state on failure needs narrowing. They attempt rollback for live-apply exceptions, but persistence exceptions bypass it, as reproduced above. I do not dispute its numbered findings.

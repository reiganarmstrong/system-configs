# Settings generates hypridle's runtime configuration from validated user
# preferences. Its defaults are five minutes to lock, six to screen off,
# and fifteen to suspend on the laptop. The VM does not suspend by default.
# Caffeine uses a Wayland idle inhibitor to pause all three listeners.
# hypridle works under niri through ext-idle-notify; screen off uses
# `niri msg action power-off-monitors`.
{ ... }:
{
  services.hypridle.enable = true;
  # The settings module supplies ExecStart and the generated configuration.
}

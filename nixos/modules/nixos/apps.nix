# System support for the user's apps: zsh as the login shell, Flatpak for
# Zen and Bitwarden, and the compatibility layers that let self-updating vendor builds
# (Claude Code, Codex, T3 Code's AppImage) run on NixOS.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.desktop;
in
{
  options.desktop.flatpaks = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [
      "app.zen_browser.zen"
      "com.bitwarden.desktop"
    ];
    description = "Flathub apps installed for everyone; Flatpak keeps them updated.";
  };

  config = lib.mkIf cfg.enable {
    programs.zsh.enable = true;
    users.users.${cfg.user}.shell = pkgs.zsh;

    # Prebuilt Linux binaries expect a standard dynamic loader.
    programs.nix-ld.enable = true;
    programs.appimage = {
      enable = true;
      binfmt = true;
    };

    services.flatpak.enable = true;
    environment.systemPackages = [
      (pkgs.writeTextDir "share/polkit-1/actions/com.bitwarden.desktop.policy" (
        builtins.readFile ./bitwarden.policy
      ))
    ];
    systemd.services.flatpak-apps = {
      description = "Install the configured Flathub apps";
      wantedBy = [ "multi-user.target" ];
      restartIfChanged = true;
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      path = [ pkgs.flatpak ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
        flatpak install --system --noninteractive --or-update flathub ${lib.escapeShellArgs cfg.flatpaks}
      '';
    };
    # Flatpak apps update on their own schedule, like on Fedora.
    systemd.services.flatpak-update = {
      description = "Update Flatpak apps";
      path = [ pkgs.flatpak ];
      serviceConfig.Type = "oneshot";
      script = "flatpak update --system --noninteractive";
      startAt = "daily";
    };
  };
}

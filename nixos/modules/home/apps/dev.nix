# Development tools, and the vendor apps that update themselves: Claude Code
# (Anthropic's native installer, latest channel) and T3 Code (an AppImage).
# Nix only performs the first install and never replaces a newer copy.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  t3code = rec {
    version = "0.1.7";
    appimage = pkgs.fetchurl {
      url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-x86_64.AppImage";
      hash = "sha256-+q7kCU3KEnYFeEChpFprLQDXQYr79XNfdadQO3dOY9E=";
    };
    installed = "${config.home.homeDirectory}/applications/T3-Code.AppImage";
    # Where earlier generations installed it; a copy there may have updated itself.
    legacy = "${config.home.homeDirectory}/Applications/T3-Code.AppImage";
  };
in
{
  home.packages = [
    pkgs.git
    pkgs.vim
    pkgs.gnumake
    pkgs.nodejs_24
    pkgs.pnpm
    pkgs.uv
    pkgs.curl
  ];

  programs.zed-editor = {
    enable = true;
    userSettings = {
      theme = "One Dark";
      ui_font_family = "Inter";
      buffer_font_family = "JetBrains Mono";
      telemetry = {
        diagnostics = false;
        metrics = false;
      };
    };
  };

  home.activation.t3code = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e ${t3code.installed} ]; then
      run mkdir -p "$(dirname ${t3code.installed})"
      if [ -e ${t3code.legacy} ]; then
        # Keep the self-updated copy rather than reinstalling the pinned one.
        run mv ${t3code.legacy} ${t3code.installed}
        run rmdir --ignore-fail-on-non-empty "$(dirname ${t3code.legacy})"
      else
        run install -m 0755 ${t3code.appimage} ${t3code.installed}
      fi
    fi
  '';

  # Vim is terminal-only, but its package still ships a GVim launcher for a
  # gvim binary it doesn't include. Hide it from the launcher.
  xdg.desktopEntries.gvim = {
    name = "GVim";
    exec = "gvim";
    noDisplay = true;
  };
  # Keep the CLI editor installed without a redundant app-menu entry.
  xdg.desktopEntries.vim = {
    name = "Vim";
    exec = "vim";
    noDisplay = true;
  };

  xdg.desktopEntries.t3code = {
    name = "T3 Code";
    comment = "Desktop app for coding agents";
    exec = "${t3code.installed} %U";
    icon = "t3code";
    terminal = false;
    categories = [ "Development" ];
    mimeType = [ "x-scheme-handler/t3code" ];
    settings.StartupWMClass = "t3code";
  };

  # Claude Code installs into ~/.local/bin and keeps itself current.
  systemd.user.services.install-claude-code = {
    Unit.Description = "Install Claude Code once";
    Service = {
      Type = "oneshot";
      Environment = "PATH=${
        lib.makeBinPath [
          pkgs.bash
          pkgs.coreutils
          pkgs.curl
          pkgs.gnugrep
          pkgs.gnused
          pkgs.gawk
          pkgs.gnutar
          pkgs.gzip
          pkgs.findutils
        ]
      }";
      # The network may not be up yet at login; try again until it is.
      Restart = "on-failure";
      RestartSec = 30;
      ExecCondition = "${pkgs.bash}/bin/bash -c '! test -e %h/.local/bin/claude'";
      ExecStart = "${pkgs.bash}/bin/bash -c 'curl -fsSL https://claude.ai/install.sh | bash'";
    };
    Install.WantedBy = [ "default.target" ];
  };
}

# btop uses the Fedora Graphite palette with a transparent background.
# Fastfetch prints a short NixOS system summary beside a smaller copy of the
# wallpaper's NixOS logo, which spins until you type (fetch-spin.zsh).
#
# btop won't draw a layout wider than the window, and the full one needs 80
# columns, which a half-screen window misses. It opens with CPU and processes
# (60 columns); p switches to the full layout, and 1-4 toggle single boxes.
# The copy Hyprland opens at login starts on the full layout (preset 1).
{ lib, pkgs, ... }:
let
  # The wallpaper generator's two greys for the logo, as SGR colour codes.
  logoColours = [
    "38;2;94;98;104"
    "38;2;236;237;239"
  ];
  logoPadding = {
    top = 1;
    left = 2;
    right = 4;
  };
  # logo.txt, the still logo, and frames.zsh, the frames of it spinning.
  fetchLogo = pkgs.runCommand "fetch-logo" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    python3 ${./fetch-logo.py} ${../../../assets/nixos.txt} $out ${lib.escapeShellArgs logoColours}
  '';
in
{
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "shell";
      shown_boxes = "cpu proc";
      # Layouts p cycles through after the one above: everything, then
      # everything but processes.
      presets = "cpu:0:default,mem:0:default,net:0:default,proc:0:default cpu:0:default,mem:0:default,net:0:default";
      theme_background = false;
      truecolor = true;
      rounded_corners = true;
      graph_symbol = "braille";
      vim_keys = true;
      update_ms = 1000;
      # One CPU graph of total use, not the default mirrored pair.
      cpu_single_graph = true;
      cpu_graph_upper = "total";
      # Bars for memory, and no sparkline beside every process.
      mem_graphs = false;
      proc_cpu_graphs = false;
      clock_format = "%I:%M %p";
      proc_tree = false;
      # Hide kernel threads (kworker, migration) from the process list.
      proc_filter_kernel = true;
      proc_sorting = "cpu lazy";
      show_battery = true;
    };
    themes.shell = builtins.readFile ./graphite.theme;
  };

  # A short summary beside the NixOS logo: dim blue labels, plain values,
  # and the terminal's colours along the bottom.
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        type = "file";
        source = "${fetchLogo}/logo.txt";
        color = {
          "1" = builtins.elemAt logoColours 0;
          "2" = builtins.elemAt logoColours 1;
        };
        padding = logoPadding;
      };
      display = {
        separator = "  ";
        color = {
          keys = "blue";
          title = "bold_white";
        };
        key.width = 10;
        size = {
          binaryPrefix = "iec";
          ndigits = 1;
        };
        percent.type = 0;
      };
      modules = [
        "break"
        {
          type = "title";
          format = "{user-name} on {host-name}";
        }
        "break"
        {
          type = "os";
          key = "os";
          format = "{name} {version-id}";
        }
        {
          type = "kernel";
          key = "kernel";
          format = "{release}";
        }
        {
          type = "wm";
          key = "desktop";
          format = "{pretty-name}";
        }
        {
          type = "uptime";
          key = "uptime";
        }
        {
          type = "memory";
          key = "memory";
          format = "{used} of {total}";
        }
        {
          type = "disk";
          key = "disk";
          folders = "/";
          format = "{size-used} of {size-total}";
        }
        {
          type = "battery";
          key = "battery";
          format = "{capacity} {status}";
        }
        "break"
        {
          type = "colors";
          symbol = "circle";
          paddingLeft = 0;
        }
      ];
    };
  };

  # Greet each new terminal with the summary, but not shells started inside
  # another shell or by scripts.
  programs.zsh.initContent = lib.mkAfter ''
    ${builtins.replaceStrings
      [ "@frames@" "@top@" "@left@" ]
      [ "${fetchLogo}/frames.zsh" (toString logoPadding.top) (toString logoPadding.left) ]
      (builtins.readFile ./fetch-spin.zsh)
    }
    if [[ -o interactive && $SHLVL -eq 1 ]] && (( $+commands[fastfetch] )); then
      fetch_spin
    fi
  '';
}

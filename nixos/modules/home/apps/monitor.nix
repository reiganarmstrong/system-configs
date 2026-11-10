# btop uses the Fedora Graphite palette with a transparent background.
# Fastfetch prints a short NixOS system summary beside a smaller copy of the
# wallpaper's NixOS logo.
#
# btop won't draw a layout wider than the window, and the full one needs 80
# columns, which a half-screen window misses. It opens with CPU and processes
# (60 columns); p switches to the full layout, and 1-4 toggle single boxes.
# The copy Hyprland opens at login starts on the full layout (preset 1).
{ lib, ... }:
let
  # A two-thirds-size copy of the wallpaper's NixOS logo, drawn by
  # assets/fastfetch-logo.py.
  logo = ../../../assets/fastfetch-logo.txt;
  logoLines = builtins.length (lib.splitString "\n" (lib.removeSuffix "\n" (builtins.readFile logo)));
  logoPadding = {
    top = 1;
    left = 2;
    right = 4;
  };
  summary = [
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
  # fastfetch can't centre the summary beside the logo, so blank lines above
  # push it down. Without a battery it is a line short, and half a line high.
  summaryOffset = logoPadding.top + (logoLines - builtins.length summary) / 2;
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
        source = logo;
        # The wallpaper generator's two greys.
        color = {
          "1" = "38;2;94;98;104";
          "2" = "38;2;236;237;239";
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
      modules = lib.replicate summaryOffset "break" ++ summary;
    };
  };
}

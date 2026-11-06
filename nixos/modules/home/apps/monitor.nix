# btop, the resource monitor, styled like the shell: no background of its own
# so Ghostty's blur shows through, grey boxes, and graphs that run from the
# highlight blue at light load to white at full load. Also fastfetch, the system summary.
#
# btop won't draw a layout wider than the window, and the full one needs 80
# columns, which a half-screen window misses. It opens with CPU and processes
# (60 columns); p switches to the full layout, and 1-4 toggle single boxes.
{ osConfig, ... }:
let
  inherit (osConfig.desktop.theme) colors;
  grey = "#5c5c66";
  light = "#d4d4d8";
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
    themes.shell = ''
      theme[main_bg]="${colors.panel}"
      theme[main_fg]="${light}"
      theme[title]="${colors.text}"
      theme[hi_fg]="${colors.highlight}"
      theme[selected_bg]="#2f2f36"
      theme[selected_fg]="${colors.text}"
      theme[inactive_fg]="${grey}"
      theme[graph_text]="${colors.textDim}"
      theme[meter_bg]="#2a2a30"
      theme[proc_misc]="${colors.textDim}"
      theme[cpu_box]="${grey}"
      theme[mem_box]="${grey}"
      theme[net_box]="${grey}"
      theme[proc_box]="${grey}"
      theme[div_line]="#3a3a42"
      theme[temp_start]="#98c379"
      theme[temp_mid]="#e5c07b"
      theme[temp_end]="${colors.urgent}"
      theme[cpu_start]="${colors.highlight}"
      theme[cpu_mid]="#a3c2ff"
      theme[cpu_end]="${colors.text}"
      theme[free_start]="${colors.textDim}"
      theme[free_mid]="${colors.textDim}"
      theme[free_end]="${colors.text}"
      theme[cached_start]="${colors.textDim}"
      theme[cached_mid]="#82aaff"
      theme[cached_end]="${colors.text}"
      theme[available_start]="${colors.textDim}"
      theme[available_mid]="${colors.textDim}"
      theme[available_end]="${colors.text}"
      theme[used_start]="${colors.highlight}"
      theme[used_mid]="#a3c2ff"
      theme[used_end]="${colors.text}"
      theme[download_start]="${colors.highlight}"
      theme[download_mid]="#a3c2ff"
      theme[download_end]="${colors.text}"
      theme[upload_start]="#c792ea"
      theme[upload_mid]="#d9adf2"
      theme[upload_end]="${colors.text}"
      theme[process_start]="${colors.highlight}"
      theme[process_mid]="#a3c2ff"
      theme[process_end]="${colors.text}"
    '';
  };

  # A short summary beside the small NixOS logo: dim blue labels, plain
  # values, and the terminal's colours along the bottom. zsh runs it when a
  # terminal opens (shell.nix).
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        type = "builtin";
        source = "nixos_old_small";
        padding = {
          top = 1;
          left = 2;
          right = 4;
        };
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
}

# zsh with oh-my-zsh, autosuggestions, syntax highlighting and the Starship
# prompt, carried over from the Fedora setup.
{ ... }:
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" ];
    };
    shellAliases = {
      sleep = "sudo systemd-run --on-active=5s systemctl suspend && exit";
      mv = "mv -i";
      cp = "cp -i";
      rm = "rm -i";
      ls = "ls -laht --color=auto";
      t3 = "npx --yes t3@nightly";
    };
    sessionVariables = {
      EDITOR = "vim";
      CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH = "2";
      PNPM_HOME = "$HOME/.local/share/pnpm";
      # npm's default global prefix is Node's own folder in the read-only Nix
      # store, so `npm install -g` fails. Install into ~/.local/bin instead.
      NPM_CONFIG_PREFIX = "$HOME/.local";
      # uv builds tools on Pythons it downloads, not the Nix python3, which
      # a later rebuild and garbage collection could remove from under them.
      UV_PYTHON_PREFERENCE = "only-managed";
    };
    initContent = ''
      ${builtins.readFile ./zsh-functions.zsh}

      [[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
    '';
  };

  home.sessionPath = [
    "$HOME/.local/bin"
    "$HOME/.local/share/pnpm/bin"
  ];

  programs.starship = {
    enable = true;
    settings = builtins.fromTOML (builtins.readFile ./starship.toml);
  };
}

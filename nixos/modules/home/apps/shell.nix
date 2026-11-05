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

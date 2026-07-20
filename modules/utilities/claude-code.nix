_: {
  flake.modules.homeManager.utilities = {
    programs.claude-code.enable = true;
    home.shellAliases = {
      claude = "claude --permission-mode=auto";
    };
  };
}

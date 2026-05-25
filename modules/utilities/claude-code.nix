_: {
  flake.modules.homeManager.utilities = {
    programs.claude-code.enable = true;
    home.shellAliases = {
      c = "claude --permission-mode bypassPermissions";
    };
  };
}

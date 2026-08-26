_: {
  flake.modules.homeManager.utilities = {
    programs.delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        navigate = true;
        line-numbers = true;
        side-by-side = false;
      };
    };
    home.shellAliases = {
      diff = "delta";
    };
  };
}

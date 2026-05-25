_: {
  flake.modules.homeManager.utilities = {
    home = {
      shell.enableShellIntegration = true;
      shellAliases = {
        top = "btop";
        du = "ncdu";
      };
    };
  };
}

{pkgs, ...}: {
  packages = with pkgs; [
    git
    gh
    just
  ];

  languages.nix.enable = true;
  languages.python.enable = true;

  git-hooks.hooks = {
    alejandra = {
      enable = true;
      settings.exclude = ["./.devenv"];
    };
    statix.enable = true;
    deadnix.enable = true;
  };
}

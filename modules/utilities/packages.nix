{inputs, ...}: {
  flake.modules.homeManager.utilities = {pkgs, ...}: {
    home.packages = [
      inputs.herdr.packages.${pkgs.system}.default
    ];
  };
}

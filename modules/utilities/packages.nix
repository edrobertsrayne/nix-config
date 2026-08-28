# {inputs, ...}: {
_: {
  flake.modules.homeManager.utilities = _: {
    home.packages = [
      # inputs.herdr.packages.${pkgs.system}.default
    ];
  };
}

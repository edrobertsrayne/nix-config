{inputs, ...}: let
  inherit (inputs.self.settings.user) username;
  hm = inputs.self.modules.homeManager;
in {
  flake.modules.nixos.home-manager = {
    config,
    lib,
    ...
  }: {
    imports = [inputs.home-manager.nixosModules.home-manager];

    home-manager = {
      backupFileExtension = "backup";
      useGlobalPkgs = true;
      useUserPackages = true;
      users.${username} = {
        imports = [
          hm.utilities
          hm.bash
          hm.neovim
          (hm.${config.networking.hostName} or {})
        ];
        home = {
          username = lib.mkDefault username;
          homeDirectory = lib.mkDefault "/home/${username}";
          stateVersion = "25.05";
        };
      };
    };
  };
}

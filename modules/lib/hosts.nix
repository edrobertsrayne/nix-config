{
  inputs,
  lib,
  ...
}: {
  flake.lib.mkNixosSystem = {
    name,
    system ? "x86_64-linux",
  }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        inputs.self.modules.nixos.common
        inputs.self.modules.nixos.home-manager
        inputs.self.modules.nixos.interfaces
        (inputs.self.modules.nixos.${name} or {})
        {
          networking.hostId = lib.mkDefault (builtins.substring 0 8 (
            builtins.hashString "sha256" "${name}"
          ));
          networking.hostName = lib.mkDefault name;
          nixpkgs.hostPlatform = lib.mkDefault system;
          system.stateVersion = "25.05";
        }
      ];
    };
}

{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.media = {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Jellyseerr";
        subdomain = "seerr";
        aliases = ["jellyseerr"];
        port = ports.media.seerr;
        group = "Media";
        description = "Request manager";
        icon = "jellyseerr.png";
      })
    ];

    services.seerr.enable = true;
  };
}

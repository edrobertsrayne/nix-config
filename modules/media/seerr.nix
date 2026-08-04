{inputs, ...}: let
  inherit (inputs.self.settings) ports;
in {
  flake.modules.nixos.seerr = {
    imports = [
      (inputs.self.lib.mkProxiedService {
        name = "Jellyseerr";
        subdomain = "seerr";
        aliases = ["jellyseerr"];
        port = ports.media.seerr;
        group = "Media";
        description = "Request manager";
        icon = "jellyseerr.png";
        probePath = "/api/v1/status";
      })
    ];

    services.seerr.enable = true;
  };
}
